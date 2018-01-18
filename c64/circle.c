/*
Making an object travel in a circular orbit...

One way to make a circular orbit is to numerically solve
the following system of differential equations:
dx/dt = -y
dy/dt = x

According to the semi-implicit Euler method:
x1 = x0 - y0*dt
y1 = y0 + x1*dt

Why is this good? Well, We first evaluate:
x1^2 + y1^2
= x1^2 + (y0+x1*dt)^2
= x1^2 + y0^2 + 2*y0*x1*dt + x1^2*dt^2
= y0^2 + 2*y0*(x0-y0*dt)*dt + (x0-y0*dt)^2 + x1^2*dt^2
= y0^2 + 2*x0*y0*dt - 2*y0^2*dt^2 + x0^2 - 2*x0*y0*dt + y0^2*dt^2 + dt^2*x1^2
= x0^2 + y0^2 - y0^2*dt^2 + dt^2*x1^2
= x0^2 + y0^2 + (x1^2 - y0^2)*dt^2

Then we evaluate:
x1*y1
= x1*(y0+x1*dt)
= x1*y0 + x1^2*dt
= (x0-y0*dt)*y0 + x1^2*dt
= x0*y0 - y0^2*dt + x1^2*dt
= x0*y0 + (x1^2 - y0^2)*dt

These two calculations combined show that
x1^2 + y1^2 - dt*x1*y1 = x0^2 + y0^2 - dt*x0*y0

Therefore we conclude that the quantity
H0 = x0^2 + y0^2 - dt*x0*y0
is conserved, i.e. H1 = H0 exactly, for all values of dt.

This shows that the orbit will be governed by;
x0^2 + y0^2 - x0*y0*dt = constant

In particular, the orbit is closed.
*/



#define XLO 0
#define XHI 1
#define YLO 2
#define YHI 3

#define VGA_0_BITMAP    0x8000
#define VGA_0_POSXLO    0x8020
#define VGA_0_POSXHI    0x8021
#define VGA_0_POSY      0x8022
#define VGA_0_COLOR     0x8023
#define VGA_0_ENABLE    0x8024


// Entry point after CPU reset
void __fastcall__ reset(void)
{
   // Program bitmap for sprite 0
   __asm__("LDA #$00");
   __asm__("STA $8000");
   __asm__("LDA #$00");
   __asm__("STA $8001");

   __asm__("LDA #$00");
   __asm__("STA $8002");
   __asm__("LDA #$00");
   __asm__("STA $8003");

   __asm__("LDA #$01");
   __asm__("STA $8004");
   __asm__("LDA #$80");
   __asm__("STA $8005");

   __asm__("LDA #$06");
   __asm__("STA $8006");
   __asm__("LDA #$60");
   __asm__("STA $8007");

   __asm__("LDA #$08");
   __asm__("STA $8008");
   __asm__("LDA #$10");
   __asm__("STA $8009");

   __asm__("LDA #$10");
   __asm__("STA $800A");
   __asm__("LDA #$08");
   __asm__("STA $800B");

   __asm__("LDA #$10");
   __asm__("STA $800C");
   __asm__("LDA #$08");
   __asm__("STA $800D");

   __asm__("LDA #$20");
   __asm__("STA $800E");
   __asm__("LDA #$04");
   __asm__("STA $800F");

   __asm__("LDA #$20");
   __asm__("STA $8010");
   __asm__("LDA #$04");
   __asm__("STA $8011");

   __asm__("LDA #$10");
   __asm__("STA $8012");
   __asm__("LDA #$08");
   __asm__("STA $8013");

   __asm__("LDA #$10");
   __asm__("STA $8014");
   __asm__("LDA #$08");
   __asm__("STA $8015");

   __asm__("LDA #$08");
   __asm__("STA $8016");
   __asm__("LDA #$10");
   __asm__("STA $8017");

   __asm__("LDA #$06");
   __asm__("STA $8018");
   __asm__("LDA #$60");
   __asm__("STA $8019");

   __asm__("LDA #$01");
   __asm__("STA $801A");
   __asm__("LDA #$80");
   __asm__("STA $801B");

   __asm__("LDA #$00");
   __asm__("STA $801C");
   __asm__("LDA #$00");
   __asm__("STA $801D");

   __asm__("LDA #$00");
   __asm__("STA $801E");
   __asm__("LDA #$00");
   __asm__("STA $801F");

   // Configure sprite 0
   __asm__("LDA #$FF");
   __asm__("STA %w", VGA_0_POSXLO);
   __asm__("STA %w", VGA_0_COLOR);
   __asm__("STA %w", VGA_0_ENABLE);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_POSXHI);
   __asm__("STA %w", VGA_0_POSY);

   // Clear variables in zero page.
   __asm__("STA %b", XLO);
   __asm__("STA %b", XHI);
   __asm__("STA %b", YLO);
   __asm__("STA %b", YHI);

   // Enable interrupts.
   __asm__("CLI");

   // Loop forever doing nothing
here:
   goto here;  // Just do an endless loop. Everything is run from the IRQ.
} // end of reset


// The interrupt service routine.
void __fastcall__ irq(void)
{
   // Clear interrupt source
   // When entering this function, the interrupts are already disabled, 
   // but the interrupt source (i.e. the VGA driver) is continuously
   // asserting the IRQ pin.
   // Reading this register clears the assertion.
   __asm__("LDA $8001");

   // Just move the sprite vertically down slowly (one pixel every four seconds).
   __asm__("LDA %b", YLO);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %b", YLO);
   __asm__("LDA %b", YHI);
   __asm__("ADC #$00");
   __asm__("STA %b", YHI);
   __asm__("STA %w", VGA_0_POSY); // Set Y coordinate of sprite 0
   __asm__("RTI");
   

/*
   x -= y/256;
   y += x/256;
*/
   __asm__("LDA %b", XLO);
   __asm__("CLC");
   __asm__("SBC %b", YHI);
   __asm__("STA %b", XLO);
   __asm__("LDA %b", XHI);
   __asm__("SBC #$00");
   __asm__("STA %b", XHI);
   __asm__("CLC");
   __asm__("ADC %b", YLO);
   __asm__("STA %b", YLO);
   __asm__("LDA %b", YHI);
   __asm__("ADC #$00");
   __asm__("STA %b", YHI);
   __asm__("CLC");
   __asm__("ADC #$80");
   __asm__("STA %w", VGA_0_POSY); // Set Y coordinate of sprite 0
   __asm__("LDA %b", XHI);
   __asm__("CLC");
   __asm__("ADC #$80");
   __asm__("STA %w", VGA_0_POSXLO); // Set X coordinate of sprite 0
   __asm__("RTI");
} // end of irq


// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

