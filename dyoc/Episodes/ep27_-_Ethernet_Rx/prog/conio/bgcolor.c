#include <stdint.h>     // uint8_t, etc.
#include <conio.h>
#include "memorymap.h"

uint8_t bgcolor(uint8_t newCol)
{
   uint8_t oldCol = MEMIO_CONFIG->vgaPalette[0];
   MEMIO_CONFIG->vgaPalette[0] = newCol;
   return oldCol;
}

