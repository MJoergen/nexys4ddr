// A test program for the implementation in fun.c

#include <stdint.h>
#include <stdio.h>

#include "fun.h"

void fun_print(t_fun *ptr)
{
   for (int i=0; i<10; ++i)
   {
      printf("%d ", ptr->m_mem[i]);
   }

   printf(": %d", ptr->m_idx);
   printf("\n");
}

int main()
{
   t_fun fun;

   fun_init(&fun);

   for (int i=0; i<100; ++i)
   {
      fun_iter(&fun);
   }

   fun_print(&fun);
} // end of main

