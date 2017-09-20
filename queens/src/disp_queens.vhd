--------------------------------------------------------------------------------
-- Company: 	    Granbo
-- Engineer:	    Michael Jørgensen
--
-- Create Date:    
-- Design Name:    
-- Module Name:     disp_cells
-- Project Name:   
-- Target Device:  
-- Tool versions:  
-- Description:	    Generates a background VGA image.
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.bitmap_pkg.ALL;

entity disp_queens is
    generic (
        NUM_QUEENS: integer
        );
    port (
        vga_clk_i : in  std_logic; -- Currently not used

        hcount_i  : in  std_logic_vector(11 downto 0);
        vcount_i  : in  std_logic_vector(11 downto 0);
        blank_i   : in  std_logic;

        board_i   : in  std_logic_vector(NUM_QUEENS*NUM_QUEENS-1 downto 0);
        vga_o     : out std_logic_vector(7 downto 0)
		);
end disp_queens;

architecture Behavioral of disp_queens is

    constant OFFSET_X : integer := 50;
    constant OFFSET_Y : integer := 150;

    type bitmaps_vector is array(natural range <>) of bitmap_t;
    constant bitmaps : bitmaps_vector(0 to 9) := (
        bitmap_grey, bitmap_1, bitmap_2, bitmap_3, bitmap_4,
        bitmap_5, bitmap_6, bitmap_7, bitmap_8, bitmap_9);

begin

    gen_vga : process (hcount_i, vcount_i, blank_i, board_i) is
        variable hcount : integer;
        variable vcount : integer;
        variable col    : integer;
        variable row    : integer;
        variable xdiff  : integer range 0 to 15;
        variable ydiff  : integer range 0 to 15;
        variable bitmap : bitmap_t;

    begin
        hcount := conv_integer(hcount_i);
        vcount := conv_integer(vcount_i);
        col    := 0;
        row    := 0;
        xdiff  := 0;
        ydiff  := 0;
        vga_o  <= (others => '0');

        if blank_i = '0' then -- in the active screen
            if hcount >= offset_x and hcount < offset_x + 16 * NUM_QUEENS
            and vcount >= offset_y and vcount < offset_y + 16 * NUM_QUEENS then
                row := NUM_QUEENS-1 - (vcount-offset_y) / 16;
                col := NUM_QUEENS-1 - (hcount-offset_x) / 16;
                xdiff := (hcount - OFFSET_X) rem 16;
                ydiff := (vcount - OFFSET_Y) rem 16;
                if (row rem 2) = (col rem 2) then
                    vga_o <= "10110110";  -- light grey
                else
                    vga_o <= "01001001";  -- dark grey
                end if;
                if board_i(row*NUM_QUEENS + col) = '1' then
                    case bitmap_queen(ydiff*16 + xdiff) is
                        when "01"   => vga_o <= "11011010";
                        when "00"   => vga_o <= "00100101";
                        when others => null;
                    end case;
                end if;
            end if;

            if hcount >= offset_x and hcount <= offset_x + 16 * NUM_QUEENS
            and vcount >= offset_y and vcount <= offset_y + 16 * NUM_QUEENS then
                if (vcount - offset_y) rem 16 = 0 then
                    vga_o <= "11111111"; -- white
                end if;   

                if (hcount - offset_x) rem 16 = 0 then
                    vga_o <= "11111111"; -- white
                end if;   
            end if;   
        end if;   

    end process gen_vga;

end Behavioral;

