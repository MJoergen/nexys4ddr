----------------------------------------------------------------------------------
-- Company:  Granbo
-- Engineer: Michael Jørgensen
-- 
-- The file contains the top level test bench for the timer_demo
----------------------------------------------------------------------------------
library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;

entity basys2_tb is
end basys2_tb;

architecture Structural of basys2_tb is

    -- Clock and reset
    signal clk25  : std_logic;  -- 25 MHz

    -- VGA port
    signal vga_hs    : std_logic; 
    signal vga_vs    : std_logic;
    signal vga_col   : std_logic_vector ( 7 downto 0); 

    -- Switches
    signal sw        : std_logic_vector ( 7 downto 0);

    -- Buttons
    signal btn       : std_logic_vector( 3 downto 0);

    signal test_running : boolean := true;

begin

    -- Generate clock
    clk_gen : process
    begin
      if not test_running then
        wait;
      end if;

      clk25 <= '1', '0' after 20 ns; -- 25 MHz
      wait for 40 ns;
    end process clk_gen;

    -- Generate reset (asserted high)
    btn(3) <= '1', '0' after 100 ns;


    -- Generate input switches
    sw <= X"00";


    -- Generate input buttons
    btn(2 downto 0) <= "000";


    -- Instantiate DUT
    inst_basys2 : entity work.basys2
    port map (
       clk25_i    => clk25,
       vga_hs_o   => vga_hs,
       vga_vs_o   => vga_vs,
       vga_col_o  => vga_col,
       ps2_clk_i  => '1',
       ps2_data_i => '1',
       sw_i       => sw,
       btn_i      => btn
    );

    test_running <= true, false after 1000 us;
   
end Structural;

