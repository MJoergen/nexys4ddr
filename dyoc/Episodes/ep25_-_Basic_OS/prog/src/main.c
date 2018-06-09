#include <6502.h>                // CLI()
#include <string.h>              // memmove
#include "keyboard.h"
#include "vga.h"
#include "memorymap.h"

static void putchxy(uint8_t x, uint8_t y, uint8_t ch, uint8_t col)
{
   MEM_CHAR[80*y+x] = ch;
   MEM_COL[80*y+x] = col;
} // end of putchxy

static uint8_t curs_x = 0;
static uint8_t curs_y = 0;
static uint8_t curs_col = 0x0F;     // White text on black background.

static void readline()
{
   // Just go into a busy loop
   while (1)
   {
      uint8_t ch;

      vga_cursor_enable(&MEM_COL[80*curs_y+curs_x]);
      ch = kbd_getchar();    // Wait for next character.
      vga_cursor_disable();

      switch (ch)
      {
         case 0x08 :    // Backspace
            if (curs_x>0)
            {
               curs_x--;
               memmove(&MEM_CHAR[80*curs_y+curs_x], &MEM_CHAR[80*curs_y+curs_x+1], 79-curs_x);
               memmove(&MEM_COL[80*curs_y+curs_x], &MEM_COL[80*curs_y+curs_x+1], 79-curs_x);
            }
            break;

         case 0x7F :    // Delete
            memmove(&MEM_CHAR[80*curs_y+curs_x], &MEM_CHAR[80*curs_y+curs_x+1], 79-curs_x);
            memmove(&MEM_COL[80*curs_y+curs_x], &MEM_COL[80*curs_y+curs_x+1], 79-curs_x);
            break;

         case 0x1B :    // Left
            if (curs_x>0)
            {
               curs_x--;
            }
            break;

         case 0x1A :    // Right
            if (curs_x<79)
            {
               curs_x++;
            }
            break;

         case 0x02 :    // Home
            curs_x = 0;
            break;

         case 0x03 :    // End
            if (MEM_CHAR[80*curs_y+79] != ' ')
            {
               curs_x = 79;
               break;
            }
            for (curs_x=78; curs_x>0; --curs_x)
            {
               if (MEM_CHAR[80*curs_y+curs_x] != ' ')
               {
                  curs_x++;
                  break;
               }
            }
            break;

         case 0x0D :    // Newline
            return;

         default :      // Ordinary character
            memmove(&MEM_CHAR[80*curs_y+curs_x+1], &MEM_CHAR[80*curs_y+curs_x], 79-curs_x);
            memmove(&MEM_COL[80*curs_y+curs_x+1], &MEM_COL[80*curs_y+curs_x], 79-curs_x);
            putchxy(curs_x, curs_y, ch, curs_col);
            if (curs_x<79)
            {
               curs_x++;
            }
            break;

      }   // end of case
   } // end of while (1)
} // end of readline


// Called from crt0.s
void main()
{
   uint8_t dummy;

   *VGA_PIX_Y_INT = PIXELS_Y-1;     // Generate interrupts at end of last line.
   vga_cursor_disable();            // Make sure cursor is disabled before enabling interrupts.
   dummy = *IRQ_STATUS;             // Clear any pending interrupts.
   *IRQ_MASK = IRQ_KBD | IRQ_VGA;   // Enable keyboard and VGA interupts.
   CLI();                           // Enable CPU interrupts.

   while (1)
   {
      readline(); // Return when user hits Enter.

      // Go to start of next line
      curs_y++;
      curs_x = 0;
   }

} // end of main

