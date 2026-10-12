# TODO

1. Remove the reset process of the block RAM. On reset, the display memory
   ([`src/disp_mem.vhd`](src/disp_mem.vhd)) fills all its BRAMs with the value
   0x055, which takes `G_NUM_BLOCKS`*4096/`G_PIXELS` clock cycles (1.09 ms on
   the Nexys 4 DDR, and 2.31 ms on the MEGA65), and ignores the writes until it
   is finished. So [`src/main/main.vhd`](src/main/main.vhd) must wait for it
   (`wr_busy_o` and `wr_busy_i`) before it starts the first picture, see
   [The top level](ALGORITHM.md#the-top-level). The first picture overwrites
   every visible pixel anyway. Without the reset process, the wait, the busy
   signal, and the address counter and the multiplexer on the write port can
   be removed, and the testbenches `disp_mem_tb` and `redraw_tb` must be
   changed. The BRAMs are cleared when the FPGA is configured (the count 0,
   black in palette 0), and after a reset the previous picture stays until the
   first picture has overwritten it.

2. Display current centre coordinate and zoom level as decimal values at top
   of screen

3. Use keyboard (on MEGA65) to change palette

4. Offset palette at a certain depth, i.e. set color = depth - offset. And have
   the offset value change slowly with time. This gives a feeling of "moving".

5. Move this folder to a separate repo on GitHub, and make the MEGA65 boards
   the "first citizen", and the Nexys board an added feature (currently it's
   the other way around).

