library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

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

   constant C_SEG_0   : std_logic_vector(6 downto 0) := "1000000";
   constant C_SEG_1   : std_logic_vector(6 downto 0) := "1111001";
   constant C_SEG_2   : std_logic_vector(6 downto 0) := "0100100";
   constant C_SEG_3   : std_logic_vector(6 downto 0) := "0110000";
   constant C_SEG_4   : std_logic_vector(6 downto 0) := "0011001";
   constant C_SEG_5   : std_logic_vector(6 downto 0) := "0010010";
   constant C_SEG_6   : std_logic_vector(6 downto 0) := "0000010";
   constant C_SEG_7   : std_logic_vector(6 downto 0) := "1111000";
   constant C_SEG_8   : std_logic_vector(6 downto 0) := "0000000";
   constant C_SEG_9   : std_logic_vector(6 downto 0) := "0010000";
   constant C_SEG_OFF : std_logic_vector(6 downto 0) := "1111111";

begin

   process (value_i)
   begin
      if value_i < G_INC then
         seg_o <= C_SEG_0;
         remain_o <= value_i;
      elsif value_i < 2*G_INC then
         seg_o <= C_SEG_1;
         remain_o <= value_i - G_INC;
      elsif value_i < 3*G_INC then
         seg_o <= C_SEG_2;
         remain_o <= value_i - 2*G_INC;
      elsif value_i < 4*G_INC then
         seg_o <= C_SEG_3;
         remain_o <= value_i - 3*G_INC;
      elsif value_i < 5*G_INC then
         seg_o <= C_SEG_4;
         remain_o <= value_i - 4*G_INC;
      elsif value_i < 6*G_INC then
         seg_o <= C_SEG_5;
         remain_o <= value_i - 5*G_INC;
      elsif value_i < 7*G_INC then
         seg_o <= C_SEG_6;
         remain_o <= value_i - 6*G_INC;
      elsif value_i < 8*G_INC then
         seg_o <= C_SEG_7;
         remain_o <= value_i - 7*G_INC;
      elsif value_i < 9*G_INC then
         seg_o <= C_SEG_8;
         remain_o <= value_i - 8*G_INC;
      elsif value_i < 10*G_INC then
         seg_o <= C_SEG_9;
         remain_o <= value_i - 9*G_INC;
      else
         seg_o <= C_SEG_OFF;
         remain_o <= (others => '0');
      end if;
   end process;

end architecture synthesis;

