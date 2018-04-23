#include "memorymap.h"
#include "keyboard.h"
#include "tennis.h"
#include "tennis_ball.h"

void __fastcall__ ai_move(void)
{
   // Get AI's x-coordinate
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("ROR A");
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("ROR A");

   // Shall we move left?
   __asm__("CMP %v", ball_x_hi);
   __asm__("BCS %g", moveLeft);
   // Shall we move right?
   __asm__("BNE %g", moveRight);
return:
   __asm__("RTS");

moveLeft:
   // Can we move left?
   __asm__("CMP #%b", (AI_LEFT_MARGIN-AI_VEL)/2);
   __asm__("BCC %g", return);

   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("SEC");
   __asm__("SBC #%b", AI_VEL);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("SBC #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("RTS");

moveRight:
   // Can we move right?
   __asm__("CMP #%b", (AI_RIGHT_MARGIN+AI_VEL)/2);
   __asm__("BCS %g", return);

   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("CLC");
   __asm__("ADC #%b", AI_VEL);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("ADC #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("RTS");

} // end of ai_move

