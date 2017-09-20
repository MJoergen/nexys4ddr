----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:02:31 08/18/2012 
-- Design Name: 
-- Module Name:    int2dec - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity digit is
	generic (
		INC  : integer;
		BITS : integer
	);
	port (
		value_i  : in  std_logic_vector(BITS-1 downto 0);
		remain_o : out std_logic_vector(BITS-1 downto 0);
		seg_o    : out std_logic_vector(6 downto 0)
	);
end digit;

-- segment encoding
--      0
--     ---  
--  5 |   | 1
--     ---   <- 6
--  4 |   | 2
--     ---
--      3

architecture structural of digit is
begin
	process (value_i)
	begin
		seg_o <= "1111111";
		remain_o <= (others => '0');
		if value_i < INC then
			seg_o <= "1000000";
			remain_o <= value_i;
		elsif value_i < 2*INC then
			seg_o <= "1111001";
			remain_o <= value_i - INC;
		elsif value_i < 3*INC then
			seg_o <= "0100100";
			remain_o <= value_i - 2*INC;
		elsif value_i < 4*INC then
			seg_o <= "0110000";
			remain_o <= value_i - 3*INC;
		elsif value_i < 5*INC then
			seg_o <= "0011001";
			remain_o <= value_i - 4*INC;
		elsif value_i < 6*INC then
			seg_o <= "0010010";
			remain_o <= value_i - 5*INC;
		elsif value_i < 7*INC then
			seg_o <= "0000010";
			remain_o <= value_i - 6*INC;
		elsif value_i < 8*INC then
			seg_o <= "1111000";
			remain_o <= value_i - 7*INC;
		elsif value_i < 9*INC then
			seg_o <= "0000000";
			remain_o <= value_i - 8*INC;
		elsif value_i < 10*INC then
			seg_o <= "0010000";
			remain_o <= value_i - 9*INC;
		else
			seg_o <= "0111111";
			remain_o <= std_logic_vector(conv_unsigned(INC, BITS));
		end if;
	end process;
	
end structural;
