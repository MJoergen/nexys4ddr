----------------------------------------------------------------------------------
-- Company:  Granbo
-- Engineer: Michael Jørgensen
-- 
-- The file contains the top level test bench for the timer_demo
----------------------------------------------------------------------------------
library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;

entity nexys4ddr_tb is
end nexys4ddr_tb;

architecture Structural of nexys4ddr_tb is

   -- Clock and reset
   signal clk100   : std_logic := '0';  -- 100 MHz
   signal sys_rstn : std_logic := '0';

   -- VGA port
   signal vga_hs    : std_logic; 
   signal vga_vs    : std_logic;
   signal vga_col   : std_logic_vector (11 downto 0); 

   -- Connected to PHY
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

   -- Switches
   signal sw        : std_logic_vector (15 downto 0);

   -- Buttons
   signal btn       : std_logic_vector( 4 downto 0);

   -- Keyboard
   signal ps2_clk  : std_logic;
   signal ps2_data : std_logic;

   signal key_rst   : std_logic := '1';
   signal key_cnt   : std_logic_vector(11 downto 0) := (others => '0');
   signal key_valid : std_logic;
   signal key_data  : std_logic_vector(7 downto 0);

   signal test_running : boolean := true;

begin

   -- Generate clock
   clk_gen : process
   begin
     if not test_running then
       wait;
     end if;

     clk100 <= '1', '0' after 5 ns; -- 100 MHz
     wait for 10 ns;
   end process clk_gen;

   -- Generate reset (asserted low)
   sys_rstn <= '0', '1' after 100 ns;

   key_rst <= '1', '0' after 10 us;

   proc_ps2 : process (clk100)
   begin
      if rising_edge(clk100) then
         key_valid <= '0';
         key_cnt   <= key_cnt + 1;
         if key_cnt = X"CCC" then
            key_cnt <= (others => '0');
         end if;

         if key_cnt = 0 then
            key_valid <= '1';
            key_data <= key_data + 1;
         end if;

         if key_rst = '1' then
            key_valid <= '0';
            key_cnt   <= (others => '0');
            key_data  <= X"3C";
         end if;
      end if;
   end process proc_ps2;

   -- Generate input switches
   sw <= X"0000";
   -- sw <= X"0100";
   -- sw <= X"0101"; -- Used for testing single-step.

   -- Generate input buttons
   btn_gen : process
   begin
      if not test_running then
         wait;
      end if;

      btn <= "00000", "00001" after 100 ns;
      wait for 200 ns;
   end process btn_gen;

   -- Instantiate keyboard
   inst_ps2_tb : entity work.ps2_tb
   port map (
      -- Clock
      clk_i      => clk100,
      rst_i      => key_rst,
      data_i     => key_data,
      valid_i    => key_valid,
      ps2_clk_o  => ps2_clk,
      ps2_data_o => ps2_data 
   );

   -- Instantiate DUT
   inst_nexys4ddr : entity work.nexys4ddr
   generic map (
      G_RESET_SIZE => 8,
      G_SIMULATION => true,
      G_HOST_MAC   => X"F46D04112233",
      G_HOST_IP    => X"C0A8012E",
      G_HOST_PORT  => X"2345"
   )
   port map (
      clk100_i   => clk100,
      sys_rstn_i => sys_rstn,
      vga_hs_o   => vga_hs,
      vga_vs_o   => vga_vs,
      vga_col_o  => vga_col,

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

      ps2_clk_i  => ps2_clk,
      ps2_data_i => ps2_data,
      sw_i       => sw,
      btn_i      => btn
   );

   eth_rxd   <= eth_txd;
   eth_crsdv <= eth_txen;
   eth_rxerr <= '0';
   eth_intn  <= '1';

   test_running <= true, false after 10000 us;
   
end Structural;

