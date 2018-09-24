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
   uint16_t ethStart;         // 7FD2 - 7FD3
   uint16_t ethEnd;           // 7FD4 - 7FD5
   uint16_t ethRdPtr;         // 7FD6 - 7FD7
   uint8_t  ethEnable;        // 7FD8
   uint8_t  ethTxCtrl;        // 7FD9
   uint16_t ethTxPtr;         // 7FDA - 7FDB
   uint8_t  cpuCycLatch;      // 7FDC
   uint8_t  _reserved[2];
   uint8_t  irqMask;          // 7FDF
} t_memio_config;

typedef struct
{
   uint16_t vgaPixX;          // 7FE0 - 7FE1
   uint16_t vgaPixY;          // 7FE2 - 7FE3
   uint32_t cpuCyc;           // 7FE4 - 7FE7
   uint8_t  kbdData;          // 7FE8
   uint8_t  _reserved;
   uint16_t ethWrPtr;         // 7FEA - 7FEB
   uint16_t ethCnt;           // 7FEC - 7FED
   uint8_t  ethErr0;          // 7FEE
   uint8_t  ethErr1;          // 7FEF
   uint8_t  _reserved2[22];
   uint8_t  irqStatus;        // 7FFF
} t_memio_status;

#define MEMIO_CONFIG ((t_memio_config *) 0x7FC0)
#define MEMIO_STATUS ((t_memio_status *) 0x7FE0)

#define IRQ_TIMER_NUM    0
#define IRQ_VGA_NUM      1
#define IRQ_KBD_NUM      2

#endif // _MEMORY_MAP_H_
