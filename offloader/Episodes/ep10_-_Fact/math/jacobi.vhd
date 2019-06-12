library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module calculates the Jacobi Symbol using the algorithm described in
-- https://en.wikipedia.org/wiki/Jacobi_symbol#Calculating_the_Jacobi_symbol
--
-- function Jacobi(n,k)
--    assert(k > 0 and k % 2 == 1)
--    n = n % k
--    t = 1
--    while n ~= 0 do
--       while n % 2 == 0 do
--          n = n / 2
--          r = k % 8
--          if r == 3 or r == 5 then
--             t = -t
--          end
--       end
--       n, k = k, n
--       if n % 4 == k % 4 == 3 then
--          t = -t
--       end
--       n = n % k
--    end
--    if k == 1 then
--       return t
--    else
--       return 0
--    end
-- end
--
-- Examples:
-- (19/45)     =  1,
-- (8/21)      = -1,
-- (5/21)      =  1,
-- (1001/9907) = -1,
-- (30/7)      =  1,
-- (30/11)     = -1,
-- (30/13)     =  1

entity jacobi is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val_n_i : in  std_logic_vector(G_SIZE-1 downto 0);
      val_k_i : in  std_logic_vector(G_SIZE-1 downto 0);
      start_i : in  std_logic;
      res_o   : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o : out std_logic;
      busy_o  : out std_logic
   );
end jacobi;

architecture structural of jacobi is

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   constant C_ONE  : std_logic_vector(G_SIZE-1 downto 0) := to_stdlogicvector(1, G_SIZE);

   type fsm_state is (IDLE_ST, DIVMOD_ST, REDUCE_ST, DONE_ST);
   signal state    : fsm_state;

   signal dm_val_n : std_logic_vector(G_SIZE-1 downto 0);
   signal dm_val_d : std_logic_vector(G_SIZE-1 downto 0);
   signal dm_start : std_logic;
   signal dm_res_r : std_logic_vector(G_SIZE-1 downto 0);
   signal dm_valid : std_logic;

   signal val_n    : std_logic_vector(G_SIZE-1 downto 0);
   signal val_k    : std_logic_vector(G_SIZE-1 downto 0);

   signal res      : std_logic_vector(G_SIZE-1 downto 0);
   signal valid    : std_logic;

begin

   dm_val_n <= val_n;
   dm_val_d <= val_k;

   i_divmod : entity work.divmod
   generic map (
      G_SIZE => G_SIZE
   )
   port map (
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_n_i => dm_val_n,
      val_d_i => dm_val_d,
      start_i => dm_start,
      res_q_o => open,  -- Not used
      res_r_o => dm_res_r,
      valid_o => dm_valid
   ); -- i_divmod

   p_fsm : process (clk_i)   
   begin
      if rising_edge(clk_i) then

         -- Set default values
         dm_start <= '0';

         case state is
            when IDLE_ST =>
               if start_i = '1' then
                  val_n <= val_n_i;
                  val_k <= val_k_i;
                  res   <= C_ONE;
                  valid <= '0';

                  dm_start <= '1';
                  state    <= DIVMOD_ST;
               end if;

            when DIVMOD_ST =>
               if dm_start = '0' and dm_valid = '1' then
                  val_n <= dm_res_r;
                  state <= REDUCE_ST;

                  if dm_res_r = 0 then
                     if dm_val_d /= 1 then
                        res <= (others => '0');
                     end if;
                     state <= DONE_ST;
                  end if;
               end if;

            when REDUCE_ST =>
               if val_n(0) = '0' then
                  val_n <= '0' & val_n(G_SIZE-1 downto 1);

                  if val_k(2 downto 0) = 3 or val_k(2 downto 0) = 5 then
                     res <= (not res) + 1;
                  end if;
               else
                  if val_n(1 downto 0) = 3 and val_k(1 downto 0) = 3 then
                     res <= (not res) + 1;
                  end if;
                  val_n    <= val_k;
                  val_k    <= val_n;
                  dm_start <= '1';
                  state    <= DIVMOD_ST;
               end if;

            when DONE_ST =>
               valid <= '1';
               state <= IDLE_ST;
         end case;

         if rst_i = '1' then
            state <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   
   -- Connect output signals
   res_o   <= res;
   valid_o <= valid;
   busy_o  <= '0' when state = IDLE_ST else '1';

end structural;

