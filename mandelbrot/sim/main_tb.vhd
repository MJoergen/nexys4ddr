-- This testbench runs the MAIN clock domain (main.vhd) with the initial view,
-- and no buttons pressed. The first line of the file sim/main_out.txt is the
-- size of the picture and the address distance between two picture columns,
-- "columns rows stride". Then every pixel written to the display memory is
-- written to the file, as one line "address data" (all as decimal numbers).
-- The testbench stops when a complete picture has been written.
--
-- The generics are the number of job modules, the number of pixels in each
-- write, the rows in a job, the size of the picture, the address distance
-- between two picture columns, and the bits of the address, by default as on
-- the Nexys 4 DDR (nexys4ddr.vhd). They can be set with GENERICS, e.g. as on
-- the MEGA65 R6 (mega65_r6.vhd):
--   GENERICS="G_NUM_ITERATORS=368 G_PIXELS=4 G_ROWS_IN_JOB=64 G_NUM_COLS=1280 G_NUM_ROWS=1024 G_COL_STRIDE=1024 G_ADDR_BITS=21"
--
-- The testbench is not self-checking. Instead the output is compared with the
-- bit-accurate model using the script cmp_rtl.py. A complete picture of the
-- Nexys 4 DDR (1.44 ms of simulated time) takes about 40 minutes to simulate,
-- and writes a waveform of a few GB, but a partial picture can be compared
-- too, e.g.
--   make run TB=main STOP_TIME=200us
--   sim/cmp_rtl.py

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

entity main_tb is
   generic (
      G_NUM_ITERATORS : positive := 120;
      G_PIXELS        : positive := 4;
      G_ROWS_IN_JOB   : positive := 120;
      G_NUM_COLS      : positive := 640;
      G_NUM_ROWS      : positive := 480;
      G_COL_STRIDE    : positive := 512;
      G_ADDR_BITS     : positive := 19
   );
end entity main_tb;

architecture simulation of main_tb is

   constant C_NUM_PIXELS : natural := G_NUM_COLS*G_NUM_ROWS;

   signal clk     : std_logic;
   signal rst     : std_logic := '1';

   signal wr_addr : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal wr_data : std_logic_vector(9*G_PIXELS-1 downto 0);
   signal wr_en   : std_logic;

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


   -------------------
   -- Instantiate DUT
   -------------------

   i_main : entity work.main
      generic map (
         G_CLK_FREQ      => 100_000_000,   -- As p_clk
         G_NUM_ITERATORS => G_NUM_ITERATORS,
         G_PIXELS        => G_PIXELS,
         G_ROWS_IN_JOB   => G_ROWS_IN_JOB,
         G_NUM_COLS      => G_NUM_COLS,
         G_NUM_ROWS      => G_NUM_ROWS,
         G_COL_STRIDE    => G_COL_STRIDE,
         G_ADDR_BITS     => G_ADDR_BITS
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         btn_i     => "00000",
         sw_i      => X"00",
         seg_o     => open,
         seg_an_o  => open,
         wr_addr_o => wr_addr,
         wr_data_o => wr_data,
         wr_en_o   => wr_en
      ); -- i_main


   ----------------------------------
   -- Write the output to the file
   ----------------------------------

   p_dump : process (clk)
      file     f : text open write_mode is "sim/main_out.txt";
      variable l : line;
      variable n : natural := 0;
      variable header : boolean := false;
   begin
      if not header then
         write(l, G_NUM_COLS);
         write(l, string'(" "));
         write(l, G_NUM_ROWS);
         write(l, string'(" "));
         write(l, G_COL_STRIDE);
         writeline(f, l);
         header := true;
      end if;

      if rising_edge(clk) then
         if wr_en = '1' and rst = '0' then
            -- The pixels of a write are consecutive rows
            for i in 0 to G_PIXELS-1 loop
               write(l, to_integer(wr_addr) + i);
               write(l, string'(" "));
               write(l, to_integer(wr_data(9*i+8 downto 9*i)));
               writeline(f, l);
            end loop;
            n := n + G_PIXELS;
            if n = C_NUM_PIXELS then
               report "main_tb: complete picture written";
               std.env.finish;
            end if;
         end if;
      end if;
   end process p_dump;

end architecture simulation;
