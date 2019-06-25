library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the factorization module.

entity tb_fact_all is
end tb_fact_all;

architecture simulation of tb_fact_all is

   constant C_SIZE     : integer := 72;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal dut_val      : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_primes   : std_logic_vector(7 downto 0);
   signal dut_start    : std_logic;
   signal dut_res      : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_busy     : std_logic;
   signal dut_valid    : std_logic;

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

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


   --------------------------------------------------
   -- Instantiate DUT
   --------------------------------------------------

   i_fact_all : entity work.fact_all
   generic map (
      G_SIZE  => C_SIZE
   )
   port map (
      clk_i    => clk,
      rst_i    => rst,
      val_i    => dut_val,
      primes_i => dut_primes,
      start_i  => dut_start,
      res_o    => dut_res,
      busy_o   => dut_busy,
      valid_o  => dut_valid
   ); -- i_fact_all


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify FACT processing
      procedure verify_fact(val : integer) is

         variable exp_res : integer;

      begin -- procedure verify_fact

         -- Calculate expected response
         exp_res := val;
         for i in 2 to 307 loop   -- Test for all primes up to 307 inclusive.
            while (exp_res mod i) = 0 loop
               exp_res := exp_res/i;
            end loop;
         end loop;

         report "Verify FACT: " & integer'image(val) & 
            " -> " & integer'image(exp_res);

         -- Start calculation
         dut_val    <= to_stdlogicvector(val, C_SIZE);
         dut_primes <= "00000110";
         dut_start  <= '1';
         wait until clk = '1';
         dut_start <= '0';
         wait until clk = '1';
         assert dut_valid = '0'
            report "Valid not deasserted";

         -- Verify received response is correct
         wait until clk = '1' and dut_valid = '1';
         wait until clk = '0';
         assert dut_res  = to_stdlogicvector(exp_res, C_SIZE)
            report "dut_res=" & integer'image(to_integer(dut_res));
      end procedure verify_fact;

   begin
      -- Wait until reset is complete
      dut_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify FACT for a lot of small integers
      for i in 1 to 200 loop
         verify_fact(i);
      end loop;

      -- Verify FACT for some large integers
      verify_fact(1234);
      verify_fact(12345);
      verify_fact(23456);
      verify_fact(34567);
      verify_fact(45678);
      verify_fact(56789);
      verify_fact(56790);
      verify_fact(56791);
      verify_fact(56792);
      verify_fact(56793);
      verify_fact(56794);
      verify_fact(56795);
      verify_fact(56796);
      verify_fact(56797);
      verify_fact(56798);
      verify_fact(56799);
      verify_fact(56800);
      verify_fact(56801);
      verify_fact(56802);
      verify_fact(56803);
      verify_fact(56804);
      verify_fact(56805);
      verify_fact(56806);
      verify_fact(56807);
      verify_fact(56808);
      verify_fact(56809);
      verify_fact(56810);
      verify_fact(56811);
      verify_fact(56812);
      verify_fact(56813);
      verify_fact(56814);
      verify_fact(56815);
      verify_fact(56816);
      verify_fact(56817);
      verify_fact(56818);
      verify_fact(56819);
      verify_fact(56820);
      verify_fact(56821);
      verify_fact(56822);
      verify_fact(56823);
      verify_fact(56824);
      verify_fact(56825);
      verify_fact(56826);
      verify_fact(56827);
      verify_fact(56828);
      verify_fact(56829);

      wait for 20 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

