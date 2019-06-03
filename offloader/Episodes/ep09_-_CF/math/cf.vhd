library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module performs the Continued Fraction calculations.  Once initialized
-- with N, X=[sqrt(N)], and Y=N-X*X, it will repeatedly output values X and Y,
-- such that
-- 1) X^2 = (-1)^n*Y mod N.
-- 2) Y<2*sqrt(N).
-- In other words, the number of bits in Y is approximately half that of X and N.

-- Specifically, this module calculates a recurrence relation with the
-- following initialiazation:
-- 1) x_0 = 1
-- 2) x_1 = M
-- 3) y_0 = 1
-- 4) y_1 = N-M*M
-- 5) z_1 = 2*M
-- 6) p_0 = 0.
-- And then for each n>=2:
-- 1) a_n = z_n/y_n
-- 2) p_n = z_n-a_n*y_n
-- 3) x_(n+1) = (a_n * x_n + x_(n-1)) mod N.
-- 4) y_(n+1) = y_(n-1) + a_n*[p_n - p_(n-1)].
-- 5) z_(n+1) = 2*M - p_n.

-- Steps 1 and 2 in the recurrence are performed simultaneously using the divmod module.
-- Steps 3 and 4 are performed simultaneously using the add_mult and amm modules.

entity cf is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val_n_i : in  std_logic_vector(2*G_SIZE-1 downto 0);
      val_x_i : in  std_logic_vector(G_SIZE-1 downto 0);
      val_y_i : in  std_logic_vector(G_SIZE-1 downto 0);
      start_i : in  std_logic;
      res_x_o : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_y_o : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o : out std_logic
   );
end cf;

architecture Behavioral of cf is

   type fsm_state is (IDLE_ST, CALC_A_ST, CALC_XY_ST, WAIT_ST);
   signal state          : fsm_state;

   constant C_ZERO       : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   constant C_ONE        : std_logic_vector(G_SIZE-1 downto 0) := to_stdlogicvector(1, G_SIZE);

   signal val_n          : std_logic_vector(2*G_SIZE-1 downto 0);
   signal val_2root      : std_logic_vector(G_SIZE-1 downto 0);

   signal x_prev         : std_logic_vector(2*G_SIZE-1 downto 0);
   signal x_cur          : std_logic_vector(2*G_SIZE-1 downto 0);
   signal x_new          : std_logic_vector(2*G_SIZE-1 downto 0);

   signal y_prev         : std_logic_vector(G_SIZE-1 downto 0);
   signal y_cur          : std_logic_vector(G_SIZE-1 downto 0);
   signal y_new          : std_logic_vector(G_SIZE-1 downto 0);

   signal z_cur          : std_logic_vector(G_SIZE-1 downto 0);
   signal z_new          : std_logic_vector(G_SIZE-1 downto 0);

   signal p_prev         : std_logic_vector(G_SIZE-1 downto 0);
   signal p_cur          : std_logic_vector(G_SIZE-1 downto 0);

   signal a_cur          : std_logic_vector(G_SIZE-1 downto 0);

   signal divmod_val_n   : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_val_d   : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_start   : std_logic;
   signal divmod_valid   : std_logic;
   signal divmod_res_q   : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_res_r   : std_logic_vector(G_SIZE-1 downto 0);

   signal amm_val_a      : std_logic_vector(G_SIZE-1 downto 0);
   signal amm_val_x      : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_val_b      : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_val_n      : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_start      : std_logic;
   signal amm_valid      : std_logic;
   signal amm_res        : std_logic_vector(2*G_SIZE-1 downto 0);

   signal add_mult_val_a : std_logic_vector(G_SIZE-1 downto 0);
   signal add_mult_val_x : std_logic_vector(G_SIZE-1 downto 0);
   signal add_mult_val_b : std_logic_vector(2*G_SIZE-1 downto 0);
   signal add_mult_start : std_logic;
   signal add_mult_valid : std_logic;
   signal add_mult_res   : std_logic_vector(2*G_SIZE-1 downto 0);

   signal res_x          : std_logic_vector(2*G_SIZE-1 downto 0);
   signal res_y          : std_logic_vector(G_SIZE-1 downto 0);
   signal valid          : std_logic;

begin

   -- Calculate a_n = z_n/y_n and p_n = z_n-a_n*y_n.
   divmod_val_n <= z_cur;
   divmod_val_d <= y_cur;

   -- Calculate x_(n+1) = (a_n * x_n + x_(n-1)) mod N.
   amm_val_a <= a_cur;
   amm_val_x <= x_cur;
   amm_val_b <= x_prev;
   amm_val_n <= val_n;
   x_new     <= amm_res;

   -- Calculate y_(n+1) = y_(n-1) + a_n*[p_n - p_(n-1)].
   add_mult_val_a <= a_cur;
   add_mult_val_x <= p_cur - p_prev;
   add_mult_val_b <= C_ZERO & y_prev;
   y_new          <= add_mult_res(G_SIZE-1 downto 0);

   -- Calculate z_(n+1) = 2*M - p_n.
   z_new <= val_2root - p_cur;

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Set default values
         res_x          <= C_ZERO & C_ZERO;
         res_y          <= C_ZERO;
         valid          <= '0';
         divmod_start   <= '0';
         amm_start      <= '0';
         add_mult_start <= '0';

         case state is
            when IDLE_ST =>
               null;

            when CALC_A_ST =>
               if divmod_valid = '1' then
                  -- Store new values of a_n and p_n
                  a_cur <= divmod_res_q;
                  p_cur <= divmod_res_r;

                  -- Start calculating x_(n+1) and y_(n+1).
                  divmod_start   <= '0';
                  amm_start      <= '1';
                  add_mult_start <= '1';
                  state          <= CALC_XY_ST;
               end if;

            when CALC_XY_ST =>
               if amm_valid = '1' and add_mult_valid = '1' then
                  -- Update recursion
                  x_prev <= x_cur;
                  x_cur  <= x_new;
                  y_prev <= y_cur;
                  y_cur  <= y_new;
                  p_prev <= p_cur;
                  z_cur  <= z_new;

                  -- Store output values
                  res_x  <= x_new;
                  res_y  <= y_new;
                  valid  <= '1';

                  -- Start calculating a_n and p_n.
                  amm_start      <= '0';
                  add_mult_start <= '0';
                  divmod_start   <= '1';
                  state          <= CALC_A_ST;
               end if;

            when WAIT_ST =>
               if divmod_valid = '0' and amm_valid = '0' and add_mult_valid = '0' then
                  -- Start calculating a_n and p_n.
                  amm_start      <= '0';
                  add_mult_start <= '0';
                  divmod_start   <= '1';
                  state          <= CALC_A_ST;
               end if;
         end case;

         if start_i = '1' then
            -- Store input values
            val_n        <= val_n_i;
            val_2root    <= val_x_i(G_SIZE-2 downto 0) & '0';

            -- Let x_0 = 1, y_0 = 1, p_0 = 0.
            -- Then X^2 = Y mod N.
            x_prev       <= C_ZERO & C_ONE;
            y_prev       <= C_ONE;
            p_prev       <= C_ZERO;

            -- Let x_1 = M, y_1 = N-M*M, z_1 = 2*M
            -- Then X^2 = -Y mod N.
            x_cur        <= C_ZERO & val_x_i;
            y_cur        <= val_y_i;
            z_cur        <= val_x_i(G_SIZE-2 downto 0) & '0';

            -- Stop all ongoing calculations
            amm_start      <= '0';
            add_mult_start <= '0';
            divmod_start   <= '0';
            state          <= WAIT_ST;
         end if;

         if rst_i = '1' then
            state <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;


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
      clk_i    => clk_i,
      rst_i    => rst_i,
      val_a_i  => add_mult_val_a,
      val_x_i  => add_mult_val_x,
      val_b_i  => add_mult_val_b,
      start_i  => add_mult_start,
      res_o    => add_mult_res,
      valid_o  => add_mult_valid
   ); -- i_add_mult


   --------------------------
   -- Connect output signals
   --------------------------

   res_x_o <= res_x;
   res_y_o <= res_y;
   valid_o <= valid;

end Behavioral;

