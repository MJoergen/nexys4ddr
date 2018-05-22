// A little program to do some array manipulations. This is just a simple test of the toolchain and the CPU implementation.
// Call first the fun_init() function to initialize.
// After 100 calls to fun_iter() the m_mem[] array should contain the following:
// 1 7 7 2 1 2 1 2 0 2
// and the m_idx variable should contain zero.

#include <stdint.h>
#include "fun.h"

void fun_init(t_fun *ptr)
{
   uint8_t i;

   for (i=0; i<SIZE; ++i)
      ptr->m_mem[i] = 0;

   ptr->m_idx = 0;

} // end of fun_init

void fun_iter(t_fun *ptr)
{
   uint8_t k = ptr->m_mem[ptr->m_idx];

   if (k < SIZE)
   {
      ptr->m_mem[k] += 1;
   }
   else
   {
      ptr->m_mem[ptr->m_idx] = 0;
   }

   ptr->m_idx += 1;
   if (ptr->m_idx >= SIZE)
      ptr->m_idx = 0;

} // end of fun_iter

