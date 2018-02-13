// This contains definitions of the memory map of the VGA controller
// 0x8000 - 0x83FF : Chars Memory
// 0x8400 - 0x85FF : Bitmap Memory
// 0x8600 - 0x87FF : Config and Status

// The VGA screen contains 40 x 18 characters and is located at 0x8000.
#define VGA_ADDR_SCREEN          0x8000
#define VGA_SCREEN_SIZE_X        40
#define VGA_SCREEN_SIZE_Y        18

#define VGA_ADDR_SPRITE_0_BITMAP 0x8400    // Sprite 0 bitmap
#define VGA_ADDR_SPRITE_1_BITMAP 0x8420    // Sprite 1 bitmap
#define VGA_ADDR_SPRITE_2_BITMAP 0x8440    // Sprite 2 bitmap
#define VGA_ADDR_SPRITE_3_BITMAP 0x8460    // Sprite 3 bitmap

#define VGA_ADDR_SPRITE_0_X      0x8600    // X position
#define VGA_ADDR_SPRITE_0_X_MSB  0x8601    // Bit 0 : X position MSB
#define VGA_ADDR_SPRITE_0_Y      0x8602    // Y position
#define VGA_ADDR_SPRITE_0_COL    0x8603    // Color (RRRGGGBB)
#define VGA_ADDR_SPRITE_0_ENA    0x8604    // Bit 0 : Enabled

#define VGA_ADDR_SPRITE_1_X      0x8610    // X position
#define VGA_ADDR_SPRITE_1_X_MSB  0x8611    // Bit 0 : X position MSB
#define VGA_ADDR_SPRITE_1_Y      0x8612    // Y position
#define VGA_ADDR_SPRITE_1_COL    0x8613    // Color (RRRGGGBB)
#define VGA_ADDR_SPRITE_1_ENA    0x8614    // Bit 0 : Enabled

#define VGA_ADDR_SPRITE_2_X      0x8620    // X position
#define VGA_ADDR_SPRITE_2_X_MSB  0x8621    // Bit 0 : X position MSB
#define VGA_ADDR_SPRITE_2_Y      0x8622    // Y position
#define VGA_ADDR_SPRITE_2_COL    0x8623    // Color (RRRGGGBB)
#define VGA_ADDR_SPRITE_2_ENA    0x8624    // Bit 0 : Enabled

#define VGA_ADDR_SPRITE_3_X      0x8630    // X position
#define VGA_ADDR_SPRITE_3_X_MSB  0x8631    // Bit 0 : X position MSB
#define VGA_ADDR_SPRITE_3_Y      0x8632    // Y position
#define VGA_ADDR_SPRITE_3_COL    0x8633    // Color (RRRGGGBB)
#define VGA_ADDR_SPRITE_3_ENA    0x8634    // Bit 0 : Enabled

#define VGA_ADDR_IRQ             0x8640    // Bit 0 : Y-line interrupt
#define VGA_ADDR_YLINE           0x8641    // The line number for interrupt
#define VGA_ADDR_MASK            0x8642    // Bit 0 : Y-line interrupt
#define VGA_ADDR_XSCROLL         0x8643    // Bits 3-0 : X-scroll
#define VGA_ADDR_FGCOL           0x8650    // Character foreground colour
#define VGA_ADDR_BGCOL           0x8651    // Character background colour

