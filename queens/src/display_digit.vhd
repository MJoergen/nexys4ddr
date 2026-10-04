library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_digit is
   generic (
      G_INC  : integer;
      G_BITS : integer
   );
   port (
      value_i  : in  std_logic_vector(G_BITS-1 downto 0);
      remain_o : out std_logic_vector(G_BITS-1 downto 0);
      seg_o    : out std_logic_vector(6 downto 0)
   );
end display_digit;

architecture synthesis of display_digit is

-- segment encoding
--      0
--     ---
--  5 |   | 1
--     ---   <- 6
--  4 |   | 2
--     ---
--      3

   type seg_vector is array(0 to 9) of std_logic_vector(6 downto 0);
   constant C_SEG : seg_vector := (
      "1000000",  -- 0
      "1111001",  -- 1
      "0100100",  -- 2
      "0110000",  -- 3
      "0011001",  -- 4
      "0010010",  -- 5
      "0000010",  -- 6
      "1111000",  -- 7
      "0000000",  -- 8
      "0010000"); -- 9
   constant C_SEG_OFF : std_logic_vector(6 downto 0) := "1111111";

begin

   process (value_i)
      variable value : unsigned(G_BITS-1 downto 0);
   begin
      value    := unsigned(value_i);
      seg_o    <= C_SEG_OFF;
      remain_o <= (others => '0');
      for d in 9 downto 0 loop
         if value >= d*G_INC then
            seg_o    <= C_SEG(d);
            remain_o <= std_logic_vector(value - d*G_INC);
            exit;
         end if;
      end loop;
      if value >= 10*G_INC then
         seg_o    <= C_SEG_OFF;
         remain_o <= (others => '0');
      end if;
   end process;

end architecture synthesis;
