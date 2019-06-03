library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module converts a stream of bytes into a wider bus interface.
-- Both the input stream and the output stream use a pushing interface without
-- back-pressure.
-- The first byte received is placed in MSB, i.e.  tx_data_o(G_BYTES*8-1 downto G_BYTES*8-8);
--
-- In this module only two states are used:
-- * IDLE_ST : This state is used when no data is being forwarded.
-- * FWD_ST  : This state is used when a frame is currently being forwarded.
--
-- The value of rx_valid_i and rx_last_i control the transitions between these
-- two states. The register tx_bytes_r counts the number of bytes received so
-- far. When G_BYTES bytes have been received, this counter is reset to zero, and
-- the signal tx_valid_r is asserted.

entity byte2wide is
   generic (
      G_BYTES    : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Receive interface (byte oriented data bus). Pushing interface.
      rx_valid_i : in  std_logic;
      rx_last_i  : in  std_logic;
      rx_data_i  : in  std_logic_vector(7 downto 0);

      -- Transmit interface (wide data bus). Pushing interface.
      tx_valid_o : out std_logic;
      tx_last_o  : out std_logic;
      tx_data_o  : out std_logic_vector(G_BYTES*8-1 downto 0);
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end byte2wide;

architecture Structural of byte2wide is

   signal tx_valid_r : std_logic;
   signal tx_last_r  : std_logic;
   signal tx_data_r  : std_logic_vector(G_BYTES*8-1 downto 0);
   signal tx_bytes_r : std_logic_vector(5 downto 0);

   type t_state is (IDLE_ST, FWD_ST);
   signal state_r : t_state := IDLE_ST;

begin

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Default value
         tx_valid_r <= '0';

         case state_r is
            when IDLE_ST =>
               tx_last_r  <= '0';
               tx_bytes_r <= (others => '0');
               tx_data_r  <= (others => '0');

               if rx_valid_i = '1' then
                  tx_data_r(G_BYTES*8-1 downto G_BYTES*8-8) <= rx_data_i;  -- Write first byte to MSB.
                  tx_bytes_r <= to_stdlogicvector(1, 6);                   -- Number of bytes written so far.
                  state_r    <= FWD_ST;
               end if;

            when FWD_ST =>
               if rx_valid_i = '1' then
                  if tx_bytes_r = 0 then
                     tx_data_r <= (others => '0');
                  end if;
                  tx_data_r(G_BYTES*8-1-to_integer(tx_bytes_r)*8 downto    -- Write next byte
                            G_BYTES*8-8-to_integer(tx_bytes_r)*8) <= rx_data_i;
                  tx_bytes_r <= tx_bytes_r + 1;

                  if tx_bytes_r = G_BYTES-1 then                           -- If G_BYTES received, forward them.
                     tx_valid_r <= '1';
                     tx_bytes_r <= (others => '0');
                  end if;

                  if rx_last_i = '1' then                                  -- Forward last chunk.
                     tx_valid_r <= '1';
                     tx_last_r  <= '1';
                     state_r    <= IDLE_ST;
                  end if;
               end if;
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;


   -- Connnect output signals
   tx_valid_o <= tx_valid_r;
   tx_last_o  <= tx_last_r;
   tx_bytes_o <= tx_bytes_r;
   tx_data_o  <= tx_data_r;

end Structural;

