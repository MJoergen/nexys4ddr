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


Another way to look at it, is to rewrite the transformation with a matrix.
First we have:
y1 = y0 + (x0 - y0*dt) * dt
   = dt*x0 + (1-dt^2)*y0
Therefore, the matrix is
+----+--------+
|  1 |    -dt |
+----+--------+
| dt | 1-dt^2 |
+----+--------+
Since the determinant of this matrix is 1, and the trace is 2-dt^2, i.e. less than 2,
then we conclude that the eigenvalues are complex conjugate on the unit circle.

The two eigenvalues are therefore l_12 = cos(v) +/- i*sin(v), and we must have
2*cos(v) = 2-dt^2, This shows that: dt^2 = 2*(1-cos(v)) = (2*sin(v/2))^2. In other words:
dt = 2*sin(v/2).


Let w = (1, a)^T be an eigenvector. Then we calculate:
A*w = (1 - a*dt, dt + a*(1-dt^2))^T.
Equation this with (1-a*dt)*w gives:
(1-a*dt)*a = dt + a*(1-dt^2)
-a^2*dt = dt - a*dt^2
-a^2 = 1 - a*dt

Insert here a = i+b*dt we get:
1 - b^2*dt^2 - 2ib*dt = 1 - (i+b*dt)*dt
-b^2*dt^2 - 2ib*dt = -i*dt - b*dt^2
-b^2*dt - 2ib = -i - b*dt
Letting dt=0 gives
2ib=i
i.e. b=1/2
Therefore, one eigenvalue is
w = (1, i+dt/2)^T,
to first order in dt.

The exact eigenvector is:
w = (1, dt/2 + i*sqrt(4-dt^2)/2)^T.

Now 4-dt^2 = 4*cos^2(v/2). Therefore, the eigenvector can be written as:
w = (1, sin(v/2) + i*cos(v/2))^T.


In general, if a 2x2 linear transformation A has determinant 1, i.e.
+---+---+
| a | b |
+---+---+
| c | d |
+---+---+
with a*d - b*c = 1, then there is an associated invariant quadratic form with

+---------+---------+
| c       | (d-a)/2 |
+---------+---------+
| (d-a)/2 | -b      |
+---------+---------+

In other words, if
y1 = a*x1 + b*x2
y2 = c*x1 + d*x2
c*y1^2 - b*y2^2 + (d-a)*y1*y2 = (ad-bc) * (c*x1^2 - b*x2^2 + (d-a)*x1*x2).
With ad-bc = 1 we see that the quadratic form is indeed invariant.

*/


/*
 * Define some zero-page variables
 */
#define XLO 0
#define XHI 1
#define YLO 2
#define YHI 3
#define CNT 4


/*
 * Memory Map:
 * 0x8000 - 0x83FF : Chars Memory
 * 0x8400 - 0x85FF : Bitmap Memory
 * 0x8600 - 0x87FF : Config and Status
 */

#define VGA_SCREEN      0x8000
#define VGA_0_BITMAP    0x8400
#define VGA_0_POSXLO    0x8600
#define VGA_0_POSXHI    0x8601
#define VGA_0_POSY      0x8602
#define VGA_0_COLOR     0x8603
#define VGA_0_ENABLE    0x8604
#define VGA_IRQ         0x8640
#define VGA_YLINE       0x8641
#define VGA_MASK        0x8642
#define VGA_XSCROLL     0x8643
#define VGA_FGCOL       0x8650
#define VGA_BGCOL       0x8651
#define VGA_KEY         0x8660


// Entry point after CPU reset
void __fastcall__ reset(void)
{
   // Write text on screen
   __asm__("LDA #$48");
   __asm__("STA %w", VGA_SCREEN+100);
   __asm__("LDA #$65");
   __asm__("STA %w", VGA_SCREEN+101);
   __asm__("LDA #$6A");
   __asm__("STA %w", VGA_SCREEN+102);

   // Write bitmap for sprite 0
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+0);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+1);

   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+2);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+3);

   __asm__("LDA #$01");
   __asm__("STA %w", VGA_0_BITMAP+4);
   __asm__("LDA #$80");
   __asm__("STA %w", VGA_0_BITMAP+5);

   __asm__("LDA #$06");
   __asm__("STA %w", VGA_0_BITMAP+6);
   __asm__("LDA #$60");
   __asm__("STA %w", VGA_0_BITMAP+7);

   __asm__("LDA #$08");
   __asm__("STA %w", VGA_0_BITMAP+8);
   __asm__("LDA #$10");
   __asm__("STA %w", VGA_0_BITMAP+9);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_0_BITMAP+10);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_0_BITMAP+11);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_0_BITMAP+12);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_0_BITMAP+13);

   __asm__("LDA #$20");
   __asm__("STA %w", VGA_0_BITMAP+14);
   __asm__("LDA #$04");
   __asm__("STA %w", VGA_0_BITMAP+15);

   __asm__("LDA #$20");
   __asm__("STA %w", VGA_0_BITMAP+16);
   __asm__("LDA #$04");
   __asm__("STA %w", VGA_0_BITMAP+17);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_0_BITMAP+18);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_0_BITMAP+19);

   __asm__("LDA #$10");
   __asm__("STA %w", VGA_0_BITMAP+20);
   __asm__("LDA #$08");
   __asm__("STA %w", VGA_0_BITMAP+21);

   __asm__("LDA #$08");
   __asm__("STA %w", VGA_0_BITMAP+22);
   __asm__("LDA #$10");
   __asm__("STA %w", VGA_0_BITMAP+23);

   __asm__("LDA #$06");
   __asm__("STA %w", VGA_0_BITMAP+24);
   __asm__("LDA #$60");
   __asm__("STA %w", VGA_0_BITMAP+25);

   __asm__("LDA #$01");
   __asm__("STA %w", VGA_0_BITMAP+26);
   __asm__("LDA #$80");
   __asm__("STA %w", VGA_0_BITMAP+27);

   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+28);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+29);

   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+30);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_BITMAP+31);

   // Configure sprite 0
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_POSXLO);
   __asm__("LDA #$FF");
   __asm__("STA %w", VGA_0_ENABLE);
   __asm__("LDA #$E0"); // Red
   __asm__("STA %w", VGA_0_COLOR);
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_0_POSY);
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_0_POSXHI);

   // Clear variables in zero page.
   __asm__("STA %b", XLO);
   __asm__("STA %b", YLO);
   __asm__("STA %b", YHI);
   __asm__("STA %b", CNT);
   __asm__("LDA #$40");    // Radius of circle
   __asm__("STA %b", XHI);

   // Configure X scroll
   __asm__("LDA #$00");
   __asm__("STA %w", VGA_XSCROLL);

   // Configure text color
   __asm__("LDA #$44");
   __asm__("STA %w", VGA_FGCOL);
   __asm__("LDA #$CC");
   __asm__("STA %w", VGA_BGCOL);

   // Configure interrupt at end of line 240 (i.e. end of screen).
   __asm__("LDA #$F0");
   __asm__("STA %w", VGA_YLINE);
   __asm__("LDA #$01");
   __asm__("STA %w", VGA_MASK);
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
   __asm__("LDA %w", VGA_IRQ);

   // Time to scroll?
   __asm__("LDA %b", CNT);
   __asm__("CLC");
   __asm__("ADC #$02"); // The value 8 must be a divisor of 256.
   __asm__("STA %b", CNT);
   __asm__("BNE %g", circle);

   // Yes. Time to move a whole character?
   __asm__("LDA %w", VGA_XSCROLL);
   __asm__("BNE %g", shift_pixel);

   // Keep left-most character
   __asm__("LDA %w", VGA_SCREEN+80);
   __asm__("TAY");

   __asm__("LDA #%b", 80);
more_scroll:
   __asm__("TAX");
   __asm__("LDA %w,X", VGA_SCREEN+1);
   __asm__("STA %w,X", VGA_SCREEN);
   __asm__("TXA");
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("CMP #%b", 119);
   __asm__("BNE %g", more_scroll);

   // Wrap around
   __asm__("TYA");
   __asm__("STA %w", VGA_SCREEN+119);

   __asm__("LDA %w", VGA_XSCROLL);
shift_pixel:
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("AND #$0F");
   __asm__("STA %w", VGA_XSCROLL);

circle:
/*
 * As written above, implement the following:
 * x -= y/256;
 * y += x/256;
 */
   __asm__("LDA %b", YHI);
   __asm__("BPL %g", y_positive); // Jump if YHI is positive

   __asm__("LDA %b", XHI); // Increment if YHI is negative
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %b", XHI);

y_positive:
   __asm__("LDA %b", XLO);
   __asm__("SEC");
   __asm__("SBC %b", YHI);
   __asm__("STA %b", XLO);
   __asm__("LDA %b", XHI);
   __asm__("SBC #$00");
   __asm__("STA %b", XHI);


   __asm__("LDA %b", XHI); // Move sign bit to carry.
   __asm__("BPL %g", x_positive); // Jump if XHI is positive

   __asm__("LDA %b", YHI); // Decrement if XHI is negative.
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("STA %b", YHI);

x_positive:
   __asm__("LDA %b", YLO);
   __asm__("CLC");
   __asm__("ADC %b", XHI);
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

