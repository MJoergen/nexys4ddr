library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module is a small test module that inverts everything received.

entity math is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      debug_o    : out std_logic_vector(255 downto 0);

      -- Ingress to client
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress from client
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end math;

architecture Structural of math is

   -- The UDP payload consists of 60-42=18 bytes in the first clock cycle.
   constant C_SIZE : integer := 9*8;

   -- Signals connected to GCD
   signal val1  : std_logic_vector(C_SIZE-1 downto 0);
   signal val2  : std_logic_vector(C_SIZE-1 downto 0);
   signal start : std_logic;
   signal res   : std_logic_vector(C_SIZE-1 downto 0);
   signal valid : std_logic;

   signal debug    : std_logic_vector(255 downto 0) := 
      X"FEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFE";
begin

   -- We just ignore rx_last_i and rx_bytes_i.
   val1  <= rx_data_i(60*8-1        downto 60*8-C_SIZE);
   val2  <= rx_data_i(60*8-1-C_SIZE downto 60*8-C_SIZE*2);
   start <= rx_valid_i;

   i_gcd : entity work.gcd
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => val1,
      val2_i  => val2,
      start_i => start,
      res_o   => res,
      valid_o => valid
   );

   tx_valid_o <= valid;
   tx_data_o(60*8-1        downto 60*8-C_SIZE)   <= res;
   tx_data_o(60*8-1-C_SIZE downto 60*8-C_SIZE*2) <= (others => '0');
   tx_bytes_o <= to_stdlogicvector(18, 6);
   tx_last_o  <= '1';

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' then
            debug <= rx_data_i(60*8-1 downto 60*8-256);
         end if;
         if valid = '1' then
            debug <= (others => '0');
            debug(C_SIZE-1 downto 0) <= res;
         end if;
      end if;
   end process p_debug;

   -- Connect output signal
   debug_o <= debug;

end Structural;

