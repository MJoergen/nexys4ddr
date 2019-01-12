library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module instantiates a number of iterators, dispatches jobs to them, and
-- collects results from them.

entity dispatcher is
   generic (
      G_MAX_COUNT     : integer;
      G_NUM_ROWS      : integer;
      G_NUM_COLS      : integer;
      G_NUM_ITERATORS : integer
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
      done_o          : out std_logic;
      wait_cnt_tot_o  : out std_logic_vector(15 downto 0)
   );
end entity dispatcher;

architecture rtl of dispatcher is

   type job_addr_vector is array (natural range <>) of
      std_logic_vector(9 downto 0);
   type res_addr_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);
   type res_data_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);
   type wait_cnt_vector is array (natural range <>) of
      std_logic_vector(15 downto 0);

   signal sched_active_r    : std_logic;
   --
   signal job_cx_r          : std_logic_vector(17 downto 0);
   signal job_stepx_r       : std_logic_vector(17 downto 0);
   signal job_starty_r      : std_logic_vector(17 downto 0);
   signal job_stepy_r       : std_logic_vector(17 downto 0);
   --
   signal job_start_r       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal job_addr_r        : job_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal cur_addr_r        : std_logic_vector(9 downto 0);
   --
   signal job_busy_s        : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_addr_s        : res_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal res_data_s        : res_data_vector( G_NUM_ITERATORS-1 downto 0);
   signal res_valid_s       : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_ack_r         : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_busy_r        : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal wait_cnt_s        : wait_cnt_vector( G_NUM_ITERATORS-1 downto 0);
   signal wait_cnt_d        : wait_cnt_vector( G_NUM_ITERATORS-1 downto 0);

   signal wr_addr_r         : std_logic_vector(18 downto 0);
   signal wr_data_r         : std_logic_vector( 8 downto 0);
   signal wr_en_r           : std_logic;

   signal wr_addr_d         : std_logic_vector(18 downto 0);
   signal wr_data_d         : std_logic_vector( 8 downto 0);
   signal wr_en_d           : std_logic;

   signal done_r            : std_logic;

   signal idx_start_r       : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_start_valid_r : std_logic;

   signal idx_iterator_r    : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_valid_r       : std_logic;

   signal wait_cnt_tot_r    : wait_cnt_vector(G_NUM_ITERATORS-1 downto 0);

begin

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


   ---------------------------
   -- Start any idle iterator
   ---------------------------

   p_job_start : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Only pulse for one clock cycle.
         job_start_r <= (others => '0');
         
         if idx_start_valid_r = '1' and
            cur_addr_r < G_NUM_COLS
         then
            job_start_r(idx_start_r) <= '1';
            job_addr_r(idx_start_r)  <= cur_addr_r;
            cur_addr_r               <= cur_addr_r + 1;
         end if;

         if start_i = '1' then
            cur_addr_r <= (others => '0');
         end if;

         if rst_i = '1' then
            job_start_r <= (others => '0');
            cur_addr_r  <= (others => '0');
         end if;
      end if;
   end process p_job_start;


   ---------------------------------
   -- Prepare job for next iterator
   ---------------------------------

   p_job_cx : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if job_start_r /= 0 then
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


   -------------------------
   -- Instantiate iterators
   -------------------------

   gen_column : for i in 0 to G_NUM_ITERATORS-1 generate
      i_column : entity work.column
         generic map (
            G_MAX_COUNT => G_MAX_COUNT,
            G_NUM_ROWS  => G_NUM_ROWS
         )
         port map (
            clk_i        => clk_i,
            rst_i        => rst_i,
            job_start_i  => job_start_r(i),
            job_cx_i     => job_cx_r,
            job_starty_i => job_starty_r,
            job_stepy_i  => job_stepy_r,
            job_busy_o   => job_busy_s(i),
            res_addr_o   => res_addr_s(i),
            res_data_o   => res_data_s(i),
            res_valid_o  => res_valid_s(i),
            res_ack_i    => res_ack_r(i),
            wait_cnt_O   => wait_cnt_s(i)
         ); -- i_column
      end generate gen_column;


   ------------------------------------
   -- Find one iterator to acknowledge
   ------------------------------------

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

   p_wr : process (clk_i)
   begin
      if rising_edge(clk_i) then

         res_ack_r <= (others => '0');

         if idx_valid_r = '1' then
            res_ack_r(idx_iterator_r) <= '1';
         end if;

         wr_addr_r <= job_addr_r(idx_iterator_r) & res_addr_s(idx_iterator_r);
         wr_data_r <= res_data_s(idx_iterator_r);
         wr_en_r   <= idx_valid_r;
      end if;
   end process p_wr;


   p_done : process (clk_i)
   begin
      if rising_edge(clk_i) then
         done_r <= '0';
         if cur_addr_r = G_NUM_COLS and job_busy_s = 0 then
            done_r <= '1';
         end if;
      end if;
   end process p_done;


   --------------------------------
   -- Add together all wait counts
   --------------------------------

   wait_cnt_tot_r(0) <= wait_cnt_s(0);
   g_wait_cnt_tot : for i in 1 to G_NUM_ITERATORS-1 generate
      p_g_wait_cnt_tot : process (clk_i)
      begin
         if rising_edge(clk_i) then
            wait_cnt_tot_r(i) <= wait_cnt_tot_r(i-1) + wait_cnt_s(i);

            if rst_i = '1' then
               wait_cnt_tot_r(i) <= (others => '0');
            end if;
         end if;
      end process p_g_wait_cnt_tot;
   end generate g_wait_cnt_tot;


   ----------------------------
   -- Pipeline output signals.
   ----------------------------

   p_pipe : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wr_addr_d <= wr_addr_r;
         wr_data_d <= wr_data_r;
         wr_en_d   <= wr_en_r;
      end if;
   end process p_pipe;


   --------------------------
   -- Connect output signals
   --------------------------

   wr_addr_o      <= wr_addr_d;
   wr_data_o      <= wr_data_d;
   wr_en_o        <= wr_en_d;

   done_o         <= done_r;
   wait_cnt_tot_o <= wait_cnt_tot_r(G_NUM_ITERATORS-1);

end architecture rtl;

