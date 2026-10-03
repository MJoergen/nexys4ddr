library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module instantiates a number of column modules, dispatches jobs to them
-- (one picture column per job), and collects results from them.

entity dispatcher is
   generic (
      G_MAX_COUNT     : integer;
      G_NUM_ROWS      : integer;
      G_NUM_COLS      : integer;
      G_NUM_ITERATORS : integer;
      G_GROUP_SIZE    : integer := 16
   );
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;
      start_i         : in  std_logic;
      startx_i        : in  std_logic_vector(17 downto 0);
      starty_i        : in  std_logic_vector(17 downto 0);
      stepx_i         : in  std_logic_vector(17 downto 0);
      stepy_i         : in  std_logic_vector(17 downto 0);
      wr_addr_o       : out std_logic_vector(18 downto 0);
      wr_data_o       : out std_logic_vector( 8 downto 0);
      wr_en_o         : out std_logic;
      done_o          : out std_logic
   );
end entity dispatcher;

architecture rtl of dispatcher is

   -- The job (cx, starty, and stepy), the reset, and the index of the column
   -- module whose result is accepted all go to all the column modules. To make
   -- the routing shorter, they go through an extra register in each group of
   -- G_GROUP_SIZE column modules. The registers in each group are identical,
   -- so the attribute keep prevents the synthesis tool from merging them.
   constant C_NUM_GROUPS : integer := (G_NUM_ITERATORS + G_GROUP_SIZE - 1) / G_GROUP_SIZE;

   type job_addr_vector is array (natural range <>) of
      std_logic_vector(9 downto 0);
   type res_addr_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);
   type res_data_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);
   type value_vector is array (natural range <>) of
      std_logic_vector(17 downto 0);
   type idx_vector is array (natural range <>) of
      integer range 0 to G_NUM_ITERATORS-1;

   signal sched_active_r    : std_logic;
   --
   signal job_cx_r          : std_logic_vector(17 downto 0);
   signal job_stepx_r       : std_logic_vector(17 downto 0);
   signal job_starty_r      : std_logic_vector(17 downto 0);
   signal job_stepy_r       : std_logic_vector(17 downto 0);
   --
   signal job_start_r       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal job_started_r     : std_logic;
   signal job_addr_r        : job_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal cur_addr_r        : std_logic_vector(9 downto 0);
   --
   -- The job, delayed by one clock cycle, in each group of column modules
   signal grp_cx_r          : value_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_starty_r      : value_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_stepy_r       : value_vector(C_NUM_GROUPS-1 downto 0);
   signal job_start_d       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal job_started_d     : std_logic;
   signal job_started_dd    : std_logic;
   -- High when any column module in the group is busy with a job
   signal grp_job_busy_r    : std_logic_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_rst_r         : std_logic_vector(C_NUM_GROUPS-1 downto 0);

   -- The index of the column module whose result is accepted, delayed by one
   -- clock cycle, in each group of column modules, and the result of the
   -- selected column module in each group.
   signal grp_idx_r         : idx_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_valid_r       : std_logic_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_res_addr_r    : res_addr_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_res_data_r    : res_data_vector(C_NUM_GROUPS-1 downto 0);

   attribute keep : string;
   attribute keep of grp_cx_r     : signal is "true";
   attribute keep of grp_starty_r : signal is "true";
   attribute keep of grp_stepy_r  : signal is "true";
   attribute keep of grp_rst_r    : signal is "true";
   attribute keep of grp_idx_r    : signal is "true";
   attribute keep of grp_valid_r  : signal is "true";
   --
   signal job_busy_s        : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_addr_s        : res_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal res_data_s        : res_data_vector( G_NUM_ITERATORS-1 downto 0);
   signal res_valid_s       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_ack_r         : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_busy_r        : std_logic_vector(G_NUM_ITERATORS-1 downto 0);

   signal wr_addr_r         : std_logic_vector(18 downto 0);
   signal wr_data_r         : std_logic_vector( 8 downto 0);
   signal wr_en_r           : std_logic;

   -- The accepted result, delayed by one and two clock cycles
   signal acc_job_addr_r    : std_logic_vector(9 downto 0);
   signal acc_job_addr_d    : std_logic_vector(9 downto 0);
   signal acc_grp_r         : integer range 0 to C_NUM_GROUPS-1;
   signal acc_grp_d         : integer range 0 to C_NUM_GROUPS-1;
   signal acc_valid_r       : std_logic;
   signal acc_valid_d       : std_logic;

   signal done_r            : std_logic;

   signal idx_start_r       : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_start_valid_r : std_logic;

   signal idx_iterator_r    : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_valid_r       : std_logic;

begin

   -- When the scheduler samples the busy flag of a column module and selects
   -- it, the new busy flag of that column module is sampled by the scheduler
   -- five clock cycles later at the earliest, both for a job (job_busy_s, the
   -- selection goes through the scheduler, job_start_r and job_start_d) and
   -- for a result (res_busy_r, the selection goes through the scheduler,
   -- grp_idx_r and res_ack_r). The scheduler samples the busy flag of the
   -- same column module again G_NUM_ITERATORS clock cycles later. With fewer
   -- than five column modules a job could therefore be started twice (and the
   -- first one would be lost), or a result accepted twice.
   assert G_NUM_ITERATORS >= 5
      report "The dispatcher needs at least five column modules"
      severity failure;

   p_sched_active : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if done_r = '1' then
            sched_active_r <= '0';
         end if;

         if start_i = '1' then
            sched_active_r <= '1';
         end if;

         if rst_i = '1' then
            sched_active_r <= '0';
         end if;
      end if;
   end process p_sched_active;


   -------------------------
   -- Instantiate scheduler
   -------------------------

   i_scheduler : entity work.scheduler
      generic map (
         G_SIZE => G_NUM_ITERATORS
      )
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         sched_active_i  => sched_active_r,
         job_idx_valid_o => idx_start_valid_r,
         job_idx_start_o => idx_start_r,
         job_busy_i      => job_busy_s
      ); -- i_scheduler


   ----------------------------------
   -- Start any idle column module
   ----------------------------------

   p_job_start : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Only pulse for one clock cycle. The signal job_started_r is high
         -- when any bit of job_start_r is high.
         job_start_r   <= (others => '0');
         job_started_r <= '0';

         if idx_start_valid_r = '1' and
            cur_addr_r < G_NUM_COLS
         then
            job_start_r(idx_start_r) <= '1';
            job_started_r            <= '1';
            job_addr_r(idx_start_r)  <= cur_addr_r;
            cur_addr_r               <= cur_addr_r + 1;
         end if;

         if start_i = '1' then
            cur_addr_r <= (others => '0');
         end if;

         if rst_i = '1' then
            job_start_r   <= (others => '0');
            job_started_r <= '0';
            cur_addr_r    <= (others => '0');
         end if;
      end if;
   end process p_job_start;


   ----------------------------------------
   -- Prepare job for next column module
   ----------------------------------------

   p_job_cx : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if job_started_r = '1' then
            job_cx_r <= job_cx_r + job_stepx_r;
         end if;

         if start_i = '1' then
            job_cx_r     <= startx_i;
            job_stepx_r  <= stepx_i;
            job_starty_r <= starty_i;
            job_stepy_r  <= stepy_i;
         end if;
      end if;
   end process p_job_cx;


   -----------------------------------------------
   -- Delay the job by one clock cycle, in groups
   -----------------------------------------------

   -- The column module takes the value of cx when it sees the start of the
   -- job, so job_start_r is delayed too. The values of starty and stepy do not
   -- change during a picture. After a start (start_i), the first job is
   -- started (job_start_d) five clock cycles later, and by then the new values
   -- have reached the column modules.
   p_grp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         for g in 0 to C_NUM_GROUPS-1 loop
            grp_cx_r(g)     <= job_cx_r;
            grp_starty_r(g) <= job_starty_r;
            grp_stepy_r(g)  <= job_stepy_r;
         end loop;

         -- These need no reset, because job_start_r and job_started_r are
         -- reset, and the reset lasts more than one clock cycle.
         job_start_d    <= job_start_r;
         job_started_d  <= job_started_r;
         job_started_dd <= job_started_d;

         -- The column modules are reset two clock cycles after the rest of the
         -- dispatcher (they register the reset again).
         for g in 0 to C_NUM_GROUPS-1 loop
            grp_rst_r(g) <= rst_i;
         end loop;
      end if;
   end process p_grp;


   ------------------------------
   -- Instantiate column modules
   ------------------------------

   gen_column : for i in 0 to G_NUM_ITERATORS-1 generate
      i_column : entity work.column
         generic map (
            G_MAX_COUNT => G_MAX_COUNT,
            G_NUM_ROWS  => G_NUM_ROWS
         )
         port map (
            clk_i        => clk_i,
            rst_i        => grp_rst_r(i / G_GROUP_SIZE),
            job_start_i  => job_start_d(i),
            job_cx_i     => grp_cx_r(i / G_GROUP_SIZE),
            job_starty_i => grp_starty_r(i / G_GROUP_SIZE),
            job_stepy_i  => grp_stepy_r(i / G_GROUP_SIZE),
            job_busy_o   => job_busy_s(i),
            res_addr_o   => res_addr_s(i),
            res_data_o   => res_data_s(i),
            res_valid_o  => res_valid_s(i),
            res_ack_i    => res_ack_r(i)
         ); -- i_column
      end generate gen_column;


   -----------------------------------------
   -- Find one column module to acknowledge
   -----------------------------------------

   p_res_busy : process (clk_i)
   begin
      if rising_edge(clk_i) then
         res_busy_r <= not (res_valid_s and not res_ack_r);
      end if;
   end process p_res_busy;


   i_scheduler_res : entity work.scheduler
      generic map (
         G_SIZE => G_NUM_ITERATORS
      )
      port map (
         clk_i           => clk_i,
         rst_i           => rst_i,
         sched_active_i  => sched_active_r,
         job_idx_valid_o => idx_valid_r,
         job_idx_start_o => idx_iterator_r,
         job_busy_i      => res_busy_r
      ); -- i_scheduler_res


   ------------------------
   -- Generate output data
   ------------------------

   -- The result of the column module selected by i_scheduler_res is
   -- acknowledged and written in three steps:
   -- 1. The index of the column module goes to each group (grp_idx_r).
   -- 2. Each group acknowledges the selected column module, if it is in the
   --    group, and selects its result (grp_res_addr_r and grp_res_data_r).
   -- 3. The result is selected from the group of the column module.
   -- The column module keeps its result unchanged until it has seen the
   -- acknowledge, so the result is still there in step 2.

   p_res_grp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         for g in 0 to C_NUM_GROUPS-1 loop
            grp_idx_r(g)   <= idx_iterator_r;
            grp_valid_r(g) <= idx_valid_r;
         end loop;

         acc_job_addr_r <= job_addr_r(idx_iterator_r);
         acc_grp_r      <= idx_iterator_r / G_GROUP_SIZE;
         acc_valid_r    <= idx_valid_r;
      end if;
   end process p_res_grp;

   gen_ack : for i in 0 to G_NUM_ITERATORS-1 generate
      p_ack : process (clk_i)
      begin
         if rising_edge(clk_i) then
            res_ack_r(i) <= '0';
            if grp_valid_r(i / G_GROUP_SIZE) = '1' and
               grp_idx_r(i / G_GROUP_SIZE) = i
            then
               res_ack_r(i) <= '1';
            end if;
         end if;
      end process p_ack;
   end generate gen_ack;

   gen_grp_res : for g in 0 to C_NUM_GROUPS-1 generate
      p_grp_res : process (clk_i)
      begin
         if rising_edge(clk_i) then
            for i in g*G_GROUP_SIZE to minimum((g+1)*G_GROUP_SIZE, G_NUM_ITERATORS)-1 loop
               if grp_idx_r(g) = i then
                  grp_res_addr_r(g) <= res_addr_s(i);
                  grp_res_data_r(g) <= res_data_s(i);
               end if;
            end loop;
         end if;
      end process p_grp_res;
   end generate gen_grp_res;

   p_wr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         acc_job_addr_d <= acc_job_addr_r;
         acc_grp_d      <= acc_grp_r;
         acc_valid_d    <= acc_valid_r;

         wr_addr_r <= acc_job_addr_d & grp_res_addr_r(acc_grp_d);
         wr_data_r <= grp_res_data_r(acc_grp_d);
         wr_en_r   <= acc_valid_d;
      end if;
   end process p_wr;


   -- The busy flags of all the column modules are combined in two steps, to
   -- keep the paths short: first in each group (grp_job_busy_r), and then in
   -- p_done.
   gen_grp_job_busy : for g in 0 to C_NUM_GROUPS-1 generate
      p_grp_job_busy : process (clk_i)
      begin
         if rising_edge(clk_i) then
            grp_job_busy_r(g) <= '0';
            for i in g*G_GROUP_SIZE to minimum((g+1)*G_GROUP_SIZE, G_NUM_ITERATORS)-1 loop
               if job_busy_s(i) = '1' then
                  grp_job_busy_r(g) <= '1';
               end if;
            end loop;
         end if;
      end process p_grp_job_busy;
   end generate gen_grp_job_busy;

   -- The signal done_r stays high until the next start. It is cleared by the
   -- start, because otherwise the old value of done_r would stop the scheduler
   -- (see p_sched_active) just after the start. It is not set while a job has
   -- just been started (job_started_r, job_started_d or job_started_dd),
   -- because then the busy flag of the column module has not reached
   -- grp_job_busy_r yet.
   p_done : process (clk_i)
   begin
      if rising_edge(clk_i) then
         done_r <= '0';
         if cur_addr_r = G_NUM_COLS and grp_job_busy_r = 0 and
            job_started_r = '0' and job_started_d = '0' and
            job_started_dd = '0' and start_i = '0'
         then
            done_r <= '1';
         end if;
      end if;
   end process p_done;


   --------------------------
   -- Connect output signals
   --------------------------

   wr_addr_o      <= wr_addr_r;
   wr_data_o      <= wr_data_r;
   wr_en_o        <= wr_en_r;

   done_o         <= done_r;

end architecture rtl;

