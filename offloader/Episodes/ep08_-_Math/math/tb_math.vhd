library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Math module.

entity tb_math is
end tb_math;

architecture simulation of tb_math is

   constant C_SIZE     : integer := 72;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(60*8-1 downto 0);
      last  : std_logic;
      bytes : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal cmd          : t_sim;
   signal resp         : t_sim;
   signal debug        : std_logic_vector(255 downto 0);

   signal exp          : t_sim;

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

   i_math : entity work.math
   generic map (
      G_SIZE     => C_SIZE
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      debug_o    => debug,
      rx_valid_i => cmd.valid,
      rx_data_i  => cmd.data,
      rx_last_i  => cmd.last,
      rx_bytes_i => cmd.bytes,
      tx_valid_o => resp.valid,
      tx_data_o  => resp.data,
      tx_last_o  => resp.last,
      tx_bytes_o => resp.bytes
   ); -- i_math


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify SQRT processing
      procedure verify_sqrt(val  : integer) is

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

         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 60*8-2*C_SIZE) <=
            to_stdlogicvector(val, 2*C_SIZE);
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(2*C_SIZE/8, 6);
         wait until clk = '1';
         cmd.valid <= '0';
         wait until clk = '1';
         wait until clk = '0';
         assert resp.valid = '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-2*C_SIZE) <= 
            to_stdlogicvector(exp_sqrt, C_SIZE) &
            to_stdlogicvector(exp_diff, C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(2*C_SIZE/8, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
      end procedure verify_sqrt;

   begin
      -- Wait until reset is complete
      cmd.valid <= '0';
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

      wait for 200 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

