library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simulation model of the Ethernet port.

entity ethernet is
   port (
      -- Must be 50 MHz
      clk_i        : in  std_logic;

      -- Connected to user
      user_wren_o  : out std_logic;
      user_addr_o  : out std_logic_vector(15 downto 0);
      user_data_o  : out std_logic_vector( 7 downto 0);
      user_memio_o : out std_logic_vector(47 downto 0);

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

begin

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
      user_memio_o(15 downto  0) <= X"7000";
      user_memio_o(31 downto 16) <= X"0000";
      user_memio_o(39 downto 32) <= X"00";
      user_memio_o(47 downto 40) <= X"00";

      user_wren_o <= '0';
      user_addr_o <= X"0000";
      user_data_o <= X"00";
      wait for 50 us;
      wait until clk_i = '1';

      -- Make a burst of 64 writes.
      for i in 0 to 63 loop
         user_wren_o <= '1';
         user_addr_o <= X"7000" + i;
         user_data_o <= X"11" + i;
         wait until clk_i = '1';
      end loop;

      -- Have a short pause.
      user_memio_o(15 downto  0) <= X"7040";
      user_memio_o(31 downto 16) <= X"0001";
      user_memio_o(39 downto 32) <= X"00";
      user_memio_o(47 downto 40) <= X"00";

      user_wren_o <= '0';
      user_addr_o <= X"0000";
      user_data_o <= X"00";
      wait for 20 us;
      wait until clk_i = '1';

      -- Make a burst of 256 writes.
      for i in 0 to 255 loop
         user_wren_o <= '1';
         user_addr_o <= X"7040" + i;
         user_data_o <= X"22" + i;
         wait until clk_i = '1';
      end loop;

      -- Stop any further stimuli.
      user_memio_o(15 downto  0) <= X"7140";
      user_memio_o(31 downto 16) <= X"0002";
      user_memio_o(39 downto 32) <= X"00";
      user_memio_o(47 downto 40) <= X"00";

      user_wren_o <= '0';
      user_addr_o <= X"0000";
      user_data_o <= X"00";
      wait;

   end process eth_sim_proc;
   
end Structural;

