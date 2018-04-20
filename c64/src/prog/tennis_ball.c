#include "memorymap.h"
#include "tennis.h"

/* Coordinates and velocities are stored in 16 bit numbers in fixed-point
 * representation, where the upper 9 bits are before the fixed-point, and the
 * lower 7 bits are after the fixed-point
 */
static char ball_x_hi;
static char ball_x_lo;
static char ball_y_hi;
static char ball_y_lo;
static char ball_vx_hi;
static char ball_vx_lo;
static char ball_vy_hi;
static char ball_vy_lo;

void __fastcall__ ball_reset(void)
{
   ball_x_hi  = WALL_XPOS/4-3;
   ball_x_lo  = 0;
   ball_y_hi  = WALL_YPOS/4;
   ball_y_lo  = 0;
   ball_vx_hi = 0;
   ball_vx_lo = 0;
   ball_vy_hi = 0;
   ball_vy_lo = 0;
} // end of ball_reset

void __fastcall__ ball_move(void)
{
   // Update velocity
   __asm__("LDA %v", ball_vy_lo);
   __asm__("CLC");
   __asm__("ADC #%b", GRAVITY);
   __asm__("STA %v", ball_vy_lo);
   __asm__("LDA %v", ball_vy_hi);
   __asm__("ADC #$00");
   __asm__("STA %v", ball_vy_hi);

   // Update position
   __asm__("LDA %v", ball_y_lo);
   __asm__("CLC");
   __asm__("ADC %v", ball_vy_lo);
   __asm__("STA %v", ball_y_lo);
   __asm__("LDA %v", ball_y_hi);
   __asm__("ADC %v", ball_vy_hi);
   __asm__("STA %v", ball_y_hi);

   __asm__("LDA %v", ball_x_lo);
   __asm__("CLC");
   __asm__("ADC %v", ball_vx_lo);
   __asm__("STA %v", ball_x_lo);
   __asm__("LDA %v", ball_x_hi);
   __asm__("ADC %v", ball_vx_hi);
   __asm__("STA %v", ball_x_hi);

   // Update VGA
   __asm__("LDA %v", ball_x_lo);
   __asm__("ROL A");
   __asm__("LDA %v", ball_x_hi);
   __asm__("ROL A");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X);
   __asm__("LDA #$00");
   __asm__("ROL A");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X_MSB);

   __asm__("LDA %v", ball_y_lo);
   __asm__("ROL A");
   __asm__("LDA %v", ball_y_hi);
   __asm__("ROL A");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_Y);
} // end of ball_move


