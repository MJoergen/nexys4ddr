library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module performa the Continued Fraction calculations.  Once initialized
-- with N and M=[sqrt(N)], it will repeatedly output values x and y, such that
-- x^2 = y mod N and y<M.

-- Specifically, it performs the following initialiazation:
-- Let x_(-1) = 1, x_0 = M, y_(-1) = 1, y_0 = N-M*M, z_0 = 2*M, p_(-1) = 0.
--
-- Then for each n>0 calculate
-- 1) a_n and p_n such that z_n = a_n*y_n + p_n.
-- 2) y_(n+1) = y_(n-1) + a_n*[p_n - p_(n-1)].
-- 3) x_(n+1) = (a_n * x_n + x_(n-1)) mod N.
-- 4) z_(n+1) = 2*M - p_n.


entity cf is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val_n_i : in  std_logic_vector(2*G_SIZE-1 downto 0);
      val_m_i : in  std_logic_vector(G_SIZE-1 downto 0);
      val_y_i : in  std_logic_vector(G_SIZE-1 downto 0);
      start_i : in  std_logic;
      res_x_o : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_y_o : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o : out std_logic
   );
end cf;

architecture Behavioral of cf is

   type fsm_state is (IDLE_ST, CALC_A_ST, CALC_XY_ST, UPDATE_ST);
   signal state        : fsm_state;

   constant C_ZERO     : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   constant C_ONE      : std_logic_vector(G_SIZE-1 downto 0) := to_stdlogicvector(1, G_SIZE);

   signal val_n        : std_logic_vector(2*G_SIZE-1 downto 0);
   signal val_m        : std_logic_vector(G_SIZE-1 downto 0);
   signal val_2m       : std_logic_vector(G_SIZE-1 downto 0);

   signal x_prev       : std_logic_vector(2*G_SIZE-1 downto 0);
   signal x_cur        : std_logic_vector(2*G_SIZE-1 downto 0);
   signal x_new        : std_logic_vector(2*G_SIZE-1 downto 0);

   signal y_prev       : std_logic_vector(G_SIZE-1 downto 0);
   signal y_cur        : std_logic_vector(G_SIZE-1 downto 0);
   signal y_new        : std_logic_vector(G_SIZE-1 downto 0);

   signal z_cur        : std_logic_vector(G_SIZE-1 downto 0);
   signal z_new        : std_logic_vector(G_SIZE-1 downto 0);

   signal p_prev       : std_logic_vector(G_SIZE-1 downto 0);
   signal p_cur        : std_logic_vector(G_SIZE-1 downto 0);

   signal a_cur        : std_logic_vector(G_SIZE-1 downto 0);

   signal divmod_val_n : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_val_d : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_start : std_logic;
   signal divmod_valid : std_logic;
   signal divmod_res_q : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_res_r : std_logic_vector(G_SIZE-1 downto 0);

   signal amm_val_a    : std_logic_vector(G_SIZE-1 downto 0);
   signal amm_val_x    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_val_b    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_val_n    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal amm_start    : std_logic;
   signal amm_valid    : std_logic;
   signal amm_res      : std_logic_vector(2*G_SIZE-1 downto 0);

   signal mult_val1    : std_logic_vector(G_SIZE-1 downto 0);
   signal mult_val2    : std_logic_vector(G_SIZE-1 downto 0);
   signal mult_start   : std_logic;
   signal mult_valid   : std_logic;
   signal mult_res     : std_logic_vector(G_SIZE-1 downto 0);

   signal res_x        : std_logic_vector(2*G_SIZE-1 downto 0);
   signal res_y        : std_logic_vector(G_SIZE-1 downto 0);
   signal valid        : std_logic;

begin

   -- Calculate a_n and p_n such that z_n = a_n*y_n + p_n.
   divmod_val_n <= z_cur;
   divmod_val_d <= y_cur;

   a_cur <= divmod_res_q;
   p_cur <= divmod_res_r;

   -- Calculate y_(n+1) = y_(n-1) + a_n*[p_n - p_(n-1)].
   mult_val1 <= a_cur;
   mult_val2 <= p_cur - p_prev;

   y_new <= y_prev + mult_res;

   -- Calculate x_(n+1) = (a_n * x_n + x_(n-1)) mod N.
   amm_val_a <= a_cur;
   amm_val_x <= x_cur;
   amm_val_b <= x_prev;
   amm_val_n <= val_n;
   x_new     <= amm_res;

   -- Calcualte z_(n+1) = 2*M - p_n.
   z_new <= val_2m - p_cur;

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         res_x <= C_ZERO & C_ZERO;
         res_y <= C_ZERO;
         valid <= '0';

         case state is
            -- Store input values
            when IDLE_ST =>
               if start_i = '1' then
                  val_n  <= val_n_i;
                  val_m  <= val_m_i;
                  val_2m <= val_m_i(G_SIZE-2 downto 0) & '0';

                  -- Let x_(-1) = 1, x_0 = M, y_(-1) = 1, y_0 = N-M*M, z_0 = 2*M, p_(-1) = 0.
                  x_prev <= C_ZERO & C_ONE;
                  x_cur  <= C_ZERO & val_m_i;
                  y_prev <= C_ONE;
                  y_cur  <= val_y_i;
                  z_cur  <= val_m_i(G_SIZE-2 downto 0) & '0';
                  p_prev <= C_ZERO;

                  divmod_start <= '1';
                  state        <= CALC_A_ST;
               end if;

            -- Calculate a_n
            when CALC_A_ST =>
               divmod_start <= '0';
               if divmod_valid = '1' then
                  amm_start  <= '1';
                  mult_start <= '1';
                  state      <= CALC_XY_ST;
               end if;

            -- Calculate x_(n+1) and y_(n+1)
            when CALC_XY_ST =>
               amm_start  <= '0';
               mult_start <= '0';
               if amm_valid = '1' and mult_valid = '1' then
                  state <= UPDATE_ST;
               end if;

            when UPDATE_ST =>
               x_prev <= x_cur;
               x_cur  <= x_new;
               y_prev <= y_cur;
               y_cur  <= y_new;
               p_prev <= p_cur;
               z_cur  <= z_new;

               res_x  <= x_new;
               res_y  <= y_new;
               valid  <= '1';
               state  <= CALC_A_ST;

         end case;

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


   --------------------
   -- Instantiate MULT
   --------------------

   i_mult : entity work.mult
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => mult_val1,
      val2_i  => mult_val2,
      start_i => mult_start,
      res_o   => mult_res,
      valid_o => mult_valid
   ); -- i_mult

   res_x_o <= res_x;
   res_y_o <= res_y;
   valid_o <= valid;

end Behavioral;

