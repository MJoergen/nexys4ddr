library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
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

-- segment encoding
--      0
--     ---
--  5 |   | 1
--     ---   <- 6
--  4 |   | 2
--     ---
--      3

architecture synthesis of display_digit is
begin
	process (value_i)
	begin
		seg_o <= "1111111";
		remain_o <= (others => '0');
		if value_i < G_INC then
			seg_o <= "1000000";
			remain_o <= value_i;
		elsif value_i < 2*G_INC then
			seg_o <= "1111001";
			remain_o <= value_i - G_INC;
		elsif value_i < 3*G_INC then
			seg_o <= "0100100";
			remain_o <= value_i - 2*G_INC;
		elsif value_i < 4*G_INC then
			seg_o <= "0110000";
			remain_o <= value_i - 3*G_INC;
		elsif value_i < 5*G_INC then
			seg_o <= "0011001";
			remain_o <= value_i - 4*G_INC;
		elsif value_i < 6*G_INC then
			seg_o <= "0010010";
			remain_o <= value_i - 5*G_INC;
		elsif value_i < 7*G_INC then
			seg_o <= "0000010";
			remain_o <= value_i - 6*G_INC;
		elsif value_i < 8*G_INC then
			seg_o <= "1111000";
			remain_o <= value_i - 7*G_INC;
		elsif value_i < 9*G_INC then
			seg_o <= "0000000";
			remain_o <= value_i - 8*G_INC;
		elsif value_i < 10*G_INC then
			seg_o <= "0010000";
			remain_o <= value_i - 9*G_INC;
		else
			seg_o <= "0111111";
			remain_o <= std_logic_vector(conv_unsigned(G_INC, G_BITS));
		end if;
	end process;

end architecture synthesis;

