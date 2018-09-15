#include <stdint.h>
#include <conio.h>

extern uint8_t  kbd_buffer_count;
extern uint8_t  kbd_buffer[];

uint8_t kbhit(void)
{
   if (kbd_buffer_count)
      return 1;
   return 0;
}

