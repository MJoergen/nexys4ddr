library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the multiplication module.

entity tb_add_mult is
end tb_add_mult;

architecture simulation of tb_add_mult is

   constant C_SIZE     : integer := 72;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal dut_val_a    : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_val_x    : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_val_b    : std_logic_vector(2*C_SIZE-1 downto 0);
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

   i_add_mult : entity work.add_mult
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk,
      rst_i   => rst,
      val_a_i => dut_val_a,
      val_x_i => dut_val_x,
      val_b_i => dut_val_b,
      start_i => dut_start,
      res_o   => dut_res,
      busy_o  => dut_busy,
      valid_o => dut_valid
   ); -- i_add_mult


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify ADD_MULT processing
      procedure verify_add_mult(val_a : integer;
                                val_x : integer;
                                val_b : integer) is

         variable exp : integer;

      begin -- procedure verify_add_mult

         -- Calculate expected response
         exp := val_a * val_x + val_b;

         report "Verify ADD_MULT: " & integer'image(val_a) &
            " * "  & integer'image(val_x) & 
            " + "  & integer'image(val_b) & 
            " -> " & integer'image(exp);

         -- Start calculation
         dut_val_a <= to_stdlogicvector(val_a, C_SIZE);
         dut_val_x <= to_stdlogicvector(val_x, C_SIZE);
         dut_val_b <= to_stdlogicvector(val_b, 2*C_SIZE);
         dut_start <= '1';
         wait until clk = '1';
         dut_start <= '0';
         wait until clk = '1';
         assert dut_valid = '0';

         -- Verify received response is correct
         wait until clk = '1' and dut_valid = '1';
         wait until clk = '0';
         assert dut_res = to_stdlogicvector(exp, 2*C_SIZE);
      end procedure verify_add_mult;

   begin
      -- Wait until reset is complete
      dut_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify ADD_MULT for a lot of small integers
      for a in 0 to 5 loop
         for x in 0 to 5 loop
            for b in 0 to 5 loop
               verify_add_mult(a, x, b);
            end loop;
         end loop;
      end loop;

      -- Verify ADD_MULT for some large integers
      verify_add_mult(21, 321, 4321);
      verify_add_mult(321, 4321, 54321);
      verify_add_mult(5321, 54321, 654321);

      wait for 20 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

