#!/usr/bin/env python3

"""Bit-accurate model of the iteration count calculated by src/main/iterator.vhd,
compared with the iteration count calculated using real (floating point)
numbers, as done in sim/iterator_tb.vhd.

The model follows the VHDL literally. The count from the iterator may differ
slightly from the count calculated using real numbers, because of the limited
precision of the 2.16 fixed point numbers.

See also model.py, which is a vectorized (numpy) version of the same model,
used for comparing complete pictures.

Usage:
  ./iterator_model.py          Compare the points used in iterator_tb.vhd (but
                               not its grid of points).
  ./iterator_model.py --grid   Compare a grid of points over the default view.
  ./iterator_model.py CX CY    Show both counts for a single point.
"""

import sys
from typing import Dict
from typing import List
from typing import Tuple

MAX_COUNT = 100      # Must match C_MAX_COUNT in iterator_tb.vhd
TOLERANCE = 1        # Must match C_TOLERANCE in iterator_tb.vhd

# The points that iterator_tb.vhd compares with the real-number count
TB_POINTS: List[Tuple[float, float]] = [
    ( 0.0,   0.0),
    ( 0.5,   0.0),
    (-1.0,   0.0),
    ( 0.0,   1.0),
    (-1.0,   1.0),
    ( 0.1,   0.1),
    (-0.12,  0.75),
    ( 1.0,   1.0),
    (-2.0,   0.0),
    (-1.0,   0.5),
    ( 0.3,   0.0),
    (-0.75,  0.1),
    (-0.1,   0.65),
    (-0.17,  1.09),
    ( 0.02, -1.01),
]

# The points that iterator_tb.vhd compares exactly with the model (cx and cy in
# 2.16 fixed point, as integers), with the counts given in iterator_tb.vhd. For
# these, x alone or y alone repeats an earlier saved value of the periodicity
# detection.
TB_EXACT_POINTS: List[Tuple[int, int, int]] = [
    ( 31902,  31901,  5),
    (-13844,  42971, 24),
    (  2851, -42422, 69),
    ( 27412, -14976, 16),
    ( 25532,  16009, 18),
    (-92498,     96, 44),
]


def signed(v: int, bits: int) -> int:
    """Interpret the lowest 'bits' bits of v as a two's complement number."""
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def to_fixed(r: float) -> int:
    """Convert a real number to 2.16 fixed point, as an integer."""
    return signed(round(r * 65536), 18)


def real_count(cx: float, cy: float, max_count: int = MAX_COUNT) -> int:
    """Iteration count using real numbers. Same as expected_count in the testbench."""
    x = y = 0.0
    for n in range(1, max_count):
        x, y = x*x - y*y + cx, 2.0*x*y + cy
        if not (-2.0 <= x < 2.0) or not (-2.0 <= y < 2.0):
            return n
    return max_count


def iterator_count(cx: float, cy: float, max_count: int = MAX_COUNT) -> int:
    """Iteration count of src/main/iterator.vhd. The inputs are real numbers."""
    cx_i = to_fixed(cx)            # 2.16
    cy_i = to_fixed(cy)            # 2.16
    cx_s = cx_i << 16              # 4.32 (sign extended)
    cy_div_2_s = cy_i << 15        # 4.32 (sign extended), this is cy/2

    x = y = 0                      # 2.16
    cnt = 0
    ovf_x = ovf_y = False

    while True:
        # The count, and the end of the iteration
        if ovf_x or ovf_y:
            return cnt
        cnt += 1
        if cnt - 1 == max_count - 1:
            return cnt

        # Operands to the multiplier. The one of x+y and x-y that may be out of
        # range goes to the 19-bit input, the other one to the 18-bit input.
        if (x < 0) == (y < 0):
            a, b = signed(x + y, 19), signed(x - y, 18)
        else:
            a, b = signed(x - y, 19), signed(x + y, 18)

        # The two DSPs. The products are 4.32 (36 bits).
        product    = a * b         # (x+y)*(x-y)
        product_xy = x * y

        # Sum of 36 bits. It can not overflow, because it is between -6 and 6.
        new_x_s      = signed(product + cx_s, 36)
        new_y_half_s = signed(product_xy + cy_div_2_s, 36)

        # The new x is in range (-2 <= x < 2) if the top three bits are equal.
        # The new y/2 is in range (-1 <= y/2 < 1) if the top four bits are equal.
        top_x = (new_x_s      >> 33) & 0x7
        top_y = (new_y_half_s >> 32) & 0xF
        ovf_x = top_x not in (0x0, 0x7)
        ovf_y = top_y not in (0x0, 0xF)

        x = signed(new_x_s >> 16, 18)         # Bits 33 downto 16
        y = signed(new_y_half_s >> 15, 18)    # Bits 32 downto 15


def compare(points: List[Tuple[float, float]]) -> int:
    """Print a table, and return the number of points outside the tolerance."""
    bad = 0
    print(f"{'cx':>10} {'cy':>10} {'real':>6} {'iterator':>9}")
    for cx, cy in points:
        # Use the rounded value of c in the real calculation, like the testbench
        cxq, cyq = to_fixed(cx) / 65536, to_fixed(cy) / 65536
        r = real_count(cxq, cyq)
        m = iterator_count(cx, cy)
        flag = ""
        if abs(r - m) > TOLERANCE:
            bad += 1
            flag = "  <-- differs"
        print(f"{cx:10.5f} {cy:10.5f} {r:6d} {m:9d}{flag}")
    return bad


def compare_exact(points: List[Tuple[int, int, int]]) -> int:
    """Print a table of the model's count and the count given in the testbench,
    and return the number of points where they differ."""
    bad = 0
    print(f"{'cx':>10} {'cy':>10} {'tb':>6} {'iterator':>9}")
    for cx_i, cy_i, expected in points:
        m = iterator_count(cx_i / 65536, cy_i / 65536)
        flag = ""
        if m != expected:
            bad += 1
            flag = "  <-- differs"
        print(f"{cx_i:10d} {cy_i:10d} {expected:6d} {m:9d}{flag}")
    return bad


def grid(n: int = 100) -> None:
    """Compare a grid of points over the default view."""
    hist: Dict[int, int] = {}
    total = outside = 0
    for i in range(n):
        for j in range(n):
            cx = -1.6667 + 2.6667 * i / (n - 1)
            cy = -1.0 + 2.0 * j / (n - 1)
            cxq, cyq = to_fixed(cx) / 65536, to_fixed(cy) / 65536
            d = abs(real_count(cxq, cyq) - iterator_count(cx, cy))
            hist[d] = hist.get(d, 0) + 1
            total += 1
            if d > TOLERANCE:
                outside += 1
    print(f"{total} points, maximum count {MAX_COUNT}")
    print(f"Difference in count (iterator vs. real) : number of points")
    for d in sorted(hist)[:6]:
        print(f"  {d:3d} : {hist[d]}")
    print(f"Points with a difference larger than {TOLERANCE}: {outside} "
          f"({100.0 * outside / total:.1f}%)")


def main() -> None:
    args: List[str] = sys.argv[1:]
    if args == ["--grid"]:
        grid()
    elif len(args) == 2:
        sys.exit(1 if compare([(float(args[0]), float(args[1]))]) else 0)
    elif not args:
        bad = compare(TB_POINTS)
        print()
        bad += compare_exact(TB_EXACT_POINTS)
        sys.exit(1 if bad else 0)
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
