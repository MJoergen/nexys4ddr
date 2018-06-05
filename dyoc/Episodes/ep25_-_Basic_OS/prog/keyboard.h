#ifndef _KEYBOARD_H_
#define _KEYBOARD_H_

#include "types.h"

// Read keyboard event. Will wait in blocking mode.
uint8_t kbd_getchar();

#endif // _KEYBOARD_H_
