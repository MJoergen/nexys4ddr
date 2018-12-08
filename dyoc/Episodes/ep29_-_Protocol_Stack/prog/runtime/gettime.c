#include <stdint.h>
#include <time.h>

#include "gettime.h"

int clock_gettime(clockid_t clk_id, struct timespec *tp)
{
   uint32_t now;

   (void) clk_id; // This line avoid compiler warning about unused variable.

   if (tp)
   {
      now = clock();

      tp->tv_sec = now / 1000;
      now -= tp->tv_sec*1000;

      tp->tv_nsec = now;
   }

   return 0;

} // end of clock_gettime


