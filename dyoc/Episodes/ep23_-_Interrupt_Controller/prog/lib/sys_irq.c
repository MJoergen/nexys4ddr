#include <stdint.h>
#include <6502.h>          // SEI()
#include "sys_irq.h"
#include "memorymap.h"     // IRQ_MASK, IRQ_VGA_NUM

extern t_irq_handler *isr_jump_table[8];

#define IRQ_VGA_MASK (1 << IRQ_VGA_NUM)

t_irq_handler *sys_set_vga_irq(t_irq_handler *irqHandler)
{
   t_irq_handler *oldHandler;

   SEI();
   oldHandler = isr_jump_table[IRQ_VGA_NUM];
   isr_jump_table[IRQ_VGA_NUM] = irqHandler;
   *IRQ_MASK |= IRQ_VGA_MASK;
   CLI();

   return oldHandler;
} // end of sys_set_vga_irq

void sys_clear_vga_irq(void)
{
   SEI();
   *IRQ_MASK &= ~IRQ_VGA_MASK;
   CLI();
} // end of sys_clear_vga_irq

