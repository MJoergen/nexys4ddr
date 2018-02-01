----------------------------------------------------------------------------------
-- Company:  Granbo
-- Engineer: Michael Jørgensen
-- 
-- The file contains the top level test bench for the timer_demo
----------------------------------------------------------------------------------
library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;

entity nexys4ddr_tb is
end nexys4ddr_tb;

architecture Structural of nexys4ddr_tb is

    -- Clock and reset
    signal clk100  : std_logic;  -- 100 MHz
    signal sys_rstn : std_logic := '1';

    -- VGA port
    signal vga_hs    : std_logic; 
    signal vga_vs    : std_logic;
    signal vga_col   : std_logic_vector (11 downto 0); 

    -- Switches
    signal sw        : std_logic_vector (15 downto 0);

    -- Buttons
    signal btn       : std_logic_vector( 4 downto 0);

    signal test_running : boolean := true;

begin

    -- Generate clock
    clk_gen : process
    begin
      if not test_running then
        wait;
      end if;

      clk100 <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
    end process clk_gen;

    -- Generate reset (asserted low)
    sys_rstn <= '0', '1' after 100 ns;


    -- Generate input switches
    sw <= X"0000";


    -- Generate input buttons
    btn <= "00000";


    -- Instantiate DUT
    inst_nexys4ddr : entity work.nexys4ddr
    port map (
       clk100_i   => clk100,
       sys_rstn_i => sys_rstn,
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

