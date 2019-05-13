library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module receives data from the PHY.
-- It takes care of:
-- * 2-bit to 8-bit expansion.
-- * Decapsulation of MAC frames.
-- * CRC validation.
-- * Framing with SOF/EOF.
--
-- Data forwarded is stripped of MAC preample and Inter-Frame-Gap. The MAC CRC
-- remains though.
--
-- In MAC framing, packets are preceeded by an 8-byte preamble
-- in hex: 55 55 55 55 55 55 55 D5
-- Each byte is transmitted with LSB first.
-- Frames are appended with a 32-bit CRC, and then followed by 12 bytes of
-- interpacket gap (idle).
--
-- Timing: The 2-bit data nibbles are sent to the RMII block.
-- These data nibbles are clocked to the controller at a rate of 50MHz. The
-- controller samples the data on the rising edge of XTAL1/CLKIN (REF_CLK). To
-- ensure that the setup and hold requirements are met, the nibbles are clocked
-- out of the transceiver on the falling edge of XTAL1/CLKIN (REF_CLK). 

entity eth_rx is

   port (
      eth_clk_i   : in  std_logic;        -- Must be 50 MHz
      eth_rst_i   : in  std_logic;

      -- Pushing interface
      valid_o     : out std_logic;
      sof_o       : out std_logic;
      eof_o       : out std_logic;
      data_o      : out std_logic_vector(7 downto 0);
      err_o       : out std_logic;
      crc_valid_o : out std_logic;  -- Valid only at EOF.

      -- Connectedto PHY
      eth_rxd_i   : in  std_logic_vector(1 downto 0);
      eth_rxerr_i : in  std_logic;
      eth_crsdv_i : in  std_logic;
      eth_intn_i  : in  std_logic
   );
end eth_rx;

architecture Structural of eth_rx is

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, PRE1_ST, PRE2_ST, PAYLOAD_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;
      
   signal ena  : std_logic := '0';
   signal sof  : std_logic;
   signal data : std_logic_vector(7 downto 0);

   signal dibit_cnt : integer range 0 to 3;
   signal byte_cnt  : integer range 0 to 11;

   signal crc : std_logic_vector(31 downto 0);

begin

   -- Generate MAC framing
   proc_fsm : process (eth_clk_i)
      variable crc_v : std_logic_vector(31 downto 0);
      variable newdata_v : std_logic_vector(7 downto 0);
   begin
      if rising_edge(eth_clk_i) then

         if eth_crsdv_i = '1' then 
            newdata_v := eth_rxd_i & data(7 downto 2);
            data      <= newdata_v;
            dibit_cnt <= (dibit_cnt + 1) mod 4;

            -- Calculate CRC
            -- Consume two bits of data
            crc_v := crc;
            for i in 0 to 1 loop
               if eth_rxd_i(i) = crc_v(31) then
                  crc_v :=  crc_v(30 downto 0) & '0';
               else
                  crc_v := (crc_v(30 downto 0) & '0') xor x"04C11DB7";
               end if;
            end loop;
            crc <= crc_v;
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
                  sof       <= '1';
                  fsm_state <= PAYLOAD_ST;
               end if;
               if newdata_v = X"D5" then
                  crc       <= (others => '1');
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
         end if;
      end if;
   end process proc_fsm;

   ena <= '1' when fsm_state = PAYLOAD_ST and dibit_cnt = 3 else '0';

   -- Drive output signals
   proc_out : process (eth_clk_i)
   begin
      if rising_edge(eth_clk_i) then
         valid_o     <= ena;
         sof_o       <= ena and sof;
         eof_o       <= ena and not eth_crsdv_i;
         data_o      <= data;
         err_o       <= eth_rxerr_i;
         crc_valid_o <= '0';
         if ena = '1' and eth_crsdv_i = '0' and crc = X"C704DD7B" then
            crc_valid_o <= '1';
         end if;
      end if;
   end process proc_out;

end Structural;

