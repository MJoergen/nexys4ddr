----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/25/2014 02:10:40 PM
-- Design Name: 
-- Module Name: vga_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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
--use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.std_logic_unsigned.all;
--use ieee.math_real.all;

entity vga_tb is
end vga_tb;

architecture Behavioral of vga_tb is

    signal CLK          : STD_LOGIC;
    signal VGA_HS       : STD_LOGIC;
    signal VGA_VS       : STD_LOGIC;
    signal VGA_RED      : STD_LOGIC_VECTOR (3 downto 0);
    signal VGA_BLUE     : STD_LOGIC_VECTOR (3 downto 0);
    signal VGA_GREEN    : STD_LOGIC_VECTOR (3 downto 0);
    signal PS2_CLK      : STD_LOGIC;
    signal PS2_DATA     : STD_LOGIC;

begin

    -- Generate clock
    vga_clk_gen : process
    begin
        clk <= '1', '0' after 5 ns;
    end process vga_clk_gen;

    -- Instantiate DUT
    inst_vgda : entity work.vga
    port map (
           CLK_I        => CLK        ,
           VGA_HS_O     => VGA_HS     ,
           VGA_VS_O     => VGA_VS     ,
           VGA_RED_O    => VGA_RED    ,
           VGA_BLUE_O   => VGA_BLUE   ,
           VGA_GREEN_O  => VGA_GREEN  ,
           PS2_CLK      => PS2_CLK    ,
           PS2_DATA     => PS2_DATA   );

end Behavioral;

