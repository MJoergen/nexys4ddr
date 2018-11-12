library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb is
end tb;

architecture Structural of tb is

   -- Clock and Reset
   signal clk  : std_logic;
   signal rstn : std_logic;

   -- Computer
   signal sw       : std_logic_vector(7 downto 0);
   signal led      : std_logic_vector(7 downto 0);
   signal vga_hs   : std_logic;
   signal vga_vs   : std_logic;
   signal vga_col  : std_logic_vector(7 downto 0);
   signal ps2_clk  : std_logic;
   signal ps2_data : std_logic;

   -- PS/2 interface
   signal data  : std_logic_vector(7 downto 0);
   signal valid : std_logic;

   -- Connected to Ethernet PHY
   signal eth_txd    : std_logic_vector(1 downto 0);
   signal eth_txen   : std_logic;
   signal eth_rxd    : std_logic_vector(1 downto 0);
   signal eth_rxerr  : std_logic;
   signal eth_crsdv  : std_logic;
   signal eth_intn   : std_logic;
   signal eth_mdio   : std_logic;
   signal eth_mdc    : std_logic;
   signal eth_rstn   : std_logic;
   signal eth_refclk : std_logic;
   
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
      clk_i        => clk,
      sw_i         => sw,
      led_o        => led,
      rstn_i       => rstn,
      ps2_clk_i    => ps2_clk,
      ps2_data_i   => ps2_data,
      eth_txd_o    => eth_txd,
      eth_txen_o   => eth_txen,
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => eth_rxerr,
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => eth_intn,
      eth_mdio_io  => eth_mdio,
      eth_mdc_o    => eth_mdc,
      eth_rstn_o   => eth_rstn,
      eth_refclk_o => eth_refclk,
      vga_hs_o     => vga_hs,
      vga_vs_o     => vga_vs,
      vga_col_o    => vga_col
   );


   --------------------------------------------------
   -- Instantiate PS/2 writer
   --------------------------------------------------

   inst_ps2_tb : entity work.ps2_tb
   port map (
      -- Clock
      clk_i      => clk,
      data_i     => data,
      valid_i    => valid,
      ps2_clk_o  => ps2_clk,
      ps2_data_o => ps2_data
   );


   ---------------------
   -- Generate PS/2 data
   ---------------------

   process
   begin
      data <= X"13";
      valid <= '0';
      wait for 40 us;
      valid <= '1';
      wait until clk = '1';
      valid <= '0';
      wait;
   end process;

end architecture Structural;

