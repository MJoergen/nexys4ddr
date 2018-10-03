library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This is a simulation model of the Ethernet PHY.

entity lan8720a_sim is
   port (
      eth_txd_i    : in    std_logic_vector(1 downto 0);
      eth_txen_i   : in    std_logic;
      eth_rxd_o    : out   std_logic_vector(1 downto 0);
      eth_rxerr_o  : out   std_logic;
      eth_crsdv_o  : out   std_logic;
      eth_intn_o   : out   std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_i    : in    std_logic;
      eth_rstn_i   : in    std_logic;
      eth_refclk_i : in    std_logic
   );
end lan8720a_sim;

architecture Structural of lan8720a_sim is

   type frame_t is array (natural range <>) of std_logic_vector(7 downto 0);
   constant frame : frame_t(0 to 45) :=
      (X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"F4", x"6D",
       X"04", X"D7", X"F3", X"CA", X"08", X"06", X"00", x"01",
       X"08", X"00", X"06", X"04", X"00", X"01", X"F4", X"6D",
       X"04", X"D7", X"F3", X"CA", X"C0", X"A8", X"01", X"2B",
       X"00", X"00", X"00", X"00", X"00", X"00", X"C0", X"A8",
       X"01", X"4D", X"CC", X"CC", X"CC", X"CC");  -- Must include 4 dummy bytes for CRC.

   signal data  : std_logic_vector(128*8-1 downto 0);
   signal len   : std_logic_vector(15 downto 0);
   signal start : std_logic;
   signal done  : std_logic;

   signal eth_rst : std_logic;

begin

   eth_rst <= not eth_rstn_i;

   inst_tx : entity work.sim_tx
   port map (
      clk_i      => eth_refclk_i,
      rst_i      => eth_rst,
      data_i     => data,
      len_i      => len,
      start_i    => start,
      done_o     => done,
      eth_txd_o  => eth_rxd_o,
      eth_txen_o => eth_crsdv_o 
   );

   -- These signals are not used
   eth_rxerr_o <= '0';
   eth_intn_o  <= '0';

   eth_sim_proc : process
   begin
      -- Wait until reset is complete
      start <= '0';
      wait until eth_rst = '0';
      wait until eth_refclk_i = '1';

      -- Send one frame
      for i in 0 to 45 loop
         data(8*i+7 downto 8*i) <= frame(i);
      end loop;
      len   <= std_logic_vector(to_unsigned(frame'length, 16));
      start <= '1';
      wait until done = '1';
      start <= '0';
      wait until eth_refclk_i = '1';

      -- Stop any further stimuli.
      wait;
   end process eth_sim_proc;
   
end Structural;

