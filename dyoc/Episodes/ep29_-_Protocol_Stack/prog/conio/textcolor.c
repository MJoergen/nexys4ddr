#include <stdint.h>
#include <conio.h>

#include "memorymap.h"

uint8_t textcolor(uint8_t newCol)
{
   uint8_t oldCol = MEMIO_CONFIG->vgaPalette[15];
   MEMIO_CONFIG->vgaPalette[15] = newCol;
   return oldCol;
}


