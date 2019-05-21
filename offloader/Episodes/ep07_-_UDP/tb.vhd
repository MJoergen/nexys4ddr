library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb is
end tb;

architecture simulation of tb is

   signal clk     : std_logic;                      -- 100 MHz
   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;
   signal vga_col : std_logic_vector(11 downto 0);  -- RRRRGGGGBBB

begin

   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   -- Generate clock
   clk_gen : process
   begin
      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process clk_gen;


   --------------------------------------------------
   -- Instantiate DUT
   --------------------------------------------------
   
   i_top : entity work.top
   port map (
      clk_i     => clk,
      vga_hs_o  => vga_hs,
      vga_vs_o  => vga_vs,
      vga_col_o => vga_col
   ); -- i_top

end architecture simulation;

