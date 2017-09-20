----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/25/2014 02:10:40 PM
-- Design Name: 
-- Module Name: vga_ctrl - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description:  This generates the horizontal and vertical synchronization signals
--               for a VGA display with 1280 * 1024 @ 60 Hz refresh rate.
--               User must supply a 108 MHz clock on the input.
--               This is because 1688 * 1066 * 60 Hz = 107,96 MHz.
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
use IEEE.std_logic_unsigned.all;
use ieee.math_real.all;


-- simulation library
library UNISIM;
use UNISIM.VComponents.all;

-- the vga_ctrl entity declaration
entity vga_ctrl is
    port (
        rst_i     : in std_logic;
        vga_clk_i : in std_logic;

        hs_o      : out std_logic;
        vs_o      : out std_logic;
        hcount_o  : out std_logic_vector(11 downto 0);
        vcount_o  : out std_logic_vector(11 downto 0);
        blank_o   : out std_logic
    );
end vga_ctrl;

architecture Behavioral of vga_ctrl is

    constant FRAME_WIDTH  : natural := 1280;
    constant FRAME_HEIGHT : natural := 1024;

    constant H_FP  : natural := 48;     --H front porch width (pixels)
    constant H_PW  : natural := 112;    --H sync pulse width (pixels)
    constant H_MAX : natural := 1688;   --H total period (pixels)

    constant V_FP  : natural := 1;      --V front porch width (lines)
    constant V_PW  : natural := 3;      --V sync pulse width (lines)
    constant V_MAX : natural := 1066;   --V total period (lines)

    constant H_POL : std_logic := '1';
    constant V_POL : std_logic := '1';

    -------------------------------------------------------------------------

    -- VGA Controller specific signals: Counters, Sync, R, G, B

    -------------------------------------------------------------------------
    -- Pixel clock, in this case 108 MHz
    signal vga_clk : std_logic;
    -- The active signal is used to signal the active region of the screen (when not blank)
    signal active  : std_logic;
    signal active_dly  : std_logic;

    -- Horizontal and Vertical counters
    signal h_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
    signal v_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');

    -- Pipe Horizontal and Vertical Counters
    signal h_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');
    signal v_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');

    -- Horizontal and Vertical Sync
    signal h_sync_reg : std_logic := not(H_POL);
    signal v_sync_reg : std_logic := not(V_POL);
    -- Pipe Horizontal and Vertical Sync
    signal h_sync_reg_dly : std_logic := not(H_POL);
    signal v_sync_reg_dly : std_logic :=  not(V_POL);

begin

    -- Assign outputs
    hs_o     <= h_sync_reg_dly;
    vs_o     <= v_sync_reg_dly;
    hcount_o <= h_cntr_reg_dly;
    vcount_o <= v_cntr_reg_dly;
    blank_o  <= not active_dly;

    ---------------------------------------------------------------

    -- Generate Horizontal, Vertical counters and the Sync signals

    ---------------------------------------------------------------
    -- Horizontal counter
    process (vga_clk)
    begin
        if (rising_edge(vga_clk)) then
            if (h_cntr_reg = (H_MAX - 1)) then
                h_cntr_reg <= (others =>'0');
            else
                h_cntr_reg <= h_cntr_reg + 1;
            end if;
        end if;
    end process;

    -- Vertical counter
    process (vga_clk)
    begin
        if (rising_edge(vga_clk)) then
            if ((h_cntr_reg = (H_MAX - 1)) and (v_cntr_reg = (V_MAX - 1))) then
                v_cntr_reg <= (others =>'0');
            elsif (h_cntr_reg = (H_MAX - 1)) then
                v_cntr_reg <= v_cntr_reg + 1;
            end if;
        end if;
    end process;

    -- Horizontal sync
    process (vga_clk)
    begin
        if (rising_edge(vga_clk)) then
            if (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) and (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1)) then
                h_sync_reg <= H_POL;
            else
                h_sync_reg <= not(H_POL);
            end if;
        end if;
    end process;

    -- Vertical sync
    process (vga_clk)
    begin
        if (rising_edge(vga_clk)) then
            if (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) and (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1)) then
                v_sync_reg <= V_POL;
            else
                v_sync_reg <= not(V_POL);
            end if;
        end if;
    end process;

    --------------------

    -- The active 

    --------------------  
    -- active signal
    active <= '1' when h_cntr_reg < FRAME_WIDTH and v_cntr_reg < FRAME_HEIGHT
              else '0';


    -- Register Outputs
    process (vga_clk)
    begin
        if (rising_edge(vga_clk)) then
            h_sync_reg_dly <= h_sync_reg;
            v_sync_reg_dly <= v_sync_reg;
            h_cntr_reg_dly <= h_cntr_reg;
            v_cntr_reg_dly <= v_cntr_reg;
            active_dly     <= active;
        end if;
    end process;

end Behavioral;

