----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:14:10 08/18/2012 
-- Design Name: 
-- Module Name:    seg - Behavioral 
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

entity seg is
   port ( 
        clk_1kHz_i : in    std_logic;							  -- Clock input 1 kHz
        seg_ca_o   : out   std_logic_vector (6 downto 0); 
        seg_dp_o   : out   std_logic; 
        seg_an_o   : out   std_logic_vector (3 downto 0);
        dp_i       : in    std_logic_vector (3 downto 0);
        seg3_i     : in    std_logic_vector (6 downto 0);  -- First segment
        seg2_i     : in    std_logic_vector (6 downto 0);  -- Second segment
        seg1_i     : in    std_logic_vector (6 downto 0);  -- Third segment
        seg0_i     : in    std_logic_vector (6 downto 0)   -- Fourth segment
   );

end seg;

architecture Behavioral of seg is

	signal digit : integer range 0 to 3;				-- Current segment being displayed

begin

    count: process (clk_1kHz_i)
    begin
        if rising_edge(clk_1kHz_i) then
            if digit = 0 then
                digit <= 3;
            else
                digit <= digit - 1;
            end if;
        end if;
    end process;
	
    with digit select
        seg_dp_o <= not dp_i(3) when 3,
                    not dp_i(2) when 2,
                    not dp_i(1) when 1,
                    not dp_i(0) when others;

    with digit select
        seg_ca_o <= seg3_i when 3,
                    seg2_i when 2,
                    seg1_i when 1,
                    seg0_i when others;

    with digit select
        seg_an_o <= "0111" when 3,
                    "1011" when 2,
                    "1101" when 1,
                    "1110" when others;
  
end Behavioral;
