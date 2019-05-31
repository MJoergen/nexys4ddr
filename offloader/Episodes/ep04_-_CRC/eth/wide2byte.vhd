library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module converts a wide bus interface into a stream of bytes.
-- The MSB is transmitted first, i.e. rx_data_i(G_BYTES*8-1 downto
-- G_BYTES*8-8).

-- This module immediately starts forwarding data as soon as the first row has
-- been received. This could potentially trigger an error, if the remainder of
-- the frame is not received in time. The user of this module must ensure that
-- the rest of the frame is available in time. Just in case, I've added an
-- assert to check for this error condition.

entity wide2byte is
   generic (
      G_BYTES    : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Receive interface (wide data bus). Pushing interface.
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(G_BYTES*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);           -- Only used when rx\_last\_i is asserted.

      -- Transmit interface (byte data bus). Pulling interface.
      tx_empty_o : out std_logic;
      tx_rden_i  : in  std_logic;
      tx_data_o  : out std_logic_vector(7 downto 0);
      tx_last_o  : out std_logic
   );
end wide2byte;

architecture Structural of wide2byte is

   type t_state is (IDLE_ST, FWD_ST);
   signal state_r    : t_state := IDLE_ST;

   -- Connected to FIFO
   signal wr_en      : std_logic;
   signal wr_data    : std_logic_vector(G_BYTES*8+8 downto 0);
   signal rd_empty   : std_logic;
   signal rd_en      : std_logic;
   signal rd_data    : std_logic_vector(G_BYTES*8+8 downto 0);
   signal data_s     : std_logic_vector(G_BYTES*8-1 downto 0);
   signal last_s     : std_logic;
   signal bytes_s    : std_logic_vector(5 downto 0);

   signal data_r     : std_logic_vector(G_BYTES*8-1 downto 0);
   signal last_r     : std_logic;
   signal bytes_r    : std_logic_vector(5 downto 0);

   signal tx_empty_r : std_logic;
   signal tx_last_r  : std_logic;

      
begin

   -- Check that 'bytes' is zero except possibly at end of frame.
   p_assert : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' and rx_last_i = '0' then -- Not end of frame
            assert rx_bytes_i = 0;
         end if;
      end if;
   end process p_assert;

   -- Store payload data in a fifo
   wr_en                                   <= rx_valid_i;
   wr_data(G_BYTES*8+8)                    <= rx_last_i;
   wr_data(G_BYTES*8+7 downto G_BYTES*8+6) <= "00";
   wr_data(G_BYTES*8+5 downto G_BYTES*8)   <= rx_bytes_i;
   wr_data(G_BYTES*8-1 downto 0)           <= rx_data_i;

   i_fifo : entity work.fifo
   generic map (
      G_WIDTH => G_BYTES*8+9
   )
   port map (
      wr_clk_i   => clk_i,
      wr_rst_i   => rst_i,
      wr_en_i    => wr_en,
      wr_data_i  => wr_data,
      wr_error_o => open,
      rd_clk_i   => clk_i,
      rd_rst_i   => rst_i,
      rd_en_i    => rd_en,
      rd_data_o  => rd_data,
      rd_empty_o => rd_empty,
      rd_error_o => open
   ); -- i_fifo

   -- Decode FIFO output
   last_s  <= rd_data(G_BYTES*8+8);
   bytes_s <= rd_data(G_BYTES*8+5 downto G_BYTES*8);
   data_s  <= rd_data(G_BYTES*8-1 downto 0);


   ----------------------------------------------
   -- State machine to control reading from FIFO
   ----------------------------------------------

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Default value
         rd_en <= '0';

         case state_r is
            when IDLE_ST =>
               if rd_empty = '0' then                                -- Data is present in FIFO.
                  data_r  <= data_s;                                 -- Store entire row of data.
                  last_r  <= last_s;
                  bytes_r <= bytes_s;
                  rd_en   <= '1';                                    -- Consume data from FIFO.

                  -- Calculate number of valid bytes in data_r.
                  if bytes_s = 0 then
                     bytes_r <= to_stdlogicvector(G_BYTES mod 64, 6);
                  end if;

                  tx_last_r  <= '0';
                  if last_s = '1' and bytes_s = 1 then               -- In case frame only contains one byte.
                     tx_last_r <= '1';
                  end if;
                  tx_empty_r <= '0';                                 -- Indicate data is ready for the receiver.
                  state_r <= FWD_ST;
               end if;

            when FWD_ST =>
               if tx_rden_i = '1' then                               -- Receiver has consumed the data.
                  data_r  <= data_r(G_BYTES*8-9 downto 0) & X"00";   -- Shift next data byte up to MSB.
                  bytes_r <= bytes_r-1;

                  if bytes_r-1 = 1 and last_r = '1' then             -- No more data left.
                     tx_last_r <= '1';                               -- Indicate end of frame.
                  end if;

                  if bytes_r-1 = 0 and last_r = '0' then
                     data_r  <= data_s;
                     last_r  <= last_s;
                     bytes_r <= bytes_s;
                     if bytes_s = 0 then
                        bytes_r <= to_stdlogicvector(G_BYTES mod 64, 6);
                     end if;
                     if last_s = '1' and bytes_s = 1 then            -- In case frame only contains one byte.
                        tx_last_r <= '1';
                     end if;
                     rd_en   <= '1';                                 -- Consume more data from FIFO.
                     assert rd_empty = '0';                          -- If no more data available, this is an error.
                  end if;

                  if tx_last_r = '1' then                            -- Last byte has been read.
                     tx_empty_r <= '1';
                     tx_last_r  <= '0';
                     state_r    <= IDLE_ST;
                  end if;
               end if;
         end case;

         if rst_i = '1' then
            tx_empty_r <= '1';
            tx_last_r  <= '0';
            state_r    <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   -- Drive output signals
   tx_empty_o <= tx_empty_r;
   tx_last_o  <= tx_last_r;
   tx_data_o  <= data_r(G_BYTES*8-1 downto G_BYTES*8-8);

end Structural;

