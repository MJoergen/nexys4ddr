#include <stdint.h>

#define SIZE 10

typedef struct
{
   uint8_t m_mem[SIZE];
   uint8_t m_idx;
} t_fun;

void fun_init(t_fun *ptr);
void fun_iter(t_fun *ptr);

