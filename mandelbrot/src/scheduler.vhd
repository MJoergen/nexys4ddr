library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module handles a number of parallel processes, and
-- repeatedly starts any idle processes.
--
-- A counter goes round all the processes, one per clock cycle, and an idle
-- process is started when the counter reaches it. The busy flag of the
-- process is selected in two steps, to keep the paths short: first, in each
-- group of 16 processes, the flag of the process at the position of the
-- counter in the group is registered (grp_busy_r), and then, in the next
-- clock cycle, the flag of the group of the counter is used. So a process is
-- started two clock cycles after its busy flag is sampled.

entity scheduler is
   generic (
      G_SIZE : integer
   );
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;
      sched_active_i  : in  std_logic;
      job_idx_valid_o : out std_logic;
      job_idx_start_o : out integer range 0 to G_SIZE-1;
      job_busy_i      : in  std_logic_vector(G_SIZE-1 downto 0)
   );
end entity scheduler;

architecture rtl of scheduler is

   constant C_GROUP_SIZE  : integer := 16;
   constant C_NUM_GROUPS  : integer := (G_SIZE + C_GROUP_SIZE - 1) / C_GROUP_SIZE;

   signal cnt_r           : integer range 0 to G_SIZE-1;
   signal cnt_d           : integer range 0 to G_SIZE-1;
   signal active_d        : std_logic;
   signal grp_busy_r      : std_logic_vector(C_NUM_GROUPS-1 downto 0);
   signal job_idx_start_r : integer range 0 to G_SIZE-1;
   signal job_idx_valid_r : std_logic;

begin

   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if cnt_r < G_SIZE-1 then
            cnt_r <= cnt_r + 1;
         else
            cnt_r <= 0;
         end if;

         if rst_i = '1' then
            cnt_r <= 0;
         end if;
      end if;
   end process p_cnt;

   -- The busy flag of the process at the position of the counter in each
   -- group. Positions after the last process count as busy.
   p_grp_busy : process (clk_i)
      variable idx_v : integer;
   begin
      if rising_edge(clk_i) then
         for g in 0 to C_NUM_GROUPS-1 loop
            idx_v := g*C_GROUP_SIZE + cnt_r mod C_GROUP_SIZE;
            grp_busy_r(g) <= '1';
            if idx_v < G_SIZE then
               grp_busy_r(g) <= job_busy_i(idx_v);
            end if;
         end loop;

         cnt_d    <= cnt_r;
         active_d <= sched_active_i;

         if rst_i = '1' then
            active_d <= '0';
         end if;
      end if;
   end process p_grp_busy;

   p_job : process (clk_i)
   begin
      if rising_edge(clk_i) then

         job_idx_valid_r <= '0';

         if active_d = '1' then
            if grp_busy_r(cnt_d / C_GROUP_SIZE) = '0' then
               job_idx_valid_r <= '1';
               job_idx_start_r <= cnt_d;
            end if;
         end if;

         if rst_i = '1' then
            job_idx_start_r <= 0;
            job_idx_valid_r <= '0';
         end if;
      end if;
   end process p_job;

   job_idx_valid_o <= job_idx_valid_r;
   job_idx_start_o <= job_idx_start_r;

end architecture rtl;

