----------------------------------------------------------------------------------
-- Company:  Granbo
-- Engineer: Michael Jørgensen
-- 
-- The file contains the top level test bench for the timer_demo
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity queens_top_tb is
end queens_top_tb;

architecture Structural of queens_top_tb is

    constant NUM_QUEENS : integer := 4;
    constant FREQ       : integer := 5;

    -- Clock
    signal vga_clk   : std_logic;  -- 25 MHz

    -- LED, buttom, and switches
    signal led       : std_logic_vector (7 downto 0); 
    signal sw        : std_logic_vector (7 downto 0); 

    -- VGA port
    signal vga_hs    : std_logic; 
    signal vga_vs    : std_logic;
    signal vga_red   : std_logic_vector (2 downto 0); 
    signal vga_green : std_logic_vector (2 downto 0); 
    signal vga_blue  : std_logic_vector (2 downto 1); 

    -- Output segment display
    signal seg_ca    : std_logic_vector (6 downto 0);
    signal seg_dp    : std_logic;
    signal seg_an    : std_logic_vector (3 downto 0);

    signal board     : std_logic_vector (NUM_QUEENS*NUM_QUEENS-1 downto 0);
    signal num_solutions : std_logic_vector(13 downto 0);
    signal valid    : std_logic;
    signal done     : std_logic;
    signal enable   : std_logic;

    signal count     : integer;
 
    signal test_running : boolean := true;

begin

    -- Generate clock and reset
    vga_clk_gen : process
    begin
      if not test_running then
        wait;
      end if;

      vga_clk <= '1', '0' after 20 ns;
      wait for 40 ns;
    end process vga_clk_gen;

    rst_gen : process
    begin
      sw(0) <= '1', '0' after 100 ns;
      wait;
    end process rst_gen;

    sw(7 downto 1) <= "0000101"; -- Stop the stepping

    -- Instantiate DUT
    inst_queens_top : entity work.queens_top
    generic map (
        FREQ       => FREQ  ,
        NUM_QUEENS => NUM_QUEENS
        )
    port map (
        vga_clk_i   => vga_clk   ,
        sw_i        => sw        ,
        led_o       => led       ,
        board_o         => board         ,
        num_solutions_o => num_solutions ,
        valid_o         => valid         ,
        done_o          => done          ,
        enable_o        => enable         ,
        vga_hs_o    => vga_hs    ,
        vga_vs_o    => vga_vs    ,
        vga_red_o   => vga_red   ,
        vga_green_o => vga_green ,
        vga_blue_o  => vga_blue  
        );

    valid_count : process (vga_clk, sw(0))
        variable rows_or  : std_logic_vector(NUM_QUEENS-1 downto 0);
        constant ROW_ONES : std_logic_vector(NUM_QUEENS-1 downto 0) := (others => '1');
    begin
        if sw(0) = '1' then
            count <= 0;
        elsif rising_edge(vga_clk) then
            if valid = '1' and enable = '1' then
                count <= count + 1;
            end if;

            rows_or := (others => '0');
            for row in 0 to NUM_QUEENS-1 loop
                rows_or := rows_or or board(row*NUM_QUEENS + NUM_QUEENS-1 downto row*NUM_QUEENS);
            end loop;

            assert (valid = '0' or (rows_or = ROW_ONES));
            assert (done = '0' or (count = 2));
            if done = '1' then
              report "End of simulation.";
              test_running <= false;
            end if;
        end if;
    end process valid_count;
   
end Structural;

