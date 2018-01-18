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
2*cos(v) = 2-dt^2, i.e. cos(v) = 1-1/2*dt^2. This shows that v = dt approximately.
Another formulation is: dt^2 = 2*(1-cos(v)) = (2*sin(v/2))^2. In other words:
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



*/



#define XLO 0
#define XHI 1
#define YLO 2
#define YHI 3
#define TEMP1 4
#define TEMP2 5
#define YTEMP 6

#define VGA_0_BITMAP    0x8000
#define VGA_0_POSXLO    0x8020
#define VGA_0_POSXHI    0x8021
#define VGA_0_POSY      0x8022
#define VGA_0_COLOR     0x8023
#define VGA_0_ENABLE    0x8024


// Entry point after CPU reset
void __fastcall__ reset(void)
{
   // Write bitmap for sprite 0
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
   __asm__("STA %b", TEMP1);
   __asm__("STA %b", TEMP2);
   __asm__("LDA #$40");    // Radius of circle
   __asm__("STA %b", XHI);

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

/*
   x -= y/256;
   y += x/256;
*/
   __asm__("LDA %b", YHI); // Make YHI negative
   __asm__("CLC");
   __asm__("SBC #$01");
   __asm__("EOR #$FF");
   __asm__("STA %b", YTEMP);

   __asm__("LDA %b", YTEMP); // Move sign bit to carry.
   __asm__("CLC");
   __asm__("ADC %b", YTEMP);
   __asm__("LDA %b", XHI); // Decrement if YTEMP was negative.
   __asm__("SBC #$00");
   __asm__("STA %b", XHI);

   __asm__("LDA %b", XLO);
   __asm__("CLC");
   __asm__("ADC %b", YTEMP);
   __asm__("STA %b", XLO);
   __asm__("LDA %b", XHI);
   __asm__("ADC #$00");
   __asm__("STA %b", XHI);

   __asm__("LDA %b", XHI); // Move sign bit to carry.
   __asm__("CLC");
   __asm__("ADC %b", XHI);
   __asm__("LDA %b", YHI); // Decrement if XHI was negative.
   __asm__("SBC #$00");
   __asm__("STA %b", YHI);

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
   __asm__("STA %b", TEMP2);

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

