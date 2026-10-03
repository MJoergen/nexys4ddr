#!/usr/bin/env python3

# Vectorized (numpy) bit-accurate model of the picture calculated by the
# design, and a reference calculated using real (floating point) numbers.
#
# hw_count() follows src/main/iterator.vhd (like iterator_model.py, but for many
# points at once), and view() gives the values of c for each pixel, calculated
# in the same way as src/main/main.vhd, src/main/dispatcher.vhd and src/main/column.vhd. This
# module is used by cmp_rtl.py to compare the simulated design with the model.
#
# Run as a script, it compares the model with the reference for the initial
# view (640x480), and prints how many pixels differ. It also estimates the time
# it takes the design to calculate the picture, see picture_cycles(), and the
# total time the column modules wait for their results to be accepted. For
# this, hw_stop() follows the periodicity detection of the iterator, which stops
# the iteration early for most points in the set, and checks that it gives the
# same count as hw_count().
#
# Usage:
#   ./model.py           Compare the model with the reference.
#   ./model.py --png     Same, and write the pictures to model.png and ref.png
#                        (requires Pillow), using the same colours as the VGA
#                        output.
#
# Requires numpy.

import heapq
import sys
from typing import List
from typing import Optional
from typing import Tuple

import numpy as np
from numpy.typing import ArrayLike
from numpy.typing import NDArray

# Arrays of integers (e.g. 2.16 fixed point numbers or counts), real numbers,
# and booleans
IntArray = NDArray[np.int64]
RealArray = NDArray[np.float64]
BoolArray = NDArray[np.bool_]

MAX_COUNT = 511      # Must match C_MAX_COUNT in main.vhd
NUM_COLS  = 640      # Must match C_NUM_COLS in main.vhd
NUM_ROWS  = 480      # Must match C_NUM_ROWS in main.vhd
JOB_ROWS  = 120      # Must match C_JOB_ROWS in main.vhd
NUM_ITERATORS = 240  # Must match C_NUM_ITERATORS in mandelbrot.vhd
MAIN_CLOCK_KHZ = 1200e3 / 6.375  # The main clock, see clk_rst.vhd


def wrap(v: ArrayLike, bits: int) -> IntArray:
    """Interpret the lowest 'bits' bits of v as two's complement numbers."""
    m = 1 << bits
    low: IntArray = np.asarray(v, dtype=np.int64) & (m - 1)
    return np.where(low >= m >> 1, low - m, low)


def hw_count(cx: ArrayLike, cy: ArrayLike,
             max_count: int = MAX_COUNT) -> IntArray:
    """Iteration count of src/main/iterator.vhd. cx and cy are 2.16 fixed point
    numbers, i.e. 18-bit signed integers."""
    cx_i: IntArray = np.asarray(cx, np.int64)
    cy_i: IntArray = np.asarray(cy, np.int64)
    cx_s: IntArray = cx_i << 16              # 4.32
    cy_div_2_s: IntArray = cy_i << 15        # 4.32, this is cy/2
    x: IntArray = np.zeros_like(cx_i)        # 2.16
    y: IntArray = np.zeros_like(cx_i)        # 2.16
    cnt: IntArray = np.zeros_like(cx_i)
    done: BoolArray = np.zeros(cx_i.shape, bool)
    ovf: BoolArray = np.zeros(cx_i.shape, bool)
    while True:
        # ADD_ST
        done |= ovf
        active = ~done
        cnt = np.where(active, cnt + 1, cnt)
        done |= active & (cnt == max_count)
        if done.all():
            return cnt

        # x+y and x-y do not wrap around, because the one that may be out of
        # range goes to the 19-bit input of the multiplier. The products are
        # 4.32, and can not overflow.
        new_x_s = (x + y) * (x - y) + cx_s
        new_y_half_s = x * y + cy_div_2_s

        # The new x is in range (-2 <= x < 2) if the top three bits are equal.
        # The new y/2 is in range (-1 <= y/2 < 1) if the top four bits are equal.
        ovf_x = (new_x_s < -(1 << 33)) | (new_x_s >= (1 << 33))
        ovf_y = (new_y_half_s < -(1 << 32)) | (new_y_half_s >= (1 << 32))
        ovf = np.where(done, ovf, ovf_x | ovf_y)
        x = np.where(done, x, wrap(new_x_s >> 16, 18))         # Bits 33 downto 16
        y = np.where(done, y, wrap(new_y_half_s >> 15, 18))    # Bits 32 downto 15


def ref_count(cx: ArrayLike, cy: ArrayLike,
              max_count: int = MAX_COUNT) -> IntArray:
    """Iteration count using real numbers (cx and cy are real numbers). Same
    counting as the iterator: The number of the first iteration where x or y is
    outside the range -2 to 2, or max_count if this does not happen."""
    cx_r: RealArray = np.asarray(cx, np.float64)
    cy_r: RealArray = np.asarray(cy, np.float64)
    x: RealArray = np.zeros_like(cx_r)
    y: RealArray = np.zeros_like(cx_r)
    cnt: IntArray = np.full(cx_r.shape, max_count, np.int64)
    done: BoolArray = np.zeros(cx_r.shape, bool)
    for n in range(1, max_count):
        x, y = x*x - y*y + cx_r, 2*x*y + cy_r
        out = ~((x >= -2) & (x < 2) & (y >= -2) & (y < 2)) & ~done
        cnt[out] = n
        done |= out
        # Stop iterating the points that are done, so they do not overflow
        x = np.where(done, 0.0, x)
        y = np.where(done, 0.0, y)
    return cnt


def view(startx: Optional[int] = None, starty: Optional[int] = None,
         stepx: Optional[int] = None, stepy: Optional[int] = None,
         cols: int = NUM_COLS,
         rows: int = NUM_ROWS) -> Tuple[IntArray, IntArray]:
    """The values of cx and cy (2.16 fixed point) for each pixel, as arrays
    indexed by [row, column]. The default is the initial view in main.vhd."""
    if startx is None:
        startx = int(round((-1.6667 + 4.0) * 65536))
    if starty is None:
        starty = int(round((-1.0 + 4.0) * 65536))
    if stepx is None:
        stepx = int(round(2.6667 * 65536)) // cols
    if stepy is None:
        stepy = int(round(2.0 * 65536)) // rows
    # The dispatcher and the column modules add the step in 18 bits, so the
    # values wrap around.
    cx = wrap(startx + np.arange(cols) * stepx, 18)
    cy = wrap(starty + np.arange(rows) * stepy, 18)
    cx_grid, cy_grid = np.meshgrid(cx, cy)
    return cx_grid, cy_grid


def hw_stop(cx: ArrayLike, cy: ArrayLike,
            max_count: int = MAX_COUNT) -> Tuple[IntArray, IntArray]:
    """Follow src/main/iterator.vhd including the periodicity detection. Returns
    the count (which must be the same as from hw_count()), and the number of
    iterations done when the iterator stops, i.e. the value of cnt_r in the
    last ADD_ST. x and y are saved after iterations 1, 2, 4, 8, ..., and
    compared with the saved values in each iteration from iteration 2. A
    match is registered, and stops the iteration one iteration later, with
    the count max_count."""
    cx_i: IntArray = np.asarray(cx, np.int64)
    cy_i: IntArray = np.asarray(cy, np.int64)
    x: IntArray = np.zeros_like(cx_i)
    y: IntArray = np.zeros_like(cx_i)
    sx: IntArray = np.zeros_like(cx_i)
    sy: IntArray = np.zeros_like(cx_i)
    cnt: IntArray = np.zeros_like(cx_i)
    stop: IntArray = np.zeros_like(cx_i)
    done: BoolArray = np.zeros(cx_i.shape, bool)
    ovf: BoolArray = np.zeros(cx_i.shape, bool)
    match: BoolArray = np.zeros(cx_i.shape, bool)
    while True:
        # ADD_ST, with x and y after cnt iterations
        active = ~done
        new_match = (cnt >= 2) & (x == sx) & (y == sy)
        save = active & (cnt != 0) & ((cnt & (cnt - 1)) == 0)
        stop = np.where(active, cnt, stop)
        found = active & ~ovf & match
        cnt = np.where(found, max_count, cnt)
        done |= active & (ovf | match)
        active = ~done
        cnt = np.where(active, cnt + 1, cnt)
        done |= active & (cnt == max_count)
        match = np.where(active, new_match, match)
        sx = np.where(save, x, sx)
        sy = np.where(save, y, sy)
        if done.all():
            return cnt, stop

        # The iteration (MULT_ST and UPDATE_ST), as in hw_count()
        new_x_s = (x + y) * (x - y) + (cx_i << 16)
        new_y_half_s = x * y + (cy_i << 15)
        ovf_x = (new_x_s < -(1 << 33)) | (new_x_s >= (1 << 33))
        ovf_y = (new_y_half_s < -(1 << 32)) | (new_y_half_s >= (1 << 32))
        ovf = np.where(done, ovf, ovf_x | ovf_y)
        x = np.where(done, x, wrap(new_x_s >> 16, 18))
        y = np.where(done, y, wrap(new_y_half_s >> 15, 18))


def iterating_cycles(stop: ArrayLike) -> IntArray:
    """The number of clock cycles the iterator needs for each pixel: 3 clock
    cycles per iteration, plus 7 to start and to deliver the result. stop is
    the number of iterations done when the iterator stops (see hw_stop())."""
    return 3*np.asarray(stop, np.int64) + 7


def pixel_cycles(stop: ArrayLike,
                 num_iterators: int = NUM_ITERATORS) -> IntArray:
    """The number of clock cycles a column module uses for each pixel. stop is
    the number of iterations done when the iterator stops (see hw_stop()).

    The iterator uses 3 clock cycles per iteration, and a few more to start and
    finish. Then the result has to be accepted by the dispatcher. The scheduler
    for the results (i_scheduler_res) checks each column module once every
    num_iterators clock cycles, so the time from one result to the next is
    always a multiple of num_iterators clock cycles. This has been checked in
    simulation (main_tb) for the first 11744 pixels, and the estimated time
    for the picture was the same as the time measured on the board (before
    the periodicity detection)."""
    busy: IntArray = iterating_cycles(stop)
    return -(-busy // num_iterators) * num_iterators      # Round up


def picture_cycles(stop: ArrayLike, num_iterators: int = NUM_ITERATORS,
                   job_rows: int = JOB_ROWS) -> int:
    """Estimate the number of clock cycles used to calculate the picture. stop
    is the number of iterations done by the iterator for each pixel (see
    hw_stop()), indexed by [row, column]. Each job is job_rows rows of a
    picture column, and the jobs are given in the same order as by the
    dispatcher (all the picture columns of the top block of rows, then all the
    picture columns of the next block, and so on) to the first column module
    that is idle. The time it takes the dispatcher to give a job to a column
    module is not included."""
    cycles: IntArray = pixel_cycles(stop, num_iterators)
    rows, cols = cycles.shape
    job_cycles: IntArray = cycles.reshape(rows // job_rows, job_rows,
                                          cols).sum(axis=1).flatten()
    # The time when each column module becomes idle
    idle: List[int] = [0] * num_iterators
    heapq.heapify(idle)
    for c in job_cycles:
        heapq.heappush(idle, heapq.heappop(idle) + int(c))
    return max(idle)


def rgb(cnt: ArrayLike) -> NDArray[np.uint8]:
    """The colour shown on the VGA output: The lowest 8 bits of the count, as
    RRRGGGBB. Returns an array of 8-bit RGB values."""
    v: IntArray = np.asarray(cnt, np.int64) & 0xFF
    r = ((v >> 5) & 7) * 255 // 7
    g = ((v >> 2) & 7) * 255 // 7
    b = (v & 3) * 255 // 3
    return np.stack([r, g, b], -1).astype(np.uint8)


def main() -> None:
    args: List[str] = sys.argv[1:]
    if args not in ([], ["--png"]):
        print("Usage: model.py [--png]")
        sys.exit(2)

    cx, cy = view()
    hw = hw_count(cx, cy)
    ref = ref_count(cx / 65536.0, cy / 65536.0)

    diff = hw - ref
    print(f"{hw.size} pixels, maximum count {MAX_COUNT}")
    print("Difference in count (model vs. real) : number of pixels")
    values, counts = np.unique(np.clip(np.abs(diff), 0, 5), return_counts=True)
    for v, c in zip(values, counts):
        print(f"  {v:3d}{'+' if v == 5 else ' '}: {c}")
    print(f"Pixels in the set: model {(hw == MAX_COUNT).sum()}, "
          f"real {(ref == MAX_COUNT).sum()}, "
          f"different {((hw == MAX_COUNT) != (ref == MAX_COUNT)).sum()}")

    detected, stop = hw_stop(cx, cy)
    in_set = hw == MAX_COUNT
    print(f"Periodicity detection: same count as without it for all pixels: "
          f"{bool((detected == hw).all())}. It stops "
          f"{(in_set & (stop < MAX_COUNT - 1)).sum()} of the {in_set.sum()} "
          f"pixels in the set early, after {stop[in_set].mean():.0f} "
          f"iterations on average")

    cycles = picture_cycles(stop)
    per_pixel = pixel_cycles(stop).mean()
    iterating = iterating_cycles(stop).mean()
    print(f"Average count {hw.mean():.1f}. The iterator needs {iterating:.0f} "
          f"clock cycles per pixel, and {per_pixel:.0f} clock cycles per "
          f"pixel including the time waiting for the result to be accepted")
    print(f"Estimated time for the picture: {cycles} clock cycles "
          f"({cycles / 2**11:.0f} x 2^11), i.e. {cycles / MAIN_CLOCK_KHZ:.2f} ms "
          f"at {MAIN_CLOCK_KHZ / 1000:.3f} MHz")
    # The waiting time is the time from the end of the iteration until the
    # result is accepted. The wait counters, which have been removed from the
    # design, counted 2 clock cycles more for each pixel, in units of 2^11.
    waiting = int((pixel_cycles(stop) - iterating_cycles(stop)).sum())
    print(f"Estimated total waiting time: {waiting} clock cycles "
          f"({waiting / 2**11:.0f} x 2^11), i.e. {waiting / hw.size:.0f} clock "
          f"cycles per pixel. The wait counters would have shown "
          f"{(waiting + 2*hw.size) // 2**11} x 2^11")

    if args == ["--png"]:
        from PIL import Image
        Image.fromarray(rgb(hw)).save("model.png")
        Image.fromarray(rgb(ref)).save("ref.png")
        print("Pictures written to model.png and ref.png")


if __name__ == "__main__":
    main()
