// A little program to do some array manipulations. This is just a simple test of the toolchain and the CPU implementation.
// Call first the rom_init() function to initialize.
// After 100 calls to rom_iter() the m_mem[] array should contain the following:
// 1 7 7 2 1 2 1 2 0 2
// and the m_idx variable should contain zero.

#include <stdint.h>
#include "main.h"

void rom_init(t_rom *ptr)
{
   uint8_t i;

   for (i=0; i<SIZE; ++i)
      ptr->m_mem[i] = 0;

   ptr->m_idx = 0;

} // end of rom_init

void rom_iter(t_rom *ptr)
{
   uint8_t *pMem = ptr->m_mem;

   uint8_t k = pMem[ptr->m_idx];

   if (k < SIZE)
   {
      pMem[k] += 1;
   }
   else
   {
      pMem[ptr->m_idx] = 0;
   }

   ptr->m_idx += 1;
   if (ptr->m_idx >= SIZE)
      ptr->m_idx = 0;

} // end of rom_iter

void main()
{
   t_rom rom;
   uint8_t i;

   rom_init(&rom);
   for (i=0; i<10; ++i)
   {
      rom_iter(&rom);
   }

   // Infinite loop
   while(1)
   {}

} // end of main

