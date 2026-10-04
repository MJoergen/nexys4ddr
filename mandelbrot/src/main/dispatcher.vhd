-- This module instantiates a number of column modules, dispatches jobs to them,
-- and collects results from them.
--
-- The picture is divided into blocks of G_JOB_ROWS rows, and each job is one
-- picture column of a block. The jobs are given out one block at a time:
-- First all the picture columns of the top block, then all the picture columns
-- of the next block, and so on. Smaller jobs make the work more evenly shared
-- between the column modules at the end of the picture, when the expensive
-- jobs would otherwise keep a few column modules busy long after the others
-- have finished.
--
-- Each write to the display memory is G_PIXELS pixels: consecutive rows of a
-- picture column, starting at the row given by wr_addr_o, with the first row in
-- the lowest 9 bits of wr_data_o (see column.vhd). Writing more than one pixel
-- at a time lets the dispatcher write more than one pixel per clock cycle.
--
-- The address of the pixel in column x and row y of the picture is
-- x*G_COL_STRIDE + y, with G_ADDR_BITS bits. When G_COL_STRIDE is a power of
-- two, this is the column followed by the row, e.g. 512 for 640x480 (19 bits)
-- and 1024 for 1280x1024 (21 bits). Otherwise G_COL_STRIDE can be the number
-- of rows, so that the picture takes fewer addresses.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity dispatcher is
   generic (
      G_MAX_COUNT     : integer;
      G_NUM_ROWS      : integer;
      G_NUM_COLS      : integer;
      G_COL_STRIDE    : integer;         -- Address distance between columns
      G_ADDR_BITS     : integer := 19;   -- Bits of the address
      G_JOB_ROWS      : integer;         -- Rows in each job
      G_NUM_ITERATORS : integer;
      G_GROUP_SIZE    : integer := 16;
      G_PIXELS        : integer := 1     -- Pixels in each write
   );
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;
      start_i         : in  std_logic;
      startx_i        : in  std_logic_vector(17 downto 0);
      starty_i        : in  std_logic_vector(17 downto 0);
      stepx_i         : in  std_logic_vector(17 downto 0);
      stepy_i         : in  std_logic_vector(17 downto 0);
      wr_addr_o       : out std_logic_vector(G_ADDR_BITS-1 downto 0);
      wr_data_o       : out std_logic_vector(9*G_PIXELS-1 downto 0);
      wr_en_o         : out std_logic;
      done_o          : out std_logic
   );
end entity dispatcher;

architecture rtl of dispatcher is

   -- The number of bits needed for the values 0 to n-1
   function log2 (n : integer) return integer is
      variable r : integer := 0;
   begin
      while 2**r < n loop
         r := r + 1;
      end loop;
      return r;
   end function log2;

   -- The number of bits of the column (at least one, also for a single
   -- column) and of the row in the picture
   constant C_COL_BITS   : integer := maximum(1, log2(G_NUM_COLS));
   constant C_ROW_BITS   : integer := log2(G_NUM_ROWS);

   -- The job (cx, starty, and stepy), the reset, and the index of the column
   -- module whose result is accepted all go to all the column modules. To make
   -- the routing shorter, they go through an extra register in each group of
   -- G_GROUP_SIZE column modules. The registers in each group are identical,
   -- so the attribute keep prevents the synthesis tool from merging them.
   constant C_NUM_GROUPS : integer := (G_NUM_ITERATORS + G_GROUP_SIZE - 1) / G_GROUP_SIZE;

   -- The number of blocks of rows
   constant C_NUM_BLOCKS : integer := G_NUM_ROWS / G_JOB_ROWS;

   type job_addr_vector is array (natural range <>) of
      std_logic_vector(C_COL_BITS-1 downto 0);
   type res_addr_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);
   type res_data_vector is array (natural range <>) of
      std_logic_vector(9*G_PIXELS-1 downto 0);
   type value_vector is array (natural range <>) of
      std_logic_vector(17 downto 0);
   type idx_vector is array (natural range <>) of
      integer range 0 to G_NUM_ITERATORS-1;
   type blk_vector is array (natural range <>) of
      integer range 0 to C_NUM_BLOCKS-1;

   signal sched_active_r    : std_logic;
   --
   -- The job: cx of the picture column, and cy of the first row of the block
   signal job_cx_r          : std_logic_vector(17 downto 0);
   signal job_starty_r      : std_logic_vector(17 downto 0);
   signal job_startx_r      : std_logic_vector(17 downto 0);
   signal job_stepx_r       : std_logic_vector(17 downto 0);
   signal job_stepy_r       : std_logic_vector(17 downto 0);
   -- The difference in cy between two blocks
   signal job_blk_stepy_r   : std_logic_vector(17 downto 0);
   --
   signal job_start_r       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal job_started_r     : std_logic;
   -- High together with job_started_r, when the job is the last picture
   -- column of a block
   signal job_wrap_r        : std_logic;
   -- The picture column and the block of the job of each column module
   signal job_addr_r        : job_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal job_blk_r         : blk_vector(      G_NUM_ITERATORS-1 downto 0);
   -- The picture column and the block of the next job. All the jobs have
   -- been given out when cur_blk_r is C_NUM_BLOCKS.
   signal cur_addr_r        : std_logic_vector(C_COL_BITS-1 downto 0) := (others => '0');
   signal cur_blk_r         : integer range 0 to C_NUM_BLOCKS := 0;
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

   -- The multiplication by the constant G_JOB_ROWS uses LUTs, because all
   -- the DSPs are used by the iterators.
   attribute use_dsp : string;
   attribute use_dsp of job_blk_stepy_r : signal is "no";

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
   signal res_ready_s       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);

   signal wr_addr_r         : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal wr_data_r         : std_logic_vector(9*G_PIXELS-1 downto 0);
   signal wr_en_r           : std_logic;

   -- The accepted result, delayed by one, two and three clock cycles: The
   -- picture column and the block of the job, the first row of the block, and
   -- then the address of the column and the row of the result.
   signal acc_job_addr_r    : std_logic_vector(C_COL_BITS-1 downto 0);
   signal acc_job_addr_d    : std_logic_vector(C_COL_BITS-1 downto 0);
   signal acc_blk_r         : integer range 0 to C_NUM_BLOCKS-1;
   signal acc_col_dd        : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal acc_row_d         : std_logic_vector(C_ROW_BITS-1 downto 0);
   signal acc_row_dd        : std_logic_vector(C_ROW_BITS-1 downto 0);
   signal acc_data_dd       : std_logic_vector(9*G_PIXELS-1 downto 0);
   signal acc_grp_r         : integer range 0 to C_NUM_GROUPS-1;
   signal acc_grp_d         : integer range 0 to C_NUM_GROUPS-1;
   signal acc_valid_r       : std_logic;
   signal acc_valid_d       : std_logic;
   signal acc_valid_dd      : std_logic;

   -- The multiplication by the constant G_COL_STRIDE uses LUTs, like the one
   -- by G_JOB_ROWS.
   attribute use_dsp of acc_col_dd : signal is "no";

   signal done_r            : std_logic;

   signal idx_start_r       : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_start_valid_r : std_logic;

   signal idx_iterator_r    : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_valid_r       : std_logic;

begin

   -- When the scheduler samples the busy flag of a column module and selects
   -- it, the new busy flag of that column module (job_busy_s) is sampled by
   -- the scheduler five clock cycles later at the earliest (the selection goes
   -- through the scheduler, job_start_r and job_start_d). The scheduler
   -- samples the busy flag of the same column module again G_NUM_ITERATORS
   -- clock cycles later. With fewer than five column modules a job could
   -- therefore be started twice (and the first one would be lost).
   assert G_NUM_ITERATORS >= 5
      report "The dispatcher needs at least five column modules"
      severity failure;

   assert G_NUM_ROWS mod G_JOB_ROWS = 0
      report "The number of rows must be a multiple of the rows in a job"
      severity failure;

   -- The write address must be a multiple of G_PIXELS, see disp_mem.vhd
   assert G_COL_STRIDE >= G_NUM_ROWS and
          G_COL_STRIDE mod G_PIXELS = 0 and
          (G_NUM_COLS-1)*G_COL_STRIDE + G_NUM_ROWS <= 2**G_ADDR_BITS
      report "The picture does not fit in the display memory"
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
         job_wrap_r    <= '0';

         if idx_start_valid_r = '1' and
            cur_blk_r < C_NUM_BLOCKS
         then
            job_start_r(idx_start_r) <= '1';
            job_started_r            <= '1';
            job_addr_r(idx_start_r)  <= cur_addr_r;
            job_blk_r(idx_start_r)   <= cur_blk_r;
            cur_addr_r               <= cur_addr_r + 1;
            if cur_addr_r = G_NUM_COLS-1 then
               job_wrap_r <= '1';
               cur_addr_r <= (others => '0');
               cur_blk_r  <= cur_blk_r + 1;
            end if;
         end if;

         if start_i = '1' then
            cur_addr_r <= (others => '0');
            cur_blk_r  <= 0;
         end if;

         if rst_i = '1' then
            job_start_r   <= (others => '0');
            job_started_r <= '0';
            job_wrap_r    <= '0';
            cur_addr_r    <= (others => '0');
            cur_blk_r     <= 0;
         end if;
      end if;
   end process p_job_start;


   ----------------------------------------
   -- Prepare job for next column module
   ----------------------------------------

   -- After the last picture column of a block, cx starts again from the left
   -- edge, and cy moves to the next block. The column modules add stepy in 18
   -- bits, so adding G_JOB_ROWS times stepy (also in 18 bits) gives exactly the
   -- same values of cy as if all the rows were calculated in one job. The value
   -- of job_blk_stepy_r is ready two clock cycles after a start (start_i), and
   -- it is not used until the first job has been started, which is at least
   -- five clock cycles after the start.
   p_job_cx : process (clk_i)
      variable blk_stepy_v : std_logic_vector(35 downto 0);
   begin
      if rising_edge(clk_i) then
         blk_stepy_v     := job_stepy_r * to_slv(G_JOB_ROWS, 18);
         job_blk_stepy_r <= blk_stepy_v(17 downto 0);

         if job_started_r = '1' then
            job_cx_r <= job_cx_r + job_stepx_r;
            if job_wrap_r = '1' then
               job_cx_r     <= job_startx_r;
               job_starty_r <= job_starty_r + job_blk_stepy_r;
            end if;
         end if;

         if start_i = '1' then
            job_cx_r     <= startx_i;
            job_startx_r <= startx_i;
            job_stepx_r  <= stepx_i;
            job_starty_r <= starty_i;
            job_stepy_r  <= stepy_i;
         end if;
      end if;
   end process p_job_cx;


   -----------------------------------------------
   -- Delay the job by one clock cycle, in groups
   -----------------------------------------------

   -- The column module takes the values of cx and starty when it sees the
   -- start of the job, so job_start_r is delayed too. The value of stepy does
   -- not change during a picture. After a start (start_i), the first job is
   -- started (job_start_d) five clock cycles later, and by then the new value
   -- has reached the column modules.
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
            G_NUM_ROWS  => G_JOB_ROWS,
            G_PIXELS    => G_PIXELS
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


   -- A column module has a result ready when it is valid and has not been
   -- acknowledged. When i_res_scheduler selects a column module in clock cycle
   -- c, the acknowledge (res_ack_r) is high in clock cycle c+2, and
   -- res_busy_r is high from clock cycle c+3, until the next result. So the
   -- ready flag is low from clock cycle c+2, as i_res_scheduler requires.
   res_ready_s <= not res_busy_r and not res_ack_r;

   i_res_scheduler : entity work.res_scheduler
      generic map (
         G_SIZE       => G_NUM_ITERATORS,
         G_GROUP_SIZE => G_GROUP_SIZE
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         active_i    => sched_active_r,
         ready_i     => res_ready_s,
         idx_valid_o => idx_valid_r,
         idx_o       => idx_iterator_r
      ); -- i_res_scheduler


   ------------------------
   -- Generate output data
   ------------------------

   -- The result of the column module selected by i_res_scheduler is
   -- acknowledged and written in four steps:
   -- 1. The index of the column module goes to each group (grp_idx_r).
   -- 2. Each group acknowledges the selected column module, if it is in the
   --    group, and selects its result (grp_res_addr_r and grp_res_data_r).
   -- 3. The result is selected from the group of the column module, and its
   --    row in the picture and the address of its column are calculated.
   -- 4. The address is calculated from the column and the row.
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
         acc_blk_r      <= job_blk_r(idx_iterator_r);
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
      variable col_v : std_logic_vector(C_COL_BITS+G_ADDR_BITS-1 downto 0);
   begin
      if rising_edge(clk_i) then
         -- Step 2
         acc_job_addr_d <= acc_job_addr_r;
         acc_row_d      <= to_slv(acc_blk_r * G_JOB_ROWS, C_ROW_BITS);
         acc_grp_d      <= acc_grp_r;
         acc_valid_d    <= acc_valid_r;

         -- Step 3. The column module gives the row within the block. The
         -- multiplication is not in step 2, because acc_job_addr_r is read
         -- from a table, which may be a BRAM (job_addr_r). When G_COL_STRIDE
         -- is a power of two, the multiplication is only wires.
         col_v        := acc_job_addr_d * to_slv(G_COL_STRIDE, G_ADDR_BITS);
         acc_col_dd   <= col_v(G_ADDR_BITS-1 downto 0);
         acc_row_dd   <= acc_row_d + resize(grp_res_addr_r(acc_grp_d), C_ROW_BITS);
         acc_data_dd  <= grp_res_data_r(acc_grp_d);
         acc_valid_dd <= acc_valid_d;

         -- Step 4. When G_COL_STRIDE is 2**C_ROW_BITS, this is the column
         -- followed by the row, i.e. only wires.
         wr_addr_r <= acc_col_dd + acc_row_dd;
         wr_data_r <= acc_data_dd;
         wr_en_r   <= acc_valid_dd;
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
         if cur_blk_r = C_NUM_BLOCKS and grp_job_busy_r = 0 and
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

