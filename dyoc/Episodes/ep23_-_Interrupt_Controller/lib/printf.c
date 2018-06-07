#include <string.h>     // memmove() and memset()
#include <stdint.h>     // uint8_t, etc.
#include "memorymap.h"  // MEM_CHAR
#include "printf.h"     // H_CHARS and V_CHARS

// Simple implementation of printf. Only supports printing text strings.
// A newline will jump to the beginning of the next line.

void printf(char* str)
{
   // Current position of cursor
   static uint8_t x=0, y=0;

   int i;

   for (i = 0; str[i] != '\0'; ++i)
   {
      switch (str[i])
      {
         case '\n':
            x = 0;
            y++;
            break;

         default:
            MEM_CHAR[H_CHARS*y+x] = str[i];
            x++;
            break;
      } // end of switch

      if (x >= H_CHARS)
      {
         x = 0;
         y++;
      }

      if (y >= V_CHARS)
      {
         // Move entire screen up one line
         memmove(MEM_CHAR,                   // destination is start of first line.
                 MEM_CHAR + H_CHARS,         // source is start of second line.
                 H_CHARS*(V_CHARS-1));       // length is screen minus one line.

         // Clear bottom line
         memset(MEM_CHAR + H_CHARS*(V_CHARS-1),       // destination is start of last line.
                ' ',                                  // character is space.
                H_CHARS);                             // size if one line.

         y = V_CHARS-1;
         x = 0;
      }
   } // end of for
} // end of printf

// Print an 8-bit hexadecimal number
void printfHex8(uint8_t key)
{
    char foo[3] = "00";
    const char* hex = "0123456789ABCDEF";
    foo[0] = hex[(key >> 4) & 0xF];
    foo[1] = hex[key & 0xF];
    printf(foo);
} // end of printfHex8

// Print a 16-bit hexadecimal number
void printfHex16(uint16_t key)
{
    printfHex8((key >> 8) & 0xFF);
    printfHex8( key & 0xFF);
} // end of printfHex16

