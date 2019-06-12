-- This implements the Binary Euclidian Algorithm.
-- Pseudo-code is as follows:
--   unsigned int gcd(unsigned int a, unsigned int b)
--   {
--     if (a == 0 || b == 0)
--       return 0;
--     if (a == 1 || b == 1)
--       return 1;
--     if ((a%2)==0 && (b%2)==0)
--       return 2*gcd(a/2, b/2); // Both even
--     if ((a%2)==1 && (b%2)==0)
--       return gcd(a, b/2); // b even
--     if ((a%2)==0 && (b%2)==1)
--       return gcd(a/2, b); // a even
--     // Now both are odd
--     if (a > b)
--       return gcd((a-b)/2, b);
--     if (a < b)
--       return gcd((b-a)/2, a);
--     // a == b
--     return a;
--   } // end of gcd


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity gcd is
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
end gcd;

architecture Behavioral of gcd is

   signal val1  : std_logic_vector(G_SIZE-1 downto 0);
   signal val2  : std_logic_vector(G_SIZE-1 downto 0);

   signal shift : integer range 0 to G_SIZE-1;

   type fsm_state is (IDLE_ST, REDUCE_ST, SHIFTING_ST, DONE_ST);

   signal state : fsm_state;

begin

   res_o   <= val1 when state = DONE_ST else (others => '0');
   valid_o <= '1'  when state = DONE_ST else '0';

   p_fsm : process (clk_i) is
      variable res1 : std_logic_vector(G_SIZE-1 downto 0);
      variable res2 : std_logic_vector(G_SIZE-1 downto 0);
      constant zero : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
      constant one  : std_logic_vector(G_SIZE-1 downto 0) := to_stdlogicvector(1, G_SIZE);
      variable c : std_logic_vector(1 downto 0);
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST =>
               if start_i = '1' then
                  val1  <= val1_i;
                  val2  <= val2_i;
                  shift <= 0;
                  state <= REDUCE_ST;
               end if;

            when REDUCE_ST =>
               if val1 = zero or val2 = zero then
                  val1 <= (others => '0');
                  state <= DONE_ST;
               elsif val1 = one or val2 = one then
                  val1 <= one;
                  val2 <= one;
                  state <= SHIFTING_ST;
               else
                  if val1(0) = '0' and  val2(0) = '0' then
                     shift <= shift + 1; -- both are even, remember this!
                  end if;

                  if val1(0) = '0' then
                     val1 <= '0' & val1(G_SIZE-1 downto 1); -- Divide by two
                  end if;

                  if val2(0) = '0' then
                     val2 <= '0' & val2(G_SIZE-1 downto 1); -- Divide by two
                  end if;

                  if val1(0) = '1' and val2(0) = '1' then
                            -- Skip away the '1' bit at the zero position. We
                            -- won't need that anymore.
                            -- We must, however, have an extra zero in front,
                            -- to detect overflow (negative results).
                     res1 := ('0' & val1(G_SIZE-1 downto 1)) - ('0' & val2(G_SIZE-1 downto 1));
                     res2 := ('0' & val2(G_SIZE-1 downto 1)) - ('0' & val1(G_SIZE-1 downto 1));

                     c := res1(G_SIZE-1 downto G_SIZE-1) & res2(G_SIZE-1 downto G_SIZE-1);
                     case c is
                        when "00" =>
                                    -- val1 and val2 are equal. Now we're almost done.
                           state <= SHIFTING_ST;

                        when "01" => 
                           val1 <= res1;

                        when "10" => 
                           val2 <= res2;

                        when others =>  -- This should never happen.
                           assert false;
                           null;
                     end case;
                  end if;
               end if;

            when SHIFTING_ST =>
               if shift > 0 then
                  val1  <= val1(G_SIZE-2 downto 0) & '0'; -- Multiply by 2
                  shift <= shift - 1;
               else
                  state <= DONE_ST;
               end if;

            when DONE_ST =>
               if start_i = '0' then
                  state <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            val1  <= zero;
            val2  <= zero;
            shift <= 0;
            state <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

end Behavioral;

