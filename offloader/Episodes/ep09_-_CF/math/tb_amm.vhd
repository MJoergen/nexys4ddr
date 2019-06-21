library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the multiplication modulo module.

entity tb_amm is
end tb_amm;

architecture simulation of tb_amm is

   constant C_SIZE     : integer := 72;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal dut_val_a    : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_val_x    : std_logic_vector(2*C_SIZE-1 downto 0);
   signal dut_val_b    : std_logic_vector(2*C_SIZE-1 downto 0);
   signal dut_val_n    : std_logic_vector(2*C_SIZE-1 downto 0);
   signal dut_start    : std_logic;
   signal dut_res      : std_logic_vector(2*C_SIZE-1 downto 0);
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

   i_amm : entity work.amm
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk,
      rst_i   => rst,
      val_a_i => dut_val_a,
      val_x_i => dut_val_x,
      val_b_i => dut_val_b,
      val_n_i => dut_val_n,
      start_i => dut_start,
      res_o   => dut_res,
      busy_o  => dut_busy,
      valid_o => dut_valid
   ); -- i_amm


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify AMM processing
      procedure verify_amm(val_a : integer;
                           val_x : integer;
                           val_b : integer;
                           val_n : integer) is

         variable exp : integer;

      begin -- procedure verify_add_mult

         -- Calculate expected response
         exp := (val_a * val_x + val_b) mod val_n;

         report "Verify AMM: " & integer'image(val_a) &
            " * "    & integer'image(val_x) & 
            " + "    & integer'image(val_b) & 
            " mod "  & integer'image(val_n) & 
            " -> "   & integer'image(exp);

         -- Start calculation
         dut_val_a <= to_stdlogicvector(val_a, C_SIZE);
         dut_val_x <= to_stdlogicvector(val_x, 2*C_SIZE);
         dut_val_b <= to_stdlogicvector(val_b, 2*C_SIZE);
         dut_val_n <= to_stdlogicvector(val_n, 2*C_SIZE);
         dut_start <= '1';
         wait until clk = '1';
         dut_start <= '0';
         wait until clk = '1';
         assert dut_valid = '0';

         -- Verify received response is correct
         wait until clk = '1' and dut_valid = '1';
         wait until clk = '0';
         assert dut_res = to_stdlogicvector(exp, 2*C_SIZE);
      end procedure verify_amm;

   begin
      -- Wait until reset is complete
      dut_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify AMM for a lot of small integers
      for a in 0 to 5 loop
         for x in 0 to 5 loop
            for b in 0 to 5 loop
               for n in 8 to 15 loop
                  verify_amm(a, x, b, n);
               end loop;
            end loop;
         end loop;
      end loop;

      -- Verify AMM for some large integers
      verify_amm(21, 321, 4321, 54321);
      verify_amm(321, 4321, 54321, 654321);
      verify_amm(5321, 54321, 654321, 7654321);

      wait for 20 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

