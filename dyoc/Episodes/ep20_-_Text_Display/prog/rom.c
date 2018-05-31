#include <stdint.h>

uint8_t *ADDR_CHAR = (uint8_t *) 0x8000;
uint8_t *ADDR_COL  = (uint8_t *) 0xA000;

#define COL_WHITE 0xFF

static uint8_t hex2char(uint8_t val)
{
   if (val < 10)
      return val + '0';
   else
      return val-10 + 'A';
}

void main()
{
   uint16_t cnt;

   ADDR_COL[100] = COL_WHITE;
   ADDR_COL[101] = COL_WHITE;
   ADDR_COL[102] = COL_WHITE;
   ADDR_COL[103] = COL_WHITE;

   // Infinite loop
   while(1)
   {
      ADDR_CHAR[100] = hex2char((cnt>>12) & 0xF);
      ADDR_CHAR[101] = hex2char((cnt>>8) & 0xF);
      ADDR_CHAR[102] = hex2char((cnt>>4) & 0xF);
      ADDR_CHAR[103] = hex2char((cnt>>0) & 0xF);

      cnt++;
   }

} // end of main

