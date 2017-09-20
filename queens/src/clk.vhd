----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:34:58 08/18/2012 
-- Design Name: 
-- Module Name:    clk - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity clk is

	generic (
		SCALER : integer range 2 to 1000000
		);
		
   port ( 
			clk_i : in  std_logic;
			clk_o : out std_logic
			);
			
end clk;

architecture Behavioral of clk is

	signal count : integer range 0 to 1000000;

begin

	process (clk_i)
	begin
		if rising_edge(clk_i) then
			if count < SCALER/2 then
				clk_o <= '0';
				count <= count + 1;
			elsif count < SCALER-1 then
				clk_o <= '1';
				count <= count + 1;
			else
				clk_o <= '1';
				count <= 0;
			end if;
		end if;
	end process;


end Behavioral;

