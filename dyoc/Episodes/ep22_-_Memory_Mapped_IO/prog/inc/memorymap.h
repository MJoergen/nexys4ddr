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

// Memory mapped IO
typedef struct
{
   uint8_t  vgaPalette[16];   // 7FC0 - 7FCF
   uint8_t  _reserved[16];
} t_memio_config;

typedef struct
{
   uint16_t vgaPixX;          // 7FE0 - 7FE1
   uint16_t vgaPixY;          // 7FE2 - 7FE3
   uint8_t  _reserved[28];
} t_memio_status;

#define MEMIO_CONFIG ((t_memio_config *) 0x7FC0)
#define MEMIO_STATUS ((t_memio_status *) 0x7FE0)

#endif // _MEMORY_MAP_H_
