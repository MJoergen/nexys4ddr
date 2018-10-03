#include <time.h>
#include <conio.h>

#include "gettime.h"

int main(void)
{
   struct timespec tp;
   clock_gettime(0, &tp);

   gotoxy(10, 10);
   cprintf("%ld.%09ld", tp.tv_sec, tp.tv_nsec);
}

