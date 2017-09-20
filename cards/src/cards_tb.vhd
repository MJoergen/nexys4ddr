----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:01:12 01/11/2013 
-- Design Name: 
-- Module Name:    dragon - Behavioral 
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

entity cards_tb is
end cards_tb;

architecture Behavioral of cards_tb is

  signal clk    : std_logic;
  signal rst    : std_logic;
  signal cards1 : std_logic_vector(7 downto 0);
  signal cards2 : std_logic_vector(7 downto 0);
  signal cards3 : std_logic_vector(7 downto 0);
  signal cards4 : std_logic_vector(7 downto 0);
  signal valid  : std_logic;
  signal done   : std_logic;
  signal count  : integer range 0 to 100000;
  signal test_running : boolean := true;

begin

    inst_cards : entity work.cards
        port map (
			clk_i => clk,
			rst_i => rst,
			cards1_o => cards1,
			cards2_o => cards2,
			cards3_o => cards3,
			cards4_o => cards4,
            valid_o  => valid,
            done_o   => done
            );
  
    rst_driver : rst <= '1', '0' after 40 ns;

	clk_driver : process
	begin
        if not test_running then
            wait;
        end if;

        clk <= '1', '0' after 10 ns;
        wait for 20 ns;
    end process clk_driver;

    valid_count : process (clk, rst)
    begin
      if rst = '1' then
        count <= 0;
      elsif rising_edge(clk) then

        if valid = '1' then
          count <= count + 1;
        end if;

        assert (valid = '0' or ((cards1 or cards2 or cards3 or cards4) = "11111111"));
        assert (done = '0' or (count = 2));
        if done = '1' then
          test_running <= false;
        end if;
      end if;
    end process valid_count;

end Behavioral;

