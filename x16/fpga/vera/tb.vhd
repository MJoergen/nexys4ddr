library ieee;
use ieee.std_logic_1164.all;

-- This is a test bench for the VERA

entity tb is
end tb;

architecture simulation of tb is

   signal clk_s     : std_logic;                       -- 25 MHz
   signal vga_hs_s  : std_logic; 
   signal vga_vs_s  : std_logic;
   signal vga_col_s : std_logic_vector(11 downto 0);   -- 4 bits for each colour RGB.

begin

   --------------------
   -- Clock generation
   --------------------

   p_clk : process
   begin
      clk_s <= '1', '0' after 2 ns;
      wait for 4 ns; -- 25 MHz
   end process p_clk;


   --------------------
   -- Instantiate VERA
   --------------------

   i_vera : entity work.vera
      port map (
         clk_i     => clk_s,
         vga_hs_o  => vga_hs_s,
         vga_vs_o  => vga_vs_s,
         vga_col_o => vga_col_s
      ); -- i_vera

end architecture simulation;

