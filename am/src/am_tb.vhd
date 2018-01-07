----------------------------------------------------------------------------------
-- Company:  Granbo
-- Engineer: Michael Jørgensen
-- 
-- The file contains the top level test bench for the timer_demo
----------------------------------------------------------------------------------
library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;

entity am_tb is
   generic (
      G_SIMULATION : string := ""
   );
end am_tb;

architecture Structural of am_tb is

    -- Clock and reset
    signal clk  : std_logic;  -- 100 MHz
    signal rstn : std_logic := '1';

    -- VGA port
    signal vga_hs    : std_logic; 
    signal vga_vs    : std_logic;
    signal vga_col   : std_logic_vector(11 downto 0); 

    -- Switches
    signal sw        : std_logic_vector( 7 downto 0);

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

      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
    end process clk_gen;

    -- Generate reset (asserted low)
    rstn <= '0', '1' after 100 ns;


    -- Generate input switches
    sw <= X"FF";


    -- Generate input buttons
    btn <= "0000";


    -- Instantiate DUT
    inst_am : entity work.am
    generic map (
       G_SIMULATION => G_SIMULATION 
    )
    port map (
       clk_i     => clk,
       rstn_i    => rstn,
       vga_hs_o  => vga_hs,
       vga_vs_o  => vga_vs,
       vga_col_o => vga_col,
       sw_i      => sw,
       btn_i     => btn
    );

    test_running <= true, false after 1000 us;
   
end Structural;

