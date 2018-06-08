library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity tb is
end tb;

architecture Structural of tb is

   -- Clock and Reset
   signal clk  : std_logic;
   signal rstn : std_logic;

   -- Computer
   signal sw      : std_logic_vector(7 downto 0);
   signal led     : std_logic_vector(7 downto 0);
   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;
   signal vga_col : std_logic_vector(7 downto 0);

begin
   
   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   clk_gen : process
   begin
      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process clk_gen;


   --------------------------------------------------
   -- Generate Reset
   --------------------------------------------------

   rstn <= '0', '1' after 15 ns;


   --------------------------------------------------
   -- Generate input switches
   --------------------------------------------------

   sw <= "10000000"; -- Fast mode


   --------------------------------------------------
   -- Instantiate computer
   --------------------------------------------------

   inst_comp : entity work.comp
   port map (
      clk_i     => clk,
      sw_i      => sw,
      led_o     => led,
      rstn_i    => rstn,
      vga_hs_o  => vga_hs,
      vga_vs_o  => vga_vs,
      vga_col_o => vga_col
   );

end architecture Structural;

