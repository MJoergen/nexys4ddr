# CPU offloader
# Episode 9 : "CF"

Welcome to this ninth episode of "CPU offloader", where we implement
the first part of the Continued Fraction algorithm.

## Continued Fraction Algorithm

The Continued Fraction algorithm is a recurrence relation that given a number N
generates pairs of numbers (x<sub>n</sub>, y<sub>n</sub>) with the following
two properties:
* X<sup>2</sup> = (-1)<sup>n</sup>&middot;Y mod N.
* Y < 2\*sqrt(N).
These numbers will be used in the next episode.

The actual recurrence relations consists of the four state variables x<sub>n</sub>,
y<sub>n</sub>, z<sub>n</sub>, and p<sub>n</sub> and are given by the following equations:
* x<sub>n+1</sub> = (a<sub>n</sub> \* x<sub>n</sub> + x<sub>n-1</sub>) mod N.
* y<sub>n+1</sub> = y<sub>n-1</sub> + a<sub>n</sub>\*[p<sub>n</sub> - p<sub>n-1</sub>].
* z<sub>n+1</sub> = 2\*M - p<sub>n</sub>,
where 
* a<sub>n</sub> = z<sub>n</sub>/y<sub>n</sub>
* p<sub>n</sub> = z<sub>n</sub> - a<sub>n</sub>\*y<sub>n</sub>

The starting values are given by:
* x<sub>0</sub> = 1
* x<sub>1</sub> = M
* y<sub>0</sub> = 1
* y<sub>1</sub> = N-M\*M
* z<sub>1</sub> = 2\*M
* p<sub>0</sub> = 0,

where M=floor(sqrt(N)).

## Block Diagram

## Testing in simulation
The test bench sends a single command with the value N=2059 and verifies the
first three responses generated.
I've added a spread sheet cf.xlsx which performs the above calculations. Using
this spread sheet it is possible to calculate the expected responses.

## Testing in hardware

