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
   uint16_t vgaPixYInt;       // 7FD0 - 7FD1
   uint8_t  _reserved2;       // 7FD2
   uint8_t  ethRxdmaEnable;   // 7FD3
   uint16_t ethRxdmaPtr;      // 7FD4 - 7FD5
   uint8_t  _reserved[9];
   uint8_t  irqMask;          // 7FDF
} t_memio_config;

typedef struct
{
   uint16_t vgaPixX;          // 7FE0 - 7FE1
   uint16_t vgaPixY;          // 7FE2 - 7FE3
   uint8_t  kbdData;          // 7FE4
   uint8_t  ethRxPending;     // 7FE5
   uint16_t ethRxCnt;         // 7FE6 - 7FE7
   uint8_t  ethRxErr;         // 7FE8
   uint8_t  ethRxOverflow;    // 7FE9
   uint8_t  _reserved2[21];
   uint8_t  irqStatus;        // 7FFF
} t_memio_status;

#define MEMIO_CONFIG ((t_memio_config *) 0x7FC0)
#define MEMIO_STATUS ((t_memio_status *) 0x7FE0)

#define IRQ_TIMER_NUM    0
#define IRQ_VGA_NUM      1
#define IRQ_KBD_NUM      2

#endif // _MEMORY_MAP_H_

