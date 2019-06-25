library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is Math module. It receives a number N and two configuration
-- parameters, cfg_factors and cfg_primes, and sends these to the ALG module.
-- In return, it gets a sequence of value pairs (x,y) and five statistics
-- counters (CF, Miss_CF, Miss_Fact, Factored, Clk_cnt). All this is sent back
-- as a response.

entity math is
   generic (
      G_NUM_FACTS : integer;
      G_SIZE      : integer
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      debug_o     : out std_logic_vector(255 downto 0);

      -- Incoming command
      rx_valid_i  : in  std_logic;
      rx_data_i   : in  std_logic_vector(60*8-1 downto 0);
      rx_last_i   : in  std_logic;
      rx_bytes_i  : in  std_logic_vector(5 downto 0);

      -- Outgoing response
      tx_valid_o  : out std_logic;
      tx_data_o   : out std_logic_vector(60*8-1 downto 0);
      tx_last_o   : out std_logic;
      tx_bytes_o  : out std_logic_vector(5 downto 0)
   );
end math;

architecture Structural of math is

   signal alg_cfg_primes    : std_logic_vector(7 downto 0);    -- Number of primes.
   signal alg_cfg_factors   : std_logic_vector(7 downto 0);    -- Number of factors.
   signal alg_mon_cf        : std_logic_vector(31 downto 0);   -- Number of generated CF.
   signal alg_mon_miss_cf   : std_logic_vector(31 downto 0);   -- Number of missed CF.
   signal alg_mon_miss_fact : std_logic_vector(31 downto 0);   -- Number of missed FACT.
   signal alg_mon_factored  : std_logic_vector(31 downto 0);   -- Number of completely factored.
   signal alg_mon_clkcnt    : std_logic_vector(15 downto 0);   -- Average clock count factoring.
   signal alg_val           : std_logic_vector(2*G_SIZE-1 downto 0);
   signal alg_start         : std_logic;
   signal alg_res_x         : std_logic_vector(2*G_SIZE-1 downto 0);
   signal alg_res_p         : std_logic_vector(G_SIZE-1 downto 0);
   signal alg_res_w         : std_logic;
   signal alg_valid         : std_logic;

   signal res_y             : std_logic_vector(G_SIZE-1 downto 0);
   signal res               : std_logic_vector(3*G_SIZE+4*32+16-1 downto 0);

   signal debug             : std_logic_vector(255 downto 0);

begin

   -- We just ignore rx_last_i and rx_bytes_i.
   p_alg_start : process (clk_i)
   begin
      if rising_edge(clk_i) then
         alg_start <= '0';
         if rx_valid_i = '1' then
            alg_val         <= rx_data_i(60*8-1          downto 60*8-2*G_SIZE);
            alg_cfg_factors <= rx_data_i(60*8-2*G_SIZE-1 downto 60*8-2*G_SIZE-8);
            alg_cfg_primes  <= rx_data_i(60*8-2*G_SIZE-9 downto 60*8-2*G_SIZE-16);
            alg_start       <= '1';
         end if;
      end if;
   end process p_alg_start;


   --------------------------------
   -- Instantiate Algorithm module
   --------------------------------

   i_alg : entity work.alg
   generic map (
      G_NUM_FACTS => G_NUM_FACTS,
      G_SIZE      => G_SIZE
   )
   port map (
      clk_i           => clk_i,
      rst_i           => rst_i,
      start_i         => alg_start,
      cfg_primes_i    => alg_cfg_primes,
      cfg_factors_i   => alg_cfg_factors,
      val_i           => alg_val,
      valid_o         => alg_valid,
      res_x_o         => alg_res_x,
      res_p_o         => alg_res_p,
      res_w_o         => alg_res_w,
      mon_cf_o        => alg_mon_cf,
      mon_miss_cf_o   => alg_mon_miss_cf,
      mon_miss_fact_o => alg_mon_miss_fact,
      mon_factored_o  => alg_mon_factored,
      mon_clkcnt_o    => alg_mon_clkcnt
   ); -- i_alg


   ------------------------
   -- Drive output signals
   ------------------------
   
   res_y <= alg_res_p when alg_res_w = '0' else (not alg_res_p) + 1;
   res   <= alg_res_x & res_y & alg_mon_cf & alg_mon_miss_cf &
            alg_mon_miss_fact & alg_mon_factored & alg_mon_clkcnt;
   
   p_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         tx_data_o  <= (others => '0');
         tx_data_o(60*8-1 downto 60*8-res'length) <= res;
         tx_bytes_o <= to_stdlogicvector(res'length/8, 6);
         tx_last_o  <= '1';
         tx_valid_o <= alg_valid;
      end if;
   end process p_out;
         
   
   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' then
            debug <= rx_data_i(60*8-1 downto 60*8-256);
         end if;
         if tx_valid_o = '1' then
            debug <= tx_data_o(60*8-1 downto 60*8-256);
         end if;
         if rst_i = '1' then
            debug <= (others => '1');
         end if;
      end if;
   end process p_debug;

   -- Connect output signal
   debug_o <= debug;

end Structural;

