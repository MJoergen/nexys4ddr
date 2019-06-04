library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the algorithm module.

entity alg is
   generic (
      G_SIZE : integer
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      val_n_i    : in  std_logic_vector(2*G_SIZE-1 downto 0);
      val_x_i    : in  std_logic_vector(G_SIZE-1 downto 0);
      val_y_i    : in  std_logic_vector(G_SIZE-1 downto 0);
      valid_i    : in  std_logic;

      cf_res_x_o : out std_logic_vector(2*G_SIZE-1 downto 0);
      cf_res_y_o : out std_logic_vector(G_SIZE-1 downto 0);
      cf_valid_o : out std_logic;

      res_x_o    : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_y_o    : out std_logic_vector(G_SIZE-1 downto 0);
      res_fact_o : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o    : out std_logic
   );
end alg;

architecture Structural of alg is

   constant C_ZERO    : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   signal cf_start    : std_logic;
   signal cf_res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal cf_res_y    : std_logic_vector(G_SIZE-1 downto 0);
   signal cf_valid    : std_logic;

   signal res_x       : std_logic_vector(2*G_SIZE-1 downto 0);

   signal fact_primes : std_logic_vector(G_SIZE-1 downto 0);
   signal fact_val    : std_logic_vector(G_SIZE-1 downto 0);
   signal fact_start  : std_logic;
   signal fact_res    : std_logic_vector(G_SIZE-1 downto 0);
   signal fact_busy   : std_logic;
   signal fact_valid  : std_logic;

begin

   ------------------
   -- Instantiate CF
   ------------------

   i_cf : entity work.cf
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_n_i => val_n_i,
      val_x_i => val_x_i,
      val_y_i => val_y_i,
      start_i => valid_i,
      res_x_o => cf_res_x,
      res_y_o => cf_res_y, 
      valid_o => cf_valid
   ); -- i_cf


   p_fact : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if fact_busy = '0' then
            if cf_valid = '1' then
               fact_primes <= to_stdlogicvector(2*3*5*7*11*13*17*19, G_SIZE);
               fact_val    <= cf_res_y;
               res_x       <= cf_res_x;
            end if;
            fact_start <= cf_valid;
         end if;

         if rst_i = '1' then
            fact_start <= '0';
         end if;
      end if;
   end process p_fact;


   --------------------
   -- Instantiate FACT
   --------------------

   i_fact : entity work.fact
   generic map (
      G_SIZE   => G_SIZE
   )
   port map ( 
      clk_i    => clk_i,
      rst_i    => rst_i,
      primes_i => fact_primes,
      val_i    => fact_val,
      start_i  => fact_start,
      res_o    => fact_res,
      busy_o   => fact_busy,
      valid_o  => fact_valid
   ); -- i_fact


   -- Connect output signals
   res_x_o    <= res_x;
   res_y_o    <= fact_val;
   res_fact_o <= fact_res;
   valid_o    <= fact_valid;

   cf_res_x_o <= cf_res_x;
   cf_res_y_o <= cf_res_y;
   cf_valid_o <= cf_valid;

end Structural;

