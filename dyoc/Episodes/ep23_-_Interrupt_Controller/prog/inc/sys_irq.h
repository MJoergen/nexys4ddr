#ifndef _SYS_IRQ_H_
#define _SYS_IRQ_H_

#include <stdint.h>

typedef void (*t_irq_handler)(void);

// This stores a new VGA interrupt handler and enables VGA interrupt.
// It returns a copy of the old interrupt handler.
t_irq_handler *sys_set_vga_irq(t_irq_handler *irqHandler);

// This disables the VGA interrupt.
void sys_clear_vga_irq(void);

#endif // _SYS_IRQ_H_

