#include <stdint.h>

#define SIZE 10

typedef struct
{
   uint8_t m_mem[SIZE];
   uint8_t m_idx;
} t_rom;

void rom_init(t_rom *ptr);
void rom_iter(t_rom *ptr);

