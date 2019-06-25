library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module performs the Continued Fraction calculations.  Once initialized
-- with the integer N, it will repeatedly output values X and Y, such that
-- 1) X^2 = Y mod N.
-- 2) |Y|<2*sqrt(N).
-- In other words, the number of bits in Y is approximately half that of X and N.
-- The value of Y is represented as a sign bit in W and an absolute value in P.

-- Specifically, this module calculates a recurrence relation with the
-- following initialiazation:
-- p_0 = 1
-- r_0 = 0
-- x_0 = 1
-- p_1 = N - M*M
-- s_1 = 2*M
-- w_1 = -1
-- x_1 = M,
-- and then for each n>=2:
-- 1) a_n = s_n/p_n
-- 2) r_n = s_n-a_n*p_n
-- 3) s_(n+1) = 2*M - r\_n
-- 4) p_(n+1) = a_n (r_n - r_(n-1)) + p_(n-1)
-- 5) w_(n+1) = - w_n
-- 6) x_(n+1) = a_n x_n + x_(n-1) mod N
-- Steps 1 and 2 in the recurrence are performed simultaneously using the divmod module.
-- Steps 4 and 6 are performed simultaneously using the add_mult and amm modules.

entity cf is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val_i   : in  std_logic_vector(2*G_SIZE-1 downto 0);  -- N
      start_i : in  std_logic;
      res_x_o : out std_logic_vector(2*G_SIZE-1 downto 0);  -- X
      res_p_o : out std_logic_vector(G_SIZE-1 downto 0);    -- |Y|
      res_w_o : out std_logic;                              -- sign(Y)
      valid_o : out std_logic
   );
end cf;

architecture Behavioral of cf is

   constant C_ZERO       : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   constant C_ONE        : std_logic_vector(G_SIZE-1 downto 0) := to_stdlogicvector(1, G_SIZE);

   -- State variables
   type fsm_state is (IDLE_ST, SQRT_ST, CALC_AR_ST, CALC_XP_ST);
   signal state          : fsm_state;

   signal val_n          : std_logic_vector(2*G_SIZE-1 downto 0);
   signal val_2root      : std_logic_vector(G_SIZE-1 downto 0);

   signal p_prev         : std_logic_vector(G_SIZE-1 downto 0);
   signal r_prev         : std_logic_vector(G_SIZE-1 downto 0);
   signal x_prev         : std_logic_vector(2*G_SIZE-1 downto 0);

   signal p_cur          : std_logic_vector(G_SIZE-1 downto 0);
   signal s_cur          : std_logic_vector(G_SIZE-1 downto 0);
   signal w_cur          : std_logic;
   signal x_cur          : std_logic_vector(2*G_SIZE-1 downto 0);

   signal a_cur          : std_logic_vector(G_SIZE-1 downto 0);
   signal r_cur          : std_logic_vector(G_SIZE-1 downto 0);

   signal p_new          : std_logic_vector(G_SIZE-1 downto 0);
   signal s_new          : std_logic_vector(G_SIZE-1 downto 0);
   signal w_new          : std_logic;
   signal x_new          : std_logic_vector(2*G_SIZE-1 downto 0);

   -- Signals connected to SQRT module
   signal sqrt_val       : std_logic_vector(2*G_SIZE-1 downto 0);
   signal sqrt_start     : std_logic;
   signal sqrt_res       : std_logic_vector(G_SIZE-1 downto 0);
   signal sqrt_diff      : std_logic_vector(G_SIZE-1 downto 0);
   signal sqrt_busy      : std_logic;
   signal sqrt_valid     : std_logic;

   -- Signals connected to DIVMOD module
   signal divmod_val_n   : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_val_d   : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_start   : std_logic;
   signal divmod_res_q   : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_res_r   : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_busy    : std_logic;
   signal divmod_valid   : std_logic;

   -- Signals connected to AMM module
   signal amm_val_a      : std_logic_vector(G_SIZE-1 downto 0);
   signal amm_val_x      : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_val_b      : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_val_n      : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_start      : std_logic;
   signal amm_res        : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_busy       : std_logic;
   signal amm_valid      : std_logic;

   -- Signals connected to ADD-MULT module
   signal add_mult_val_a : std_logic_vector(G_SIZE-1 downto 0);
   signal add_mult_val_x : std_logic_vector(G_SIZE-1 downto 0);
   signal add_mult_val_b : std_logic_vector(2*G_SIZE-1 downto 0);
   signal add_mult_start : std_logic;
   signal add_mult_res   : std_logic_vector(2*G_SIZE-1 downto 0);
   signal add_mult_busy  : std_logic;
   signal add_mult_valid : std_logic;

   -- Output signals
   signal res_x          : std_logic_vector(2*G_SIZE-1 downto 0);
   signal res_p          : std_logic_vector(G_SIZE-1 downto 0);
   signal res_w          : std_logic;
   signal valid          : std_logic;

begin

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Set default values
         res_x          <= C_ZERO & C_ZERO;
         res_p          <= C_ZERO;
         res_w          <= '0';
         valid          <= '0';

         sqrt_start     <= '0';
         divmod_start   <= '0';
         amm_start      <= '0';
         add_mult_start <= '0';

         case state is
            when IDLE_ST =>
               null;

            when SQRT_ST =>
               -- Wait until data is ready
               if sqrt_start = '0' and sqrt_valid = '1' then
                  assert divmod_busy = '0' and amm_busy = '0' and add_mult_busy = '0';
                  -- Store input values
                  val_2root <= sqrt_res(G_SIZE-2 downto 0) & '0';

                  -- Let: p_0 = 1, r_0 = 0, x_0 = 1.
                  p_prev <= C_ONE;
                  r_prev <= C_ZERO;
                  x_prev <= C_ZERO & C_ONE;

                  -- Let: p_1 = N - M*M, s_1 = 2*M, w_1 = -1, x_1 = M.
                  p_cur <= sqrt_diff;
                  s_cur <= sqrt_res(G_SIZE-2 downto 0) & '0';
                  w_cur <= '1';
                  x_cur <= C_ZERO & sqrt_res;

                  -- Store output values
                  valid <= '1';

                  -- Start calculating a_n and p_n.
                  divmod_start <= '1';
                  state        <= CALC_AR_ST;
               end if;

            when CALC_AR_ST =>
               if divmod_start = '0' and divmod_valid = '1' then
                  -- Store new values of a_n and r_n
                  a_cur <= divmod_res_q;
                  r_cur <= divmod_res_r;

                  -- Start calculating x_(n+1) and p_(n+1).
                  amm_start      <= '1';
                  add_mult_start <= '1';
                  state          <= CALC_XP_ST;
               end if;

            when CALC_XP_ST =>
               if amm_start = '0' and amm_valid = '1' and add_mult_start = '0' and add_mult_valid = '1' then
                  -- Update recursion
                  s_cur  <= s_new;
                  p_cur  <= p_new;
                  w_cur  <= w_new;
                  x_cur  <= x_new;

                  p_prev <= p_cur;
                  r_prev <= r_cur;
                  x_prev <= x_cur;

                  -- Store output values
                  valid  <= '1';

                  -- Start calculating a_n and p_n.
                  divmod_start <= '1';
                  state        <= CALC_AR_ST;
               end if;
         end case;

         -- A start command should be processed from any state
         if start_i = '1' then
            val_n      <= val_i;
            sqrt_start <= '1';
            state      <= SQRT_ST;

            if val_i = 0 then
               sqrt_start <= '0';
               state      <= IDLE_ST;
            end if;
         end if;

         if rst_i = '1' then
            sqrt_start <= '0';
            state      <= SQRT_ST;
         end if;
      end if;
   end process p_fsm;

   -- Calculate M=floor(sqrt(N)).
   sqrt_val <= val_n;

   -- Calculate a_n = s_n/p_n and r_n = s_n-a_n*p_n.
   divmod_val_n <= s_cur;
   divmod_val_d <= p_cur;

   -- Calculate x_(n+1) = (a_n * x_n + x_(n-1)) mod N.
   amm_val_a <= a_cur;
   amm_val_x <= x_cur;
   amm_val_b <= x_prev;
   amm_val_n <= val_n;
   x_new     <= amm_res;

   -- Calculate p_(n+1) = p_(n-1) + a_n*[r_n - r_(n-1)].
   add_mult_val_a <= a_cur;
   add_mult_val_x <= r_cur - r_prev;
   add_mult_val_b <= C_ZERO & p_prev;
   p_new          <= add_mult_res(G_SIZE-1 downto 0);

   -- Calculate s_(n+1) = 2*M - r_n.
   s_new <= val_2root - r_cur;

   -- Calculate w_(n+1) = - w_n.
   w_new <= not w_cur;


   --------------------
   -- Instantiate SQRT
   --------------------

   i_sqrt : entity work.sqrt
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_i   => sqrt_val,
      start_i => sqrt_start,
      res_o   => sqrt_res,
      diff_o  => sqrt_diff,
      busy_o  => sqrt_busy,
      valid_o => sqrt_valid
   ); -- i_sqrt


   ----------------------
   -- Instantiate DIVMOD
   ----------------------

   i_divmod : entity work.divmod
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_n_i => divmod_val_n,
      val_d_i => divmod_val_d,
      start_i => divmod_start,
      res_q_o => divmod_res_q,
      res_r_o => divmod_res_r,
      busy_o  => divmod_busy,
      valid_o => divmod_valid
   ); -- i_divmod


   ----------------------
   -- Instantiate AMM
   ----------------------

   i_amm : entity work.amm
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_a_i => amm_val_a,
      val_x_i => amm_val_x,
      val_b_i => amm_val_b,
      val_n_i => amm_val_n,
      start_i => amm_start,
      res_o   => amm_res,
      busy_o  => amm_busy,
      valid_o => amm_valid
   ); -- i_amm


   ------------------------
   -- Instantiate ADD_MULT
   ------------------------

   i_add_mult : entity work.add_mult
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_a_i => add_mult_val_a,
      val_x_i => add_mult_val_x,
      val_b_i => add_mult_val_b,
      start_i => add_mult_start,
      res_o   => add_mult_res,
      busy_o  => add_mult_busy,
      valid_o => add_mult_valid
   ); -- i_add_mult


   --------------------------
   -- Connect output signals
   --------------------------

   res_x_o <= x_cur;
   res_p_o <= p_cur;
   res_w_o <= w_cur;
   valid_o <= valid;

end Behavioral;

