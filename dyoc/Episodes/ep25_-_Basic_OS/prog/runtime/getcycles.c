#include <stdint.h>

#include "getcycles.h"
#include "memorymap.h"

uint32_t getcycles(void)
{
   uint32_t now;

   MEMIO_CONFIG->cpuCycLatch = 1;
   now = MEMIO_STATUS->cpuCyc;
   MEMIO_CONFIG->cpuCycLatch = 0;

   return now;

} // end of getcycles


