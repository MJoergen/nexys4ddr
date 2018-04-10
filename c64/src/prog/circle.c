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

In general, if:
y1 = a*x1 + b*x2
y2 = c*x1 + d*x2
then:
c*y1^2 - b*y2^2 + (d-a)*y1*y2 = (ad-bc) * (c*x1^2 - b*x2^2 + (d-a)*x1*x2).
With ad-bc = 1 we see that the quadratic form is indeed invariant.

The figure-eight is achieved by replacing y with x*y. To calculate
x*y we use the following approximate differential:
d(x*y) = x*dy + y*dx = (x^2-y^2)*dt = (x^2/4 - y^2/4)*(4*dt)

*/

#include "memorymap.h"
#include "zeropage.h"
#include "umult.h"

// Entry point after CPU reset
void __fastcall__ circle_init(void)
{
   // Write bitmap for sprite 0
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+0);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+1);

   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+2);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+3);

   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+4);
   __asm__("LDA #$80");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+5);

   __asm__("LDA #$06");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+6);
   __asm__("LDA #$60");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+7);

   __asm__("LDA #$08");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+8);
   __asm__("LDA #$10");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+9);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+10);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+11);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+12);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+13);

   __asm__("LDA #$20");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+14);
   __asm__("LDA #$04");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+15);

   __asm__("LDA #$20");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+16);
   __asm__("LDA #$04");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+17);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+18);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+19);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+20);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+21);

   __asm__("LDA #$08");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+22);
   __asm__("LDA #$10");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+23);

   __asm__("LDA #$06");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+24);
   __asm__("LDA #$60");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+25);

   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+26);
   __asm__("LDA #$80");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+27);

   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+28);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+29);

   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+30);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_BITMAP+31);

   // Configure sprite 0
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X);
   __asm__("LDA #$FF");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_ENA);
   __asm__("LDA #$E0"); // Red
   __asm__("STA %w", VGA_ADDR_SPRITE_0_COL);
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_Y);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X_MSB);

   // Reset coordinates
   __asm__("LDA #$60");
   __asm__("STA %b", ZP_XHI);
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_XLO);
   __asm__("STA %b", ZP_YHI);
   __asm__("STA %b", ZP_YLO);
   __asm__("STA %b", ZP_XYHI);
   __asm__("STA %b", ZP_XYLO);

} // end of circle_init


// Move the sprite a small amount.
void __fastcall__ circle_move(void)
{
   // x -= y/256
   __asm__("LDA %b", ZP_YHI);
   __asm__("BPL %g", y_positive); // Jump if YHI is positive

   __asm__("LDA %b", ZP_XHI); // Increment if YHI is negative
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %b", ZP_XHI);

y_positive:
   __asm__("LDA %b", ZP_XLO);
   __asm__("SEC");
   __asm__("SBC %b", ZP_YHI);
   __asm__("STA %b", ZP_XLO);
   __asm__("LDA %b", ZP_XHI);
   __asm__("SBC #$00");
   __asm__("STA %b", ZP_XHI);

   // y += x/256;
   __asm__("LDA %b", ZP_XHI);
   __asm__("BPL %g", x_positive); // Jump if XHI is positive

   __asm__("LDA %b", ZP_YHI); // Decrement if XHI is negative.
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("STA %b", ZP_YHI);

x_positive:
   __asm__("LDA %b", ZP_YLO);
   __asm__("CLC");
   __asm__("ADC %b", ZP_XHI);
   __asm__("STA %b", ZP_YLO);
   __asm__("LDA %b", ZP_YHI);
   __asm__("ADC #$00");
   __asm__("STA %b", ZP_YHI);

   // Move XLO high bit into carry
   __asm__("LDA %b", ZP_XLO);
   __asm__("ROL A");
   __asm__("LDA %b", ZP_XHI);
   __asm__("ADC #$65");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X); // Set X coordinate of sprite 0

//// Uncomment below to generate a circle.
//   // Move YLO high bit into carry
//   __asm__("LDA %b", ZP_YLO);
//   __asm__("ROL A");
//   __asm__("LDA %b", ZP_YHI);
//   __asm__("ADC #$65");
//   __asm__("STA %w", VGA_ADDR_SPRITE_0_Y); // Set Y coordinate of sprite 0
//
//   __asm__("RTS");

   // The following code incrementally calculates 4*X*Y

   // Calculate 2X
   __asm__("LDA %b", ZP_XLO);
   __asm__("ROL A");    // Move MSB into carry. Previous value of carry is not important
   __asm__("TAY");
   __asm__("LDA %b", ZP_XHI);
   __asm__("ROL A");
   __asm__("BCC %g", noNegX);
   __asm__("EOR #$FF");
   __asm__("ADC #$00");
noNegX:
   __asm__("TAX");

   __asm__("TYA");
   __asm__("BPL %g", noIncX);
   __asm__("INX");
noIncX:

   // Calculate (2X)^2/4
   __asm__("LDA $0700,X"); // MSB into X
   __asm__("TAX");
   __asm__("LDA $0600,X"); // LSB into Y
   //__asm__("TAY");

   // Multiply by 4
   //__asm__("TYA");
   __asm__("ROL A");    // Previous value of carry is not important
   __asm__("TAY");
   __asm__("TXA");
   __asm__("ROL A");
   __asm__("TAX");

   __asm__("TYA");
   __asm__("ROL A");    // Previous value of carry is not important
   //__asm__("TAY");
   __asm__("TXA");
   __asm__("ROL A");
   //__asm__("TAX");

   // Add to XY
   //__asm__("TXA");
   //__asm__("CLC");
   __asm__("ADC %b", ZP_XYLO);
   __asm__("STA %b", ZP_XYLO);
   __asm__("LDA %b", ZP_XYHI);
   __asm__("ADC #$00");
   __asm__("STA %b", ZP_XYHI);


   // Calculate 2Y
   __asm__("LDA %b", ZP_YLO);
   __asm__("ROL A");    // Move MSB into carry. Previous value of carry is not important
   __asm__("TAY");
   __asm__("LDA %b", ZP_YHI);
   __asm__("ROL A");
   __asm__("BCC %g", noNegY);
   __asm__("EOR #$FF");
   __asm__("ADC #$00");
noNegY:
   __asm__("TAX");

   __asm__("TYA");
   __asm__("BPL %g", noIncY);
   __asm__("INX");
noIncY:

   // Calculate (2Y)^2/4
   __asm__("LDA $0700,X"); // MSB into X
   __asm__("TAX");
   __asm__("LDA $0600,X"); // LSB into Y
   //__asm__("TAY");

   // Multiply by 4
   //__asm__("TYA");
   __asm__("ROL A");    // Previous value of carry is not important
   __asm__("TAY");
   __asm__("TXA");
   __asm__("ROL A");
   __asm__("TAX");

   __asm__("TYA");
   __asm__("ROL A");    // Previous value of carry is not important
   //__asm__("TAY");
   __asm__("TXA");
   __asm__("ROL A");
   //__asm__("TAX");

   // Subtract XY
   //__asm__("TXA");
   __asm__("EOR #$FF");          // Negate
   __asm__("SEC");
   __asm__("ADC %b", ZP_XYLO);
   __asm__("STA %b", ZP_XYLO);
   __asm__("LDA %b", ZP_XYHI);
   __asm__("ADC #$FF");
   __asm__("STA %b", ZP_XYHI);

   __asm__("CLC");
   __asm__("ADC #$65");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_Y); // Set Y coordinate of sprite 0

} // end of circle_move

