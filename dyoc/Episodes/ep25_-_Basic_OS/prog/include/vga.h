#ifndef _VGA_H_
#define _VGA_H_

#include <stdint.h>

#define PIXELS_X 640
#define PIXELS_Y 480

// Enable blinking cursor.
// Pass pointer to position in colour memory.
void vga_cursor_enable(uint8_t *cursor_pos);

// Disable blinking cursor.
void vga_cursor_disable();

#endif // _VGA_H_
