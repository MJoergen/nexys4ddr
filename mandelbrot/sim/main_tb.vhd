library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

-- This testbench runs the MAIN clock domain (main.vhd) with the initial view,
-- and no buttons pressed. Every pixel written to the display memory is written
-- to the file sim/main_out.txt, as one line "address data" (both as decimal
-- numbers). The testbench stops when a complete picture (640x480 pixels) has
-- been written.
--
-- The generics are the number of column modules and the number of pixels in
-- each write, by default as on the Nexys 4 DDR (mandelbrot.vhd). They can be
-- set with GENERICS, e.g. GENERICS="G_NUM_ITERATORS=450 G_PIXELS=4" as on the
-- MEGA65 R6 (mega65_r6.vhd).
--
-- The testbench is not self-checking. Instead the output is compared with the
-- bit-accurate model using the script cmp_rtl.py. A complete picture takes
-- about 1.5 hours to simulate (with STOP_TIME=4ms), and writes a waveform of
-- about 5 GB, but a partial picture can be compared too, e.g.
--   make run TB=main STOP_TIME=700us
--   sim/cmp_rtl.py

entity main_tb is
   generic (
      G_NUM_ITERATORS : integer := 240;
      G_PIXELS        : integer := 1
   );
end entity main_tb;

architecture simulation of main_tb is

   constant C_NUM_PIXELS : integer := 640*480;

   signal clk     : std_logic;
   signal rst     : std_logic := '1';

   signal wr_addr : std_logic_vector(18 downto 0);
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
         G_NUM_ITERATORS => G_NUM_ITERATORS,
         G_PIXELS        => G_PIXELS
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
      variable n : integer := 0;
   begin
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
