#ifndef _MEMORY_MAP_H_
#define _MEMORY_MAP_H_

#include "types.h"

#define MEM_RAM  ((uint8_t *) 0x0000)
#define MEM_CHAR ((uint8_t *) 0x8000)
#define MEM_COL  ((uint8_t *) 0xA000)
#define MEM_ROM  ((uint8_t *) 0xF800)

#define SIZE_RAM  (0x1000)
#define SIZE_CHAR (0x2000)
#define SIZE_COL  (0x2000)
#define SIZE_ROM  (0x0800)

// Writeable
#define VGA_CHAR_BG_COL  ((uint8_t *)  0x7FF0)
#define VGA_OVERL_FG_COL ((uint8_t *)  0x7FF1)
#define VGA_PIX_Y_INT    ((uint16_t *) 0x7FF2)
#define IRQ_MASK         ((uint8_t *)  0x7FF7)

// Readonly
#define VGA_PIX_X        ((uint16_t *) 0x7FF8)
#define VGA_PIX_Y        ((uint16_t *) 0x7FFA)
#define KBD_DATA         ((uint8_t *)  0x7FFE)
#define IRQ_STATUS       ((uint8_t *)  0x7FFF)

#endif // _MEMORY_MAP_H_
