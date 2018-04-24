//
// This implements a simple tennis game
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "tennis.h"
#include "tennis_ball.h"
#include "tennis_player.h"
#include "tennis_ai.h"
#include "smult.h"

extern char ball_vx_lo;
extern char ball_vx_hi;
extern char ball_vy_lo;
extern char ball_vy_hi;

static const char bitmap_ball[32] = {
   0x01, 0x80,
   0x0F, 0xF0,
   0x3F, 0xFC,
   0x3F, 0xFC,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0xFF, 0xFF,
   0xFF, 0xFF,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0x3F, 0xFC,
   0x3F, 0xFC,
   0x0F, 0xF0,
   0x01, 0x80};

static const char bitmap_player[32] = {
   0x01, 0x80,
   0x0F, 0xF0,
   0x3F, 0xFC,
   0x3F, 0xFC,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0xFF, 0xFF,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00};

static const char bitmap_wall[32] = {
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0,
   0x03, 0xC0};

void __fastcall__ my_memcpy(void)
{
loop:
   __asm__("DEY");
   __asm__("LDA (%b),Y", ZP_SRC_LO);
   __asm__("STA (%b),Y", ZP_DST_LO);
   __asm__("TYA");
   __asm__("BNE %g", loop);
} // end of my_memcpy

void __fastcall__ my_memset(void)
{
   __asm__("TAX");
loop:
   __asm__("DEY");
   __asm__("TXA");
   __asm__("STA (%b),Y", ZP_DST_LO);
   __asm__("TYA");
   __asm__("BNE %g", loop);
} // end of my_memset

static void __fastcall__ clearScreen(void)
{
   // Clear the screen
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("LDA #$80");
   __asm__("STA %b", ZP_SCREEN_POS_HI);
   __asm__("LDA #$00");
   __asm__("TAY");
clear:
   __asm__("LDA #$20");
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);
   __asm__("INY");
   __asm__("BNE %g", clear);
   __asm__("LDA %b", ZP_SCREEN_POS_HI);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %b", ZP_SCREEN_POS_HI);
   __asm__("CMP #$84");
   __asm__("BNE %g", clear);
   __asm__("RTS");
} // end of clearScreen

void __fastcall__ vga_init(void)
{
   // Configure text color
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w",  VGA_ADDR_FGCOL);
   __asm__("LDA #%b", COL_DARK);
   __asm__("STA %w",  VGA_ADDR_BGCOL);

   // Configure sprite 0 as the ball
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_0_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_0_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #<%v", bitmap_ball);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_ball);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();

   // Configure sprite 1 as the left player
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_1_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_1_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #<%v", bitmap_player);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_player);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();

   // Configure sprite 2 as the right player
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_2_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_2_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #<%v", bitmap_player);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_player);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();

   // Configure sprite 3 as the wall
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_3_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_3_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #<%v", bitmap_wall);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_wall);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();

   // Configure ball
   __asm__("LDA #<%w", WALL_XPOS/2);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X);
   __asm__("LDA #>%w", WALL_XPOS/2);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X_MSB);
   __asm__("LDA #%b", WALL_YPOS/2);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_Y);
   __asm__("LDA #%b", COL_RED);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_COL);
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_ENA);

   // Configure left player
   __asm__("LDA #<%w", WALL_XPOS/2);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X);
   __asm__("LDA #>%w", WALL_XPOS/2);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X_MSB);
   __asm__("LDA #%b", WALL_YPOS+8);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_Y);
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_COL);
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_1_ENA);

   // Configure right player
   __asm__("LDA #<%w", (3*WALL_XPOS)/2);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA #>%w", WALL_XPOS/2);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("LDA #%b", WALL_YPOS+8);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_Y);
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_COL);
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_2_ENA);

   // Configure wall
   __asm__("LDA #<%w", WALL_XPOS);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_X);
   __asm__("LDA #>%w", WALL_XPOS);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_X_MSB);
   __asm__("LDA #%b", WALL_YPOS);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_Y);
   __asm__("LDA #%b", COL_WHITE);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_COL);
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_3_ENA);
} // end of vga_init

// Entry point after CPU reset
void __fastcall__ reset(void)
{
   __asm__("SEI");                           // Disable all interrupts
   __asm__("LDX #$FF");
   __asm__("TXS");                           // Reset stack pointer

   smult_init();
   clearScreen();

   // Initialize ball position and velocity
   ball_reset();

   // Now we have A11 in 'A' and A12 in 'X'.
   //__asm__("LDA #$58");
   //__asm__("LDX #$A3");
   //ball_rotate();

   vga_init();

   __asm__("LDA #%b", WALL_YPOS+16);
   __asm__("STA %w", VGA_ADDR_YLINE); // The line number for interrupt
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_MASK); // Enable IRQ
   __asm__("CLI");

   // Just busy wait here. Everything is processed during IRQ.
loop:
   __asm__("JMP %g", loop);
} // end of reset


// Maskable interrupt
void __fastcall__ irq(void)
{
   __asm__("LDA %w", VGA_ADDR_IRQ);  // Read IRQ status
   __asm__("STA %w", VGA_ADDR_IRQ);  // Clear IRQ assertion.

   // checkGameOver
   __asm__("LDA %v", ball_y_hi);
   __asm__("CMP #%b", WALL_YPOS/2+8);
   __asm__("BCC %g", checkLeftBounce);

   // Game over: Ball fell out of bottom of screen.
   ball_reset();

checkLeftBounce:
   __asm__("LDA %v", ball_x_hi);
   __asm__("CMP #$D0");
   // Are we past the left wall?
   __asm__("BCC %g", checkRightBounce);

   // Snap to left wall
   __asm__("LDA #$00");
   __asm__("STA %v", ball_x_lo);
   __asm__("STA %v", ball_x_hi);

   // Are we moving to the right?
   __asm__("LDA %v", ball_vx_hi);
   __asm__("BPL %g", checkRightBounce);

   // Reflect
   __asm__("LDA %v", ball_vx_lo);
   __asm__("EOR #$FF");
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %v", ball_vx_lo);
   __asm__("LDA %v", ball_vx_hi);
   __asm__("EOR #$FF");
   __asm__("ADC #$00");
   __asm__("STA %v", ball_vx_hi);
   
checkRightBounce:
   __asm__("LDA %v", ball_x_hi);
   // Are we past the right wall?
   __asm__("CMP #%b", SIZE_X/2-8);
   __asm__("BCC %g", checkCollisionPlayer);

   // Snap to right wall
   __asm__("LDA #$00");
   __asm__("STA %v", ball_x_lo);
   __asm__("LDA #%b", SIZE_X/2-8);
   __asm__("STA %v", ball_x_hi);

   // Are we moving to the left?
   __asm__("LDA %v", ball_vx_hi);
   __asm__("BMI %g", checkCollisionPlayer);

   // Reflect
   __asm__("LDA %v", ball_vx_lo);
   __asm__("EOR #$FF");
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %v", ball_vx_lo);
   __asm__("LDA %v", ball_vx_hi);
   __asm__("EOR #$FF");
   __asm__("ADC #$00");
   __asm__("STA %v", ball_vx_hi);

checkCollisionPlayer:
   __asm__("LDA %w", VGA_COLL);  // Read collision status
   __asm__("AND #$03");
   __asm__("CMP #$03");
   __asm__("BNE %g", checkCollisionAi);

   // Get players coordinates, and divide by 2.
   __asm__("LDA %w", VGA_ADDR_SPRITE_1_X_MSB);
   __asm__("ROR A");  // Move MSB to carry
   __asm__("LDA %w", VGA_ADDR_SPRITE_1_X);
   __asm__("ROR A");
   __asm__("TAX");

   __asm__("LDA %w", VGA_ADDR_SPRITE_1_Y);
   __asm__("CLC");
   __asm__("ROR A");

   ball_bounce();

#if 0
loop:
   __asm__("LDA %b", ZP_BALL_T0);
//   __asm__("LDA %v", ball_vx_lo);
   __asm__("STA %w", 0x8614);
   __asm__("LDA %b", ZP_BALL_T1);
 //  __asm__("LDA %v", ball_vx_hi);
   __asm__("STA %w", 0x8615);
   __asm__("LDA %b", ZP_BALL_T2);
//   __asm__("LDA %v", ball_vy_lo);
   __asm__("STA %w", 0x8616);
   __asm__("LDA %b", ZP_BALL_T3);
//   __asm__("LDA %v", ball_vy_hi);
   __asm__("STA %w", 0x8617);
   __asm__("JMP %g", loop);
#endif

checkCollisionAi:
   __asm__("LDA %w", VGA_COLL);  // Read collision status
   __asm__("AND #$05");
   __asm__("CMP #$05");
   __asm__("BNE %g", update);

   // Get AIs coordinates, and divide by 2.
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X_MSB);
   __asm__("ROR A");  // Move MSB to carry
   __asm__("LDA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("ROR A");
   __asm__("TAX");

   __asm__("LDA %w", VGA_ADDR_SPRITE_2_Y);
   __asm__("CLC");
   __asm__("ROR A");

   ball_bounce();

update:
   ai_move();
   ball_move();
   player_move();

   // Clear collision status
   __asm__("LDA %w", VGA_COLL);
   __asm__("STA %w", VGA_COLL); 

   __asm__("RTI");
} // end of irq

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

