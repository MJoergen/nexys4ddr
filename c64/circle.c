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

/*
   x -= y/256;
   y += x/256;
*/

void __fastcall__ reset(void)
{
   __asm__("LDA #$FF");
   __asm__("STA $8000");
   __asm__("STA $8001");
   __asm__("STA $8002");
   __asm__("STA $8003");
   __asm__("STA $8020"); // X
   __asm__("STA $8023"); // Color
   __asm__("STA $8024"); // Enable
   __asm__("LDA #$00");
   __asm__("STA $00");
   __asm__("STA $01");
   __asm__("STA $02");
   __asm__("STA $03");
here:
   goto here;  // Just do an endless loop. Everything is run from the IRQ.
}

void __fastcall__ irq(void)
{
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
   __asm__("STA $8022"); // Y
   __asm__("LDA %b", XHI);
   __asm__("CLC");
   __asm__("ADC #$80");
   __asm__("STA $8020"); // X
   __asm__("RTI");
}

void __fastcall__ nmi(void)
{
   __asm__("RTI");
}

