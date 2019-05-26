library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module converts a stream of bytes into a wider bus interface.
-- The first byte received is placed in MSB, i.e.  tx_data_o(G_SIZE*8-1 downto G_SIZE*8-8);

entity byte2wide is
   generic (
      G_SIZE     : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Receive interface (byte oriented data bus)
      rx_valid_i : in  std_logic;
      rx_last_i  : in  std_logic;
      rx_data_i  : in  std_logic_vector(7 downto 0);

      -- Transmitinterface (wide data bus)
      tx_valid_o : out std_logic;
      tx_last_o  : out std_logic;
      tx_data_o  : out std_logic_vector(G_SIZE*8-1 downto 0);
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end byte2wide;

architecture Structural of byte2wide is

   signal tx_valid_r : std_logic;
   signal tx_last_r  : std_logic;
   signal tx_data_r  : std_logic_vector(G_SIZE*8-1 downto 0);
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
                  tx_data_r(G_SIZE*8-1 downto G_SIZE*8-8) <= rx_data_i;
                  tx_bytes_r <= to_stdlogicvector(1, 6);
                  state_r    <= FWD_ST;
               end if;

            when FWD_ST =>
               if rx_valid_i = '1' then
                  tx_data_r(G_SIZE*8-1-to_integer(tx_bytes_r)*8 downto
                            G_SIZE*8-8-to_integer(tx_bytes_r)*8) <= rx_data_i;
                  tx_bytes_r <= tx_bytes_r + 1;

                  if rx_last_i = '1' then
                     tx_valid_r <= '1';
                     tx_last_r  <= '1';
                     state_r    <= IDLE_ST;
                  end if;

                  if tx_bytes_r = G_SIZE-1 then
                     tx_valid_r  <= '1';
                     tx_bytes_r <= (others => '0');
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

