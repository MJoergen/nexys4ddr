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

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   signal val_n    : std_logic_vector(2*G_SIZE-1 downto 0);

   signal cf_start : std_logic;
   signal cf_res_x : std_logic_vector(2*G_SIZE-1 downto 0);
   signal cf_res_p : std_logic_vector(G_SIZE-1 downto 0);
   signal cf_res_w : std_logic;
   signal cf_valid : std_logic;

   signal debug    : std_logic_vector(255 downto 0);

begin

   -- We just ignore rx_last_i and rx_bytes_i.
   val_n <= rx_data_i(60*8-1          downto 60*8-2*G_SIZE);

   cf_start <= rx_valid_i;

   i_cf : entity work.cf
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_i   => val_n,
      start_i => cf_start,
      res_x_o => cf_res_x,
      res_p_o => cf_res_p, 
      res_w_o => cf_res_w, 
      valid_o => cf_valid
   );

   tx_valid_o <= cf_valid;
   tx_data_o(60*8-1          downto 60*8-2*G_SIZE) <= cf_res_x;
   tx_data_o(60*8-1-2*G_SIZE downto 60*8-3*G_SIZE) <= cf_res_p;
   tx_data_o(60*8-1-3*G_SIZE downto 0)             <= (others => '0');
   tx_bytes_o <= to_stdlogicvector(3*G_SIZE/8, 6);
   tx_last_o  <= '1';

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' then
            debug <= rx_data_i(60*8-1 downto 60*8-256);
         end if;
         if cf_valid = '1' then
            debug <= (others => '0');
            debug(2*G_SIZE-1 downto 0) <= cf_res_x;
         end if;
      end if;
   end process p_debug;

   -- Connect output signal
   debug_o <= debug;

end Structural;

