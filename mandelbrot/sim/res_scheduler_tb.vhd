-- This is a self-checking testbench for the result scheduler. Each process
-- behaves like a job module in the dispatcher: when it has a result, it is
-- ready until the result has been selected, and its ready flag goes low as
-- late as allowed (two clock cycles after the selection, see
-- res_scheduler.vhd). It then gets a new result after a random delay. It
-- checks:
-- * Nothing is selected when the scheduler is not active, or when no process
--   is ready.
-- * Only a process that is ready is selected, and each result is selected
--   only once.
-- * A process that is ready is selected within the expected time, also when
--   all the processes are ready all the time (i.e. the order is fair).
-- * All the results are selected.
-- This is done for two instances: one with several groups, where the last one
-- is smaller, and one with a single group, where the counter has empty
-- positions.

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

entity res_scheduler_tb is
end entity res_scheduler_tb;

architecture simulation of res_scheduler_tb is

   type config_t is record
      size       : positive;
      group_size : positive;
   end record config_t;
   type config_vector is array (natural range <>) of config_t;

   constant C_CONFIGS : config_vector := (
      (size => 21, group_size => 5),   -- Five groups, the last one has 1 process
      (size => 6,  group_size => 16)); -- One group

   signal clk      : std_logic;
   signal rst      : std_logic;
   signal finished : std_logic_vector(C_CONFIGS'range) := (others => '0');

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
      report "res_scheduler_tb: finished";
      std.env.stop;
   end process p_finish;


   gen_config : for n in C_CONFIGS'range generate
      constant C_SIZE       : natural := C_CONFIGS(n).size;
      constant C_GROUP_SIZE : natural := C_CONFIGS(n).group_size;
      constant C_NUM_GROUPS : natural := (C_SIZE + C_GROUP_SIZE - 1) / C_GROUP_SIZE;
      constant C_PERIOD     : natural := maximum(C_NUM_GROUPS, 5);
      -- A ready process is selected within this number of clock cycles: its
      -- group is visited once every C_PERIOD clock cycles, and each other
      -- process of the group is selected at most once before it. The ready
      -- flag and the candidate are registered in the group, and the selection
      -- is registered.
      constant C_MAX_WAIT   : natural := minimum(C_GROUP_SIZE, C_SIZE)*C_PERIOD + 3;

      signal active : std_logic := '0';
      signal ready  : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');
      signal valid  : std_logic;
      signal idx    : natural range 0 to C_SIZE-1;

   begin

      i_res_scheduler : entity work.res_scheduler
         generic map (
            G_SIZE       => C_SIZE,
            G_GROUP_SIZE => C_GROUP_SIZE
         )
         port map (
            clk_i       => clk,
            rst_i       => rst,
            active_i    => active,
            ready_i     => ready,
            idx_valid_o => valid,
            idx_o       => idx
         ); -- i_res_scheduler

      p_test : process
         type int_vector is array (0 to C_SIZE-1) of integer;
         variable seed1_v    : positive := 1 + n;
         variable seed2_v    : positive := 7;
         variable r_v        : real;
         variable t_v        : natural := 0;                  -- The current clock cycle
         variable has_v      : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');
         variable sel_v      : int_vector := (others => -1);  -- Clock cycle of the selection
         variable since_v    : int_vector := (others => 0);   -- Ready since this clock cycle
         variable delay_v    : int_vector := (others => 0);   -- Until the next result
         variable results_v  : natural := 0;
         variable selected_v : natural := 0;
         variable max_wait_v : natural := 0;

         -- Advance one clock cycle. The outputs of the scheduler are those of
         -- clock cycle t_v-1, and the ready flags are set for clock cycle t_v.
         -- New results come after max_delay clock cycles at most, or never
         -- when max_delay is negative.
         procedure step (max_delay : integer) is
            variable i_v : natural;
         begin
            wait until rising_edge(clk);
            t_v := t_v + 1;

            if valid = '1' then
               i_v := idx;
               assert active = '1'
                  report "Selected when not active"
                  severity error;
               assert has_v(i_v) = '1' and sel_v(i_v) = -1
                  report "Process " & integer'image(i_v) & " selected when it has no result"
                  severity error;
               sel_v(i_v) := t_v-1;
               selected_v := selected_v + 1;
               assert t_v-1 - since_v(i_v) <= C_MAX_WAIT
                  report "Process " & integer'image(i_v) & " waited " &
                         integer'image(t_v-1 - since_v(i_v)) & " clock cycles"
                  severity error;
               if t_v-1 - since_v(i_v) > max_wait_v then
                  max_wait_v := t_v-1 - since_v(i_v);
               end if;
            end if;

            for p in 0 to C_SIZE-1 loop
               -- The ready flag goes low two clock cycles after the selection
               if sel_v(p) /= -1 and t_v = sel_v(p) + 2 then
                  has_v(p) := '0';
                  sel_v(p) := -1;
                  uniform(seed1_v, seed2_v, r_v);
                  delay_v(p) := integer(trunc(r_v * real(max_delay + 1)));
               elsif has_v(p) = '0' and max_delay >= 0 then
                  if delay_v(p) = 0 then
                     has_v(p)   := '1';
                     since_v(p) := t_v;
                     results_v  := results_v + 1;
                  else
                     delay_v(p) := delay_v(p) - 1;
                  end if;
               end if;
            end loop;
            ready <= has_v;
         end procedure step;

      begin
         wait until rst = '0';

         -- Not active, and all ready: nothing is selected (checked in step)
         for i in 1 to 30 loop
            step(0);
         end loop;
         -- The processes have been ready while not active, so they wait from
         -- now on.
         since_v  := (others => t_v);
         active <= '1';

         -- All processes ready all the time
         for i in 1 to 500 loop
            step(0);
         end loop;

         -- Random delays, from short to long
         for i in 1 to 2000 loop
            step(3);
         end loop;
         for i in 1 to 3000 loop
            step(30);
         end loop;
         for i in 1 to 3000 loop
            step(300);
         end loop;

         -- No more results. All the results are selected.
         for i in 1 to 4*C_MAX_WAIT loop
            step(-1);
         end loop;
         assert has_v = (has_v'range => '0') and selected_v = results_v
            report "Not all results selected: " & integer'image(selected_v) &
                   " of " & integer'image(results_v)
            severity error;

         -- Nothing is ready: nothing is selected (checked in step)
         for i in 1 to 50 loop
            step(-1);
         end loop;

         report "Size " & integer'image(C_SIZE) & ", group size " &
                integer'image(C_GROUP_SIZE) & ": " & integer'image(selected_v) &
                " results selected, maximum wait " & integer'image(max_wait_v) &
                " clock cycles (limit " & integer'image(C_MAX_WAIT) & ")";
         finished(n) <= '1';
         wait;
      end process p_test;

   end generate gen_config;

end architecture simulation;
