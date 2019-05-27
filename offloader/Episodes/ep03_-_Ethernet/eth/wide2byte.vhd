library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module takes a parallel input and serializes it one-byte-at-a-time.
-- The MSB is transmitted first, i.e. rx_data_i(G_BYTES*8-1 downto
-- G_BYTES*8-8).

entity wide2byte is
   generic (
      G_BYTES    : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Receive interface (wide data bus)
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(G_BYTES*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Transmit interface (byte data bus)
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
   signal tx_data_r  : std_logic_vector(7 downto 0);

      
begin

   -- Store payload data in a fifo
   wr_en                                   <= rx_valid_i;
   wr_data(G_BYTES*8+8)                    <= rx_last_i;
   wr_data(G_BYTES*8+7 downto G_BYTES*8+6) <= "00";
   wr_data(G_BYTES*8+5 downto G_BYTES*8)   <= rx_bytes_i;
   wr_data(G_BYTES*8-1 downto 0)           <= rx_data_i;

   i_wide_fifo : entity work.wide_fifo
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

   tx_data_r <= data_r(G_BYTES*8-1 downto G_BYTES*8-8);

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Default value
         rd_en <= '0';

         case state_r is
            when IDLE_ST =>
               if rd_empty = '0' then
                  -- Consume data from FIFO
                  data_r  <= data_s;
                  last_r  <= last_s;
                  bytes_r <= bytes_s;
                  rd_en   <= '1';

                  -- Calculate number of valid bytes in data_r.
                  if (last_s = '0' or bytes_s = 0) and G_BYTES < 64 then
                     bytes_r <= to_stdlogicvector(G_BYTES, 6);
                  end if;

                  tx_empty_r <= '0';
                  tx_last_r  <= '0';
                  if last_s = '1' and bytes_s = 1 then
                     tx_last_r <= '1';
                  end if;
                  state_r <= FWD_ST;
               end if;

            when FWD_ST =>
               if tx_rden_i = '1' then
                  data_r  <= data_r(G_BYTES*8-9 downto 0) & X"00";
                  bytes_r <= bytes_r-1;

                  if bytes_r-1 = 1 then
                     if last_r = '1' then
                        tx_last_r <= '1';
                     else
                        -- Consume data from FIFO
                        data_r  <= data_s;
                        last_r  <= last_s;
                        bytes_r <= bytes_s;
                        rd_en   <= '1';
                        assert rd_empty = '0';
                     end if;
                  end if;

                  if tx_last_r = '1' then
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
   tx_data_o  <= tx_data_r;

end Structural;

