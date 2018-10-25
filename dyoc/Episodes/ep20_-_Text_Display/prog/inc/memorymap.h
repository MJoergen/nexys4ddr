#ifndef _MEMORY_MAP_H_
#define _MEMORY_MAP_H_

#include <stdint.h>

#define MEM_RAM  ((uint8_t *) 0x0000)
#define MEM_CHAR ((uint8_t *) 0x8000)
#define MEM_COL  ((uint8_t *) 0xA000)
#define MEM_ROM  ((uint8_t *) 0xC000)

#define SIZE_RAM  (0x8000)
#define SIZE_CHAR (0x2000)
#define SIZE_COL  (0x2000)
#define SIZE_ROM  (0x4000)

#endif // _MEMORY_MAP_H_
