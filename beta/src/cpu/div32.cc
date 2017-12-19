#include <stdint.h>
#include <iostream>
#include <assert.h>

// This is a C-implementation of a 32-bit unsigned integer division.
// First both dividend and divisor is left-shifted until bit 31 (MSB)
// is one. Then all numbers are interpreted as units of 2^-32. I.e.
// the nunber 0x80000000 is equal to 0,5.
//
// Let T be the dividend (T for "top") and B be the dividor (B for "bottom").
// The algorithm first normalize T and B, so both values are in the
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
   return arg / 65536.0 / 65536.0;
} // end of int_to_float

uint32_t float_to_int(float arg)
{
   assert (arg >= 0.5);
   assert (arg < 1.0);

   return (uint32_t) (arg * 65536 * 65536 + 0.5);
} // end of float_to_int


// Returns the number of left shifts needed to bring the MSB into bit 
// position 31. If the argument is 0, then the value 32 is returned.
uint32_t normalize(uint32_t val)
{
   uint32_t res = 0;

//   std::cout << "Normalize " << val << " gives ";

   while ((val & 0x80000000) == 0 and res<32)
   {
      res += 1;
      val <<= 1;
   }

//   std::cout << res << std::endl;

   return res;
} // end of normalize


// Returns an initial guess for the value F = 0.5/val.
// It is assumed that 0.5 <= val < 1.0, i.e. that bit 31 of val is one.
// The result returned is res = 1.5 - val;
// The true value F will be in the range ]0.5, 1]. However, the result
// will be in the range [0.5, 1[.
//
// Actually, the value 1.5 - 2^-32 is used instead of 1.5, because it is
// easier, and still good enough.
// The actual calculation performed is shown below, where yyy are inverted
// bits of xxx.
// 1.5 = 1.0111 : 
// val =  .1xxx
// res =  .1yyy
uint32_t guess(uint32_t val)
{
   assert ((val & 0x80000000) != 0);
   return val ^ 0x7FFFFFFF;
} // end of guess


// This takes two numbers in the range [0.5, 1[ and computes their
// product.
// It does this by splitting both arguments into two 16-bit values.
uint32_t multiply(uint32_t a, uint32_t b)
{
   uint16_t a_hi = a >> 16;
   uint16_t a_lo = a & 0xFFFF;
   uint16_t b_hi = b >> 16;
   uint16_t b_lo = b & 0xFFFF;

   uint32_t rhh = a_hi * b_hi;
   uint32_t rhl = a_hi * b_lo;
   uint32_t rlh = a_lo * b_hi;

   return rhh + ((rhl + rlh) >> 16);
} // end of multiply


// This performs one loop of Newtons iteration
// This works by searching for roots of the function 
// f(x) = 0.5/x - y. In other words, this function
// attempts to compute the value x = 0.5/y, given 
// the value of y and an initial guess for x.
// f'(x) = -0.5/x^2.
// Delta x = -f(x) / f'(x) = (0.5/x - y) / (0.5/x^2) = x - 2*x^2*y
// New x = x + Delta x = 2x*(1-x*y).
// Introduce the temporary variable k = 2*(1-x*y);
// 
// Example: The initial guess is x = 1.5 - y. The product x*y
// becomes x*y = 1.5*y - y^2. For y=0.5 and y=1 the value is 0.5. The maximum
// value is 0.5625, achieved at y=0.75. In other words, 0.5 <= x*y <= 0.5625,
// at least for the initial guess.
// Therefore 0.4375 <= 1-x*y <= 0.5, and therefore
// 0.875 <= 2*(1-x*y) <= 1.0. The value 1.0 can never be achieved in this
// implementation.
uint32_t newton(uint32_t y, uint32_t x)
{
   uint32_t xy = multiply(x, y);
   uint32_t k = (xy ^ 0xFFFFFFFF) << 1;
//   std::cout << "x = " << int_to_float(x);
//   std::cout << ", y = " << int_to_float(y);
//   std::cout << ", x*y = " << int_to_float(xy);
//   std::cout << ": k = " << int_to_float(k);
   uint32_t res = multiply(k, x);
   if ((xy & 0x80000000) == 0) {
      res += x;
   }
//   std::cout << ": res = " << int_to_float(res) << std::endl;
   return res;
} // end of newton.


uint32_t div32(uint32_t dividend, uint32_t divisor)
{
   uint32_t shift_dividend = normalize(dividend);
   uint32_t shift_divisor = normalize(divisor);

   dividend <<= shift_dividend;
   divisor <<= shift_divisor;

//   std::cout << "Dividend = 0x" << std::hex << dividend << std::dec << std::endl;
//   std::cout << "Divisor  = 0x" << std::hex << divisor << std::dec << std::endl;

   uint32_t x = guess(divisor);
   x = newton(divisor, x);
   x = newton(divisor, x);
   x = newton(divisor, x);
   x = newton(divisor, x);
   x = newton(divisor, x);

   uint32_t prod = multiply(x, dividend);
//   std::cout << "Prod  = " << int_to_float(prod) << std::endl;

   uint32_t res = prod >> (31 - shift_divisor + shift_dividend);

//   std::cout << res << std::endl;

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

   std::cout << "1/" << a << " == " << int_to_float(ib);
   std::cout << ". Product=" << int_to_float(ic) << std::endl;
   return int_to_float(ic);
} // end of test_guess


int main()
{
   //test_guess(0.5);
   //test_guess(0.6);
   //test_guess(0.7);
   //test_guess(0.75);
   //test_guess(0.8);
   //test_guess(0.9);

   //test_multiply(0.5, 0.5);
   //test_multiply(0.5, 0.9);
   //test_multiply(0.9, 0.9);

   //return 0;

   for (uint32_t i=1; i<100; ++i) {
      for (uint32_t j=1; j<100; ++j) {
         uint32_t res = div32(i, j);
         if (res != i/j) {
            std::cout << i << "/" << j << "=" << res << std::endl;
         }
      }
   }
         
   return 0;
}

