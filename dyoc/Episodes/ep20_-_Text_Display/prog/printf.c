#include "types.h"

void printf(char* str)
{
   static uint8_t* CharMemory = (uint8_t*)0x8000;

   static uint8_t x=0,y=0;

   int i;

   for(i = 0; str[i] != '\0'; ++i)
   {
      switch(str[i])
      {
         case '\n':
            x = 0;
            y++;
            break;
         default:
            CharMemory[80*y+x] = str[i];
            x++;
            break;
      }

      if(x >= 80)
      {
         x = 0;
         y++;
      }

      if(y >= 25)
      {
         for(y = 0; y < 25; y++)
            for(x = 0; x < 80; x++)
               CharMemory[80*y+x] = ' ';
         x = 0;
         y = 0;
      }
   }
} // end of printf

void printfHex(uint8_t key)
{
    char foo[3] = "00";
    char* hex = "0123456789ABCDEF";
    foo[0] = hex[(key >> 4) & 0xF];
    foo[1] = hex[key & 0xF];
    printf(foo);
} // end of printfHex

void printfHex16(uint16_t key)
{
    printfHex((key >> 8) & 0xFF);
    printfHex( key & 0xFF);
} // end of printfHex16

