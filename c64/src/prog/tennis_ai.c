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

ret:
   __asm__("RTS");

moveLeft:
   // Mode to the left
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("SEC");
   __asm__("SBC #%b", AI_VEL);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("SBC #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);

   // Have we passed the wall?
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("SEC");
   __asm__("SBC #<%w", AI_LEFT_MARGIN);
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("SBC #>%w", AI_LEFT_MARGIN);
   __asm__("BCS %g", ret);

   // Snap to wall
   __asm__("LDA #<%w", AI_LEFT_MARGIN);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA #>%w", AI_LEFT_MARGIN);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);
   
   __asm__("RTS");

moveRight:
   // Mode to the right
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("CLC");
   __asm__("ADC #%b", AI_VEL);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("ADC #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);

   // Have we passed the wall?
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("SEC");
   __asm__("SBC #<%w", AI_RIGHT_MARGIN);
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("SBC #>%w", AI_RIGHT_MARGIN);
   __asm__("BCC %g", ret);

   // Snap to wall
   __asm__("LDA #<%w", AI_RIGHT_MARGIN);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA #>%w", AI_RIGHT_MARGIN);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);
   
   __asm__("RTS");

} // end of ai_move

