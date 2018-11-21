library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb is
end tb;

architecture structural of tb is

   -- Clock
   signal clk  : std_logic;

   -- VGA
   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;
   signal vga_col : std_logic_vector(7 downto 0);

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
   -- Instantiate Computer
   --------------------------------------------------
   
   i_comp : entity work.comp
   port map (
      clk_i     => clk,
      sw_i      => X"80",
      led_o     => open,
      rstn_i    => '1',
      vga_hs_o  => vga_hs,
      vga_vs_o  => vga_vs,
      vga_col_o => vga_col
   );


end architecture structural;

