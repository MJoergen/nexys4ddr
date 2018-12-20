library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This calculates (sequentially) an entire column

entity column is
   generic (
      G_MAX_COUNT : integer;
      G_NUM_ROWS  : integer
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;
      job_start_i  : in  std_logic;
      job_cx_i     : in  std_logic_vector(17 downto 0);
      job_starty_i : in  std_logic_vector(17 downto 0);
      job_stepy_i  : in  std_logic_vector(17 downto 0);
      job_done_o   : out std_logic;
      res_addr_o   : out std_logic_vector( 9 downto 0);
      res_ack_i    : in  std_logic;
      res_data_o   : out std_logic_vector( 8 downto 0);
      res_valid_o  : out std_logic
   );
end entity column;

architecture rtl of column is

   signal res_start_r : std_logic;
   signal res_cx_r    : std_logic_vector(17 downto 0);
   signal res_cy_r    : std_logic_vector(17 downto 0);
   signal res_data_s  : std_logic_vector( 8 downto 0);
   signal res_valid_s : std_logic;
   signal res_addr_r  : std_logic_vector( 9 downto 0);

   signal job_done_r  : std_logic;

begin

   -----------------------------
   -- Simple state machine to
   -- iterate through each row.
   -----------------------------

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         res_start_r <= '0';

         if job_start_i = '1' then
            res_cx_r    <= job_cx_i;
            res_cy_r    <= job_starty_i;
            res_start_r <= '1';
            res_addr_r  <= (others => '0');
         end if;

         if res_valid_s = '1' and res_ack_i = '1' and
            res_start_r = '0' and
            res_addr_r + 1 /= G_NUM_ROWS
         then
            res_addr_r  <= res_addr_r + 1;
            res_cy_r    <= res_cy_r + job_stepy_i;
            res_start_r <= '1';
         end if;
      end if;
   end process p_fsm;


   p_job_done : process (clk_i)
   begin
      if rising_edge(clk_i) then
         job_done_r  <= '0';

         if res_valid_s = '1' and res_addr_r + 1 = G_NUM_ROWS and
            res_start_r = '0' and res_ack_i = '1'
         then
            job_done_r <= '1';
         end if;
      end if;
   end process p_job_done;


   i_iterator : entity work.iterator
      generic map (
         G_MAX_COUNT => G_MAX_COUNT
      )
      port map (
         clk_i   => clk_i,
         rst_i   => rst_i,
         start_i => res_start_r,
         cx_i    => res_cx_r,
         cy_i    => res_cy_r,
         cnt_o   => res_data_s,
         done_o  => res_valid_s
      ); -- i_iterator

   --------------------------
   -- Connect output signals
   --------------------------

   job_done_o  <= job_done_r;
   res_addr_o  <= res_addr_r;
   res_data_o  <= res_data_s;
   res_valid_o <= res_valid_s and not res_start_r;

end architecture rtl;

