#include <stdint.h>     // uint8_t, etc.
#include <conio.h>
#include "memorymap.h"

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

// Current cursor position
extern uint8_t pos_x;
extern uint8_t pos_y;

void putchar(uint8_t ch)
{
   MEM_CHAR[H_CHARS*pos_y+pos_x] = ch;
}

