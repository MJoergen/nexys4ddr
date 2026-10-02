#!/usr/bin/env python3

# Vectorized (numpy) bit-accurate model of the picture calculated by the
# design, and a reference calculated using real (floating point) numbers.
#
# hw_count() follows src/iterator.vhd (like iterator_model.py, but for many
# points at once), and view() gives the values of c for each pixel, calculated
# in the same way as src/main.vhd, src/dispatcher.vhd and src/column.vhd. This
# module is used by cmp_rtl.py to compare the simulated design with the model.
#
# Run as a script, it compares the model with the reference for the initial
# view (640x480), and prints how many pixels differ. It also estimates the time
# it takes the design to calculate the picture, see picture_cycles().
#
# Usage:
#   ./model.py           Compare the model with the reference.
#   ./model.py --png     Same, and write the pictures to model.png and ref.png
#                        (requires Pillow), using the same colours as the VGA
#                        output.
#
# Requires numpy.

import sys

import numpy as np

MAX_COUNT = 511      # Must match C_MAX_COUNT in main.vhd
NUM_COLS  = 640      # Must match C_NUM_COLS in main.vhd
NUM_ROWS  = 480      # Must match C_NUM_ROWS in main.vhd
NUM_ITERATORS = 240  # Must match C_NUM_ITERATORS in main.vhd


def wrap(v, bits: int) -> np.ndarray:
    """Interpret the lowest 'bits' bits of v as two's complement numbers."""
    m = 1 << bits
    v = np.asarray(v, dtype=np.int64) & (m - 1)
    return np.where(v >= m >> 1, v - m, v)


def hw_count(cx, cy, max_count: int = MAX_COUNT) -> np.ndarray:
    """Iteration count of src/iterator.vhd. cx and cy are 2.16 fixed point
    numbers, i.e. 18-bit signed integers."""
    cx = np.asarray(cx, np.int64)
    cy = np.asarray(cy, np.int64)
    cx_s = cx << 16                   # 4.32
    cy_div_2_s = cy << 15             # 4.32, this is cy/2
    x = np.zeros_like(cx)             # 2.16
    y = np.zeros_like(cx)             # 2.16
    cnt = np.zeros_like(cx)
    done = np.zeros(cx.shape, bool)
    ovf = np.zeros(cx.shape, bool)
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


def ref_count(cx, cy, max_count: int = MAX_COUNT) -> np.ndarray:
    """Iteration count using real numbers (cx and cy are real numbers). Same
    counting as the iterator: The number of the first iteration where x or y is
    outside the range -2 to 2, or max_count if this does not happen."""
    cx = np.asarray(cx, float)
    cy = np.asarray(cy, float)
    x = np.zeros_like(cx)
    y = np.zeros_like(cx)
    cnt = np.full(cx.shape, max_count, np.int64)
    done = np.zeros(cx.shape, bool)
    for n in range(1, max_count):
        x, y = x*x - y*y + cx, 2*x*y + cy
        out = ~((x >= -2) & (x < 2) & (y >= -2) & (y < 2)) & ~done
        cnt[out] = n
        done |= out
        # Stop iterating the points that are done, so they do not overflow
        x = np.where(done, 0.0, x)
        y = np.where(done, 0.0, y)
    return cnt


def view(startx: int = None, starty: int = None, stepx: int = None,
         stepy: int = None, cols: int = NUM_COLS, rows: int = NUM_ROWS):
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
    return np.meshgrid(cx, cy)


def pixel_cycles(cnt, num_iterators: int = NUM_ITERATORS) -> np.ndarray:
    """The number of clock cycles a column module uses for each pixel.

    The iterator uses 3 clock cycles per iteration, and a few more to start and
    finish. Then the result has to be accepted by the dispatcher. The scheduler
    for the results (i_scheduler_res) checks each column module once every
    num_iterators clock cycles, so the time from one result to the next is
    always a multiple of num_iterators clock cycles. This has been checked in
    simulation (main_tb) for the first 11744 pixels, and the estimated time
    for the picture is the same as the time measured on the board."""
    cnt = np.asarray(cnt, np.int64)
    busy = np.where(cnt == MAX_COUNT, 3*cnt + 4, 3*cnt + 7)
    return -(-busy // num_iterators) * num_iterators      # Round up


def picture_cycles(cnt, num_iterators: int = NUM_ITERATORS) -> int:
    """Estimate the number of clock cycles used to calculate the picture. cnt
    is the count of each pixel, indexed by [row, column]. The picture columns
    are given in order to the first column module that is idle. The time it
    takes the dispatcher to give a job to a column module is not included."""
    col_cycles = pixel_cycles(cnt, num_iterators).sum(axis=0)
    idle = [0] * num_iterators       # The time each column module becomes idle
    for c in col_cycles:
        i = idle.index(min(idle))
        idle[i] += int(c)
    return max(idle)


def rgb(cnt) -> np.ndarray:
    """The colour shown on the VGA output: The lowest 8 bits of the count, as
    RRRGGGBB. Returns an array of 8-bit RGB values."""
    v = np.asarray(cnt, np.int64) & 0xFF
    r = ((v >> 5) & 7) * 255 // 7
    g = ((v >> 2) & 7) * 255 // 7
    b = (v & 3) * 255 // 3
    return np.stack([r, g, b], -1).astype(np.uint8)


def main() -> None:
    args = sys.argv[1:]
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

    cycles = picture_cycles(hw)
    per_pixel = pixel_cycles(hw).mean()
    iterating = np.where(hw == MAX_COUNT, 3*hw + 4, 3*hw + 7).mean()
    print(f"Average count {hw.mean():.1f}, i.e. {iterating:.0f} clock cycles "
          f"per pixel for the iterator, and {per_pixel:.0f} clock cycles per "
          f"pixel including the time waiting for the result to be accepted")
    print(f"Estimated time for the picture: {cycles} clock cycles "
          f"({cycles / 2**11:.0f} x 2^11), i.e. {cycles / 140.625e3:.2f} ms "
          f"at 140.625 MHz")

    if args == ["--png"]:
        from PIL import Image
        Image.fromarray(rgb(hw)).save("model.png")
        Image.fromarray(rgb(ref)).save("ref.png")
        print("Pictures written to model.png and ref.png")


if __name__ == "__main__":
    main()
