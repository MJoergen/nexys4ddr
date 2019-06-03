library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_math is
end tb_math;

architecture simulation of tb_math is

   constant C_SIZE     : integer := 64;
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

      -- Verify CF processing
      procedure verify_cf(val_n  : integer;
                          val_x  : integer;
                          val_y  : integer;
                          res1_x : integer;
                          res1_y : integer;
                          res2_x : integer;
                          res2_y : integer;
                          res3_x : integer;
                          res3_y : integer) is
      begin

         report "Verify CF: N=" & integer'image(val_n) & 
            ", X=" & integer'image(val_x) & 
            ", Y=" & integer'image(val_y) & 
            " -> (" & integer'image(res1_x) &
            ", " & integer'image(res1_y) &
            " -> (" & integer'image(res2_x) &
            ", " & integer'image(res2_y) &
            ") -> (" & integer'image(res3_x) &
            ", " & integer'image(res3_y) &
            ")";

         assert val_n - val_x*val_x = val_y;
         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 60*8-4*C_SIZE) <=
            to_stdlogicvector(val_n, 2*C_SIZE) & 
            to_stdlogicvector(val_x, C_SIZE) &
            to_stdlogicvector(val_y, C_SIZE);
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(18, 6);
         wait until clk = '1';
         cmd.valid <= '0';

         -- Build expected response 1
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-3*C_SIZE) <= 
            to_stdlogicvector(res1_x, 2*C_SIZE) &
            to_stdlogicvector(res1_y, C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(3*C_SIZE/8, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';

         -- Build expected response 2
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-3*C_SIZE)  <= 
            to_stdlogicvector(res2_x, 2*C_SIZE) &
            to_stdlogicvector(res2_y, C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(3*C_SIZE/8, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';

         -- Build expected response 3
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-3*C_SIZE)  <= 
            to_stdlogicvector(res3_x, 2*C_SIZE) &
            to_stdlogicvector(res3_y, C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(3*C_SIZE/8, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';
      end procedure verify_cf;

   begin
      -- Wait until reset is complete
      cmd.valid <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify CF
      verify_cf(2059, 45, 34, 91, 45, 136, 35, 227, 54);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

