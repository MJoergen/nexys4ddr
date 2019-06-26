library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity fact_all is
   generic (
      G_SIZE   : integer
   );
   port ( 
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;

      val_i    : in  std_logic_vector(G_SIZE-1 downto 0);
      primes_i : in  std_logic_vector(7 downto 0);
      start_i  : in  std_logic;

      -- Outputs driven by this module
      res_o    : out std_logic_vector(G_SIZE-1 downto 0);
      busy_o   : out std_logic;
      clkcnt_o : out std_logic_vector(15 downto 0);
      valid_o  : out std_logic
   );
end fact_all;

architecture structural of fact_all is

   type primes_vector  is array (natural range <>) of std_logic_vector(G_SIZE-1 downto 0);

   constant C_PRIMES : primes_vector := (
      X"683ba8ff3e8b8a015e",  -- 2*3*5*7*11*13*17*19*23*29*31*37*41*43*47*53*59
      X"485b2c5de43e46e77d",  -- 61*67*71*73*79*83*89*97*101*103*107 
      X"79ccb68227152cf3c7",  -- 109*113*127*131*137*139*149*151*157*163
      X"0f7904b436e31510f3",  -- 167*173*179*181*191*193*197*199*211
      X"008b45a8fd62e4ee5d",  -- 223*227*229*233*239*241*251*257
      X"020f33695f0d471f95",  -- 263*269*271*277*281*283*293*307
      X"07fa1341067038b57f",  -- 311*313*317*331*337*347*349*353
      X"17f2ba61acf18f5401",  -- 359*367*373*379*383*389*397*401
      X"3fbc371491902b3fd5",  -- 409*419*421*431*433*439*443*449
      X"004868384877bc9713",  -- 457*461*463*467*479*487*491
      X"008ef71c2a0e870fa5",  -- 499*503*509*521*523*541*547
      X"011bfd10f7ecc996a7",  -- 557*563*569*571*577*587*593
      X"01bfff6f66e2591ed9",  -- 599*601*607*613*617*619*631
      X"02c472f76d04e016df",  -- 641*643*647*653*659*661*673
      X"047ff4473885d242dd",  -- 677*683*691*701*709*719*727
      X"07424027993fde8a83",  -- 733*739*743*751*757*761*769
      X"0ba6f1c444888d9e1b",  -- 773*787*797*809*811*821*823
      X"10e5e55499aba341a9",  -- 827*829*839*853*857*859*863
      X"18e9122485a9eba413",  -- 877*881*883*887*907*911*919
      X"25a0d3adaa90c1e80b"   -- 929*937*941*947*953*967*971
   );
   

   signal fact_val      : std_logic_vector(G_SIZE-1 downto 0);
--   signal fact_primes   : std_logic_vector(G_SIZE-1 downto 0);
   signal fact_start    : std_logic;
   signal fact_res      : std_logic_vector(G_SIZE-1 downto 0);
   signal fact_busy     : std_logic;
   signal fact_valid    : std_logic;

   type fsm_state is (IDLE_ST, WORKING_ST);
   signal state   : fsm_state;

   signal primes        : std_logic_vector(7 downto 0);
   signal prime_idx     : std_logic_vector(7 downto 0);

   signal fact_primes_d : std_logic_vector(G_SIZE-1 downto 0);
   signal fact_start_d  : std_logic;

   signal res           : std_logic_vector(G_SIZE-1 downto 0);
   signal busy          : std_logic;
   signal valid         : std_logic;
   signal clkcnt        : std_logic_vector(15 downto 0);
   signal clkcnt_avg    : std_logic_vector(31 downto 0);

begin

   p_fsm : process (clk_i) is
      variable diff_v  : std_logic_vector(31 downto 0);
      variable delta_v : std_logic_vector(31 downto 0);
   begin
      if rising_edge(clk_i) then

         -- Default values
         fact_start <= '0';
         valid      <= '0';

         case state is
            when IDLE_ST   =>
               if start_i = '1' then
                  fact_val   <= val_i;
                  primes     <= primes_i;
                  prime_idx  <= X"00";
                  fact_start <= '1';
                  state      <= WORKING_ST;
                  clkcnt     <= (others => '0');
               end if;

            when WORKING_ST =>
               clkcnt <= clkcnt + 1;
               if fact_start = '0' and fact_valid = '1' then
                  if fact_res = 1 or prime_idx+1 = primes or prime_idx+1 = C_PRIMES'length then

                     -- Calculate running average.
                     diff_v  := clkcnt & X"0000" - clkcnt_avg;
                     delta_v := (others => diff_v(31));
                     delta_v(31-8 downto 0) := diff_v(31 downto 8);

                     if clkcnt_avg = 0 then
                        clkcnt_avg <= clkcnt & X"0000";
                     else
                        clkcnt_avg <= clkcnt_avg + delta_v;
                     end if;
                     res        <= fact_res;
                     valid      <= '1';
                     state      <= IDLE_ST;
                  else
                     fact_val   <= fact_res;
                     prime_idx  <= prime_idx+1;
                     fact_start <= '1';
                  end if;
               end if;
         end case;

         if rst_i = '1' then
            state      <= IDLE_ST;
            clkcnt_avg <= (others => '0');
         end if;
      end if;
   end process p_fsm;

   p_primes : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fact_primes_d <= C_PRIMES(to_integer(prime_idx));
         fact_start_d  <= fact_start;
      end if;
   end process p_primes;


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
      val_i    => fact_val,
      primes_i => fact_primes_d,
      start_i  => fact_start_d,
      res_o    => fact_res,
      busy_o   => fact_busy,
      valid_o  => fact_valid
   ); -- i_fact


   --------------------------
   -- Connect output signals
   --------------------------

   res_o    <= res;
   valid_o  <= valid;
   busy_o   <= '0' when state = IDLE_ST else '1';
   clkcnt_o <= clkcnt_avg(31 downto 16);

end architecture structural;

