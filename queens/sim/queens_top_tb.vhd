library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;

entity queens_top_tb is
end entity queens_top_tb;

architecture simulation of queens_top_tb is

   constant NUM_QUEENS : integer := 4;
   constant FREQ       : integer := 5;

    -- Clock
   signal clk   : std_logic;  -- 100 MHz

    -- LED, buttom, and switches
   signal led       : std_logic_vector (7 downto 0);
   signal sw        : std_logic_vector (7 downto 0);

    -- VGA port
   signal vga_hs    : std_logic;
   signal vga_vs    : std_logic;
   signal vga_red   : std_logic_vector (3 downto 0);
   signal vga_green : std_logic_vector (3 downto 0);
   signal vga_blue  : std_logic_vector (3 downto 0);

    -- Output segment display
   signal seg_ca    : std_logic_vector (6 downto 0);
   signal seg_dp    : std_logic;
   signal seg_an    : std_logic_vector (3 downto 0);

begin

    -- Generate clock and reset
   p_clk : process
   begin
      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      sw(0) <= '1', '0' after 1000 ns;
      wait;
   end process p_rst;

   sw(7 downto 1) <= "0000101"; -- Stop the stepping

    -- Instantiate DUT
   i_queens_top : entity work.queens_top
      generic map (
         G_FREQ       => FREQ,
         G_NUM_QUEENS => NUM_QUEENS
      )
      port map (
         clk_i       => clk,
         sw_i        => sw,
         led_o       => led,
         vga_hs_o    => vga_hs,
         vga_vs_o    => vga_vs,
         vga_red_o   => vga_red,
         vga_green_o => vga_green,
         vga_blue_o  => vga_blue
      ); -- i_queens_top

end architecture simulation;

