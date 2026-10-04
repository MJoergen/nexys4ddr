-- This is a small self-checking testbench for the scheduler. It checks:
-- * Nothing is started when the scheduler is not active.
-- * Nothing is started when all processes are busy.
-- * An idle process is started once in every round, and a busy process is never
--   started. This is checked for all processes idle, for a single idle process
--   (all positions), and for two idle processes.
-- * The processes are started in a round-robin order.
-- * The scheduler is restarted from the first process by reset.

library ieee;
use ieee.std_logic_1164.all;

entity job_scheduler_tb is
end entity job_scheduler_tb;

architecture sim of job_scheduler_tb is

   -- Not a power of two, to test the wrap around of the counter, and more than
   -- 16, so there are two groups of processes (see job_scheduler.vhd), and the
   -- second group is smaller.
   constant C_SIZE : integer := 21;

   type count_t is array (0 to C_SIZE-1) of integer;

   signal clk    : std_logic;
   signal rst      : std_logic;
   signal rst_gen  : std_logic;
   signal rst_test : std_logic := '0';   -- Used to test the reset
   signal active : std_logic := '0';
   signal busy   : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');
   signal valid  : std_logic;
   signal idx    : integer range 0 to C_SIZE-1;

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
      rst_gen <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst_gen <= '0';
      wait;
   end process p_rst;

   rst <= rst_gen or rst_test;


   ----------------------------
   -- Stimulus and checking
   ----------------------------

   p_test : process

      -- Count how many times each process is started, during the given number
      -- of clock cycles.
      procedure observe (
         cycles : integer;
         name   : string;
         counts : out count_t
      ) is
         variable prev_valid : boolean := false;
         variable prev_idx   : integer := 0;
      begin
         counts := (others => 0);
         for t in 1 to cycles loop
            wait until rising_edge(clk);
            if valid = '1' then
               counts(idx) := counts(idx) + 1;

               -- Round-robin: If started in two consecutive clock cycles, then
               -- the second process is the one after the first.
               if prev_valid then
                  assert idx = (prev_idx + 1) mod C_SIZE
                     report name & ": Not round-robin: " & integer'image(prev_idx) &
                            " followed by " & integer'image(idx)
                     severity error;
               end if;
            end if;
            prev_valid := (valid = '1');
            prev_idx   := idx;
         end loop;
      end procedure observe;

      -- Set the busy flags, and check that each idle process is started
      -- exactly once in each round (when active), and that busy processes are
      -- not started.
      procedure check_mask (
         mask   : std_logic_vector(C_SIZE-1 downto 0);
         rounds : integer;
         name   : string
      ) is
         variable counts : count_t;
         variable exp    : integer;
      begin
         busy <= mask;
         for t in 1 to C_SIZE + 4 loop    -- Wait for the change to take effect
            wait until rising_edge(clk);
         end loop;

         observe(rounds * C_SIZE, name, counts);

         for i in 0 to C_SIZE-1 loop
            if mask(i) = '0' and active = '1' then
               exp := rounds;
            else
               exp := 0;
            end if;
            assert counts(i) = exp
               report name & ": Process " & integer'image(i) & " was started " &
                      integer'image(counts(i)) & " times, expected " & integer'image(exp)
               severity error;
         end loop;
      end procedure check_mask;

      variable counts : count_t;
      variable mask   : std_logic_vector(C_SIZE-1 downto 0);

   begin
      wait until rst_gen = '0';

      -- Not active: nothing is started, even if all processes are idle
      active <= '0';
      check_mask((C_SIZE-1 downto 0 => '0'), 3, "not active");

      -- Active, and all processes idle
      active <= '1';
      check_mask((C_SIZE-1 downto 0 => '0'), 4, "all idle");

      -- Active, and only a single process idle
      for k in 0 to C_SIZE-1 loop
         mask    := (others => '1');
         mask(k) := '0';
         check_mask(mask, 3, "only process " & integer'image(k) & " idle");
      end loop;

      -- Two idle processes
      -- Two idle processes, one in each group
      mask     := (others => '1');
      mask(1)  := '0';
      mask(17) := '0';
      check_mask(mask, 3, "processes 1 and 17 idle");

      -- All processes busy
      check_mask((C_SIZE-1 downto 0 => '1'), 3, "all busy");

      -- Reset restarts the scheduler from the first process
      busy <= (others => '0');
      for t in 1 to C_SIZE + 4 loop
         wait until rising_edge(clk);
      end loop;
      wait for 2 ns;           -- Not at a clock edge, so reset is not aligned with the count
      rst_test <= '1';
      wait until rising_edge(clk);
      rst_test <= '0';
      wait until rising_edge(clk);
      assert valid = '0' and idx = 0
         report "Not cleared by reset"
         severity error;
      -- The busy flag is sampled one clock cycle before the process is started
      wait until rising_edge(clk);
      assert valid = '0' and idx = 0
         report "Started too early after reset"
         severity error;
      wait until rising_edge(clk);
      assert valid = '1' and idx = 0
         report "First process after reset is not 0"
         severity error;
      wait until rising_edge(clk);
      assert valid = '1' and idx = 1
         report "Second process after reset is not 1"
         severity error;

      report "job_scheduler_tb: finished";
      std.env.finish;
   end process p_test;


   -------------------
   -- Instantiate DUT
   -------------------

   i_job_scheduler : entity work.job_scheduler
      generic map (
         G_SIZE => C_SIZE
      )
      port map (
         clk_i           => clk,
         rst_i           => rst,
         sched_active_i  => active,
         job_idx_valid_o => valid,
         job_idx_start_o => idx,
         job_busy_i      => busy
      ); -- i_job_scheduler

end architecture sim;
