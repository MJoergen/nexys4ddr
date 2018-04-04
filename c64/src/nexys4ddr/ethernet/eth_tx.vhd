library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module sends transmit data to the LAN8720A Ethernet PHY.
-- It automatically calculates the MAC CRC.
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

entity eth_tx is

   port (
      eth_clk_i    : in  std_logic;        -- Must be 50 MHz
      eth_rst_i    : in  std_logic;

      -- Pulling interface
      data_i       : in  std_logic_vector(7 downto 0);
      sof_i        : in  std_logic;
      eof_i        : in  std_logic;
      empty_i      : in  std_logic;
      rden_o       : out std_logic;
      err_o        : out std_logic;

      -- Connected to PHY
      eth_txd_o    : out std_logic_vector(1 downto 0);
      eth_txen_o   : out std_logic
   );
end eth_tx;

architecture Structural of eth_tx is

   signal err        : std_logic := '0';
   signal eth_txen   : std_logic := '0';
   signal rden       : std_logic := '0';

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, PRE1_ST, PRE2_ST, PAYLOAD_ST, LAST_ST, CRC_ST, IFG_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

   signal byte_cnt   : integer range 0 to 12;
   signal cur_byte   : std_logic_vector(7 downto 0) := X"00";
   signal twobit_cnt : std_logic_vector(1 downto 0) := "00";

   signal crc        : std_logic_vector(31 downto 0);
   signal crc_reg    : std_logic_vector(31 downto 0);
   signal crc_enable : std_logic;

begin

   -- Generate MAC framing
   proc_mac : process (eth_clk_i)
      variable crc_v : std_logic_vector(31 downto 0);
   begin
      if falling_edge(eth_clk_i) then

         -- Calculate CRC
         if crc_enable = '1' then   -- Consume two bits of data
            crc_v := crc;
            for i in 0 to 1 loop
               if cur_byte(i) = crc_v(31) then
                  crc_v :=  crc_v(30 downto 0) & '0';
               else
                  crc_v := (crc_v(30 downto 0) & '0') xor x"04C11DB7";
               end if;
            end loop;
            crc <= crc_v;
         else
            crc <= (others => '1');
         end if;

         rden       <= '0';
         twobit_cnt <= twobit_cnt + 1;
         cur_byte   <= "00" & cur_byte(7 downto 2);

         if twobit_cnt = 0 then        -- Only change state on a byte boundary.
            case fsm_state is
               when IDLE_ST    =>
                  eth_txen <= '0';
                  cur_byte <= X"00";
                  if empty_i = '0' then
                     if sof_i = '0' then
                        err <= '1';
                     end if;
                     assert sof_i = '1' report "Missing SOF" severity failure;
                     byte_cnt  <= 7;
                     cur_byte  <= X"55";
                     fsm_state <= PRE1_ST;
                     eth_txen  <= '1';
                  end if;

               when PRE1_ST    =>
                  cur_byte  <= X"55";
                  if byte_cnt = 1 then
                     byte_cnt  <= 1;
                     cur_byte  <= X"D5";
                     fsm_state <= PRE2_ST;
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

               when PRE2_ST    =>
                  crc_enable <= '1';
                  cur_byte  <= data_i;
                  rden      <= '1';
                  fsm_state <= PAYLOAD_ST;

                  -- Abort! Data not available yet.
                  if empty_i = '1' then
                     cur_byte  <= (others => '0');
                     fsm_state <= IFG_ST;
                     eth_txen  <= '0';
                     rden      <= '0';
                     err       <= '1';
                  end if;

               when PAYLOAD_ST =>
                  cur_byte <= data_i;
                  rden     <= '1';
                  if eof_i = '1' then
                     fsm_state <= LAST_ST;
                  end if;

                  -- Abort! Data not available yet.
                  if empty_i = '1' then
                     cur_byte  <= (others => '0');
                     fsm_state <= IFG_ST;
                     eth_txen  <= '0';
                     rden      <= '0';
                     err       <= '1';
                  end if;

               when LAST_ST => 
                  byte_cnt   <= 4;
                  -- CRC is transmitted MSB first.
                  cur_byte   <= not (crc_v(24) & crc_v(25) & crc_v(26) & crc_v(27) &
                                     crc_v(28) & crc_v(29) & crc_v(30) & crc_v(31));
                  crc_reg    <= crc_v(23 downto 0) & X"00";
                  crc_enable <= '0';         -- This will reset the CRC.
                  fsm_state  <= CRC_ST;

               when CRC_ST =>
                  -- CRC is transmitted MSB first.
                  cur_byte <= not (crc_reg(24) & crc_reg(25) & crc_reg(26) & crc_reg(27) &
                                   crc_reg(28) & crc_reg(29) & crc_reg(30) & crc_reg(31));
                  crc_reg  <= crc_reg(23 downto 0) & X"00";
                  if byte_cnt = 1 then
                     -- Only 11 octets, because the next state is always the idle state.
                     byte_cnt  <= 11;
                     cur_byte  <= (others => '0');
                     fsm_state <= IFG_ST;
                     eth_txen  <= '0';
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

               when IFG_ST =>
                  if byte_cnt = 1 then
                     fsm_state <= IDLE_ST;
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

            end case;
         end if;

         if eth_rst_i = '1' then
            fsm_state  <= IDLE_ST;
            err        <= '0';
            twobit_cnt <= (others => '0');
         end if;
      end if;
   end process proc_mac;

   -- Drive output signals
   eth_txd_o    <= cur_byte(1 downto 0);
   eth_txen_o   <= eth_txen;

   rden_o <= rden;
   err_o  <= err;

end Structural;

