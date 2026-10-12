-- This module is the part of the dispatcher (see dispatcher.vhd) that
-- collects the results from the job modules and writes them to the display
-- memory.
--
-- It keeps a table of the picture column and the block of the job of each job
-- module, written by dispatcher_jobs.vhd (tbl_*_i) when the job is started.
-- When a result is accepted, the address of the result is calculated from the
-- table and the row of the result within the job (res_addr_i).
--
-- The results of the job modules are in res_data_i, 9*G_PIXELS bits for each
-- job module, with job module 0 in the lowest bits.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.dispatcher_pkg.all;

entity dispatcher_results is
   generic (
      G_NUM_ROWS      : positive;
      G_NUM_COLS      : positive;
      G_COL_STRIDE    : positive;         -- Address distance between columns
      G_ADDR_BITS     : positive;         -- Bits of the address
      G_ROWS_IN_JOB   : positive;         -- Rows in each job
      G_NUM_ITERATORS : positive;
      G_GROUP_SIZE    : positive;
      G_PIXELS        : positive          -- Pixels in each write
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      -- High while the picture is being calculated
      sched_active_i : in  std_logic;

      -- From dispatcher_jobs: The index of the job module, the picture
      -- column, and the block of each job, when tbl_valid_i is high
      tbl_valid_i    : in  std_logic;
      tbl_idx_i      : in  natural range 0 to G_NUM_ITERATORS-1;
      tbl_col_i      : in  std_logic_vector(maximum(1, log2(G_NUM_COLS))-1 downto 0);
      tbl_blk_i      : in  natural range 0 to G_NUM_ROWS/G_ROWS_IN_JOB-1;

      -- From and to the job modules
      res_addr_i     : in  res_addr_vector(G_NUM_ITERATORS-1 downto 0);
      res_data_i     : in  std_logic_vector(G_NUM_ITERATORS*9*G_PIXELS-1 downto 0);
      res_valid_i    : in  std_logic_vector(G_NUM_ITERATORS-1 downto 0);
      res_ack_o      : out std_logic_vector(G_NUM_ITERATORS-1 downto 0);

      -- To the display memory
      wr_addr_o      : out std_logic_vector(G_ADDR_BITS-1 downto 0);
      wr_data_o      : out std_logic_vector(9*G_PIXELS-1 downto 0);
      wr_en_o        : out std_logic
   );
end entity dispatcher_results;

architecture rtl of dispatcher_results is

   -- The number of bits of the column (at least one, also for a single
   -- column) and of the row in the picture
   constant C_COL_BITS   : natural := maximum(1, log2(G_NUM_COLS));
   constant C_ROW_BITS   : natural := log2(G_NUM_ROWS);

   -- The index of the job module whose result is accepted goes to all the
   -- job modules. To make the routing shorter, it goes through an extra
   -- register in each group of G_GROUP_SIZE job modules. The registers in
   -- each group are identical, so the attribute keep prevents the synthesis
   -- tool from merging them.
   constant C_NUM_GROUPS : natural := (G_NUM_ITERATORS + G_GROUP_SIZE - 1) / G_GROUP_SIZE;

   -- The number of blocks of rows
   constant C_NUM_BLOCKS : natural := G_NUM_ROWS / G_ROWS_IN_JOB;

   type job_addr_vector is array (natural range <>) of
      std_logic_vector(C_COL_BITS-1 downto 0);
   type res_data_vector is array (natural range <>) of
      std_logic_vector(9*G_PIXELS-1 downto 0);
   type idx_vector is array (natural range <>) of
      natural range 0 to G_NUM_ITERATORS-1;
   type blk_vector is array (natural range <>) of
      natural range 0 to C_NUM_BLOCKS-1;

   -- The picture column and the block of the job of each job module
   signal job_addr_r        : job_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal job_blk_r         : blk_vector(      G_NUM_ITERATORS-1 downto 0);

   -- The index of the job module whose result is accepted, delayed by one
   -- clock cycle, in each group of job modules, and the result of the
   -- selected job module in each group.
   signal grp_idx_r         : idx_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_valid_r       : std_logic_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_res_addr_r    : res_addr_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_res_data_r    : res_data_vector(C_NUM_GROUPS-1 downto 0);

   attribute keep : string;
   attribute keep of grp_idx_r   : signal is "true";
   attribute keep of grp_valid_r : signal is "true";
   --
   signal res_ack_r         : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_busy_r        : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_ready_s       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);

   signal wr_addr_r         : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal wr_data_r         : std_logic_vector(9*G_PIXELS-1 downto 0);
   signal wr_en_r           : std_logic;

   -- The accepted result, delayed by one, two, and three clock cycles: The
   -- picture column and the block of the job, the first row of the block, and
   -- then the address of the column and the row of the result.
   signal acc_job_addr_r    : std_logic_vector(C_COL_BITS-1 downto 0);
   signal acc_job_addr_d    : std_logic_vector(C_COL_BITS-1 downto 0);
   signal acc_blk_r         : natural range 0 to C_NUM_BLOCKS-1;
   signal acc_col_dd        : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal acc_row_d         : std_logic_vector(C_ROW_BITS-1 downto 0);
   signal acc_row_dd        : std_logic_vector(C_ROW_BITS-1 downto 0);
   signal acc_data_dd       : std_logic_vector(9*G_PIXELS-1 downto 0);
   signal acc_grp_r         : natural range 0 to C_NUM_GROUPS-1;
   signal acc_grp_d         : natural range 0 to C_NUM_GROUPS-1;
   signal acc_valid_r       : std_logic;
   signal acc_valid_d       : std_logic;
   signal acc_valid_dd      : std_logic;

   -- The multiplication by the constant G_COL_STRIDE uses LUTs, because all
   -- the DSPs are used by the iterators.
   attribute use_dsp : string;
   attribute use_dsp of acc_col_dd : signal is "no";

   signal idx_iterator_r    : natural range 0 to G_NUM_ITERATORS-1;
   signal idx_valid_r       : std_logic;

begin

   -- The write address must be a multiple of G_PIXELS, see disp_mem.vhd
   assert G_COL_STRIDE >= G_NUM_ROWS and
          G_COL_STRIDE mod G_PIXELS = 0 and
          (G_NUM_COLS-1)*G_COL_STRIDE + G_NUM_ROWS <= 2**G_ADDR_BITS
      report "The picture does not fit in the display memory"
      severity failure;


   ----------------------------------------------
   -- Remember the job of each job module
   ----------------------------------------------

   -- The table is written one clock cycle after the job is started
   -- (job_start_r in dispatcher_jobs), long before the job module has a
   -- result.
   p_tbl : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if tbl_valid_i = '1' then
            job_addr_r(tbl_idx_i) <= tbl_col_i;
            job_blk_r(tbl_idx_i)  <= tbl_blk_i;
         end if;
      end if;
   end process p_tbl;


   -----------------------------------------
   -- Find one job module to acknowledge
   -----------------------------------------

   p_res_busy : process (clk_i)
   begin
      if rising_edge(clk_i) then
         res_busy_r <= not (res_valid_i and not res_ack_r);
      end if;
   end process p_res_busy;


   -- A job module has a result ready when it is valid and has not been
   -- acknowledged. When i_res_scheduler selects a job module in clock cycle
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
         active_i    => sched_active_i,
         ready_i     => res_ready_s,
         idx_valid_o => idx_valid_r,
         idx_o       => idx_iterator_r
      ); -- i_res_scheduler


   ------------------------
   -- Generate output data
   ------------------------

   -- The result of the job module selected by i_res_scheduler is
   -- acknowledged and written in four steps:
   -- 1. The index of the job module goes to each group (grp_idx_r).
   -- 2. Each group acknowledges the selected job module, if it is in the
   --    group, and selects its result (grp_res_addr_r and grp_res_data_r).
   -- 3. The result is selected from the group of the job module, and its
   --    row in the picture and the address of its column are calculated.
   -- 4. The address is calculated from the column and the row.
   -- The job module keeps its result unchanged until it has seen the
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
                  grp_res_addr_r(g) <= res_addr_i(i);
                  grp_res_data_r(g) <= res_data_i((i+1)*9*G_PIXELS-1 downto i*9*G_PIXELS);
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
         acc_row_d      <= to_slv(acc_blk_r * G_ROWS_IN_JOB, C_ROW_BITS);
         acc_grp_d      <= acc_grp_r;
         acc_valid_d    <= acc_valid_r;

         -- Step 3. The job module gives the row within the block. The
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


   --------------------------
   -- Connect output signals
   --------------------------

   res_ack_o <= res_ack_r;

   wr_addr_o <= wr_addr_r;
   wr_data_o <= wr_data_r;
   wr_en_o   <= wr_en_r;

end architecture rtl;
