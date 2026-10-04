#!/usr/bin/env python3

# Compares the picture calculated by the simulated design (main_tb.vhd) with
# the bit-accurate model in model.py.
#
# The testbench main_tb.vhd writes the line "columns rows stride" to
# sim/main_out.txt, and then one line "address data" for each pixel written to
# the display memory. The size of the picture (columns and rows) gives the
# initial view, the address is column*stride + row (see dispatcher.vhd), and
# the data is the count.
# A complete picture takes about 40 minutes to simulate, so a partial picture
# is fine too: All the pixels written so far are compared, and the last line is
# ignored if it is incomplete.
#
# Usage (from the mandelbrot directory):
#   make run TB=main STOP_TIME=200us
#   sim/cmp_rtl.py [sim/main_out.txt]
#
# Requires numpy.

import os
import sys
from typing import List

import numpy as np

import model
from model import IntArray


def main() -> None:
    default: str = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "main_out.txt")
    filename: str = sys.argv[1] if len(sys.argv) > 1 else default

    with open(filename) as f:
        lines: List[List[str]] = [line.split() for line in f]
    if not lines or len(lines[0]) != 3:
        print(f"No header line \"columns rows stride\" in {filename}")
        sys.exit(1)
    cols, rows, stride = (int(v) for v in lines[0])
    writes: IntArray = np.array(
        [[int(v) for v in line] for line in lines[1:] if len(line) == 2],
        dtype=np.int64).reshape(-1, 2)
    if len(writes) == 0:
        print(f"No writes found in {filename}")
        sys.exit(1)

    col: IntArray = writes[:, 0] // stride
    row: IntArray = writes[:, 0] % stride
    data: IntArray = writes[:, 1]

    errors: int = 0
    if col.max() >= cols or row.max() >= rows:
        print("Address outside the picture")
        errors += 1
    addrs: int = len(set(writes[:, 0].tolist()))
    if addrs != len(writes):
        print(f"{len(writes) - addrs} pixels written more than once")
        errors += 1

    cx, cy = model.view(cols=cols, rows=rows)
    expected: IntArray = model.hw_count(cx, cy)[row % rows, col % cols]
    wrong: IntArray = np.flatnonzero(expected != data)
    for i in wrong[:10]:
        print(f"Pixel (column {col[i]}, row {row[i]}): got {data[i]}, "
              f"expected {expected[i]}")
    errors += len(wrong)

    print(f"{cols}x{rows} picture: "
          f"{len(writes)} pixels written ({len(set(col.tolist()))} columns, "
          f"rows up to {row.max()}), {len(wrong)} differ from the model")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
