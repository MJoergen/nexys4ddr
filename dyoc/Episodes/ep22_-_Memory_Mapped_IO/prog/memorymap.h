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

#define VGA_CHAR_BG_COL  ((uint8_t *) 0x7FF0)
#define VGA_OVERL_FG_COL ((uint8_t *) 0x7FF1)
#define VGA_PIX_X_LOW    ((uint8_t *) 0x7FF8)
#define VGA_PIX_X_HIGH   ((uint8_t *) 0x7FF9)
#define VGA_PIX_Y_LOW    ((uint8_t *) 0x7FFA)
#define VGA_PIX_Y_HIGH   ((uint8_t *) 0x7FFB)

#endif // _MEMORY_MAP_H_
