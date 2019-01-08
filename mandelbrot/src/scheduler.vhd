library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module handles a number of parallel processes, and
-- repeatedly starts any idle processes.

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

   signal cnt_r           : integer range 0 to G_SIZE-1;
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

   p_job : process (clk_i)
   begin
      if rising_edge(clk_i) then

         job_idx_valid_r <= '0';

         if sched_active_i = '1' then
            if job_busy_i(cnt_r) = '0' then
               job_idx_valid_r <= '1';
               job_idx_start_r <= cnt_r;
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

