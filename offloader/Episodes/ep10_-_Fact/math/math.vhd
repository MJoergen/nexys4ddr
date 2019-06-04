library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is Math module. It receives and dispatches command, and returns the
-- responses.

entity math is
   generic (
      G_SIZE : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      debug_o    : out std_logic_vector(255 downto 0);

      -- Incoming command
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Outgoing response
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end math;

architecture Structural of math is

   constant C_ZERO    : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   signal val_n       : std_logic_vector(2*G_SIZE-1 downto 0);
   signal val_x       : std_logic_vector(G_SIZE-1 downto 0);
   signal val_y       : std_logic_vector(G_SIZE-1 downto 0);
   signal valid       : std_logic;

   signal alg_x       : std_logic_vector(2*G_SIZE-1 downto 0);
   signal alg_y       : std_logic_vector(G_SIZE-1 downto 0);
   signal alg_fact    : std_logic_vector(G_SIZE-1 downto 0);
   signal alg_valid   : std_logic;

   signal debug       : std_logic_vector(255 downto 0);

begin

   -- We just ignore rx_last_i and rx_bytes_i.
   val_n <= rx_data_i(60*8-1          downto 60*8-2*G_SIZE);
   val_x <= rx_data_i(60*8-1-2*G_SIZE downto 60*8-3*G_SIZE);
   val_y <= rx_data_i(60*8-1-3*G_SIZE downto 60*8-4*G_SIZE);
   valid <= rx_valid_i;


   --------------------------------
   -- Instantiate Algorithm module
   --------------------------------

   i_alg : entity work.alg
   generic map (
      G_SIZE => G_SIZE
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      val_n_i    => val_n,
      val_x_i    => val_x,
      val_y_i    => val_y,
      valid_i    => valid,
      res_x_o    => alg_x,
      res_y_o    => alg_y,
      res_fact_o => alg_fact,
      valid_o    => alg_valid
   ); -- i_alg


   tx_valid_o <= alg_valid;
   tx_data_o(60*8-1          downto 60*8-2*G_SIZE) <= alg_x;
   tx_data_o(60*8-1-2*G_SIZE downto 60*8-3*G_SIZE) <= alg_y;
   tx_data_o(60*8-1-3*G_SIZE downto 60*8-4*G_SIZE) <= alg_fact;
   tx_data_o(60*8-1-4*G_SIZE downto 0)             <= (others => '0');
   tx_bytes_o <= to_stdlogicvector(G_SIZE/8, 6);
   tx_last_o  <= '1';

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' then
            debug <= rx_data_i(60*8-1 downto 60*8-256);
         end if;
         if alg_valid = '1' then
            debug <= (others => '0');
            debug(2*G_SIZE-1 downto 0) <= alg_x;
         end if;
      end if;
   end process p_debug;

   -- Connect output signal
   debug_o <= debug;

end Structural;

