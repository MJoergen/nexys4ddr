library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module synchronizes a vector

entity cdcvector is

   generic (
              G_NEXYS4DDR : boolean;             -- True, when using the Nexys4DDR board.
              G_SIZE      : integer := 1
           );
   port (
           -- The sender
           rx_clk_i : in  std_logic;
           rx_in_i  : in  std_logic_vector(G_SIZE-1 downto 0);

           -- The receiver
           tx_clk_i : in  std_logic;
           tx_out_o : out std_logic_vector(G_SIZE-1 downto 0)
        );

end entity cdcvector;

architecture Structural of cdcvector is

   signal rx_in_s    : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   signal tx_in_s    : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   signal tx_in_d_s  : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   attribute ASYNC_REG : string;
   attribute ASYNC_REG of tx_in_s   : signal is "TRUE";
   attribute ASYNC_REG of tx_in_d_s : signal is "TRUE";

begin

   gen_nexys4ddr : if G_NEXYS4DDR = true generate

      ------------------------------
      -- Synchronize in source clock domain
      ------------------------------

      p_rx : process (rx_clk_i)
      begin
         if rising_edge(rx_clk_i) then
            rx_in_s <= rx_in_i;
         end if;
      end process p_rx;


      --------------------
      -- Synchronize in destinationn clock domain
      --------------------

      p_tx : process (tx_clk_i)
      begin
         if rising_edge(tx_clk_i) then
            tx_in_s <= rx_in_s;
            tx_in_d_s <= tx_in_s;
         end if;
      end process p_tx;

      -- Drive output signal
      tx_out_o <= tx_in_d_s;

   end generate gen_nexys4ddr;


   gen_no_nexys4ddr : if G_NEXYS4DDR = false generate
      tx_out_o <= rx_in_i;
   end generate gen_no_nexys4ddr;

end architecture Structural;

