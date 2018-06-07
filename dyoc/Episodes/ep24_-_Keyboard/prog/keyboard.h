#ifndef _KEYBOARD_H_
#define _KEYBOARD_H_

#include "types.h"

// This does a BLOCKING wait, until a keyboard event is present in the buffer
// It will pop this value and return.
uint8_t kbd_buffer_pop();

#endif // _KEYBOARD_H_

