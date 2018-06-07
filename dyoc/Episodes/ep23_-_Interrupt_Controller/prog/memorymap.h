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

// Memory mapped IO

// Writeable 7FC0 - 7FDF
#define VGA_PALETTE      ((uint8_t *)  0x7FC0)  // array of 16 bytes
#define VGA_PIX_Y_INT    ((uint16_t *) 0x7FD0)
#define IRQ_MASK         ((uint8_t *)  0x7FDF)

// Readonly 7FE0 - 7FFF
#define VGA_PIX_X        ((uint16_t *) 0x7FE0)
#define VGA_PIX_Y        ((uint16_t *) 0x7FE2)
#define CPU_CYC          ((uint32_t *) 0x7FE4)
#define IRQ_STATUS       ((uint8_t *)  0x7FFF)
#define IRQ_VGA          0x01

#endif // _MEMORY_MAP_H_
