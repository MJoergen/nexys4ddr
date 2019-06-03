library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module performa the Continued Fraction calculations.
-- Specifically, it performs repeated steps of the following
-- recurrence relation:
-- The inputs are the values of N and M = [sqrt(N)].
-- Given x_(-1) = 1, x_0 = M, y_(-1) = 1, y_0 = N-M*M, z_0 = 2*M, p_(-1) = 0.

-- For each n calculate
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
      start_i : in  std_logic;
      res_q_o : out std_logic_vector(G_SIZE-1 downto 0);
      res_r_o : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o : out std_logic
   );
end cf;

architecture Behavioral of cf is

   type fsm_state is (IDLE_ST, CALC_A_ST, CALC_XY_ST, UPDATE_ST);
   signal state_r  : fsm_state;

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
   signal p_new        : std_logic_vector(G_SIZE-1 downto 0);

   signal divmod_val_n : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_val_d : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_start : std_logic;
   signal divmod_valid : std_logic;
   signal divmod_res_q : std_logic_vector(G_SIZE-1 downto 0);
   signal divmod_res_r : std_logic_vector(G_SIZE-1 downto 0);

   signal mult_x_val1  : std_logic_vector(G_SIZE-1 downto 0);
   signal mult_x_val2  : std_logic_vector(G_SIZE-1 downto 0);
   signal mult_x_start : std_logic;
   signal mult_x_valid : std_logic;
   signal mult_x_res   : std_logic_vector(G_SIZE-1 downto 0);

   signal mult_y_val1  : std_logic_vector(G_SIZE-1 downto 0);
   signal mult_y_val2  : std_logic_vector(G_SIZE-1 downto 0);
   signal mult_y_start : std_logic;
   signal mult_y_valid : std_logic;
   signal mult_y_res   : std_logic_vector(G_SIZE-1 downto 0);

begin

   -- Calculate a_n and p_n such that z_n = a_n*y_n + p_n.
   divmod_val_n <= z_cur;
   divmod_val_d <= y_cur;

   a_cur <= divmod_req_q;
   p_cur <= divmod_req_r;

   -- Calculate y_(n+1) = y_(n-1) + a_n*[p_n - p_(n-1)].
   mult_y_val1 <= a_cur;
   mult_y_val2 <= p_cur - p_prev;

   y_new <= y_prev + mult_y_res;

   -- Calcualte x_(n+1) = (a_n * x_n + x_(n-1)) mod N.
   mult_x_val1 <= a_cur;
   mult_x_val2 <= x_cur;
   x_new <= mult_x_res + x_prev;

   -- Calcualte z_(n+1) = 2*M - p_n.
   z_new <= val_2m - p_cur;

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case state is
            -- Store input values
            when IDLE_ST =>
               if valid_i = '1' then
                  val_n  <= val_n_i;
                  val_m  <= val_m_i;
                  val_2m <= val_m_i(G_SIZE-2 downto 0) & '0';
                  state  <= CALC_ST;
               end if;

            -- Calculate a_n
            when CALC_A_ST =>
               divmod_start <= '1';

               if divmod_valid = '1' then
                  divmod_start <= '0';
                  state <= CALC_XY_ST;
               end if;

            -- Calculate x_(n+1) and y_(n+1)
            when CALC_XY_ST =>
               mult_x_start <= '1';
               mult_y_start <= '1';

               if mult_x_valid = '1' and mult_y_valid = '1' then
                  mult_x_start <= '0';
                  mult_y_start <= '0';
                  state <= UPDATE_ST;
               end if;

            when UPDATE_ST =>
               x_prev <= x_cur;
               x_cur  <= x_new;
               y_prev <= y_cur;
               y_cur  <= y_new;
               p_prev <= p_cur;
               p_cur  <= p_new;
               z_cur  <= z_new;

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
   -- Instantiate MULT_X
   ----------------------

   i_mult_x : entity mult
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => mult_x_val1,
      val2_i  => mult_x_val2,
      start_i => mult_x_start,
      res_o   => mult_x_res,
      valid_o => mult_x_valid
   ); -- i_mult_x


   ----------------------
   -- Instantiate MULT_Y
   ----------------------

   i_mult_y : entity mult
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => mult_y_val1,
      val2_i  => mult_y_val2,
      start_i => mult_y_start,
      res_o   => mult_y_res,
      valid_o => mult_y_valid
   ); -- i_mult_y


end Behavioral;

