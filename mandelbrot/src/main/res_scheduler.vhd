library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module selects one of a number of processes that have a result ready,
-- so the result can be accepted. It is used by the dispatcher to pick which
-- column module's result to accept.
--
-- The processes are divided into groups of G_GROUP_SIZE processes. Each group
-- registers the ready flags of its processes (req_r), and then, in the next
-- clock cycle, a candidate: one of its processes that is ready, picked in a
-- round-robin order within the group (the first ready process after the one
-- that was selected last time). The ready flags are registered first, so the
-- routes from the processes and the round-robin selection are in separate
-- clock cycles. A counter goes round the groups, one per clock cycle, and the
-- candidate of the group of the counter is selected, if the group has one. So
-- a process is selected three clock cycles after its ready flag is sampled,
-- and a process that is ready waits at most about G_GROUP_SIZE rounds of the
-- counter, even when all the other processes are ready too.
--
-- The ready flags and the candidate of a group are registered, so the ready
-- flag of a process that has just been selected is still sampled for a while.
-- When a process is selected (idx_valid_o is high and idx_o is the process in
-- clock cycle c), its ready flag must therefore be low from clock cycle c+2
-- until it has a new result. The counter visits each group at most once every
-- five clock cycles (there are empty positions when there are fewer than five
-- groups), so the next candidate of the same group is from the ready flags
-- sampled in clock cycle c+2 at the earliest.

entity res_scheduler is
   generic (
      G_SIZE       : integer;
      G_GROUP_SIZE : integer
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      active_i    : in  std_logic;
      ready_i     : in  std_logic_vector(G_SIZE-1 downto 0);
      idx_valid_o : out std_logic;
      idx_o       : out integer range 0 to G_SIZE-1
   );
end entity res_scheduler;

architecture rtl of res_scheduler is

   constant C_NUM_GROUPS : integer := (G_SIZE + G_GROUP_SIZE - 1) / G_GROUP_SIZE;
   -- The number of positions of the counter
   constant C_PERIOD     : integer := maximum(C_NUM_GROUPS, 5);

   subtype pos_t is integer range 0 to G_GROUP_SIZE-1;
   type pos_vector is array (natural range <>) of pos_t;
   type req_vector is array (natural range <>) of
      std_logic_vector(G_GROUP_SIZE-1 downto 0);

   -- The first process at or after position ptr that is ready, or else the
   -- first process that is ready. The result is not used when no process is
   -- ready.
   function rr_pick (
      req : std_logic_vector(G_GROUP_SIZE-1 downto 0);
      ptr : pos_t
   ) return pos_t is
      variable lo_v : pos_t := 0;
      variable hi_v : pos_t := 0;
      variable hi_found_v : boolean := false;
   begin
      for i in G_GROUP_SIZE-1 downto 0 loop
         if req(i) = '1' then
            lo_v := i;
            if i >= ptr then
               hi_v := i;
               hi_found_v := true;
            end if;
         end if;
      end loop;
      if hi_found_v then
         return hi_v;
      end if;
      return lo_v;
   end function rr_pick;

   signal cnt_r       : integer range 0 to C_PERIOD-1;
   signal active_r    : std_logic;
   signal req_r       : req_vector(C_NUM_GROUPS-1 downto 0);
   signal ptr_r       : pos_vector(C_NUM_GROUPS-1 downto 0);
   signal cand_r      : pos_vector(C_NUM_GROUPS-1 downto 0);
   signal cand_ok_r   : std_logic_vector(C_NUM_GROUPS-1 downto 0);
   signal idx_r       : integer range 0 to G_SIZE-1;
   signal idx_valid_r : std_logic;

begin

   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cnt_r < C_PERIOD-1 then
            cnt_r <= cnt_r + 1;
         else
            cnt_r <= 0;
         end if;

         active_r <= active_i;

         if rst_i = '1' then
            cnt_r    <= 0;
            active_r <= '0';
         end if;
      end if;
   end process p_cnt;


   -- The ready flags and the candidate of each group. When the candidate is
   -- selected, the round-robin order continues after it.
   gen_grp : for g in 0 to C_NUM_GROUPS-1 generate
      p_grp : process (clk_i)
         variable req_v : std_logic_vector(G_GROUP_SIZE-1 downto 0);
      begin
         if rising_edge(clk_i) then
            -- Positions after the last process are never ready
            req_v := (others => '0');
            for i in 0 to G_GROUP_SIZE-1 loop
               if g*G_GROUP_SIZE + i < G_SIZE then
                  req_v(i) := ready_i(g*G_GROUP_SIZE + i);
               end if;
            end loop;

            req_r(g)     <= req_v;
            cand_r(g)    <= rr_pick(req_r(g), ptr_r(g));
            cand_ok_r(g) <= or req_r(g);

            if cnt_r = g and active_r = '1' and cand_ok_r(g) = '1' then
               if cand_r(g) < G_GROUP_SIZE-1 then
                  ptr_r(g) <= cand_r(g) + 1;
               else
                  ptr_r(g) <= 0;
               end if;
            end if;

            if rst_i = '1' then
               ptr_r(g)     <= 0;
               cand_ok_r(g) <= '0';
            end if;
         end if;
      end process p_grp;
   end generate gen_grp;


   p_sel : process (clk_i)
   begin
      if rising_edge(clk_i) then
         idx_valid_r <= '0';

         if cnt_r < C_NUM_GROUPS and active_r = '1' then
            if cand_ok_r(cnt_r) = '1' then
               idx_valid_r <= '1';
               idx_r       <= cnt_r*G_GROUP_SIZE + cand_r(cnt_r);
            end if;
         end if;

         if rst_i = '1' then
            idx_r       <= 0;
            idx_valid_r <= '0';
         end if;
      end if;
   end process p_sel;

   idx_valid_o <= idx_valid_r;
   idx_o       <= idx_r;

end architecture rtl;
