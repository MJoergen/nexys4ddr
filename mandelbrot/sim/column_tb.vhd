-- This is a simple self-checking testbench for the column. It runs three jobs,
-- each of a few rows, and checks the following:
-- * The column is not busy, and gives no results, when idle.
-- * The column is busy from the start of a job until the last result has been
--   acknowledged.
-- * The results come in order, one for each group of G_PIXELS rows, with the
--   row number of the first row, and each result is given only once.
-- * A result stays valid, and unchanged, until it is acknowledged. This is
--   tested by delaying the acknowledge by a varying number of clock cycles.
-- * The iteration count for each row is exactly the count calculated by the
--   bit-accurate model in iterator_model_pkg.vhd, for the value of c of that
--   row.
-- This is done for one, two and four pixels (rows) in each result.
--
-- Only a few rows, and a low maximum count, are used to keep the simulation
-- short.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.iterator_model_pkg.all;

entity column_tb is
end entity column_tb;

architecture simulation of column_tb is

   constant C_MAX_COUNT   : integer := 50;
   constant C_NUM_ROWS    : integer := 12;

   -- Pixels in each result, in each instance
   type int_vector is array (natural range <>) of integer;
   constant C_PIXELS      : int_vector := (1, 2, 4);

   signal clk         : std_logic;
   signal rst         : std_logic;
   signal finished    : std_logic_vector(C_PIXELS'range) := (others => '0');

   -- Convert a real value to the 2.16 fixed point format, as an integer
   function to_fixed (r : real) return integer is
   begin
      return integer(round(r * 65536.0));
   end function to_fixed;

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   p_finish : process
   begin
      wait until finished = (finished'range => '1');
      report "column_tb: finished";
      std.env.finish;
   end process p_finish;


   gen_dut : for n in C_PIXELS'range generate
      constant C_PIX : integer := C_PIXELS(n);

      -- Maximum number of clock cycles to wait for a single result
      constant C_RES_TIMEOUT : integer := C_PIX*(3*C_MAX_COUNT + 30);

      signal job_start   : std_logic := '0';
      signal job_cx      : std_logic_vector(17 downto 0) := (others => '0');
      signal job_starty  : std_logic_vector(17 downto 0) := (others => '0');
      signal job_stepy   : std_logic_vector(17 downto 0) := (others => '0');
      signal job_busy    : std_logic;
      signal res_addr    : std_logic_vector( 8 downto 0);
      signal res_ack     : std_logic := '0';
      signal res_data    : std_logic_vector(9*C_PIX-1 downto 0);
      signal res_valid   : std_logic;

   begin

      ----------------------------
      -- Stimulus and checking
      ----------------------------

      p_test : process

         -- Run a job, and check the results of all the rows. The signals are all
         -- sampled just before a rising clock edge.
         procedure run_job (
            cx_r     : real;
            starty_r : real;
            stepy_r  : real;
            name     : string
         ) is
            variable cy_i     : integer;
            variable exp      : integer;
            variable act      : integer;
            variable seen     : boolean;
            variable cap_addr : std_logic_vector(8 downto 0);
            variable cap_data : std_logic_vector(9*C_PIX-1 downto 0);
            variable row      : integer;
         begin
            report "Starting job " & name & " with " & integer'image(C_PIX) & " pixels in each result";

            wait until rising_edge(clk);
            job_cx     <= std_logic_vector(to_signed(to_fixed(cx_r),     18));
            job_starty <= std_logic_vector(to_signed(to_fixed(starty_r), 18));
            job_stepy  <= std_logic_vector(to_signed(to_fixed(stepy_r),  18));
            job_start  <= '1';
            wait until rising_edge(clk);
            job_start  <= '0';

            for res in 0 to C_NUM_ROWS/C_PIX-1 loop
               -- Wait for the result of these rows
               row  := res*C_PIX;
               seen := false;
               for t in 1 to C_RES_TIMEOUT loop
                  wait until rising_edge(clk);
                  assert job_busy = '1'
                     report name & ": Not busy during the job"
                     severity error;
                  if res_valid = '1' then
                     seen := true;
                     exit;
                  end if;
               end loop;
               assert seen
                  report name & ": Timeout waiting for the result of row " & integer'image(row)
                  severity failure;

               cap_addr := res_addr;
               cap_data := res_data;

               -- Check the row number and the count
               assert to_integer(unsigned(cap_addr)) = row
                  report name & ": Wrong row number: got " & integer'image(to_integer(unsigned(cap_addr))) &
                         ", expected " & integer'image(row)
                  severity error;

               for i in 0 to C_PIX-1 loop
                  -- The column module adds the step in 18 bits
                  cy_i := wrap18(to_fixed(starty_r) + (row+i) * to_fixed(stepy_r));
                  exp  := iterator_count(to_fixed(cx_r), cy_i, C_MAX_COUNT);
                  act  := to_integer(unsigned(cap_data(9*i+8 downto 9*i)));
                  report name & ": row " & integer'image(row+i) & ": count = " & integer'image(act) &
                         ", expected = " & integer'image(exp);
                  assert act = exp
                     report name & ": Wrong count for row " & integer'image(row+i) & ": got " &
                            integer'image(act) & ", expected " & integer'image(exp)
                     severity error;
               end loop;

               -- Delay the acknowledge. The result must remain valid and unchanged.
               for t in 1 to (res mod 3) * 3 loop
                  wait until rising_edge(clk);
                  assert res_valid = '1' and res_addr = cap_addr and res_data = cap_data
                     report name & ": Result changed before it was acknowledged, row " & integer'image(row)
                     severity error;
               end loop;

               res_ack <= '1';
               wait until rising_edge(clk);
               res_ack <= '0';
            end loop;

            -- The column should now be idle
            for t in 1 to 5 loop
               wait until rising_edge(clk);
               assert job_busy = '0' and res_valid = '0'
                  report name & ": Not idle after the last result"
                  severity error;
            end loop;
         end procedure run_job;

      begin
         wait until rst = '0';

         -- Nothing should happen when idle
         for t in 1 to 10 loop
            wait until rising_edge(clk);
            assert job_busy = '0' and res_valid = '0'
               report "Not idle before the first job"
               severity error;
         end loop;

         -- Job 1: Mixture of points in the set and points that escape quickly
         run_job(-1.0, -1.0, 0.25, "job 1");

         -- Job 2: Points with gradually decreasing counts
         run_job(-0.75, 0.0, 0.0625, "job 2");

         -- Job 3: Points near the top of the set (near i), where x+y or x-y is
         -- often outside the range -2 to 2 during the iteration
         run_job(-0.17, 0.95, 0.02, "job 3");

         finished(n) <= '1';
         wait;
      end process p_test;


      -------------------
      -- Instantiate DUT
      -------------------

      i_column : entity work.column
         generic map (
            G_MAX_COUNT => C_MAX_COUNT,
            G_NUM_ROWS  => C_NUM_ROWS,
            G_PIXELS    => C_PIX
         )
         port map (
            clk_i        => clk,
            rst_i        => rst,
            job_start_i  => job_start,
            job_cx_i     => job_cx,
            job_starty_i => job_starty,
            job_stepy_i  => job_stepy,
            job_busy_o   => job_busy,
            res_addr_o   => res_addr,
            res_ack_i    => res_ack,
            res_data_o   => res_data,
            res_valid_o  => res_valid
         ); -- i_column

   end generate gen_dut;

end architecture simulation;
