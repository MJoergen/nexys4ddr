library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module connects to the LAN8720A Ethernet PHY. The PHY supports the RMII specification.
--
-- From the NEXYS 4 DDR schematic
-- RXD0/MODE0   : External pull UP
-- RXD1/MODE1   : External pull UP
-- CRS_DV/MODE2 : External pull UP
-- RXERR/PHYAD0 : External pull UP
-- MDIO         : External pull UP
-- LED2/NINTSEL : According to note on schematic, the PHY operates in REF_CLK in Mode (ETH_REFCLK = 50 MHz). External pull UP.
-- LED1/REGOFF  : Floating (LOW)
-- NRST         : External pull UP
--
-- This means:
-- MODE    => All capable. Auto-negotiation enabled.
-- PHYAD   => SMI address 1
-- REGOFF  => Internal 1.2 V regulator is ENABLED.
-- NINTSEL => nINT/REFCLKO is an active low interrupt output.
--            The REF_CLK is sourced externally and must be driven
--            on the XTAL1/CLKIN pin.
--
-- All signals are connected to BANK 16 of the FPGA, except: eth_rstn_o and eth_clkin_o are connected to BANK 35.
--
-- When transmitting, packets must be preceeded by an 8-byte preamble
-- in hex: 55 55 55 55 55 55 55 D5
-- Each byte is transmitted with LSB first.
-- Frames are appended with a 32-bit CRC, and then followed by 12 bytes of interpacket gap (idle).

entity ethernet is

   port (
      clk100_i     : in    std_logic;        -- Must be 100 MHz
      rst100_i     : in    std_logic;

      -- Pulling interface
      data_i       : in    std_logic_vector(7 downto 0);
      sof_i        : in    std_logic;
      eof_i        : in    std_logic;
      empty_i      : in    std_logic;
      rden_o       : out   std_logic;

      -- Connected to PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_o    : out   std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic         -- Connected to XTAL1/CLKIN. Must be driven to 50 MHz.
                                             -- All RMII signals are syunchronous to this clock.
   );
end ethernet;

architecture Structural of ethernet is

   signal eth_refclk : std_logic := '0';
   signal eth_txd    : std_logic_vector(1 downto 0) := "00";
   signal eth_txen   : std_logic := '0';
   signal eth_mdc    : std_logic := '0';
   signal eth_rstn   : std_logic := '0';  -- Assert reset by default.

   -- Minimum reset assert time is 25 ms. At 100 MHz (= 10 ns) this is 2,5*10^6 clock cycles.
   -- Here we have 22 bits, corresponding to approx 4*10^6 clock cycles, i.e. 40 ms.
   signal rst_cnt    : std_logic_vector(21 downto 0) := (others => '1');   -- Set to all-ones, to start the count down.

begin

   -- The clock must always be generated
   -- Make it 50 MHz.
   proc_eth_refclk : process (clk100_i)
   begin
      if rising_edge(clk100_i) then
         eth_refclk <= not eth_refclk;
      end if;
   end process proc_eth_refclk;

   proc_eth_rstn : process (clk100_i)
   begin
      if rising_edge(clk100_i) then
         if rst_cnt /= 0 then
            rst_cnt <= rst_cnt - 1;
         else
            eth_rstn <= '1';              -- Clear reset
         end if;

         -- TBD: This could be removed, because the CPU reset should not reset the PHY.
         if rst100_i = '1' then
            eth_rstn <= '0';              -- Assert reset
            rst_cnt <= (others => '1');
         end if;
      end if;
   end process proc_eth_rstn;

   -- Drive output signals
   eth_refclk_o <= eth_refclk;
   eth_txd_o    <= eth_txd;
   eth_txen_o   <= eth_txen;
   eth_mdc_o    <= eth_mdc;
   eth_rstn_o   <= eth_rstn;

end Structural;

