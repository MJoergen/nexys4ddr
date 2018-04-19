//
// This implements a simple tennis game
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "tennis.h"
#include "tennis_ball.h"
#include "tennis_player.h"

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
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x00, 0x00,
   0x01, 0x80,
   0x0F, 0xF0,
   0x3F, 0xFC,
   0x3F, 0xFC,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0x7F, 0xFE,
   0xFF, 0xFF};

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
   __asm__("LDA #%b", WALL_YPOS);
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
   __asm__("LDA #%b", WALL_YPOS);
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

   // Initialize ball position and velocity
   ball_reset();

   vga_init();

   __asm__("LDA #%b", WALL_YPOS+16);
   __asm__("STA %w", VGA_ADDR_YLINE); // The line number for interrupt
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_MASK); // Enable IRQ
   __asm__("CLI");

wait_for_keyboard:
   __asm__("LDA %w", VGA_KEY);
   __asm__("BEQ %g", wait_for_keyboard);     // Wait until keyboard information ready

   __asm__("JMP %g", wait_for_keyboard);
} // end of reset

// Maskable interrupt
void __fastcall__ irq(void)
{
   __asm__("LDA %w", VGA_ADDR_IRQ);  // Read IRQ status
   __asm__("STA %w", VGA_ADDR_IRQ);  // Clear IRQ assertion.

   ball_move();
   player_move();

   __asm__("LDA %w", VGA_ADDR_SPRITE_0_Y);
   __asm__("CMP #%b", WALL_YPOS+16);
   __asm__("BCC %g", end);

   // Ball fell out of bottom of screen.
   ball_reset();

end:
   __asm__("RTI");
} // end of irq

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

