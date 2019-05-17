library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module receives data from the PHY.
-- It takes care of:
-- * 2-bit to 8-bit expansion.
-- * Decapsulation of MAC frames, i.e. removing of MAC preamble and Inter-Frame-Gap.
-- * CRC validation.
-- * Framing with SOF/EOF.
--
-- Data forwarded is stripped of MAC preample and Inter-Frame-Gap. The MAC CRC
-- remains, though.
--
-- The interface to the receiver is a "pushing" interface with no flow-control.
-- The frame data bytes are forwarded one byte every four clock cycles.  The
-- first byte has "rx_sof_o" asserted, the last byte has "rx_eof_o" asserted.
-- At end of frame, i.e. when "rx_eof_o" is asserted, the client must examine
-- the "rx_ok_o" signal to determine whether any errors occurred during frame
-- reception.
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
      eth_clk_i   : in  std_logic;  -- Must be 50 MHz
      eth_rst_i   : in  std_logic;

      -- Client interface
      rx_valid_o  : out std_logic;
      rx_sof_o    : out std_logic;  -- Start Of Frame
      rx_eof_o    : out std_logic;  -- End Of Frame
      rx_data_o   : out std_logic_vector(7 downto 0);
      rx_ok_o     : out std_logic;  -- Valid only at EOF.  -- True if frame has correct CRC and no errors.

      -- Connected to the PHY
      eth_rxd_i   : in  std_logic_vector(1 downto 0);
      eth_rxerr_i : in  std_logic;
      eth_crsdv_i : in  std_logic
   );
end eth_rx;

architecture Structural of eth_rx is

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, PRE_ST, PAYLOAD_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;
      
   signal sof       : std_logic;
   signal data      : std_logic_vector(7 downto 0);

   signal dibit_cnt : integer range 0 to 3;

   signal crc       : std_logic_vector(31 downto 0);

   signal rx_valid  : std_logic;
   signal rx_sof    : std_logic;  -- Start Of Frame
   signal rx_eof    : std_logic;  -- End Of Frame
   signal rx_data   : std_logic_vector(7 downto 0);
   signal rx_ok     : std_logic;  -- Valid only at EOF.  -- True if frame has no errors and correct CRC.

begin

   -- Generate MAC framing
   proc_fsm : process (eth_clk_i)
      variable crc_v : std_logic_vector(31 downto 0);
      variable newdata_v : std_logic_vector(7 downto 0);
   begin
      if rising_edge(eth_clk_i) then

         -- Set default values
         rx_valid <= '0';
         rx_sof   <= '0';
         rx_eof   <= '0';
         rx_data  <= X"00";
         rx_ok    <= '0';

         -- If valid bits are received from the PHY,
         -- shift them into the data register and update the CRC.
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
            -- Wait until a new frame starts.
            when IDLE_ST =>
               if eth_crsdv_i = '1' and eth_rxerr_i = '0' then
                  fsm_state <= PRE_ST;
                  data      <= (others => '0');
               end if;

            -- Wait until the preamble is finished.
            when PRE_ST =>
               if data = X"D5" then
                  dibit_cnt <= 0;
                  sof       <= '1';             -- Indicate start of frame.
                  fsm_state <= PAYLOAD_ST;
               end if;
               if newdata_v = X"D5" then
                  crc       <= (others => '1'); -- Initialize CRC.
               end if;
               if eth_crsdv_i = '0' or eth_rxerr_i = '1' then
                  fsm_state <= IDLE_ST;
                  sof       <= '0';
               end if;

            -- Process the frame
            when PAYLOAD_ST =>
               if dibit_cnt = 3 then
                  rx_valid <= '1';
                  rx_data  <= data;
                  rx_sof   <= sof;
                  rx_eof   <= (not eth_crsdv_i) or eth_rxerr_i;
                  sof      <= '0';
                  -- Check CRC at End Of Frame
                  if eth_crsdv_i = '0' and eth_rxerr_i = '0' and crc = X"C704DD7B" then
                     rx_ok <= '1';
                  end if;
                  if eth_crsdv_i = '0' or eth_rxerr_i = '1' then
                     fsm_state <= IDLE_ST;
                  end if;
               elsif eth_crsdv_i = '0' or eth_rxerr_i = '1' then
                  fsm_state <= IDLE_ST;
                  sof       <= '0';

                  -- If frame has already started, end it now.
                  if sof = '0' then
                     rx_valid <= '1';
                     rx_data  <= data;
                     rx_sof   <= sof;
                     rx_eof   <= '1';
                     rx_ok    <= '0';
                  end if;
               end if;

         end case;

         if eth_rst_i = '1' then
            fsm_state <= IDLE_ST;
            sof       <= '0';
         end if;
      end if;
   end process proc_fsm;

   -- Drive output signals
   rx_valid_o <= rx_valid;
   rx_sof_o   <= rx_sof;
   rx_eof_o   <= rx_eof;
   rx_data_o  <= rx_data;
   rx_ok_o    <= rx_ok;

end Structural;

