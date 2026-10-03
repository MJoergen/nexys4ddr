library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

-- This testbench runs the MAIN clock domain (main.vhd) with the initial view,
-- and no buttons pressed. Every write to the display memory is written to the
-- file sim/main_out.txt, as one line "address data" (both as decimal numbers).
-- The testbench stops when a complete picture (640x480 pixels) has been
-- written.
--
-- The testbench is not self-checking. Instead the output is compared with the
-- bit-accurate model using the script cmp_rtl.py. A complete picture takes
-- several hours to simulate, but a partial picture can be compared too, e.g.
--   make run TB=main STOP_TIME=700us
--   sim/cmp_rtl.py

entity main_tb is
end entity main_tb;

architecture simulation of main_tb is

   constant C_NUM_PIXELS : integer := 640*480;

   signal clk     : std_logic;
   signal rst     : std_logic := '1';

   signal wr_addr : std_logic_vector(18 downto 0);
   signal wr_data : std_logic_vector( 8 downto 0);
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
      port map (
         clk_i     => clk,
         rst_i     => rst,
         btn_i     => "00000",
         sw_i      => X"00",
         led_o     => open,
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
            write(l, to_integer(wr_addr));
            write(l, string'(" "));
            write(l, to_integer(wr_data));
            writeline(f, l);
            n := n + 1;
            if n = C_NUM_PIXELS then
               report "main_tb: complete picture written";
               std.env.finish;
            end if;
         end if;
      end if;
   end process p_dump;

end architecture simulation;
