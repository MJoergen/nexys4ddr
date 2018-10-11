library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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
   
   -- Controls the traffic input to Ethernet.
   signal sim_data  : std_logic_vector(128*8-1 downto 0);
   signal sim_len   : std_logic_vector( 15     downto 0);
   signal sim_start : std_logic := '0';
   signal sim_done  : std_logic;

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
      eth_txd_o    => open,   -- We're ignoring transmit for now
      eth_txen_o   => open,   -- We're ignoring transmit for now
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => '0',
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => '0',
      eth_mdio_io  => open,
      eth_mdc_o    => open,
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


   ---------------------------------
   -- Instantiate PHY simulator
   ---------------------------------

   inst_phy_sim : entity work.phy_sim
   port map (
      sim_data_i   => sim_data,
      sim_len_i    => sim_len,
      sim_start_i  => sim_start,
      sim_done_o   => sim_done,
      --
      eth_refclk_i => eth_refclk,
      eth_rstn_i   => eth_rstn,
      eth_txd_o    => eth_rxd,
      eth_txen_o   => eth_crsdv
   );


   ---------------------
   -- Generate Ethernet data
   ---------------------

   process
      type frame_t is array (natural range <>) of std_logic_vector(7 downto 0);

      constant frame : frame_t(0 to 45) :=
         (X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"F4", x"6D",
          X"04", X"D7", X"F3", X"CA", X"08", X"06", X"00", x"01",
          X"08", X"00", X"06", X"04", X"00", X"01", X"F4", X"6D",
          X"04", X"D7", X"F3", X"CA", X"C0", X"A8", X"01", X"2B",
          X"00", X"00", X"00", X"00", X"00", X"00", X"C0", X"A8",
          X"01", X"4D", X"CC", X"CC", X"CC", X"CC");  -- Must include 4 dummy bytes for CRC.

   begin
      wait for 120 us;            -- Wait until DMA's are initialized.

      -- Send frame
      for i in 0 to 45 loop
         sim_data(8*i+7 downto 8*i) <= frame(i);
      end loop;
      sim_len   <= std_logic_vector(to_unsigned(46, 16)); -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait;
   end process;


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

