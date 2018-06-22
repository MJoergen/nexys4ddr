#include <stdint.h>     // uint8_t, etc.
#include <conio.h>
#include "memorymap.h"

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

void screensize(uint8_t* x, uint8_t* y)
{
   *x = H_CHARS;
   *y = V_CHARS;
}

