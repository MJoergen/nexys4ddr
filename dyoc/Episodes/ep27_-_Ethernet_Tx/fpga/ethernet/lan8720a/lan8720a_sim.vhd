library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simulation model of the Ethernet port.

entity lan8720a is
   port (
      clk_i        : in    std_logic;
      rst_i        : in    std_logic;

      -- Rx interface
      rx_valid_o   : out   std_logic;
      rx_sof_o     : out   std_logic;
      rx_eof_o     : out   std_logic;
      rx_data_o    : out   std_logic_vector(7 downto 0);
      rx_error_o   : out   std_logic_vector(1 downto 0);

      -- Tx interface
      tx_empty_i   : in  std_logic;
      tx_rden_o    : out std_logic;
      tx_data_i    : in  std_logic_vector(7 downto 0);
      tx_eof_i     : in  std_logic;
      tx_err_o     : out std_logic;

      -- Connected to the LAN8720A Ethernet PHY.
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
end lan8720a;

architecture Structural of lan8720a is

begin

   tx_rden_o <= not tx_empty_i;
   tx_err_o  <= '0';

   -- These signals are not used
   eth_txd_o    <= (others => '0');
   eth_txen_o   <= '0';
   eth_mdio_io  <= 'Z';
   eth_mdc_o    <= '0';
   eth_rstn_o   <= '0';
   eth_refclk_o <= '0';

   eth_sim_proc : process
   begin
      -- Wait a while before starting the stimuli.
      rx_valid_o <= '0';
      rx_sof_o   <= '0';
      rx_eof_o   <= '0';
      rx_data_o  <= (others => '0');
      rx_error_o <= (others => '0');
      wait for 50 us;
      wait until clk_i = '1';

      -- Make a burst of 64 writes.
      for i in 0 to 63 loop
         rx_valid_o <= '1';
         rx_sof_o   <= '0';
         rx_eof_o   <= '0';
         rx_data_o  <= X"11" + i;
         if i=0 then
            rx_sof_o <= '1';
         end if;
         if i=63 then
            rx_eof_o <= '1';
         end if;
         wait until clk_i = '1';
         rx_valid_o <= '0';
         rx_sof_o   <= '0';
         rx_eof_o   <= '0';
         wait until clk_i = '1';
         wait until clk_i = '1';
         wait until clk_i = '1';
      end loop;

      -- Have a short pause.
      rx_valid_o <= '0';
      rx_sof_o   <= '0';
      rx_eof_o   <= '0';
      rx_data_o  <= (others => '0');
      rx_error_o <= (others => '0');
      wait for 60 us;
      wait until clk_i = '1';

      -- Make a burst of four minimum packets back-to-back.
      pkt_loop : for pkt in 0 to 3 loop
         byte_loop : for i in 0 to 63 loop
            rx_valid_o <= '1';
            rx_sof_o   <= '0';
            rx_eof_o   <= '0';
            rx_data_o  <= X"22" + i + pkt;
            if i=0 then
               rx_sof_o <= '1';
            end if;
            if i=63 then
               rx_eof_o <= '1';
            end if;
            -- Send data only every fourth clock cycle.
            wait until clk_i = '1';
            rx_valid_o <= '0';
            rx_sof_o   <= '0';
            rx_eof_o   <= '0';
            wait until clk_i = '1';
            wait until clk_i = '1';
            wait until clk_i = '1';
         end loop byte_loop;
      end loop pkt_loop;

      -- Stop any further stimuli.
      rx_valid_o <= '0';
      rx_sof_o   <= '0';
      rx_eof_o   <= '0';
      rx_data_o  <= (others => '0');
      rx_error_o <= (others => '0');
      wait;

   end process eth_sim_proc;
   
end Structural;

