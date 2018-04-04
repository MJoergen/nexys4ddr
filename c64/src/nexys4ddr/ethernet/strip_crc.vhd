library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module strips the incoming frame of the MAC CRC (the last four bytes)
-- and forwards the CRC valid bit from EOF to SOF.
-- This module therefore operates in a store-and-forward mode,
-- where the entire frame is stored in the FIFO, until the last byte is received.
-- Only valid frames are forwarded. In other words, errored frames are discarded.
-- Frames are stored in a special-purpose FIFO, where the write pointer of
-- the SOF is recorded. If the frame is to be discarded, the write pointer is reset
-- to the start of the errored frame.
-- For simplicity, everything is in the same clock domain.

-- There is no flow control.

entity strip_crc is
   port (
      -- Input interface
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      rx_ena_i       : in  std_logic;
      rx_sof_i       : in  std_logic;
      rx_eof_i       : in  std_logic;
      rx_err_i       : in  std_logic;     -- TBD: Not used.
      rx_data_i      : in  std_logic_vector(7 downto 0);
      rx_crc_valid_i : in  std_logic;    -- Only valid @ EOF

      -- Output interface
      out_ena_o       : out std_logic;
      out_sof_o       : out std_logic;
      out_eof_o       : out std_logic;
      out_data_o      : out std_logic_vector(7 downto 0)
   );
end strip_crc;

architecture Structural of strip_crc is

   -- The size of the input buffer is 2K. This fits nicely in a single BRAM.
   constant C_ADDR_SIZE : integer := 11;

   -- Current write pointer.
   signal wrptr     : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   -- Start of current frame.
   signal start_ptr : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   -- Current read pointer.
   signal rdptr     : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   type t_buf is array (0 to 2**C_ADDR_SIZE-1) of std_logic_vector(7 downto 0);

   signal rx_buf : t_buf := (others => (others => '0'));

   signal out_ena  : std_logic;
   signal out_sof  : std_logic;
   signal out_eof  : std_logic;
   signal out_data : std_logic_vector(7 downto 0);

begin

   proc_input : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_ena_i = '1' then
            rx_buf(conv_integer(wrptr)) <= rx_data_i;
            wrptr <= wrptr + 1;

            if rx_eof_i = '1' then
               if rx_crc_valid_i = '1' then
                  -- Prepare for next frame (and strip CRC).
                  start_ptr <= wrptr-3;
                  wrptr     <= wrptr-3;
               else
                  wrptr <= start_ptr;  -- Discard this frame.
               end if;
            end if;
         end if;

         if rst_i = '1' then
            start_ptr <= (others => '0');
            wrptr <= (others => '0');
         end if;
      end if;
   end process proc_input;


   proc_output : process (clk_i)
   begin
      if rising_edge(clk_i) then
         out_ena <= '0';
         out_sof <= '0';
         out_eof <= '0';
         out_data <= rx_buf(conv_integer(rdptr));

         if rdptr /= start_ptr then
            out_ena <= '1';
            rdptr <= rdptr + 1;
         end if;

         if rst_i = '1' then
            rdptr <= (others => '0');
         end if;
      end if;
   end process proc_output;

   out_ena_o  <= out_ena;
   out_sof_o  <= out_sof;
   out_eof_o  <= out_eof;
   out_data_o <= out_data;

end Structural;

