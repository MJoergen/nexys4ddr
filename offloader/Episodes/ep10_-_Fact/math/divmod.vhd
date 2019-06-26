library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module calculates the division n/d = q + r/d,
-- and returns the quotient q and remainder d.
-- The algorithm is identical to the old-school method
-- using repeated subtractions.
-- The running time is proportional to the number of bits
-- in the quotient. In other words, to the difference in size
-- of the numerator and the denominator.

-- The values N and D are presented on the input busses val_n_i and val_d_i,
-- and the input signal start_i is pulsed once. Some time later the result will
-- be present on the output busses res_q_o and res_r_o, and the output signal
-- valid_o will be held high. The result will remain valid until the next
-- time start_i is asserted.

-- There is an extra signal busy_o which is asserted when a calculation is in
-- progress. It is not possible to interrupt a calculation, and asserting
-- start_i will be ignored as long as busy_o is asserted.

entity divmod is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val_n_i : in  std_logic_vector(G_SIZE-1 downto 0);
      val_d_i : in  std_logic_vector(G_SIZE-1 downto 0);
      start_i : in  std_logic;
      res_q_o : out std_logic_vector(G_SIZE-1 downto 0);
      res_r_o : out std_logic_vector(G_SIZE-1 downto 0);
      busy_o  : out std_logic;
      valid_o : out std_logic
   );
end divmod;

architecture Behavioral of divmod is

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   constant C_ONE  : std_logic_vector(G_SIZE-1 downto 0) := to_stdlogicvector(1, G_SIZE);

   type fsm_state is (IDLE_ST, SHIFT_ST, REDUCE_ST);
   signal state : fsm_state;

   signal val_d : std_logic_vector(G_SIZE downto 0);
   signal shift : integer range 0 to G_SIZE-1;

   -- Output signals
   signal res_q : std_logic_vector(G_SIZE-1 downto 0);
   signal res_r : std_logic_vector(G_SIZE downto 0);
   signal valid : std_logic;

begin

   p_fsm : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         case state is
            -- Store the input values
            when IDLE_ST =>
               if start_i = '1' then
                  val_d <= '0' & val_d_i;
                  shift <= 0;
                  res_q <= (others => '0');
                  res_r <= '0' & val_n_i;
                  valid <= '0';
                  state <= SHIFT_ST;
               end if;

            -- Shift the denominator, until it is larger than the numerator
            when SHIFT_ST =>
               if res_r > val_d then
                  val_d <= val_d(G_SIZE-1 downto 0) & '0';
                  shift <= shift + 1;
               else
                  state <= REDUCE_ST;
               end if;

            -- Subtract the denominator from the numerator.
            when REDUCE_ST =>
               if res_r >= val_d then
                  res_r <= res_r - val_d;
                  res_q <= res_q(G_SIZE-2 downto 0) & '1';
               else
                  res_q <= res_q(G_SIZE-2 downto 0) & '0';
               end if;
               val_d <= '0' & val_d(G_SIZE downto 1);

               if shift > 0 then
                  assert val_d(0) = '0';
                  shift <= shift - 1;
               else
                  valid <= '1';
                  state <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            res_q <= (others => '0');
            res_r <= (others => '0');
            valid <= '0';
            state <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   res_q_o <= res_q;
   res_r_o <= res_r(G_SIZE-1 downto 0);
   valid_o <= valid;
   busy_o  <= '0' when state = IDLE_ST else '1';

end Behavioral;

