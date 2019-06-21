library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the integer division module.

entity tb_divmod is
end tb_divmod;

architecture simulation of tb_divmod is

   constant C_SIZE     : integer := 72;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal dut_val_n    : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_val_d    : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_start    : std_logic;
   signal dut_res_q    : std_logic_vector(C_SIZE-1 downto 0);
   signal dut_res_r    : std_logic_vector(C_SIZE-1 downto 0);
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

   i_divmod : entity work.divmod
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk,
      rst_i   => rst,
      val_n_i => dut_val_n,
      val_d_i => dut_val_d,
      start_i => dut_start,
      res_q_o => dut_res_q,
      res_r_o => dut_res_r,
      busy_o  => dut_busy,
      valid_o => dut_valid
   ); -- i_divmod


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify DIVMOD processing
      procedure verify_divmod(val_n : integer;
                              val_d : integer) is

         variable exp_q  : integer;
         variable exp_r  : integer;
         variable cycles : integer;

         function log2(val : integer) return integer is
            variable res : integer;
            variable tmp : integer;
         begin
            res := 0;
            tmp := 1;

            while tmp <= val loop
               res := res + 1;
               tmp := tmp * 2;
            end loop;

            report "log2: " & integer'image(val) & " -> " & integer'image(res);

            return res;
         end function log2;

      begin -- procedure verify_sqrt

         -- Calculate expected response
         exp_q    := val_n / val_d;
         exp_r    := val_n mod val_d;
         cycles   := 2 * log2(exp_q) + 2;

         report "Verify DIVMOD: " & integer'image(val_n) &
            " / "  & integer'image(val_d) & 
            " -> " & integer'image(exp_q) & ", " & integer'image(exp_r) &
            " in " & integer'image(cycles) & " cycles.";

         -- Start calculation
         dut_val_n <= to_stdlogicvector(val_n, C_SIZE);
         dut_val_d <= to_stdlogicvector(val_d, C_SIZE);
         dut_start <= '1';
         wait until clk = '1';
         dut_start <= '0';
         wait until clk = '1';
         assert dut_valid = '0';

         -- Verify response is received within a given time
         wait for cycles * 2 ns;
         wait until clk = '1';
         assert dut_valid = '1';

         -- Verify received response is correct
         wait until clk = '0';
         assert dut_res_q = to_stdlogicvector(exp_q, C_SIZE);
         assert dut_res_r = to_stdlogicvector(exp_r, C_SIZE);
      end procedure verify_divmod;

   begin
      -- Wait until reset is complete
      dut_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify DIVMOD for a lot of small integers
      for n in 0 to 10 loop
         for d in 1 to 10 loop
            verify_divmod(n, d);
         end loop;
      end loop;

      -- Verify DIVMOD for some large integers
      verify_divmod(1000*1000*1000, 1234567890);
      verify_divmod(1000*1000*1000, 123456789);
      verify_divmod(1000*1000*1000, 12345678);
      verify_divmod(1000*1000*1000, 1234567);
      verify_divmod(1000*1000*1000, 123456);
      verify_divmod(1000*1000*1000, 12345);
      verify_divmod(1000*1000*1000, 1234);
      verify_divmod(1000*1000*1000, 123);
      verify_divmod(1000*1000*1000, 12);
      verify_divmod(1000*1000*1000, 1);

      wait for 20 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

