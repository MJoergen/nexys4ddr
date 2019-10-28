library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module generates the VGA output signals.

-- The module ensures that the mutual relative timing between the
-- synchronization signals and colour signal adheres to the VESA standard.

entity vga is
   port (
      clk_i     : in  std_logic;

      pix_x_i   : in  std_logic_vector( 9 downto 0);
      pix_y_i   : in  std_logic_vector( 9 downto 0);
      col_i     : in  std_logic_vector(11 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)
   );
end vga;

architecture structural of vga is

   -- The following constants define a resolution of 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf

   -- Define pixel counter range
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Define VGA timing constants
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

begin

   p_vga : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Generate horizontal sync signal
         if pix_x_i >= HS_START and pix_x_i < HS_START+HS_TIME then
            vga_hs_o <= '0';
         else
            vga_hs_o <= '1';
         end if;

         -- Generate vertical sync signal
         if pix_y_i >= VS_START and pix_y_i < VS_START+VS_TIME then
            vga_vs_o <= '0';
         else
            vga_vs_o <= '1';
         end if;

         -- Generate pixel colour
         vga_col_o <= col_i;

         -- Make sure colour is black outside visible screen
         if pix_x_i >= H_PIXELS or pix_y_i >= V_PIXELS then
            vga_col_o <= (others => '0');    -- Black
         end if;
      end if;
   end process p_vga;

end architecture structural;

