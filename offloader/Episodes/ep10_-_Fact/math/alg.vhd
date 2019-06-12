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

      res_x_o      : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_y_o      : out std_logic_vector(G_SIZE-1 downto 0);
      res_neg_o    : out std_logic;
      res_fact_o   : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o      : out std_logic
   );
end alg;

architecture Structural of alg is

   signal cf_res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal cf_res_y    : std_logic_vector(G_SIZE-1 downto 0);
   signal cf_res_neg  : std_logic;
   signal cf_valid    : std_logic;

   signal fs_res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal fs_res_y    : std_logic_vector(G_SIZE-1 downto 0);
   signal fs_res_neg  : std_logic;
   signal fs_res_fact : std_logic_vector(G_SIZE-1 downto 0);
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
      res_x_o      => fs_res_x,
      res_y_o      => fs_res_y,
      res_neg_o    => fs_res_neg,
      res_fact_o   => fs_res_fact,
      valid_o      => fs_valid
   ); -- i_factors


   -- Connect output signals

   res_x_o    <= fs_res_x;
   res_y_o    <= fs_res_y;
   res_neg_o  <= fs_res_neg;
   res_fact_o <= fs_res_fact;
   valid_o    <= fs_valid;

end Structural;

