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

   p_fact_idx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fact_start <= (others => '0');
         if cf_valid = '1' then
            if fact_busy(fact_idx) = '0' then
               fact_start(fact_idx) <= '1';
               fact_val(fact_idx)   <= cf_res_y;
               fact_neg(fact_idx)   <= cf_res_neg;
               fact_x(fact_idx)     <= cf_res_x;
               fact_primes          <= to_stdlogicvector(2*3*5*7*11*13*17*19, G_SIZE);

               if fact_idx < G_NUM_FACTS-1 then
                  fact_idx <= fact_idx + 1;
               else
                  fact_idx <= 0;
               end if;
            else
               report "Missed CF output.";
            end if;
         end if;

         if rst_i = '1' then
            fact_idx   <= 0;
         end if;
      end if;
   end process p_fact_idx;


   ----------------------------
   -- Instantiate FACT modules
   ----------------------------

   gen_facts : for i in 0 to G_NUM_FACTS-1 generate
      i_fact : entity work.fact
      generic map (
         G_SIZE   => G_SIZE
      )
      port map ( 
         clk_i    => clk_i,
         rst_i    => rst_i,
         primes_i => fact_primes,
         val_i    => fact_val(i),
         start_i  => fact_start(i),
         res_o    => fact_res(i),
         busy_o   => fact_busy(i),
         valid_o  => fact_valid(i)
      ); -- i_fact
   end generate gen_facts;


   -- Arbitrate between possible results
   p_out : process (fact_res, fact_valid, fact_val)
      variable res_fact : std_logic_vector(G_SIZE-1 downto 0);
      variable res_y    : std_logic_vector(G_SIZE-1 downto 0);
      variable res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
      variable res_neg  : std_logic;
      variable valid    : std_logic;
   begin
      res_fact := (others => '0');
      res_neg  := '0';
      res_y    := (others => '0');
      res_x    := (others => '0');
      valid    := '0';
      for i in 0 to G_NUM_FACTS-1 loop
         if fact_valid(i) = '1' then
            if valid = '1' then
               report "Missed FACT output";
            end if;
            res_fact := fact_res(i);
            res_neg  := fact_neg(i);
            res_y    := fact_val(i);
            res_x    := fact_x(i);
            valid    := '1';
         end if;
      end loop;

      res_x_o    <= res_x;
      res_y_o    <= res_y;
      res_neg_o  <= res_neg;
      res_fact_o <= res_fact;
      valid_o    <= valid;
   end process p_out;

   -- Connect output signals

   cf_res_x_o   <= cf_res_x;
   cf_res_y_o   <= cf_res_y;
   cf_res_neg_o <= cf_res_neg;
   cf_valid_o   <= cf_valid;

end Structural;

