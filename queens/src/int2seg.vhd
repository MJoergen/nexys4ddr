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

entity int2seg is
    port (
        int_i  : in  std_logic_vector(13 downto 0);
        seg3_o : out std_logic_vector( 6 downto 0);
        seg2_o : out std_logic_vector( 6 downto 0);
        seg1_o : out std_logic_vector( 6 downto 0);
        seg0_o : out std_logic_vector( 6 downto 0);
        dp_o   : out std_logic_vector( 4 downto 1)
    );
end int2seg;

architecture Behavioral of int2seg is

    signal remain1 : std_logic_vector( 7 downto 0);
    signal remain2 : std_logic_vector(10 downto 0);
    signal remain3 : std_logic_vector(13 downto 0);

begin

    inst_seg3 : entity work.digit
    generic map (
        INC  => 1000,
        BITS => 14
        )
    port map (
        value_i  => int_i,
        remain_o => remain3,
        seg_o    => seg3_o
        );
	
    inst_seg2 : entity work.digit
    generic map (
        INC  => 100,
        BITS => 11
        )
    port map (
        value_i  => remain3(10 downto 0),
        remain_o => remain2,
        seg_o    => seg2_o
        );

    inst_seg1 : entity work.digit
    generic map (
        INC  => 10,
        BITS => 8
        )
    port map (
        value_i  => remain2(7 downto 0),
        remain_o => remain1,
        seg_o    => seg1_o
        );

    inst_seg0 : entity work.digit
    generic map (
        INC  => 1,
        BITS => 5
        )
    port map (
        value_i  => remain1(4 downto 0),
        remain_o => open,
        seg_o    => seg0_o
        );
	
    dp_o <= "0000";

end Behavioral;

