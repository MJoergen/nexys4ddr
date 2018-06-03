#include "types.h"
#include "memorymap.h"
#include "printf.h"

void printf(char* str)
{
   static uint8_t* CharMemory = MEM_CHAR;

   static uint8_t x=0, y=0;

   int i;

   for (i = 0; str[i] != '\0'; ++i)
   {
      switch (str[i])
      {
         case '\n':
            x = 0;
            y++;
            break;
         default:
            CharMemory[SCREEN_X*y+x] = str[i];
            x++;
            break;
      }

      if (x >= SCREEN_X)
      {
         x = 0;
         y++;
      }

      if (y >= SCREEN_Y)
      {
         // Move screen up one line
         for (y = 0; y < SCREEN_Y-1; y++)
            for (x = 0; x < SCREEN_X; x++)
               CharMemory[SCREEN_X*y+x] = CharMemory[SCREEN_X*(y+1)+x];

         // Clear bottom line
         y = SCREEN_Y-1;
         for (x = 0; x < SCREEN_X; x++)
            CharMemory[SCREEN_X*y+x] = ' ';
         x = 0;
      }
   }
} // end of printf

void printfHex8(uint8_t key)
{
    char foo[3] = "00";
    char* hex = "0123456789ABCDEF";
    foo[0] = hex[(key >> 4) & 0xF];
    foo[1] = hex[key & 0xF];
    printf(foo);
} // end of printfHex8

void printfHex16(uint16_t key)
{
    printfHex8((key >> 8) & 0xFF);
    printfHex8( key & 0xFF);
} // end of printfHex16

