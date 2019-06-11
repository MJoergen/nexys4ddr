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

   signal debug         : std_logic_vector(255 downto 0);

   signal sqrt_val      : std_logic_vector(2*G_SIZE-1 downto 0);  -- N
   signal sqrt_start    : std_logic;
   signal sqrt_res      : std_logic_vector(G_SIZE-1 downto 0);    -- M = floor(sqrt(N))
   signal sqrt_diff     : std_logic_vector(G_SIZE-1 downto 0);    -- N - M*M
   signal sqrt_busy     : std_logic;
   signal sqrt_valid    : std_logic;

begin

   -- We just ignore rx_last_i and rx_bytes_i.
   sqrt_val   <= rx_data_i(60*8-1 downto 60*8-2*G_SIZE);
   sqrt_start <= rx_valid_i;

   ---------------------------
   -- Instantiate SQRT module
   ---------------------------

   i_sqrt : entity work.sqrt
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_i   => sqrt_val,
      start_i => sqrt_start,
      res_o   => sqrt_res,
      diff_o  => sqrt_diff,
      busy_o  => sqrt_busy,
      valid_o => sqrt_valid
   ); -- i_sqrt


   ------------------------
   -- Drive output signals
   ------------------------

   p_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         tx_valid_o <= sqrt_valid;
         tx_data_o(60*8-1          downto 60*8-G_SIZE)   <= sqrt_res;
         tx_data_o(60*8-1-G_SIZE   downto 60*8-2*G_SIZE) <= sqrt_diff;
         tx_data_o(60*8-1-2*G_SIZE downto 0)             <= (others => '0');
         tx_bytes_o <= to_stdlogicvector(2*G_SIZE/8, 6);
         tx_last_o  <= '1';
      end if;
   end process p_out;


   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' then
            debug <= rx_data_i(60*8-1 downto 60*8-256);
         end if;
         if sqrt_valid = '1' then
            debug <= (others => '0');
            debug(2*G_SIZE-1 downto 0) <= sqrt_res & sqrt_diff;
         end if;
      end if;
   end process p_debug;

   -- Connect output signal
   debug_o <= debug;

end Structural;

