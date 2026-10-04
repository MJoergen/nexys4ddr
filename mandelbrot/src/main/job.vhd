library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a job module. It calculates (sequentially) G_NUM_ROWS rows of a
-- picture column, using one iterator.
--
-- Each result is the counts of G_PIXELS consecutive rows (a word of the
-- display memory), with the count of the first row in the lowest 9 bits. The
-- job module keeps the counts of the first G_PIXELS-1 rows of a result, and
-- continues with the next row at once, so it only waits for the acknowledge
-- after the last row of the result. The row number given with each result
-- (res_addr_o) is that of the first row of the result, counted from the first
-- row of the job. G_PIXELS must be a power of two, and G_NUM_ROWS a multiple of
-- G_PIXELS.

entity job is
   generic (
      G_MAX_COUNT : integer;
      G_NUM_ROWS  : integer;
      G_PIXELS    : integer := 1   -- Rows in each result
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;
      job_start_i  : in  std_logic;
      job_cx_i     : in  std_logic_vector(17 downto 0);
      job_starty_i : in  std_logic_vector(17 downto 0);
      job_stepy_i  : in  std_logic_vector(17 downto 0);
      job_busy_o   : out std_logic;
      res_addr_o   : out std_logic_vector( 8 downto 0);
      res_ack_i    : in  std_logic;
      res_data_o   : out std_logic_vector(9*G_PIXELS-1 downto 0);
      res_valid_o  : out std_logic
   );
end entity job;

architecture rtl of job is

   -- The number of bits needed for the values 0 to n-1
   function log2 (n : integer) return integer is
      variable r : integer := 0;
   begin
      while 2**r < n loop
         r := r + 1;
      end loop;
      return r;
   end function log2;

   -- The number of bits of the row number
   constant C_ADDR_BITS : integer := maximum(log2(G_NUM_ROWS), 1);

   -- The reset, registered locally, so the reset from the dispatcher only goes
   -- to this register.
   signal rst_r        : std_logic;

   signal res_start_r  : std_logic;
   signal res_cx_r     : std_logic_vector(17 downto 0);
   signal res_cy_r     : std_logic_vector(17 downto 0);
   signal res_data_s   : std_logic_vector( 8 downto 0);
   signal res_valid_s  : std_logic;
   signal res_addr_r   : std_logic_vector(C_ADDR_BITS-1 downto 0);
   -- High when res_addr_r is the last row. It is a register, so the check
   -- for the last row is not in the paths to res_addr_r and res_cy_r.
   signal res_last_r   : std_logic;
   -- High when res_addr_r is not the last row of a result, so its count is
   -- kept in the job module. Also a register, like res_last_r.
   signal res_hold_r   : std_logic;
   -- High when the count of the row is kept, and the next row is started
   signal res_keep_s   : std_logic;
   -- The counts of the first G_PIXELS-1 rows of the result
   signal res_word_r   : std_logic_vector(9*G_PIXELS-10 downto 0);

   signal job_busy_r   : std_logic;

   signal res_addr_d   : std_logic_vector(C_ADDR_BITS-1 downto 0);
   signal res_data_d   : std_logic_vector( 8 downto 0);
   signal res_valid_d  : std_logic;

begin

   assert G_NUM_ROWS mod G_PIXELS = 0 and 2**log2(G_PIXELS) = G_PIXELS
      report "G_PIXELS must be a power of two, and divide G_NUM_ROWS"
      severity failure;

   p_rst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rst_r <= rst_i;
      end if;
   end process p_rst;


   -----------------------------
   -- Simple state machine to
   -- iterate through each row.
   -----------------------------

   -- The iterator keeps the count, and done_o high, until the next start. It
   -- sees the start in the clock cycle after res_start_r is set, so the count
   -- of a row is only used when res_start_r is low.
   res_keep_s <= res_valid_s and res_hold_r and not res_start_r and not res_last_r;

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         res_start_r <= '0';

         if job_start_i = '1' then
            res_cx_r    <= job_cx_i;
            res_cy_r    <= job_starty_i;
            res_start_r <= '1';
            res_addr_r  <= (others => '0');
            res_last_r  <= '0';
            if G_NUM_ROWS = 1 then
               res_last_r <= '1';
            end if;
            res_hold_r  <= '0';
            if G_PIXELS > 1 then
               res_hold_r <= '1';
            end if;
         end if;

         -- The next row starts when the count of this row is kept, or when the
         -- result has been acknowledged.
         if res_keep_s = '1' or
            (res_valid_s = '1' and res_ack_i = '1' and
             res_start_r = '0' and res_last_r = '0')
         then
            res_addr_r  <= res_addr_r + 1;
            res_cy_r    <= res_cy_r + job_stepy_i;
            res_start_r <= '1';
            res_last_r  <= '0';
            if to_integer(res_addr_r) = G_NUM_ROWS-2 then
               res_last_r <= '1';
            end if;
            res_hold_r  <= '0';
            if G_PIXELS > 1 and to_integer(res_addr_r) mod G_PIXELS /= G_PIXELS-2 then
               res_hold_r <= '1';
            end if;
         end if;
      end if;
   end process p_fsm;


   -- The counts of the first G_PIXELS-1 rows of a result. The count of a new
   -- row is put at the top, so the count of the first row ends up at the
   -- bottom. These do not change from the last row of the result until the
   -- next row has been calculated, i.e. until after the acknowledge, so they
   -- are output directly, without the output register.
   gen_word : if G_PIXELS > 1 generate
      p_word : process (clk_i)
      begin
         if rising_edge(clk_i) then
            if res_keep_s = '1' then
               res_word_r <= res_data_s & res_word_r(res_word_r'high downto 9);
            end if;
         end if;
      end process p_word;
   end generate gen_word;


   p_job_done : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if res_valid_s = '1' and res_last_r = '1' and
            res_start_r = '0' and res_ack_i = '1'
         then
            job_busy_r <= '0';
         end if;

         if job_start_i = '1' then
            job_busy_r  <= '1';
         end if;

         if rst_r = '1' then
            job_busy_r  <= '0';
         end if;
      end if;
   end process p_job_done;


   i_iterator : entity work.iterator
      generic map (
         G_MAX_COUNT => G_MAX_COUNT
      )
      port map (
         clk_i   => clk_i,
         rst_i   => rst_r,
         start_i => res_start_r,
         cx_i    => res_cx_r,
         cy_i    => res_cy_r,
         cnt_o   => res_data_s,
         done_o  => res_valid_s
      ); -- i_iterator


   ---------------------------
   -- Pipeline output signals
   ---------------------------

   p_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- The first row of the result
         res_addr_d  <= res_addr_r and not to_slv(G_PIXELS-1, C_ADDR_BITS);
         res_data_d  <= res_data_s;
         res_valid_d <= res_valid_s and not res_start_r and job_busy_r and
                        not res_ack_i and not res_hold_r;
      end if;
   end process p_out;


   --------------------------
   -- Connect output signals
   --------------------------

   job_busy_o  <= job_busy_r;

   res_addr_o  <= (8 downto C_ADDR_BITS => '0') & res_addr_d;
   res_data_o  <= res_data_d & res_word_r;
   res_valid_o <= res_valid_d;

end architecture rtl;

