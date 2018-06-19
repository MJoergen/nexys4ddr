#include <stdint.h>     // uint8_t, etc.
#include <conio.h>
#include "memorymap.h"

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

// Current cursor position
extern uint8_t pos_x;
extern uint8_t pos_y;

extern uint8_t  curs_enable;
extern uint8_t* curs_pos;
extern uint8_t  curs_inverted;
extern uint8_t  curs_cnt;

#pragma zpsym("curs_pos");    // curs_pos is in zero-page.

static uint8_t nibble_swap(uint8_t val)
{
   return (val << 4) | (val >> 4);
}


uint8_t cursor(uint8_t onoff)
{
   uint8_t oldOnOff = curs_enable;

   curs_enable = 0;  // Make sure a stray interrupt doesn't cause a crash.

   if (onoff == 0)
   {
      curs_pos      = &MEM_CHAR[H_CHARS*pos_y+pos_x];
      curs_inverted = 0;
      curs_cnt      = 2;     // Give it a low value, so that it will quickly invert.
      curs_enable   = onoff;
   }
   else
   {
      if (curs_inverted)
      {
         *curs_pos = nibble_swap(*curs_pos);
      }
   }

   return oldOnOff;
}

