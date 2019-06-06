# CPU offloader
# Episode 9 : "CF"

Welcome to this ninth episode of "CPU offloader", where we implement
the first part of the Continued Fraction algorithm.

## Continued Fraction Algorithm

The Continued Fraction algorithm is a recurrence relation that given a number N
generates pairs of numbers (x\_n, y\_n) with the following two properties:
* X<sup>2</sup> = (-1)^n\*Y mod N.
* Y < 2\*sqrt(N).
These numbers will be used in the next episode.

The actual recurrence relations consists of the four state variables x\_n,
y\_n, z\_n, and p\_n and are given by the following equations:
* x\_(n+1) = (a\_n \* x\_n + x\_(n-1)) mod N.
* y\_(n+1) = y\_(n-1) + a\_n\*[p\_n - p\_(n-1)].
* z\_(n+1) = 2\*M - p\_n,
where 
* a\_n = z\_n/y\_n
* p\_n = z\_n - a\_n\*y\_n

The starting values are given by:
* x\_0 = 1
* x\_1 = M
* y\_0 = 1
* y\_1 = N-M\*M
* z\_1 = 2\*M
* p\_0 = 0,
where M=floor(sqrt(N)).

## Block Diagram

## Testing in simulation
The test bench sends a single command with the value N=2059 and verifies the
first three responses generated.
I've added a spread sheet cf.xlsx which performs the above calculations. Using
this spread sheet it is possible to calculate the expected responses.

## Testing in hardware

