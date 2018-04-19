#include "memorymap.h"
#include "keyboard.h"
#include "tennis.h"

#define KEYB_SHIFT_LEFT   0x12
#define KEYB_SHIFT_RIGHT  0x59

void __fastcall__ player_move(void)
{
   readCurrentKey();
   __asm__("CMP #%b", KEYB_SHIFT_LEFT);
   __asm__("BEQ %g", left);
   __asm__("CMP #%b", KEYB_SHIFT_RIGHT);
   __asm__("BEQ %g", right);
   __asm__("RTS");

left:
   __asm__("LDA %w", VGA_ADDR_SPRITE_1_X);
   __asm__("CMP #%b", PLAYER_LEFT_MARGIN + PLAYER_VEL);
   __asm__("BCS %g", moveLeft);
   __asm__("LDA #%b", PLAYER_LEFT_MARGIN + PLAYER_VEL);
   
moveLeft:
   __asm__("SEC");
   __asm__("SBC #%b", PLAYER_VEL);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X);

   __asm__("LDA %w", VGA_ADDR_SPRITE_1_X_MSB);
   __asm__("SBC #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X_MSB);
   __asm__("RTS");

right:
   __asm__("LDA %w", VGA_ADDR_SPRITE_1_X);
   __asm__("CMP #%b", PLAYER_RIGHT_MARGIN - PLAYER_VEL - 16);
   __asm__("BCC %g", moveRight);
   __asm__("LDA #%b", PLAYER_RIGHT_MARGIN - PLAYER_VEL - 16);

moveRight:
   __asm__("CLC");
   __asm__("ADC #%b", PLAYER_VEL);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X);

   __asm__("LDA %w", VGA_ADDR_SPRITE_1_X_MSB);
   __asm__("ADC #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X_MSB);
   __asm__("RTS");
} // end of player_move

