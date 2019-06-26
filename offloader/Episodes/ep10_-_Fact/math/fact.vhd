library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This function of this module can be described by the following python pseudo code:
--
--    t = all_prim_prod
--    while True:
--        t = gmpy.gcd(v, t)
--        if t == 1:
--            break
--        v = gmpy.divexact(v, t)
--    return v
--

entity fact is
   generic (
      G_SIZE   : integer
   );
   port ( 
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;

      val_i    : in  std_logic_vector(G_SIZE-1 downto 0);
      primes_i : in  std_logic_vector(G_SIZE-1 downto 0);
      start_i  : in  std_logic;

      -- Outputs driven by this module
      res_o    : out std_logic_vector(G_SIZE-1 downto 0);
      busy_o   : out std_logic;
      valid_o  : out std_logic
   );
end fact;

architecture structural of fact is

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   constant C_ONE  : std_logic_vector(G_SIZE-1 downto 0) := to_stdlogicvector(1, G_SIZE);

   type fsm_state is (IDLE_ST, GCD_ST, DIV_ST);
   signal state : fsm_state;

   signal val       : std_logic_vector(G_SIZE-1 downto 0);
   signal primes    : std_logic_vector(G_SIZE-1 downto 0);

   signal gcd_start : std_logic;
   signal gcd_val1  : std_logic_vector(G_SIZE-1 downto 0);
   signal gcd_val2  : std_logic_vector(G_SIZE-1 downto 0);
   signal gcd_valid : std_logic;
   signal gcd_res   : std_logic_vector(G_SIZE-1 downto 0);

   signal div_start : std_logic;
   signal div_val1  : std_logic_vector(G_SIZE-1 downto 0);
   signal div_val2  : std_logic_vector(G_SIZE-1 downto 0);
   signal div_valid : std_logic;
   signal div_res   : std_logic_vector(G_SIZE-1 downto 0);

   signal res       : std_logic_vector(G_SIZE-1 downto 0);
   signal valid     : std_logic;

begin

   -- Calculate GCD(val, primes)
   gcd_val1 <= val;
   gcd_val2 <= primes;

   -- Calculate val/primes
   div_val1 <= val;
   div_val2 <= primes;

   p_fsm : process (clk_i) is
   begin
      if rising_edge(clk_i) then

         -- Default values
         gcd_start <= '0';
         div_start <= '0';
         valid     <= '0';

         case state is
            when IDLE_ST   =>
               if start_i = '1' then
                  val       <= val_i;
                  primes    <= primes_i;
                  gcd_start <= '1';
                  state     <= GCD_ST;
               end if;

            when GCD_ST =>
               if gcd_start = '0' and gcd_valid = '1' then
                  if gcd_res = C_ONE then
                     valid <= '1';
                     state <= IDLE_ST;
                  else
                     primes    <= gcd_res;
                     div_start <= '1';
                     state     <= DIV_ST;
                  end if;
               end if;

            when DIV_ST =>
               if div_start = '0' and div_valid = '1' then
                  val       <= div_res;
                  gcd_start <= '1';
                  state     <= GCD_ST;
               end if;

         end case;

         if rst_i = '1' then
            valid <= '0';
            state <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;


   -------------------
   -- Instantiate GCD
   -------------------

   i_gcd : entity work.gcd
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => gcd_val1,
      val2_i  => gcd_val2,
      start_i => gcd_start,
      res_o   => gcd_res,
      valid_o => gcd_valid
   ); -- i_gcd


   ------------------------
   -- Instantiate DIVEXACT
   ------------------------

   i_divexact : entity work.divexact
   generic map (
      G_SIZE => G_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => div_val1,
      val2_i  => div_val2,
      start_i => div_start,
      res_o   => div_res,
      valid_o => div_valid
   ); -- i_divexact


   --------------------------
   -- Connect output signals
   --------------------------

   res_o   <= val;
   valid_o <= valid;
   busy_o  <= '0' when state = IDLE_ST else '1';

end architecture structural;

