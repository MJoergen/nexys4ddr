library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_math is
end tb_math;

architecture simulation of tb_math is

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(60*8-1 downto 0);
      last  : std_logic;
      bytes : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal sim_tx       : t_sim;
   signal sim_rx       : t_sim;
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
   port map (
      clk_i      => clk,
      rst_i      => rst,
      debug_o    => debug,
      rx_valid_i => sim_rx.valid,
      rx_data_i  => sim_rx.data,
      rx_last_i  => sim_rx.last,
      rx_bytes_i => sim_rx.bytes,
      tx_valid_o => sim_tx.valid,
      tx_data_o  => sim_tx.data,
      tx_last_o  => sim_tx.last,
      tx_bytes_o => sim_tx.bytes
   ); -- i_math


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify MULT processing
      procedure verify_mult(signal tx : inout t_sim;
                            signal rx : in    t_sim) is
      begin

         report "Verify MULT processing.";

         -- Send one ARP request
         tx.valid <= '1';
         tx.data  <= (others => '0');
         tx.last  <= '1';
         tx.bytes <= (others => '0');       -- Frame size 60 bytes.
         wait until clk = '1';
         tx.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.last  <= '1';
         exp.bytes <= (others => '0');

         -- Verify ARP response is correct
         wait until clk = '1' and rx.valid = '1';
         wait until clk = '0';
         assert rx.data  = exp.data;
         assert rx.last  = exp.last;
         assert rx.bytes = exp.bytes;
      end procedure verify_mult;

   begin
      -- Wait until reset is complete
      sim_tx.valid <= '0';
      wait until clk = '1' and rst = '0';

      verify_mult(sim_tx, sim_rx);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

