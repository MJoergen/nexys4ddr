#include <stdint.h>
#include <6502.h>       // SEI() and CLI()

extern uint16_t timer;

uint32_t clock(void)
{
   uint16_t ret;

   SEI();
   ret = timer;
   CLI();

   return ret;
}

