library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_alg is
end tb_alg;

architecture simulation of tb_alg is

   constant C_SIZE          : integer := 72;
   constant C_NUM_FACTS     : integer := 10;
   constant C_PRIMES        : integer := 4;

   signal clk               : std_logic;
   signal rst               : std_logic;

   -- Signals conected to DUT
   signal alg_cfg_primes    : std_logic_vector(7 downto 0);    -- Number of primes.
   signal alg_cfg_factors   : std_logic_vector(7 downto 0);    -- Number of factors.
   signal alg_mon_cf        : std_logic_vector(31 downto 0);   -- Number of generated CF.
   signal alg_mon_miss_cf   : std_logic_vector(31 downto 0);   -- Number of missed CF.
   signal alg_mon_miss_fact : std_logic_vector(31 downto 0);   -- Number of missed FACT.
   signal alg_mon_factored  : std_logic_vector(31 downto 0);   -- Number of completely factored.
   signal alg_mon_clkcnt    : std_logic_vector(15 downto 0);   -- Average clock count factoring.

   signal alg_val           : std_logic_vector(2*C_SIZE-1 downto 0);
   signal alg_start         : std_logic;
   signal alg_res_x         : std_logic_vector(2*C_SIZE-1 downto 0);
   signal alg_res_p         : std_logic_vector(C_SIZE-1 downto 0);
   signal alg_res_w         : std_logic;
   signal alg_res_valid     : std_logic;

   -- Signal to control execution of the testbench.
   signal test_running      : std_logic := '1';

begin

   --------------------------------------------------
   -- Generate clock and reset
   --------------------------------------------------

   proc_clk : process
   begin
      clk <= '1', '0' after 1 ns;
      wait for 2 ns; -- 50 MHz
      if test_running = '0' then
         wait;
      end if;
   end process proc_clk;

   proc_rst : process
   begin
      rst <= '1', '0' after 20 ns;
      wait;
   end process proc_rst;

   alg_cfg_primes  <= to_stdlogicvector(C_PRIMES,    8);
   alg_cfg_factors <= to_stdlogicvector(C_NUM_FACTS, 8);

   --------------------------------------------------
   -- Instantiate DUT
   --------------------------------------------------

   i_alg : entity work.alg
   generic map (
      G_NUM_FACTS     => C_NUM_FACTS,
      G_SIZE          => C_SIZE
   )
   port map (
      clk_i           => clk,
      rst_i           => rst,
      cfg_primes_i    => alg_cfg_primes,
      cfg_factors_i   => alg_cfg_factors,
      mon_miss_cf_o   => alg_mon_miss_cf,
      mon_miss_fact_o => alg_mon_miss_fact,
      mon_cf_o        => alg_mon_cf,
      mon_factored_o  => alg_mon_factored,
      mon_clkcnt_o    => alg_mon_clkcnt,
      val_i           => alg_val,
      start_i         => alg_start,
      res_x_o         => alg_res_x,
      res_p_o         => alg_res_p,
      res_w_o         => alg_res_w,
      valid_o         => alg_res_valid
   ); -- i_alg


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   -- Verify FACT processing
   verify_proc : process
      variable res_x : integer;                               
      variable res_p : integer;                               
      variable res_w : std_logic;                               
      variable res_f : integer;                               
   begin
      wait until clk = '1';
      if alg_res_valid = '1' and alg_val /= 0 then
         res_x := to_integer(alg_res_x);
         res_p := to_integer(alg_res_p);
         res_w := alg_res_w;

         report "x=" & integer'image(res_x) & ", " &
            "p=" & integer'image(res_p) & ", " &
            "w=" & std_logic'image(res_w);

         if res_w = '0' then
            assert (res_x * res_x - res_p) mod to_integer(alg_val) = 0;
         else
            assert (res_x * res_x + res_p) mod to_integer(alg_val) = 0;
         end if;
      end if;
   end process verify_proc;

   main_test_proc : process

      -- The number val_n should be no greater than 65536/sqrt(2) = 46340,
      -- because the square must be within a signed 32 bit number.
      procedure start_fact(val_n  : integer) is
      begin
         report "Start FACT: N=" & integer'image(val_n);

         wait until clk = '0';
         alg_val   <= to_stdlogicvector(val_n, 2*C_SIZE);
         alg_start <= '1';
         wait until clk = '1';
         alg_start <= '0';
         wait until clk = '1';
      end procedure start_fact;

   begin
      -- Wait until reset is complete
      alg_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify FACT
      start_fact(31861);
      wait for 40 us;
      start_fact(0);
      wait for 1 us;
      start_fact(45649);
      wait for 40 us;
      start_fact(0);
      wait for 1 us;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      report "Num_Facts     = " & integer'image(C_NUM_FACTS);
      report "Primes        = " & integer'image(C_PRIMES);
      report "Mon_CF        = " & integer'image(to_integer(alg_mon_cf));
      report "Mon_Miss_CF   = " & integer'image(to_integer(alg_mon_miss_cf));
      report "Mon_Miss_Fact = " & integer'image(to_integer(alg_mon_miss_fact));
      report "Mon_Factored  = " & integer'image(to_integer(alg_mon_factored));
      report "Mon_ClkCnt    = " & integer'image(to_integer(alg_mon_clkcnt));
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

