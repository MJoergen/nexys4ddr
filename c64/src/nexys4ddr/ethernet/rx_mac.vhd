library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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
--
-- Timing (from the data sheet):
-- On the transmit side: The MAC controller drives the transmit data onto the
-- TXD bus and asserts TXEN to indicate valid data.  The data is latched by the
-- transceivers RMII block on the rising edge of REF_CLK. The data is in the
-- form of 2-bit wide 50MHz data. 
-- SSD (/J/K/) is "Sent for rising TXEN".
--
-- On the receive side: The 2-bit data nibbles are sent to the RMII block.
-- These data nibbles are clocked to the controller at a rate of 50MHz. The
-- controller samples the data on the rising edge of XTAL1/CLKIN (REF_CLK). To
-- ensure that the setup and hold requirements are met, the nibbles are clocked
-- out of the transceiver on the falling edge of XTAL1/CLKIN (REF_CLK). 

entity rx_mac is

   port (
      eth_clk_i   : in  std_logic;        -- Must be 50 MHz
      eth_rst_i   : in  std_logic;

      -- Pushing interface
      ena_o       : out std_logic;
      sof_o       : out std_logic;
      eof_o       : out std_logic;
      data_o      : out std_logic_vector(7 downto 0);
      err_o       : out std_logic;

      -- Connectedto PHY
      eth_rxd_i   : in  std_logic_vector(1 downto 0);
      eth_rxerr_i : in  std_logic;
      eth_crsdv_i : in  std_logic;
      eth_intn_i  : in  std_logic
   );
end rx_mac;

architecture Structural of rx_mac is

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, PRE1_ST, PRE2_ST, PAYLOAD_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;
      
   signal ena  : std_logic := '0';
   signal sof  : std_logic;
   signal eof  : std_logic;
   signal data : std_logic_vector(7 downto 0);

   signal dibit_cnt : integer range 0 to 3;
   signal byte_cnt  : integer range 0 to 11;

begin

   -- Generate MAC framing
   proc_fsm : process (eth_clk_i)
   begin
      if rising_edge(eth_clk_i) then
         eof <= '0';

         if eth_crsdv_i = '1' then 
            data      <= eth_rxd_i & data(7 downto 2);
            dibit_cnt <= (dibit_cnt + 1) mod 4;
         end if;

         case fsm_state is
            when IDLE_ST =>
               if eth_crsdv_i = '1' then 
                  fsm_state <= PRE1_ST;
                  dibit_cnt <= 0;
                  byte_cnt  <= 0;
                  data      <= (others => '0');
               end if;

            -- Synchronize
            when PRE1_ST =>
               if data = X"D5" then
                  byte_cnt  <= 0;
                  dibit_cnt <= 0;
                  sof <= '1';
                  fsm_state <= PAYLOAD_ST;
               end if;

            when PRE2_ST =>
               null;

            when PAYLOAD_ST =>
               if dibit_cnt = 3 then
                  sof <= '0';
               end if;

               if eth_crsdv_i = '0' then
                  fsm_state <= IDLE_ST;
               end if;

         end case;

         if eth_rst_i = '1' then
            fsm_state <= IDLE_ST;
            dibit_cnt <= 0;
            byte_cnt  <= 0;
            sof       <= '0';
            eof       <= '0';
         end if;
      end if;
   end process proc_fsm;

   ena <= '1' when fsm_state = PAYLOAD_ST and dibit_cnt = 3 else '0';

   -- Drive output signals
   proc_out : process (eth_clk_i)
   begin
      if rising_edge(eth_clk_i) then
         ena_o  <= ena;
         sof_o  <= ena and sof;
         eof_o  <= ena and not eth_crsdv_i;
         data_o <= data;
         err_o  <= eth_rxerr_i;
      end if;
   end process proc_out;

end Structural;

