library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module takes an integer N and calculates the integer square root
-- M = floor(sqrt(N)) as well as the remainder N-M*M.

-- The algorithm is taken from
-- https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2)
-- and uses a fixed number of clock cycles each time, equal to G_SIZE.

-- The value N is presented on the input bus val_i, and the input signal
-- start_i is pulsed once. Some time later the result will be present on the
-- output busses res_o and diff_o, and the output signal valid_o will be held
-- high.  val_i and start_i only need to be valid for a single clock cycle.
-- However, res_o and diff_o will remain valid until the next time start_i is
-- asserted.

-- There is an extra signal busy_o which is asserted when a calculation is in
-- progress. It is not possible to interrupt a calculation, and asserting
-- start_i will be ignored as long as busy_o is asserted.

entity sqrt is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val_i   : in  std_logic_vector(2*G_SIZE-1 downto 0);  -- N
      start_i : in  std_logic;
      res_o   : out std_logic_vector(G_SIZE-1 downto 0);    -- M = floor(sqrt(N))
      diff_o  : out std_logic_vector(G_SIZE-1 downto 0);    -- N - M*M
      busy_o  : out std_logic;
      valid_o : out std_logic
   );
end sqrt;

architecture Behavioral of sqrt is

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   type fsm_state is (IDLE_ST, CALC_ST);
   signal state_r  : fsm_state;

   signal val_r    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal bit_r    : std_logic_vector(2*G_SIZE-1 downto 0);

   signal res_r    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal valid_r  : std_logic;

begin

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then

         case state_r is
            when IDLE_ST =>
               if start_i = '1' then
                  val_r   <= val_i; -- Store input value
                  bit_r   <= "01" & to_stdlogicvector(0, 2*G_SIZE-2);
                  res_r   <= (others => '0');
                  valid_r <= '0';
                  state_r <= CALC_ST;
               end if;

            when CALC_ST =>
               if val_r >= (res_r or bit_r) then
                  val_r <= val_r - (res_r or bit_r);
                  res_r <= ("0" & res_r(2*G_SIZE-1 downto 1)) or bit_r;
               else
                  res_r <= ("0" & res_r(2*G_SIZE-1 downto 1));
               end if;

               bit_r   <= "00" & bit_r(2*G_SIZE-1 downto 2);
               state_r <= CALC_ST;

               if bit_r(0) = '1' then
                  valid_r <= '1';
                  state_r <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            res_r   <= (others => '0');
            val_r   <= (others => '0');
            valid_r <= '0';
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;


   -- Connect output signals
   res_o   <= res_r(G_SIZE-1 downto 0);
   diff_o  <= val_r(G_SIZE-1 downto 0);
   valid_o <= valid_r;
   busy_o  <= '0' when state_r = IDLE_ST else '1';

end Behavioral;

