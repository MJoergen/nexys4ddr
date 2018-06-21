#include <stdint.h>
#include <time.h>
#include <6502.h>       // SEI() and CLI()

#include "gettime.h"
#include "memorymap.h"

#define CLOCK_SPEED_MHZ 25

int clock_gettime(clockid_t clk_id, struct timespec *tp)
{
   uint32_t now;

   (void) clk_id; // This line avoid compiler warning about unused variable.

   if (tp)
   {
      MEMIO_CONFIG->cpuCycLatch = 1;
      now = MEMIO_STATUS->cpuCyc;
      MEMIO_CONFIG->cpuCycLatch = 0;

      tp->tv_sec = now / (CLOCK_SPEED_MHZ*1000000UL);
      now -= tp->tv_sec*(CLOCK_SPEED_MHZ*1000000UL);

      tp->tv_nsec = now * (1000 / CLOCK_SPEED_MHZ);
   }

   return 0;

} // end of clock_gettime


