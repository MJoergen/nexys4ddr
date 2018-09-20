#include <stdint.h>     // uint8_t, etc.
#include <string.h>
#include <conio.h>

#include "memorymap.h"  // MEM_CHAR
#include "comp.h"       // H_CHARS

void clrscr(void)
{
   // memset(MEM_CHAR, ' ', H_CHARS*V_CHARS);
   gotoxy(0, 0);
} // end of clrscr


