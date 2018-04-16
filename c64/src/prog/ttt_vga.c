//
// This implements the Tic-Tac-Toe game.
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "keyboard.h"

#define COL_WHITE       0xFFU  // 111_111_11
#define COL_LIGHT       0x6E   // 011_011_10
#define COL_DARK        0x24   // 001_001_00
#define COL_BLACK       0x00   // 000_000_00

#define BOARD_YPOS      0x20
#define BOARD_XPOS      0x20

// External declaration
extern char pieces[9];

static const char bitmap_X[32] = {
   0xE0, 0x07,
   0xF0, 0x0F,
   0xF8, 0x1F,
   0x7C, 0x3E,
   0x3E, 0x7C,
   0x1F, 0xF8,
   0x0F, 0xF0,
   0x07, 0xE0,
   0x07, 0xE0,
   0x0F, 0xF0,
   0x1F, 0xF8,
   0x3E, 0x7C,
   0x7C, 0x3E,
   0xF8, 0x1F,
   0xF0, 0x0F,
   0xE0, 0x07};

static const char bitmap_O[32] = {
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

static const char bitmap_board[32] = {
   0xff, 0xff,
   0x84, 0x21,
   0x84, 0x21,
   0x84, 0x21,
   0x84, 0x21,
   0xff, 0xff,
   0x84, 0x21,
   0x84, 0x21,
   0x84, 0x21,
   0x84, 0x21,
   0xff, 0xff,
   0x84, 0x21,
   0x84, 0x21,
   0x84, 0x21,
   0x84, 0x21,
   0xff, 0xff};

static void __fastcall__ my_memcpy(void)
{
loop:
   __asm__("DEY");
   __asm__("LDA (%b),Y", ZP_SRC_LO);
   __asm__("STA (%b),Y", ZP_DST_LO);
   __asm__("TYA");
   __asm__("BNE %g", loop);
} // end of my_memcpy

void __fastcall__ vga_init(void)
{
   // Configure text color
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w",  VGA_ADDR_FGCOL);
   __asm__("LDA #%b", COL_DARK);
   __asm__("STA %w",  VGA_ADDR_BGCOL);

   // Configure sprite 0 as the playing board
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_0_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_0_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #<%v", bitmap_board);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_board);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();

   __asm__("LDA #<%w", BOARD_XPOS);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X);
   __asm__("LDA #>%w", BOARD_XPOS);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X_MSB);
   __asm__("LDA #%b", BOARD_YPOS);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_Y);
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w", VGA_ADDR_SPRITE_0_COL);
   __asm__("LDA #$05"); // Magnification = x4
   __asm__("STA %w", VGA_ADDR_SPRITE_0_ENA);

   __asm__("LDA #<%w", BOARD_XPOS+4);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X);
   __asm__("LDA #>%w", BOARD_XPOS+4);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_X_MSB);

   __asm__("LDA #<%w", BOARD_XPOS+24);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X);
   __asm__("LDA #>%w", BOARD_XPOS+24);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_X_MSB);

   __asm__("LDA #<%w", BOARD_XPOS+44);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_X);
   __asm__("LDA #>%w", BOARD_XPOS+44);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_X_MSB);

   __asm__("LDA #%b", COL_WHITE);
   __asm__("STA %w", VGA_ADDR_SPRITE_1_COL);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_COL);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_COL);

   __asm__("LDA #%b", BOARD_YPOS);
   __asm__("STA %w", VGA_ADDR_YLINE); // The line number for interrupt
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_MASK); // Enable IRQ
   __asm__("CLI");
} // end of initScreen

// Maskable interrupt
void __fastcall__ vga_irq(void)
{
   __asm__("LDA %w", VGA_ADDR_IRQ);
   __asm__("STA %w", VGA_ADDR_IRQ); // Clear latched IRQ
   __asm__("LDA %w", VGA_ADDR_YLINE); // The line number for interrupt
   __asm__("CLC");
   __asm__("ADC #$04");
   __asm__("STA %w", VGA_ADDR_SPRITE_1_Y);
   __asm__("STA %w", VGA_ADDR_SPRITE_2_Y);
   __asm__("STA %w", VGA_ADDR_SPRITE_3_Y);
   __asm__("LDA %w", VGA_ADDR_YLINE); // The line number for interrupt
   __asm__("CMP #%b", BOARD_YPOS);
   __asm__("BEQ %g", row1);
   __asm__("CMP #%b", BOARD_YPOS+20);
   __asm__("BEQ %g", row2);
   __asm__("CMP #%b", BOARD_YPOS+40);
   __asm__("BEQ %g", row3);
   __asm__("RTS");

row1:
   __asm__("LDA #%b", BOARD_YPOS+20);
   __asm__("STA %w", VGA_ADDR_YLINE);
   __asm__("LDX #$00");
   __asm__("JMP %g", row);

row2:
   __asm__("LDA #%b", BOARD_YPOS+40);
   __asm__("STA %w", VGA_ADDR_YLINE);
   __asm__("LDX #$03");
   __asm__("JMP %g", row);

row3:
   __asm__("LDA #%b", BOARD_YPOS);
   __asm__("STA %w", VGA_ADDR_YLINE);
   __asm__("LDX #$06");

row:
   __asm__("LDA %v,X", pieces);
   __asm__("BEQ %g", col1empty);
   __asm__("CMP #%b", 'X');
   __asm__("BEQ %g", col1x);
   __asm__("CMP #%b", 'O');
   __asm__("BEQ %g", col1o);
   __asm__("JMP %g", col2);
col1empty:
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_1_ENA);
   __asm__("JMP %g", col2);
col1x:
   __asm__("LDA #<%v", bitmap_X);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_X);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("JMP %g", col1enable);
col1o:
   __asm__("LDA #<%v", bitmap_O);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_O);
   __asm__("STA %b", ZP_SRC_HI);
col1enable:
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_1_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_1_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_1_ENA);

col2:
   __asm__("INX");
   __asm__("LDA %v,X", pieces);
   __asm__("BEQ %g", col2empty);
   __asm__("CMP #%b", 'X');
   __asm__("BEQ %g", col2x);
   __asm__("CMP #%b", 'O');
   __asm__("BEQ %g", col2o);
   __asm__("JMP %g", col3);
col2empty:
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_2_ENA);
   __asm__("JMP %g", col3);
col2x:
   __asm__("LDA #<%v", bitmap_X);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_X);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("JMP %g", col2enable);
col2o:
   __asm__("LDA #<%v", bitmap_O);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_O);
   __asm__("STA %b", ZP_SRC_HI);
col2enable:
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_2_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_2_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_2_ENA);

col3:
   __asm__("INX");
   __asm__("LDA %v,X", pieces);
   __asm__("BEQ %g", col3empty);
   __asm__("CMP #%b", 'X');
   __asm__("BEQ %g", col3x);
   __asm__("CMP #%b", 'O');
   __asm__("BEQ %g", col3o);
   __asm__("JMP %g", end);
col3empty:
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_3_ENA);
   __asm__("JMP %g", end);
col3x:
   __asm__("LDA #<%v", bitmap_X);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_X);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("JMP %g", col3enable);
col3o:
   __asm__("LDA #<%v", bitmap_O);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", bitmap_O);
   __asm__("STA %b", ZP_SRC_HI);
col3enable:
   __asm__("LDA #<%w", VGA_ADDR_SPRITE_3_BITMAP);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SPRITE_3_BITMAP);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #$20");
   __asm__("TAY");
   my_memcpy();
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_3_ENA);

end:
   __asm__("RTS");

} // end of irq

