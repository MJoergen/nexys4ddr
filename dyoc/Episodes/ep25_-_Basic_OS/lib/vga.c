#include <6502.h>                // CLI()
#include "memorymap.h"

// This is nonzero, if the cursor is enabled and the
// cursor position is valid.
static uint8_t curs_enable = 0;

// This is the state of the blinking cursor
// zero means the cursor is currently off (invisible),
// nonzero means it is on (colours are inverted).
static uint8_t curs_state = 0;

// This is a countdown for when the state is to change.
static uint8_t curs_cnt = 0;

#pragma bss-name (push,"ZEROPAGE")

// This is the current cursor position in colour memory.
static uint8_t curs_pos_lo;
static uint8_t curs_pos_hi;

#pragma bss-name (pop)

void cursor_enable(uint8_t *cursor_pos)
{
   (void)cursor_pos;

   // Store the pointer.
   __asm__("STA %v", curs_pos_lo);
   __asm__("STX %v", curs_pos_hi);

   // Clear current cursor state (not inverted)
   __asm__("LDA #$00");
   __asm__("STA %v", curs_state);

   // Set initial value of cursor counter
   __asm__("LDA #$14");
   __asm__("STA %v", curs_cnt);

   // Enable the cursor
   __asm__("LDA #$01");
   __asm__("STA %v", curs_enable);
} // end of cursor_enable


void cursor_disable()
{
   // Disable the cursor
   __asm__("LDA #$00");
   __asm__("STA %v", curs_enable);

   // Is cursor inverted
   __asm__("LDA %v", curs_state);
   __asm__("BEQ %g", end);

   // Ok, we assume the cursor position to be valid.
   __asm__("LDY #$00");
   __asm__("LDA (%v),Y", curs_pos_lo);
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("STA (%v),Y", curs_pos_lo);

end:
   __asm__("RTS");
} // end of cursor_disable


void vga_isr()
{
   // Is the cursor enabled
   __asm__("LDA %v", curs_enable);
   __asm__("BEQ %g", end); // Jump if no

   // Should we change cursor state?
   __asm__("DEC %v", curs_cnt);
   __asm__("BNE %g", end); // Jump if no

   // Ok, we assume the cursor position to be valid.
   __asm__("LDY #$00");
   __asm__("LDA (%v),Y", curs_pos_lo);
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("ASL");
   __asm__("ADC #$00");
   __asm__("STA (%v),Y", curs_pos_lo);

   // Change the cursor state
   __asm__("LDA %v", curs_state);
   __asm__("EOR #$FF");
   __asm__("STA %v", curs_state);

end:
   __asm__("RTS");
} // end of vga_isr

