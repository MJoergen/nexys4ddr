library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the algorithm module.
-- It instantiates the Continued Fraction module to continuously generate pairs (x,y).
-- It then dispatches the y-values to an array of factoring modules.factoring modules.

entity alg is
   generic (
      G_NUM_FACTS  : integer;
      G_SIZE       : integer
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;

      val_n_i      : in  std_logic_vector(2*G_SIZE-1 downto 0);
      val_x_i      : in  std_logic_vector(G_SIZE-1 downto 0);
      val_y_i      : in  std_logic_vector(G_SIZE-1 downto 0);
      valid_i      : in  std_logic;

      cf_res_x_o   : out std_logic_vector(2*G_SIZE-1 downto 0);
      cf_res_y_o   : out std_logic_vector(G_SIZE-1 downto 0);
      cf_res_neg_o : out std_logic;
      cf_valid_o   : out std_logic;

      res_x_o      : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_y_o      : out std_logic_vector(G_SIZE-1 downto 0);
      res_neg_o    : out std_logic;
      res_fact_o   : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o      : out std_logic
   );
end alg;

architecture Structural of alg is

   constant C_ZERO    : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   constant C_PRIMES1 : std_logic_vector(63 downto 0) := X"088886ffdb344692"; -- 2*3*5*7*11*13*17*19*23*29*31*37*41*43*47
   constant C_PRIMES2 : std_logic_vector(63 downto 0) := X"34091fa96ffdf47b"; -- 53*59*61*67*71*73*79*83*89*97
   constant C_PRIMES3 : std_logic_vector(63 downto 0) := X"3c47d8d728a77ebb"; -- 101*103*107*109*113*127*131*137*139
   constant C_PRIMES4 : std_logic_vector(63 downto 0) := X"077ab7da9d709ea9"; -- 149*151*157*163*167*173*179*181

   signal cf_start    : std_logic;
   signal cf_res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal cf_res_y    : std_logic_vector(G_SIZE-1 downto 0);
   signal cf_res_neg  : std_logic;
   signal cf_valid    : std_logic;

   type res2_vector is array (natural range <>) of std_logic_vector(2*G_SIZE-1 downto 0);
   type res_vector is array (natural range <>) of std_logic_vector(G_SIZE-1 downto 0);

   signal fact_primes : std_logic_vector(G_SIZE-1 downto 0);
   signal fact_x      : res2_vector(G_NUM_FACTS-1 downto 0);
   signal fact_val    : res_vector(G_NUM_FACTS-1 downto 0);
   signal fact_neg    : std_logic_vector(G_NUM_FACTS-1 downto 0);
   signal fact_start  : std_logic_vector(G_NUM_FACTS-1 downto 0);
   signal fact_res    : res_vector(G_NUM_FACTS-1 downto 0);
   signal fact_busy   : std_logic_vector(G_NUM_FACTS-1 downto 0);
   signal fact_valid  : std_logic_vector(G_NUM_FACTS-1 downto 0);

   signal fact_idx    : integer range 0 to G_NUM_FACTS-1;

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
      val_n_i   => val_n_i,
      val_x_i   => val_x_i,
      val_y_i   => val_y_i,
      start_i   => valid_i,
      res_x_o   => cf_res_x,
      res_y_o   => cf_res_y, 
      res_neg_o => cf_res_neg, 
      valid_o   => cf_valid
   ); -- i_cf


   -----------------------
   -- Instantiate FACTORS
   -----------------------

   i_factors : entity work.factors
   generic map (
      G_NUM_FACTS  => G_NUM_FACTS,
      G_SIZE       => G_SIZE
   )
   port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      cf_res_x_i   => cf_res_x,
      cf_res_y_i   => cf_res_y,
      cf_res_neg_i => cf_res_neg,
      cf_valid_i   => cf_valid,
      res_x_o      => res_x_o,
      res_y_o      => res_y_o,
      res_neg_o    => res_neg_o,
      res_fact_o   => res_fact_o,
      valid_o      => valid_o
   ); -- i_factors


   -- Connect output signals

   cf_res_x_o   <= cf_res_x;
   cf_res_y_o   <= cf_res_y;
   cf_res_neg_o <= cf_res_neg;
   cf_valid_o   <= cf_valid;

end Structural;

