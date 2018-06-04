#ifndef _PRINTF_H_
#define _PRINTF_H_

#include "types.h"

#define SCREEN_X 80
#define SCREEN_Y 60

void printf(char* str);
void printfHex8(uint8_t key);
void printfHex16(uint16_t key);

#endif // _PRINTF_H_
