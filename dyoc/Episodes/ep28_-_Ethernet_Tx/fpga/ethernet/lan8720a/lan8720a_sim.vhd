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

   type frame_t is array (natural range <>) of std_logic_vector(7 downto 0);
   constant frame : frame_t(0 to 45) :=
      (X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"F4", x"6D",
       X"04", X"D7", X"F3", X"CA", X"08", X"06", X"00", x"01",
       X"08", X"00", X"06", X"04", X"00", X"01", X"F4", X"6D",
       X"04", X"D7", X"F3", X"CA", X"C0", X"A8", X"01", X"2B",
       X"00", X"00", X"00", X"00", X"00", X"00", X"C0", X"A8",
       X"01", X"4D", X"CC", X"CC", X"CC", X"CC");  -- Must include 4 dummy bytes for CRC.

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
      wait for 110 us;
      wait until clk_i = '1';

      -- Write a two frames back-to-back
      loop_j : for j in 0 to 0 loop
         loop_i : for i in frame'low to frame'high loop
            rx_valid_o <= '1';
            rx_sof_o   <= '0';
            rx_eof_o   <= '0';
            rx_data_o  <= frame(i);
            if i=frame'low then
               rx_sof_o <= '1';
            end if;
            if i=frame'high then
               rx_eof_o <= '1';
            end if;
            wait until clk_i = '1';
            rx_valid_o <= '0';
            rx_sof_o   <= '0';
            rx_eof_o   <= '0';
            wait until clk_i = '1';
            wait until clk_i = '1';
            wait until clk_i = '1';
         end loop loop_i;
      end loop loop_j;

      -- Stop any further stimuli.
      rx_valid_o <= '0';
      rx_sof_o   <= '0';
      rx_eof_o   <= '0';
      rx_data_o  <= (others => '0');
      rx_error_o <= (others => '0');
      wait;

   end process eth_sim_proc;
   
end Structural;

