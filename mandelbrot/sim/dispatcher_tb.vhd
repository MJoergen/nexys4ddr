-- This is a simple self-checking testbench for the dispatcher. It is not an
-- exhaustive test. It uses three instances of the dispatcher: A normal one,
-- where each picture column is divided into four jobs; one with a single
-- picture column (i.e. with fewer picture columns than job modules) and one
-- row in each job, so every job is the last picture column of its block; and
-- one with four pixels in each write, where each picture column is divided
-- into two jobs, of two writes each. In the first two, the address is the
-- column followed by the row, and in the third the address distance between
-- two columns is not a power of two (see dispatcher.vhd). It calculates two small pictures with each
-- of them, one after the other, and checks the following for each picture:
-- * Nothing is written, and done is low, when idle. Done goes low after a
--   start.
-- * Each pixel is written exactly once, and no other pixels are written. Each
--   write starts at a row that is a multiple of the pixels in a write.
-- * All pixels have been written when done goes high, and nothing is written
--   after that.
-- * The value of each pixel is exactly the count calculated by the
--   bit-accurate model in iterator_model_pkg.vhd, for the value of c of that
--   pixel. This also checks that each pixel is calculated with the right value
--   of c, i.e. that the results are written to the right address.
--
-- A small picture, a small number of job modules, and a low maximum count
-- are used to keep the simulation short.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.iterator_model_pkg.all;

entity dispatcher_tb is
end entity dispatcher_tb;

architecture simulation of dispatcher_tb is

   constant C_MAX_COUNT     : positive := 30;
   constant C_NUM_ROWS      : positive := 16;
   constant C_NUM_COLS      : positive := 64;
   constant C_NUM_ITERATORS : positive := 16;

   -- Rows in each job, in the three instances
   constant C_ROWS_IN_JOB   : positive := 4;
   constant C_SMALL_ROWS    : positive := 1;
   constant C_WIDE_ROWS     : positive := 8;

   -- Pixels in each write in the third instance
   constant C_WIDE_PIXELS   : positive := 4;

   -- Address distance between two picture columns, in the three instances
   constant C_STRIDE        : positive := 512;
   constant C_SMALL_STRIDE  : positive := C_NUM_ROWS;
   constant C_WIDE_STRIDE   : positive := 20;

   -- Size of the groups of job modules in the first instance (see
   -- dispatcher.vhd). This gives four groups, and the last one is smaller.
   constant C_GROUP_SIZE    : positive := 5;

   -- Number of picture columns in the second instance. This is less than the
   -- number of job modules.
   constant C_SMALL_COLS    : positive := 1;

   -- Maximum number of clock cycles to wait for a picture
   constant C_TIMEOUT       : positive := 30000;

   type pixel_t is array (0 to C_NUM_COLS-1, 0 to C_NUM_ROWS-1) of integer;

   -- The signals connected to a dispatcher
   type dut_in_t is record
      start  : std_logic;
      startx : std_logic_vector(17 downto 0);
      starty : std_logic_vector(17 downto 0);
      stepx  : std_logic_vector(17 downto 0);
      stepy  : std_logic_vector(17 downto 0);
   end record dut_in_t;

   type dut_out_t is record
      wr_addr : std_logic_vector(18 downto 0);
      wr_data : std_logic_vector(9*C_WIDE_PIXELS-1 downto 0);
      wr_en   : std_logic;
      done    : std_logic;
   end record dut_out_t;

   constant C_IN_INIT : dut_in_t :=
      (start => '0', startx => (others => '0'), starty => (others => '0'),
       stepx => (others => '0'), stepy => (others => '0'));

   signal clk      : std_logic;
   signal rst      : std_logic;

   signal dut1_in  : dut_in_t := C_IN_INIT;
   signal dut1_out : dut_out_t;
   signal dut2_in  : dut_in_t := C_IN_INIT;
   signal dut2_out : dut_out_t;
   signal dut3_in  : dut_in_t := C_IN_INIT;
   signal dut3_out : dut_out_t;

   -- Convert a real value to the 2.16 fixed point format, as an integer
   function to_fixed (r : real) return integer is
   begin
      return integer(round(r * 65536.0));
   end function to_fixed;

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   ----------------------------
   -- Stimulus and checking
   ----------------------------

   p_test : process

      -- Calculate a picture, and check the results. The signals are sampled
      -- just before a rising clock edge.
      procedure run_picture (
         signal   dut_in   : out dut_in_t;
         signal   dut_out  : in  dut_out_t;
         num_cols : positive;
         stride   : positive;    -- Address distance between two columns
         pixels   : positive;    -- Pixels in each write
         startx_r : real;
         starty_r : real;
         width_r  : real;       -- Size of the picture
         height_r : real;
         name     : string
      ) is
         variable startx_i : integer := to_fixed(startx_r);
         variable starty_i : integer := to_fixed(starty_r);
         variable stepx_i  : integer := to_fixed(width_r  / real(num_cols));
         variable stepy_i  : integer := to_fixed(height_r / real(C_NUM_ROWS));
         variable col      : natural;
         variable row      : natural;
         variable total    : natural := 0;
         variable finished : boolean := false;
         variable seen_low : boolean := false;
         variable seen     : pixel_t := (others => (others => -1));
         variable exp      : integer;
         variable cx_i     : integer;
         variable cy_i     : integer;
      begin
         report "Starting picture " & name;

         wait until rising_edge(clk);
         dut_in.startx <= std_logic_vector(to_signed(startx_i, 18));
         dut_in.starty <= std_logic_vector(to_signed(starty_i, 18));
         dut_in.stepx  <= std_logic_vector(to_signed(stepx_i,  18));
         dut_in.stepy  <= std_logic_vector(to_signed(stepy_i,  18));
         dut_in.start  <= '1';
         wait until rising_edge(clk);
         dut_in.start  <= '0';

         -- The signal done is a level, which stays high after a picture is
         -- finished, until the next start. Wait for it to go low.
         for t in 1 to 5 loop
            wait until rising_edge(clk);
            assert dut_out.wr_en = '0'
               report name & ": Pixel written too early"
               severity error;
            if dut_out.done = '0' then
               seen_low := true;
            end if;
         end loop;
         assert seen_low
            report name & ": Done did not go low after start"
            severity error;

         -- Collect all the pixels until done
         for t in 1 to C_TIMEOUT loop
            wait until rising_edge(clk);

            if dut_out.wr_en = '1' then
               col := to_integer(unsigned(dut_out.wr_addr)) / stride;
               row := to_integer(unsigned(dut_out.wr_addr)) mod stride;
               if col < num_cols and row <= C_NUM_ROWS - pixels and row mod pixels = 0 then
                  for i in 0 to pixels-1 loop
                     assert seen(col, row+i) = -1
                        report name & ": Pixel (" & integer'image(col) & "," & integer'image(row+i) &
                               ") written more than once"
                        severity error;
                     seen(col, row+i) := to_integer(unsigned(dut_out.wr_data(9*i+8 downto 9*i)));
                     total := total + 1;
                  end loop;
               else
                  report name & ": Pixel outside the picture: (" & integer'image(col) & "," &
                         integer'image(row) & ")"
                     severity error;
               end if;
            end if;

            if dut_out.done = '1' then
               finished := true;
               exit;
            end if;
         end loop;

         assert finished
            report name & ": Timeout waiting for done. Pixels written: " & integer'image(total)
            severity failure;

         assert total = num_cols * C_NUM_ROWS
            report name & ": Wrong number of pixels written when done: " & integer'image(total) &
                   ", expected " & integer'image(num_cols * C_NUM_ROWS)
            severity error;

         -- Nothing more should be written after done
         for t in 1 to 20 loop
            wait until rising_edge(clk);
            assert dut_out.wr_en = '0'
               report name & ": Pixel written after done"
               severity error;
         end loop;

         -- Check the value of each pixel
         for c in 0 to num_cols-1 loop
            for r in 0 to C_NUM_ROWS-1 loop
               if seen(c, r) /= -1 then
                  -- The dispatcher and the job modules add the steps in 18
                  -- bits
                  cx_i := wrap18(startx_i + c * stepx_i);
                  cy_i := wrap18(starty_i + r * stepy_i);
                  exp  := iterator_count(cx_i, cy_i, C_MAX_COUNT);
                  assert seen(c, r) = exp
                     report name & ": Wrong count for pixel (" & integer'image(c) & "," &
                            integer'image(r) & "): got " & integer'image(seen(c, r)) &
                            ", expected " & integer'image(exp)
                     severity error;
               else
                  report name & ": Pixel (" & integer'image(c) & "," & integer'image(r) &
                         ") not written"
                     severity error;
               end if;
            end loop;
         end loop;
      end procedure run_picture;

   begin
      wait until rst = '0';

      -- Nothing should happen when idle
      for t in 1 to 20 loop
         wait until rising_edge(clk);
         assert dut1_out.done = '0' and dut1_out.wr_en = '0' and
                dut2_out.done = '0' and dut2_out.wr_en = '0' and
                dut3_out.done = '0' and dut3_out.wr_en = '0'
            report "Not idle before the first picture"
            severity error;
      end loop;

      -- Normal dispatcher. The second picture is started right after the
      -- first, which also checks that the dispatcher can be restarted.
      run_picture(dut1_in, dut1_out, C_NUM_COLS, C_STRIDE, 1, -1.0, -0.3, 0.8, 0.6, "picture 1");
      run_picture(dut1_in, dut1_out, C_NUM_COLS, C_STRIDE, 1,  0.0,  0.3, 0.5, 0.5, "picture 2");

      -- Dispatcher with a single picture column, and two pictures.
      run_picture(dut2_in, dut2_out, C_SMALL_COLS, C_SMALL_STRIDE, 1, -1.0, -0.3, 0.8, 0.6, "picture 3");
      run_picture(dut2_in, dut2_out, C_SMALL_COLS, C_SMALL_STRIDE, 1,  0.0,  0.3, 0.5, 0.5, "picture 4");

      -- Dispatcher with four pixels in each write, an address distance between
      -- two columns that is not a power of two, and two pictures.
      run_picture(dut3_in, dut3_out, C_NUM_COLS, C_WIDE_STRIDE, C_WIDE_PIXELS, -1.0, -0.3, 0.8, 0.6, "picture 5");
      run_picture(dut3_in, dut3_out, C_NUM_COLS, C_WIDE_STRIDE, C_WIDE_PIXELS,  0.0,  0.3, 0.5, 0.5, "picture 6");

      report "dispatcher_tb: finished";
      std.env.finish;
   end process p_test;


   -------------------
   -- Instantiate DUT
   -------------------

   i_dispatcher : entity work.dispatcher
      generic map (
         G_MAX_COUNT     => C_MAX_COUNT,
         G_NUM_ROWS      => C_NUM_ROWS,
         G_NUM_COLS      => C_NUM_COLS,
         G_COL_STRIDE    => C_STRIDE,
         G_ROWS_IN_JOB   => C_ROWS_IN_JOB,
         G_NUM_ITERATORS => C_NUM_ITERATORS,
         G_GROUP_SIZE    => C_GROUP_SIZE
      )
      port map (
         clk_i          => clk,
         rst_i          => rst,
         start_i        => dut1_in.start,
         startx_i       => dut1_in.startx,
         starty_i       => dut1_in.starty,
         stepx_i        => dut1_in.stepx,
         stepy_i        => dut1_in.stepy,
         wr_addr_o      => dut1_out.wr_addr,
         wr_data_o      => dut1_out.wr_data(8 downto 0),
         wr_en_o        => dut1_out.wr_en,
         done_o         => dut1_out.done
      ); -- i_dispatcher

   i_dispatcher_small : entity work.dispatcher
      generic map (
         G_MAX_COUNT     => C_MAX_COUNT,
         G_NUM_ROWS      => C_NUM_ROWS,
         G_NUM_COLS      => C_SMALL_COLS,
         G_COL_STRIDE    => C_SMALL_STRIDE,
         G_ROWS_IN_JOB   => C_SMALL_ROWS,
         G_NUM_ITERATORS => C_NUM_ITERATORS
      )
      port map (
         clk_i          => clk,
         rst_i          => rst,
         start_i        => dut2_in.start,
         startx_i       => dut2_in.startx,
         starty_i       => dut2_in.starty,
         stepx_i        => dut2_in.stepx,
         stepy_i        => dut2_in.stepy,
         wr_addr_o      => dut2_out.wr_addr,
         wr_data_o      => dut2_out.wr_data(8 downto 0),
         wr_en_o        => dut2_out.wr_en,
         done_o         => dut2_out.done
      ); -- i_dispatcher_small

   i_dispatcher_wide : entity work.dispatcher
      generic map (
         G_MAX_COUNT     => C_MAX_COUNT,
         G_NUM_ROWS      => C_NUM_ROWS,
         G_NUM_COLS      => C_NUM_COLS,
         G_COL_STRIDE    => C_WIDE_STRIDE,
         G_ROWS_IN_JOB   => C_WIDE_ROWS,
         G_NUM_ITERATORS => C_NUM_ITERATORS,
         G_GROUP_SIZE    => C_GROUP_SIZE,
         G_PIXELS        => C_WIDE_PIXELS
      )
      port map (
         clk_i          => clk,
         rst_i          => rst,
         start_i        => dut3_in.start,
         startx_i       => dut3_in.startx,
         starty_i       => dut3_in.starty,
         stepx_i        => dut3_in.stepx,
         stepy_i        => dut3_in.stepy,
         wr_addr_o      => dut3_out.wr_addr,
         wr_data_o      => dut3_out.wr_data,
         wr_en_o        => dut3_out.wr_en,
         done_o         => dut3_out.done
      ); -- i_dispatcher_wide

end architecture simulation;
