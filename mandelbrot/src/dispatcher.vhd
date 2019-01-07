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
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      start_i   : in  std_logic;
      startx_i  : in  std_logic_vector(17 downto 0);
      starty_i  : in  std_logic_vector(17 downto 0);
      stepx_i   : in  std_logic_vector(17 downto 0);
      stepy_i   : in  std_logic_vector(17 downto 0);
      wr_addr_o : out std_logic_vector(18 downto 0);
      wr_data_o : out std_logic_vector( 8 downto 0);
      wr_en_o   : out std_logic;
      done_o    : out std_logic
   );
end entity dispatcher;

architecture rtl of dispatcher is

   type job_addr_vector is array (natural range <>) of
      std_logic_vector(9 downto 0);
   type res_addr_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);
   type res_data_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);

   signal job_cx_r       : std_logic_vector(17 downto 0);
   signal job_stepx_r    : std_logic_vector(17 downto 0);
   signal job_starty_r   : std_logic_vector(17 downto 0);
   signal job_stepy_r    : std_logic_vector(17 downto 0);
   --
   signal job_start_d    : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal job_start_r    : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal job_addr_r     : job_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal cur_addr_r     : std_logic_vector(9 downto 0);
   --
   signal job_active_r   : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   --
   signal job_done_s     : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_addr_s     : res_addr_vector( G_NUM_ITERATORS-1 downto 0);
   signal res_data_s     : res_data_vector( G_NUM_ITERATORS-1 downto 0);
   signal res_valid_s    : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_ack_r      : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal res_vector_s   : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal job_vector_s   : std_logic_vector(G_NUM_ITERATORS-1 downto 0);

   signal wr_addr_r      : std_logic_vector(18 downto 0);
   signal wr_data_r      : std_logic_vector( 8 downto 0);
   signal wr_en_r        : std_logic;

   signal done_r         : std_logic;

   signal idx_start_r       : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_start_valid_r : std_logic;

   signal idx_iterator_r : integer range 0 to G_NUM_ITERATORS-1;
   signal idx_valid_r    : std_logic;

begin

   ---------------------------------
   -- Prepare job for next iterator
   ---------------------------------

   p_job_cx : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if rst_i = '0' then
            -- The following clever assert checks that at most one bit is set in
            -- the job_start_r signal.
            assert ((job_start_r-1) and job_start_r) = 0
               report "job_start_r has more than 1 bit set" severity error;
         end if;

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


   ---------------------------
   -- Start any idle iterator
   ---------------------------

   -- List of iterators not active, and not yet started.
   job_vector_s <= not job_active_r and not job_start_r;

   -- There is a two-cycle delay in this calculation.
   i_priority_job : entity work.priority_pipeline
      generic map (
         G_SIZE      => G_NUM_ITERATORS
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         vector_i  => job_vector_s,
         index_o   => idx_start_r,
         active_o  => idx_start_valid_r
      ); -- i_priority


   ---------------------------
   -- Start any idle iterator
   ---------------------------

   p_job_start : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Delay one cycle
         job_start_d <= job_start_r;

         -- Only pulse for one clock cycle.
         job_start_r <= (others => '0');
         
         if idx_start_valid_r = '1' and
            job_start_r(idx_start_r) = '0' and
            job_start_d(idx_start_r) = '0' and
            cur_addr_r < G_NUM_COLS
         then
            job_start_r(idx_start_r) <= '1';
            job_addr_r(idx_start_r)  <= cur_addr_r;
            cur_addr_r               <= cur_addr_r + 1;
         end if;

         if start_i = '1' then
            assert job_active_r = 0
               report "Start received when not ready"
                  severity error;
            cur_addr_r <= (others => '0');
         end if;

         if rst_i = '1' then
            job_start_r <= (others => '0');
            cur_addr_r  <= to_std_logic_vector(G_NUM_COLS, 10);
         end if;
      end if;
   end process p_job_start;


   ---------------------------------
   -- Monitor activity of iterators
   ---------------------------------

   p_job_active : process (clk_i)
   begin
      if rising_edge(clk_i) then
         job_active_r <= (job_active_r and not job_done_s) or job_start_r;

         if rst_i = '1' then
            job_active_r <= (others => '0');
         end if;
      end if;
   end process p_job_active;


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
            job_done_o   => job_done_s(i),
            res_addr_o   => res_addr_s(i),
            res_data_o   => res_data_s(i),
            res_valid_o  => res_valid_s(i),
            res_ack_i    => res_ack_r(i)
         ); -- i_column
      end generate gen_column;


   ------------------------------------
   -- Find one iterator to acknowledge
   ------------------------------------

   res_vector_s <= res_valid_s and not res_ack_r;

   i_priority : entity work.priority_pipeline
      generic map (
         G_SIZE      => G_NUM_ITERATORS
      )
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         vector_i  => res_vector_s,
         index_o   => idx_iterator_r,
         active_o  => idx_valid_r
      ); -- i_priority


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
         if cur_addr_r = G_NUM_COLS and job_active_r = 0 then
            done_r <= '1';
         end if;
      end if;
   end process p_done;


   --------------------------
   -- Connect output signals
   --------------------------

   done_o <= done_r;

   wr_addr_o <= wr_addr_r;
   wr_data_o <= wr_data_r;
   wr_en_o   <= wr_en_r;

end architecture rtl;

