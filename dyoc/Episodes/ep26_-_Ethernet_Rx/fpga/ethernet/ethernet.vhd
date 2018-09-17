library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module provides a high-level interface to the Ethernet port.

entity ethernet is
   port (
      -- Must be 50 MHz
      clk_i        : in  std_logic;

      -- Connected to user
      user_wren_o  : out std_logic;
      user_addr_o  : out std_logic_vector(15 downto 0);
      user_data_o  : out std_logic_vector( 7 downto 0);
      user_memio_i : in  std_logic_vector(31 downto 0);
      user_memio_o : out std_logic_vector(63 downto 0);

      -- Connected to PHY.
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_o    : out   std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic
   );
end ethernet;

architecture Structural of ethernet is

   -- Minimum reset assert time for the Ethernet PHY is 25 ms.
   -- At 50 MHz (= 20 ns pr clock cycle) this is approx 2*10^6 clock cycles.
   -- Therefore, the rst_cnt has a size of 21 bits, which means that
   -- 'eth_rst' is deasserted after 40 ms.
   signal eth_rst     : std_logic := '1';
   signal eth_rst_cnt : std_logic_vector(20 downto 0) := (others => '1');

   signal eth_rx_valid : std_logic;
   signal eth_rx_sof   : std_logic;
   signal eth_rx_eof   : std_logic;
   signal eth_rx_data  : std_logic_vector(7 downto 0);
   signal eth_rx_error : std_logic_vector(1 downto 0);

   signal user_wren    : std_logic;
   signal user_addr    : std_logic_vector(15 downto 0);
   signal user_data    : std_logic_vector( 7 downto 0);
   --
   signal cnt          : std_logic_vector(15 downto 0);
   signal errors0      : std_logic_vector( 7 downto 0);
   signal errors1      : std_logic_vector( 7 downto 0);

begin

   user_memio_o(15 downto  0) <= user_addr;
   user_memio_o(31 downto 16) <= cnt;
   user_memio_o(39 downto 32) <= errors0;
   user_memio_o(47 downto 40) <= errors1;

   proc_error : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if eth_rx_valid = '1' and eth_rx_eof = '1' then
            cnt <= cnt + 1;

            if eth_rx_error(0) = '1' then
               errors0 <= errors0 + 1;
            end if;

            if eth_rx_error(1) = '1' then
               errors1 <= errors1 + 1;
            end if;
         end if;
      end if;
   end process proc_error;

   proc_user : process (clk_i)
   begin
      if rising_edge(clk_i) then
         user_wren <= '0';
         if eth_rx_valid = '1' then
            if eth_rx_sof = '1' then
               user_addr <= X"7000";
            else
               user_addr <= user_addr + 1;
            end if;
            user_wren <= '1';
            user_data <= eth_rx_data;
         end if;
      end if;
   end process proc_user;


   ------------------------------
   -- Generates reset signal for the Ethernet PHY.
   ------------------------------

   proc_eth_rst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if eth_rst_cnt /= 0 then
            eth_rst_cnt <= eth_rst_cnt - 1;
         else
            eth_rst <= '0';
         end if;
      end if;
   end process proc_eth_rst;
   

   ------------------------------
   -- Ethernet LAN 8720A PHY
   ------------------------------

   inst_phy : entity work.lan8720a
   port map (
      clk_i          => clk_i,
      rst_i          => eth_rst,
      -- Rx interface
      rx_valid_o     => eth_rx_valid,
      rx_sof_o       => eth_rx_sof,
      rx_eof_o       => eth_rx_eof,
      rx_data_o      => eth_rx_data,
      rx_error_o     => eth_rx_error,
      -- External pins to the LAN 8720A PHY
      eth_txd_o      => eth_txd_o,
      eth_txen_o     => eth_txen_o,
      eth_rxd_i      => eth_rxd_i,
      eth_rxerr_i    => eth_rxerr_i,
      eth_crsdv_i    => eth_crsdv_i,
      eth_intn_i     => eth_intn_i,
      eth_mdio_io    => eth_mdio_io,
      eth_mdc_o      => eth_mdc_o,
      eth_rstn_o     => eth_rstn_o,
      eth_refclk_o   => eth_refclk_o
   );

   -- Drive output signals
   user_wren_o <= user_wren;
   user_addr_o <= user_addr;
   user_data_o <= user_data;
   
end Structural;

