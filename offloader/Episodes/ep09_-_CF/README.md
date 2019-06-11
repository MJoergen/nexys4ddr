# CPU offloader
# Episode 9 : "CF"

Welcome to this ninth episode of "CPU offloader", where we implement the first
part of the Continued Fraction algorithm. This is a general purpose factoring
algorithm i.e. it can factor any number N.

## Factoring algorithms

The idea of many factoring algorithms is to generate lots of pairs of numbers
(x, y) such that x^2 = y mod N, with the additional property that each y is
completely factored. By taking the product of several such relations it may be
possible to write the product of the y's as a square. For instance, if we can
find y\_1 and y\_2 such that the product y\_1 y\_2 only has even powers of each
prime factor then this product is a square and we can find z such that y\_1
y\_2 = z^2.

From this it follows that (x\_1 x\_2)^2 = z^2 mod N, or written differently:
(x+z)(x-z) = 0 mod N, where x = x\_1 x\_2. A factor of N can then be found by
computing gcd(x-z, N).

### Example
Consider for instance the number N=2059, and the three different relations:

* 227^2 = 54 mod 2059
* 465^2 = 30 mod 2059
* 1758^2 = 5 mod 2059

By taking the product of these three equations we get the result

(227\*465\*1758)^2 = 90^2 mod 2059

Then we can calculate gcd(227\*465\*1758 - 90, 2059) = 71, which indeed is a
factor of 2059.

## Continued Fraction algorithm

The Continued Fraction algorithm generates a sequence of pairs of numbers
(x\_n, y\_n) where |y\_n| &le; 2 sqrt(N).

The main idea is to approximate the square root sqrt(N) by a fraction x/d.
This means that x^2/d^2 is close to N, and hence that x^2 - N\*d^2 is close to
zero. We therefore set y = x^2 - N\*d^2, and we immediately have that x^2 = y
mod N and that y is small.

The goal now is to calculate the x and d, and hence the y. We do this by
starting from the pair of recurrence relations:

1. x\_(n+1) = a\_n x\_n + x\_(n-1),
2. d\_(n+1) = a\_n d\_n + d\_(n-1),

with the initial conditions (x\_0 = 1, x\_1 = M, d\_0 = 0, d\_1 = 1), where the
positive integer a\_n is selected such that x\_(n+1) / d\_(n+1) is close to
sqrt(N). Here M = floor(sqrt(N)). Inserting, solving for a\_n, and choosing to
round down to nearest integer gives

3. a\_n = floor[ (sqrt(N) d\_(n-1) - x\_(n-1)) / (x\_n - sqrt(N) d\_n) ].

### Simplifying the algorithm

The above is in principle enough to calculate the a\_n and hence the x\_n.
However, the formula for a\_n involves the irrational square root sqrt(N).
Instead, it is possible to simplify the procedure somewhat, and in particular
to calculate the a\_n using only integer arithmetic.

By expanding the fraction for a\_n with (x\_n + sqrt(N) d\_n) we get the
alternate expression

4. a\_n = floor[ (M w\_n - z\_n) / y\_n ]

where I have introduced two new variables:

* w\_n = x\_n d\_(n-1) - d\_n x\_(n-1)
* z\_n = x\_n x\_(n-1) - N d\_n d\_(n-1)

We find the following recurrence relations for these new variables:

5. w\_(n+1) = - w\_n
6. z\_(n+1) = a\_n y\_n + z\_n
7. y\_(n+1) = a\_n (z\_(n+1) + z\_n) + y\_(n-1)

From equation 5. we get that w\_n = (-1)^n. Furthermore, it can be shown that
w\_n y\_n is always positive, while w\_n z\_n is always negative.  So we can
avoid negative numbers by introducing the new variables:

* p\_n = w\_n y\_n
* q\_n = - w\_n z\_n.

The recurrence relations for these are:

8. p\_(n+1) = a\_n (q\_n - q\_(n+1)) + p\_(n-1)
9. q\_(n+1) = a\_n p\_n - q\_n.

We now expand the fraction for a\_n by w\_n and get

10. a\_n = floor[ (M + q\_n) / p\_n ].

So the above can be used as a pair of recurrence relations, together
with the initial conditions:

* p\_1 = N-M^2
* q\_1 = M,

to generate the sequences p\_n, q\_n, a\_n, x\_n, and y\_n.

It is possible to show that q\_n^2 + p\_n p\_(n-1) = N, but this relation
is not needed.

### Further optimizations

In the current implementation I've chosen to rewrite equation 10 as:

* M + q\_n = a\_n p\_n + r\_n,

where r\_n is the remainder. It is possible to calculate both a\_n and r\_n
simultaneously from this equation.

From this we find that

* p\_(n+1) = a\_n (r\_n - r\_(n-1)) + p\_(n-1)
* q\_(n+1) = M - r\_n.

Finally we set s\_n = M + q\_n to get the following algorithm.

### Final implementation

From s\_n and p\_n calculate a\_n and r\_n using

1. s\_n = a\_n p\_n + r\_n

Then set

2. s\_(n+1) = 2M - r\_n
3. p\_(n+1) = a\_n (r\_n - r\_(n-1)) + p\_(n-1)
4. w\_(n+1) = - w\_n
5. x\_(n+1) = a\_n x\_n + x\_(n-1).

The algorithm is initialized with the following values

* s\_1 = 2 M
* p\_1 = N - M\*M
* w\_1 = -1
* x\_1 = M

* p\_0 = 1
* r\_0 = 0
* x\_0 = 1

Then we have the following properties:

* x\_n^2 = p\_n w\_n mod N
* p\_n < 2M.

One final note is that all values (expept for x) in this method have only half
as many bits as N.

## DivMod
This module calculates the division n/d and returns the quotient q and the
remainder d.

The control signals follow the same pattern as before: The values of N and D
are presented on the input busses val\_n\_i and val\_d\_i, and the input signal
start\_i is pulsed high for one clock cycle.  Some time later the output signal
valid\_o is held high, and the result of the calculation will be presented on
the output bussess res\_q\_o and res\_r\_o.  These values will remain valid
until next time start\_i is asserted.

There is an additional output signal busy\_o which is asserted when a
calculation is in progress. During a calculation the input signal start\_i is
ignored.

## Add\_Mult

## Add\_Mult\_Modulo

## Testing in simulation
The test bench sends a single command with the value N=2059 and verifies the
first three responses generated.
I've added a spread sheet cf.xlsx which performs the above calculations. Using
this spread sheet it is possible to calculate the expected responses.

## Testing in hardware
Just run the program main.py, and it will use the number N=7\*(2^128+1). This design
will generate pairs (x,y) at a rate of about 7 million each second.

