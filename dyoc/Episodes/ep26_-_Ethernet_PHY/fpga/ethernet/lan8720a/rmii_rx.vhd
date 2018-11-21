library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module receives user data from an ethernet PHY following the RMII
-- specification, see:
-- https://en.wikipedia.org/wiki/Media-independent_interface#Reduced_media-independent_interface
--
-- This module takes care of:
-- * 2-bit to 8-bit conversion.
-- * CRC validation/stripping.
-- * Framing with VALID and EOF.
--
-- In case of receiver error the current frame is terminated (EOF=1) and
-- the error type can be sampled in the user_error_o signal. Two types
-- of errors are reported: Rx error and CRC error. In both cases, the
-- user is expected to discard the frame.
--
-- Data forwarded is stripped of the MAC preample, CRC, and Inter-Frame-Gap.
--
-- The data received from the PHY is preceeded by an 8-byte preamble in hex: 55
-- 55 55 55 55 55 55 D5.  Some of the preample dibits may be lost.  Data is
-- followed by a 32-bit CRC.  Each byte is transmitted with LSB first.
--
-- The timing is assumed to adhere to the following specification, taken from
-- section 3.1.2.9 of the document:
-- http://ww1.microchip.com/downloads/en/DeviceDoc/8720a.pdf
--    The 2-bit data nibbles are sent to the RMII block.  These data nibbles
--    are clocked to the controller at a rate of 50MHz. The controller samples
--    the data on the rising edge of XTAL1/CLKIN (REF_CLK). To ensure that the
--    setup and hold requirements are met, the nibbles are clocked out of the
--    transceiver on the falling edge of XTAL1/CLKIN (REF_CLK). 

entity rmii_rx is
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;

      -- Connected to user logic
      user_valid_o : out std_logic;    -- Remaining user_* fields are valid.
      user_eof_o   : out std_logic;    -- End of frame. Asserted on last byte.
      user_data_o  : out std_logic_vector(7 downto 0);
      user_error_o : out std_logic_vector(1 downto 0);   -- Must only be sampled @ EOF.
                                                         -- Bit 0 : Receiver error
                                                         -- Bit 1 : CRC error

      -- Connected to PHY
      phy_rxd_i    : in  std_logic_vector(1 downto 0);
      phy_rxerr_i  : in  std_logic;
      phy_crsdv_i  : in  std_logic;
      phy_intn_i   : in  std_logic
   );
end rmii_rx;

architecture structural of rmii_rx is

-- The CRC calculation is also called CRC-32 and is listed here:
-- https://en.wikipedia.org/wiki/Cyclic_redundancy_check
   constant CRC_POLYNOMIAL : std_logic_vector(31 downto 0) := X"04C11DB7";
-- The expected correct value of the CRC calculation is listed here:
-- https://en.wikipedia.org/wiki/Ethernet_frame
   constant CRC_CORRECT    : std_logic_vector(31 downto 0) := X"C704DD7B";
   signal crc              : std_logic_vector(31 downto 0);

   -- State machine to control decoding of the MAC framing
   type t_fsm_state is (IDLE_ST, PRE1_ST, PAYLOAD_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;
   signal dibit_cnt : integer range 0 to 3;

   -- Output signals
   signal valid : std_logic := '0';
   signal data  : std_logic_vector(7 downto 0);

   -- Update CRC with two bits of data
   function new_crc(old_crc : std_logic_vector(31 downto 0);
                     dibits : std_logic_vector( 1 downto 0))
   return std_logic_vector is
      variable res_v : std_logic_vector(31 downto 0);
   begin
      res_v := old_crc;
      for i in 0 to 1 loop -- process each bit one-at-a-time.
         if dibits(i) = res_v(31) then
            res_v :=  res_v(30 downto 0) & '0';
         else
            res_v := (res_v(30 downto 0) & '0') xor CRC_POLYNOMIAL;
         end if;
      end loop;
      return res_v;
   end function new_crc;

   type stage_t is record
      valid : std_logic;                        -- Remaining fields are valid.
      eof   : std_logic;                        -- End of frame. Asserted on last byte.
      data  : std_logic_vector(7 downto 0);
      err   : std_logic_vector(1 downto 0);     -- Must only be sampled @ EOF.
   end record stage_t;

   constant STAGE_DEFAULT : stage_t := (
      valid => '0',
      eof   => '0',
      data  => (others => '0'),
      err   => (others => '0')
   );

   type stage_vector_t is array (natural range<>) of stage_t;

   signal stages : stage_vector_t(5 downto 0) := (others => STAGE_DEFAULT);

begin

   -- State machine to control decoding of the MAC framing
   proc_fsm : process (clk_i)
      variable newdata_v : std_logic_vector(7 downto 0);
   begin
      if rising_edge(clk_i) then

         if phy_crsdv_i = '1' then 
            crc       <= new_crc(crc, phy_rxd_i);        -- Update CRC
            newdata_v := phy_rxd_i & data(7 downto 2);   -- Shift dibits into byte
            data      <= newdata_v;
            dibit_cnt <= (dibit_cnt + 1) mod 4;
         end if;

         case fsm_state is
            when IDLE_ST =>
               if phy_crsdv_i = '1' then 
                  fsm_state <= PRE1_ST;
                  dibit_cnt <= 0;
                  data      <= (others => '0');
               end if;

            when PRE1_ST =>
               if data = X"D5" then
                  dibit_cnt <= 0;
                  fsm_state <= PAYLOAD_ST;
               end if;
               if newdata_v = X"D5" then
                  crc <= (others => '1'); -- Initialize CRC calculation
               end if;
               if phy_crsdv_i = '0' or phy_rxerr_i = '1' then
                  fsm_state <= IDLE_ST;
               end if;

            when PAYLOAD_ST =>
               if phy_crsdv_i = '0' or phy_rxerr_i = '1' then
                  fsm_state <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            fsm_state <= IDLE_ST;
         end if;
      end if;
   end process proc_fsm;

   -- Assert valid after receiving 4 dibits.
   valid <= '1' when fsm_state = PAYLOAD_ST and dibit_cnt = 3 else
            '0';

   -- Generate signals for stage 0
   proc_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Make sure all data is cleared. This is not strictly necessary, but it makes
         -- debugging easier, when e.g. EOF is zero outside valid data.
         stages(0) <= STAGE_DEFAULT;
         if valid = '1' then
            stages(0).valid   <= '1';
            stages(0).eof     <= phy_rxerr_i or not phy_crsdv_i;
            stages(0).err(0)  <= phy_rxerr_i; -- Receiver error
            stages(0).err(1)  <= '0';                   -- No CRC error
            stages(0).data    <= data;

            -- Are we at the end of frame, and no receiver error?
            if phy_crsdv_i = '0' and phy_rxerr_i = '0' then
               -- Check for CRC error
               if crc /= CRC_CORRECT then
                  stages(0).err(1) <= '1';
               end if;
            end if;
         end if;
      end if;
   end process proc_out;

   -- Generate signals for stages 1 to 5.
   proc_pipe : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stages(5) <= STAGE_DEFAULT;

         -- Move pipeline forward one stage.
         if stages(0).valid = '1' then
            stages(1) <= stages(0);
            stages(2) <= stages(1);
            stages(3) <= stages(2);
            stages(4) <= stages(3);
            stages(5) <= stages(4);
         end if;

         -- Strip away CRC
         if stages(0).valid = '1' and stages(0).eof = '1' then
            stages(1).valid <= '0';
            stages(1).eof   <= '0';
            stages(2).valid <= '0';
            stages(2).eof   <= '0';
            stages(3).valid <= '0';
            stages(3).eof   <= '0';
            stages(4).valid <= '0';
            stages(4).eof   <= '0';
            stages(5).eof   <= '1';
         end if;
      end if;
   end process proc_pipe;

   user_valid_o <= stages(5).valid;
   user_eof_o   <= stages(5).eof;
   user_data_o  <= stages(5).data;
   user_error_o <= stages(5).err;

end structural;

