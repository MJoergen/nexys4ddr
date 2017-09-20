----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:01:12 01/11/2013 
-- Design Name: 
-- Module Name:    cards - Behavioral 
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

entity cards is
   port ( 
			clk_i    : in  std_logic;
			rst_i    : in  std_logic;
			cards1_o : out std_logic_vector(7 downto 0);
			cards2_o : out std_logic_vector(7 downto 0);
			cards3_o : out std_logic_vector(7 downto 0);
			cards4_o : out std_logic_vector(7 downto 0);
            valid_o  : out std_logic;
            done_o   : out std_logic
			);

end cards;

architecture Behavioral of cards is
    signal cards1    : std_logic_vector(7 downto 0);
    signal cards2    : std_logic_vector(7 downto 0);
    signal cards3    : std_logic_vector(7 downto 0);
    signal cards4    : std_logic_vector(7 downto 0);

    signal invalid2 : std_logic_vector(7 downto 0);
    signal invalid3 : std_logic_vector(7 downto 0);
    signal invalid4 : std_logic_vector(7 downto 0);

    constant CARDS1_INIT : std_logic_vector(7 downto 0) := "10100000";
    constant CARDS2_INIT : std_logic_vector(7 downto 0) := "10010000";
    constant CARDS3_INIT : std_logic_vector(7 downto 0) := "10001000";
    constant CARDS4_INIT : std_logic_vector(7 downto 0) := "10000100";

    signal done : std_logic;

begin

    cards1_o <= cards1;
    cards2_o <= cards2;
    cards3_o <= cards3;
    cards4_o <= cards4;
    done_o   <= done;

    valid_o  <= '1' when invalid4 = "00000000" else '0';

    invalid2 <= cards1 and cards2;
    invalid3 <= invalid2 or ((cards1 or cards2) and cards3);
    invalid4 <= invalid3 or ((cards1 or cards2 or cards3) and cards4);
			
	process(clk_i, rst_i)
	begin
		if rst_i = '1' then
            cards1 <= CARDS1_INIT;
            cards2 <= CARDS2_INIT;
            cards3 <= CARDS3_INIT;
            cards4 <= CARDS4_INIT;
            done   <= '0';
		elsif rising_edge(clk_i) then
            if done = '0' then
              if cards4(0) = '0' and invalid3 = "00000000" then
                cards4 <= "0" & cards4(7 downto 1);
              else
                cards4 <= CARDS4_INIT;
                if cards3(0) = '0' and invalid2 = "00000000" then
                  cards3 <= "0" & cards3(7 downto 1);
                else
                  cards3 <= CARDS3_INIT;
                  if cards2(0) = '0' then
                    cards2 <= "0" & cards2(7 downto 1);
                  else
                    cards2 <= CARDS2_INIT;
                    if cards1(0) = '0' then
                      cards1 <= "0" & cards1(7 downto 1);
                    else
                      done <= '1';
                    end if;
                  end if;
                end if;
              end if;
            end if;

		end if;
	 
	end process;

end Behavioral;

