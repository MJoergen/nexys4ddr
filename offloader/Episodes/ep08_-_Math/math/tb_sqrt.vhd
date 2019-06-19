library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the integer square root module.

entity tb_sqrt is
end tb_sqrt;

architecture simulation of tb_sqrt is

   constant C_SIZE     : integer := 72;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal dut_val      : std_logic_vector(2*C_SIZE-1 downto 0);
   signal dut_start    : std_logic;
   signal dut_res      : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_diff     : std_logic_vector(C_SIZE-1 downto 0);
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

   i_sqrt : entity work.sqrt
   generic map (
      G_SIZE  => C_SIZE
   )
   port map (
      clk_i   => clk,
      rst_i   => rst,
      val_i   => dut_val,
      start_i => dut_start,
      res_o   => dut_res,
      diff_o  => dut_diff,
      valid_o => dut_valid
   ); -- i_sqrt


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify SQRT processing
      procedure verify_sqrt(val : integer) is

         -- Calculate the integer square root.
         function sqrt(v : integer) return integer is
            variable r : integer;
         begin
            r := 0;

            while r*r <= v loop
               r := r + 1;
            end loop;

            return r-1;
         end function sqrt;

         variable exp_sqrt : integer;
         variable exp_diff : integer;

      begin -- procedure verify_sqrt

         -- Calculate expected response
         exp_sqrt := sqrt(val);
         exp_diff := val - exp_sqrt*exp_sqrt;

         report "Verify SQRT: " & integer'image(val) & 
            " -> " & integer'image(exp_sqrt) & ", " & integer'image(exp_diff);

         -- Start calculation
         dut_val   <= to_stdlogicvector(val, 2*C_SIZE);
         dut_start <= '1';
         wait until clk = '1';
         dut_start <= '0';
         wait until clk = '1';
         assert dut_valid = '0';

         -- Verify received response is correct
         wait until clk = '1' and dut_valid = '1';
         wait until clk = '0';
         assert dut_res  = to_stdlogicvector(exp_sqrt, C_SIZE);
         assert dut_diff = to_stdlogicvector(exp_diff, C_SIZE);
      end procedure verify_sqrt;

   begin
      -- Wait until reset is complete
      dut_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify SQRT for a lot of small integers
      for i in 0 to 100 loop
         verify_sqrt(i);
      end loop;

      -- Verify SQRT for some large integers
      verify_sqrt(1000);
      verify_sqrt(1000*10);
      verify_sqrt(1000*100);
      verify_sqrt(1000*1000);
      verify_sqrt(1000*1000*10);
      verify_sqrt(1000*1000*100);
      verify_sqrt(1000*1000*1000);

      wait for 20 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

