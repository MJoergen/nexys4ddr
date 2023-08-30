library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This computes the exact quotient of q = val1 / val2.
-- It is required that the division is exact, i.e. that there is no remainder.
-- In other words, the algorithm assumes that val1 = q * val2.

entity divexact is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val1_i  : in  std_logic_vector(G_SIZE-1 downto 0);
      val2_i  : in  std_logic_vector(G_SIZE-1 downto 0);
      start_i : in  std_logic;
      res_o   : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o : out std_logic
   );
end divexact;

architecture structural of divexact is

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   type fsm_state is (IDLE_ST, REDUCING_ST, WORKING_ST, DONE_ST);
   signal state : fsm_state;

   signal val1  : std_logic_vector(G_SIZE-1 downto 0);
   signal val2  : std_logic_vector(G_SIZE-1 downto 0);

   signal index : integer range 0 to G_SIZE-1;
   signal valid : std_logic;

begin

   p_fsm : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST =>
               if start_i = '1' then
                  val1  <= val1_i;
                  val2  <= val2_i;
                  index <= 0;
                  valid <= '0';
                  state <= REDUCING_ST;
               end if;

            when REDUCING_ST =>
               if val1(0) = '0' and val2(0) = '0' then
                  val1 <= "0" & val1(G_SIZE-1 downto 1);
                  val2 <= "0" & val2(G_SIZE-1 downto 1);
               else
                  -- At this stage val2 will always be odd, because the division is assumed to be exact.
                  assert val2(0) = '1';
                  val2(0) <= '0';   -- Clear the LSB
                  state   <= WORKING_ST;
               end if;

            when WORKING_ST =>
               if val1(index) = '1' then
                  val1 <= val1 - val2;
               end if;
               val2  <= val2(G_SIZE-2 downto 0) & "0"; -- Multiply by 2

               if or(val1(G_SIZE-1 downto index)) = '0' then
                  state <= DONE_ST;
               else
                  index <= index + 1;
               end if;

            when DONE_ST =>
               valid <= '1';
               state <= IDLE_ST;
         end case;

         if rst_i = '1' then
            val1  <= C_ZERO;
            state <= IDLE_ST;
            valid <= '0';
         end if;
      end if;
   end process p_fsm;

   -- Connect output signals
   res_o   <= val1;
   valid_o <= valid;

end structural;

