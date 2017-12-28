#include <stdint.h>
#include <iostream>
#include <iomanip>
#include <assert.h>
#include <math.h> // floor

bool debug;

// This is a C-implementation of a 32-bit unsigned integer division.
// First both dividend and divisor is left-shifted until bit 31 (MSB)
// is one.
//
// All calculations are done using fixed point arithmetic where all numbers are
// interpreted as units of 2^-32. E.g.
// 0.25 =  0x40000000
// 0.5  =  0x80000000
// 0.75 =  0xC0000000
// 1.0  = 0x100000000 (the MSB '1' is bit 32). This value is stored as 0x00000000.
//
// Let T be the dividend (T for "top") and B be the dividor (B for "bottom").
// The algorithm first normalizes T and B, so both values are in the
// interval [0.5, 1.0[.
//
// The algorithm works by first computing F = 0.5/B and then evaluating
// the multiplication 2*F*T = T/B.
//
// Computing F = 0.5/B is done by first calculating an initial approximation
// and then using Newtons method to iterate closer to the correct result.


/////////////////////////
// Conversion functions
// They are only used during debugging.
float int_to_float(uint32_t arg)
{
   if (arg == 0)
      return 1.0;

   if (arg >= 0xFF000000)
      return -int_to_float((arg ^ 0xFFFFFFFF) + 1);

//   assert (arg & 0x80000000);
   return arg / 65536.0 / 65536.0;
} // end of int_to_float

uint32_t float_to_int(float arg)
{
   if (arg == 1.0)
      return 0x0;

   assert (arg >= 0.5 && arg < 1.0);
   return (uint32_t) ((arg * 65536) * 65536 + 0.5);
} // end of float_to_int

void dump_val(std::string name, uint32_t val)
{
   std::cout << name << "=" << int_to_float(val) << " (0x";
   std::cout << std::hex;
   std::cout << std::setfill('0') << std::setw(8) << val;
   std::cout << std::dec << ")";
} // end of dump_val


// Returns the number of left shifts needed to bring the MSB into bit 
// position 31. If the argument is 0, then the value 32 is returned.
uint32_t normalize(uint32_t val)
{
   uint32_t res = 0;

   while ((val & 0x80000000) == 0 and res<32)
   {
      res += 1;
      val <<= 1;
   }

   return res;
} // end of normalize

uint32_t recip[0x100];
uint32_t slope[0x100];

// This pre-calculates a table of f(x) and f'(x + STEP/2) for the function f(x)
// = 0.5/x.  Here STEP is the stepsize, in this case 0.5 / 128 = 0.0039.
// The reason for adding STEP/2 is to get an average value of the slope in the
// range [x, x+STEP].
// This table is used to calculate an initial guess for the value of f(x).
void init()
{
   for (uint32_t i=0x80; i<0x100; ++i)
   {
      uint32_t r = ((uint32_t) floor(256.0*32768.0 / i + 0.5)) << 16;
      uint32_t s = ((uint32_t) floor(256.0*32768.0 / i / (i+1) + 0.5)) << 16;

      recip[i] = r;
      slope[i] = s;

      if (debug)
      {
         dump_val("val", i<<24);
         dump_val("  recip", r);
         dump_val("  slope", s);
         std::cout << std::endl;
      }
   }

} // end of init


// This takes two numbers in the range [0.5, 1] and computes their
// product, which will be in the range [0.25, 1]
// It does this by splitting both arguments into two 16-bit values.
uint32_t multiply(uint32_t a, uint32_t b)
{
   if (!a) return b;
   if (!b) return a;

//   assert (a & 0x80000000);
//   assert (b & 0x80000000);

   uint16_t a_hi = a >> 16;
   uint16_t a_lo = a & 0xFFFF;
   uint16_t b_hi = b >> 16;
   uint16_t b_lo = b & 0xFFFF;

   uint32_t rhh = a_hi * b_hi;
   uint32_t rhl = a_hi * b_lo;
   uint32_t rlh = a_lo * b_hi;
   uint32_t rll = a_lo * b_lo;

   // The last term (rll >> 31) is included for rounding.
   return rhh + ((rhl + rlh) >> 16) + (rll >> 31);
} // end of multiply


// Returns an initial guess for the value f(x) = 0.5/x.
// It is assumed that 0.5 <= x <= 1.0.
// The value returned is f(x) = f(x0) + (x-x0)*f'(x0 + STEP/2).
// So the method is to first select an approriate value of x0.
// This is done by selecting the 8 high-order bits of x.
//
uint32_t guess(uint32_t x)
{
   if (x==0)
      return 0x80000000;

   assert (x & 0x80000000);

   uint32_t i = x>>24; // This selects x0.
   uint32_t r = recip[i]; // This is f(x0).
   uint32_t s = slope[i]; // This is STEP * f'(x0 + STEP/2).
   uint32_t dx = x<<8; // This is (x-x0)/STEP.
   uint32_t delta = multiply(s, dx);
   if (!dx)
      delta = 0x0;

   uint32_t res = r - delta;

   if (debug)
   {
      dump_val("x", x);
      dump_val("  i", i);
      dump_val("  r", r);
      std::cout << std::endl;
      dump_val("  s", s);
      dump_val("  delta", delta);
      dump_val("  res", res);
      std::cout << std::endl;
   }

   return res;
} // end of guess


// This performs one loop of Newtons iteration
// This works by searching for roots of the function 
// f(x) = 0.5/x - y. In other words, this function
// attempts to compute a better value of x = 0.5/y, given 
// the value of y and an initial guess for x.
// f'(x) = -0.5/x^2.
// Delta x = -f(x) / f'(x) = (0.5/x - y) / (0.5/x^2) = x - 2*x^2*y
// New x = x + Delta x
// 
uint32_t newton(uint32_t y, uint32_t x)
{
   uint32_t xy = multiply(x, y);
   uint32_t x2y = multiply(x, xy);
   uint32_t delta = x - (x2y << 1);
   uint32_t res = x + delta;
   if (debug)
   {
      dump_val("x", x);
      dump_val("  y", y);
      dump_val("  xy", xy);
      dump_val("  2x2y", x2y << 1);
      dump_val("  delta", delta);
      dump_val("  res", res);
      std::cout << std::endl;
   }
   return res;
} // end of newton.


// This is the final division routine
// It takes two unsigned integer operands.
//
// First it normalizes each operand by left 
// shifting until bit 31 (MSB) is 1. Then 
// it interprets each number as a fixed point
// number scaled by 2^32.
//
// It calculates the reciprocal of the divisor
// by making an initial guess and then refining
// it using newtons method.
// Then it multiplies with the dividend,
// and finally it shifts the answer back.
//
// Currently, it makes no attempt to check for
// division by zero. In other words, divisor and
// dividend are both assumed to be nonzero.
uint32_t div32(uint32_t dividend, uint32_t divisor)
{
   // Normalize the two operands
   uint32_t shift_dividend = normalize(dividend);
   uint32_t shift_divisor = normalize(divisor);
   int32_t shift = shift_divisor - shift_dividend;

   // It is apparently necessary to make a special case here.
   // Not sure why.
   if (shift < 0)
      return 0;

   // Shift both operands, so that MSB is 1.
   dividend <<= shift_dividend;
   divisor <<= shift_divisor;

   if (debug)
   {
      std::cout << "Dividend = 0x" << std::hex << dividend << std::dec << std::endl;
      std::cout << "Divisor  = 0x" << std::hex << divisor << std::dec << std::endl;
   }

   uint32_t x = guess(divisor);
   x = newton(divisor, x);
//   x = newton(divisor, x);
//   x = newton(divisor, x);
//   x = newton(divisor, x);
//   x = newton(divisor, x);

//   uint32_t prod = multiply(x, dividend) + 1; // For rounding
   uint32_t prod = multiply(x, dividend);
   uint32_t res = prod >> (31 - shift);

//   uint32_t rem = dividend - divisor * res;

   if (debug)
   {
      dump_val("prod", prod);
      dump_val("  res", res);
      std::cout << std::endl;
   }

   return res;
}

//////////////////////////////////
// The remaining functions are
// used entirely to test the implementation.

float test_multiply(float a, float b)
{
   std::cout << "Multiplying " << a << "*" << b << "=";

   uint32_t ia = float_to_int(a);
   uint32_t ib = float_to_int(b);
   uint32_t ir = multiply(ia, ib);
   float r = int_to_float(ir);

   std::cout << r << std::endl;
   return r;
} // end of test_multiply


float test_guess(float a)
{
   uint32_t ia = float_to_int(a);
   uint32_t ib = guess(ia);
   uint32_t ic = multiply(ia, ib);

   dump_val("ia", ia);
   dump_val("  ib", ib);
   dump_val("  ic", ic);
   std::cout << std::endl;

   return int_to_float(ic);
} // end of test_guess


void test_newton(uint32_t n)
{
   uint32_t g = guess(n);
   uint32_t g1 = newton(n, g);

   dump_val("n", n);
   dump_val("  g", g);
   dump_val("  g1", g1);
   std::cout << std::endl;
} // end of test_newton


int main()
{
   init();

   //test_guess(0.5);
   //test_guess(0.6);
   //test_guess(0.7);
   //test_guess(0.75);
   //test_guess(0.8);
   //test_guess(0.9);
   //return 0;

   //test_multiply(0.5, 0.5);
   //test_multiply(0.5, 0.9);
   //test_multiply(0.9, 0.9);

   //test_newton(0xc0000000);
   //return 0;

   debug = false;
   for (uint32_t i=1; i<40000; ++i) {
      if ((i%1000) == 0)
         std::cout << "i=" << i << std::endl;
      for (uint32_t j=1; j<40000; ++j) {
         uint32_t res = div32(i, j);
         int diff = res - i/j;
         if (diff) {
            debug = true;
            std::cout << "** ERROR: ";
            std::cout << i << "/" << j << "=" << res;
            std::cout << "   DIFF=" << diff << std::endl;
            div32(i, j);
            debug = false;
         }
      }
   }
         
   return 0;
} // end of main

