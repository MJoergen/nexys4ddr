#ifndef _COMP_H_
#define _COMP_H_

#include <stdint.h>

// This declares some internal functions and variables used by the implementation of conio
// for this platform.

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

// Current cursor position
extern uint8_t pos_x;
extern uint8_t pos_y;

extern uint8_t* curs_pos;
#pragma zpsym("curs_pos");    // curs_pos is in zero-page.

void putchar(uint8_t);
void newline(void);

#endif // _COMP_H_

