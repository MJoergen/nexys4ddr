----------------------------------------------------------------------------------
-- Company:  Granbo
-- Engineer: Michael Jørgensen
-- 
-- The file contains the top level test bench for the timer_demo
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity beta_tb is
end beta_tb;

architecture Structural of beta_tb is

    -- Clock and reset
    signal clk   : std_logic;  -- 100 MHz
    signal rstn  : std_logic := '0';

    -- VGA port
    signal vga_hs    : std_logic; 
    signal vga_vs    : std_logic;
    signal vga_red   : std_logic_vector (3 downto 0); 
    signal vga_green : std_logic_vector (3 downto 0); 
    signal vga_blue  : std_logic_vector (3 downto 0); 

    -- Switches
    signal sw        : std_logic_vector (15 downto 0);

    -- Buttons
    signal btnc      : std_logic;
    signal btnl      : std_logic;

    signal test_running : boolean := true;

begin

    -- Generate clock
    clk_gen : process
    begin
      if not test_running then
        wait;
      end if;

      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
    end process clk_gen;

    -- Generate reset
    rstn <= '0', '1' after 20 ns;


    -- Generate input switches
    sw <= X"FFFF";


    -- Generate input buttons
    btnc <= '0';
    btnl <= '0';


    -- Instantiate DUT
    inst_beta : entity work.beta
    port map (
        clk_i       => clk,
        rstn_i      => rstn,         -- Active low
        vga_hs_o    => vga_hs,
        vga_vs_o    => vga_vs,
        vga_red_o   => vga_red,
        vga_green_o => vga_green,
        vga_blue_o  => vga_blue,
        sw_i        => sw,
        btnc_i      => btnc,
        btnl_i      => btnl
        );

    test_running <= true, false after 1000 us;
   
end Structural;

