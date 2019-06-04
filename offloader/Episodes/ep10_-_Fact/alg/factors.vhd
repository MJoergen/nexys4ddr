library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity factors is
   generic (
      G_NUM_FACTS  : integer;
      G_SIZE       : integer
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;

      cf_res_x_i   : in  std_logic_vector(2*G_SIZE-1 downto 0);
      cf_res_y_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      cf_res_neg_i : in  std_logic;
      cf_valid_i   : in  std_logic;

      res_x_o      : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_y_o      : out std_logic_vector(G_SIZE-1 downto 0);
      res_neg_o    : out std_logic;
      res_fact_o   : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o      : out std_logic
   );
end factors;

architecture Structural of factors is

   constant C_ZERO    : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   constant C_PRIMES1 : std_logic_vector(63 downto 0) := X"088886ffdb344692"; -- 2*3*5*7*11*13*17*19*23*29*31*37*41*43*47
   constant C_PRIMES2 : std_logic_vector(63 downto 0) := X"34091fa96ffdf47b"; -- 53*59*61*67*71*73*79*83*89*97
   constant C_PRIMES3 : std_logic_vector(63 downto 0) := X"3c47d8d728a77ebb"; -- 101*103*107*109*113*127*131*137*139
   constant C_PRIMES4 : std_logic_vector(63 downto 0) := X"077ab7da9d709ea9"; -- 149*151*157*163*167*173*179*181

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

   p_fact_idx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fact_start <= (others => '0');
         if cf_valid_i = '1' then
            if fact_busy(fact_idx) = '0' then
               fact_start(fact_idx) <= '1';
               fact_val(fact_idx)   <= cf_res_y_i;
               fact_neg(fact_idx)   <= cf_res_neg_i;
               fact_x(fact_idx)     <= cf_res_x_i;
               fact_primes          <= C_PRIMES1;

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

      -- Connect output signals
      res_x_o    <= res_x;
      res_y_o    <= res_y;
      res_neg_o  <= res_neg;
      res_fact_o <= res_fact;
      valid_o    <= valid;
   end process p_out;

end Structural;

