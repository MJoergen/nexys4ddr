library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the algorithm module.  It instantiates the Continued Fraction module
-- to continuously generate pairs (x, y).  It then dispatches the y-values to
-- an array of factoring modules.  If the y-values are completely factored,
-- then return the (x, y) pair.

entity alg is
   generic (
      G_NUM_FACTS     : integer;
      G_SIZE          : integer
   );
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      cfg_primes_i    : in  std_logic_vector(7 downto 0);    -- Number of primes.
      cfg_factors_i   : in  std_logic_vector(7 downto 0);    -- Number of factors.
      mon_cf_o        : out std_logic_vector(31 downto 0);   -- Number of generated CF.
      mon_miss_cf_o   : out std_logic_vector(31 downto 0);   -- Number of missed CF.
      mon_miss_fact_o : out std_logic_vector(31 downto 0);   -- Number of missed FACT.
      mon_factored_o  : out std_logic_vector(31 downto 0);   -- Number of completely factored.
      mon_clkcnt_o    : out std_logic_vector(15 downto 0);   -- Average clock count factoring.

      val_i           : in  std_logic_vector(2*G_SIZE-1 downto 0);
      start_i         : in  std_logic;

      res_x_o         : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_p_o         : out std_logic_vector(G_SIZE-1 downto 0);
      res_w_o         : out std_logic;
      valid_o         : out std_logic
   );
end alg;

architecture Structural of alg is

   -- Output from Continued Fraction module.
   signal cf_res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal cf_res_p    : std_logic_vector(G_SIZE-1 downto 0);
   signal cf_res_w    : std_logic;
   signal cf_valid    : std_logic;

   -- Output from Factors module.
   signal fs_res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal fs_res_p    : std_logic_vector(G_SIZE-1 downto 0);
   signal fs_res_w    : std_logic;
   signal fs_valid    : std_logic;

begin

   ------------------
   -- Instantiate CF
   ------------------

   i_cf : entity work.cf
   generic map (
      G_SIZE    => G_SIZE
   )
   port map ( 
      clk_i     => clk_i,
      rst_i     => rst_i,
      val_i     => val_i,
      start_i   => start_i,
      res_x_o   => cf_res_x,
      res_p_o   => cf_res_p, 
      res_w_o   => cf_res_w,
      valid_o   => cf_valid
   ); -- i_cf


   -----------------------
   -- Instantiate FACTORS
   -----------------------

   i_factors : entity work.factors
   generic map (
      G_NUM_FACTS     => G_NUM_FACTS,
      G_SIZE          => G_SIZE
   )
   port map (
      clk_i           => clk_i,
      rst_i           => rst_i,
      cfg_primes_i    => cfg_primes_i,
      cfg_factors_i   => cfg_factors_i,
      mon_miss_cf_o   => mon_miss_cf_o,
      mon_miss_fact_o => mon_miss_fact_o,
      mon_cf_o        => mon_cf_o,
      mon_factored_o  => mon_factored_o,
      mon_clkcnt_o    => mon_clkcnt_o,
      cf_res_x_i      => cf_res_x,
      cf_res_p_i      => cf_res_p,
      cf_res_w_i      => cf_res_w,
      cf_valid_i      => cf_valid,
      res_x_o         => fs_res_x,
      res_p_o         => fs_res_p,
      res_w_o         => fs_res_w,
      valid_o         => fs_valid
   ); -- i_factors


   -- Connect output signals

   res_x_o    <= fs_res_x;
   res_p_o    <= fs_res_p;
   res_w_o    <= fs_res_w;
   valid_o    <= fs_valid;

end Structural;

