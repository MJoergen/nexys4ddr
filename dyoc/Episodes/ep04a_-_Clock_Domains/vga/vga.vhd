library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module drives the VGA interface of the design.
-- The screen resolution generated is 640x480 @ 60 Hz,
-- with 256 colours.
-- This module expects an input clock rate of approximately
-- 25.175 MHz. It will work with a clock rate of 25.0 MHz.
--
-- The VGA output displays six hexadecimal digits (3 bytes)
-- converted from the input signal digits_i.

entity vga is
   generic (
      G_OVERLAY_BITS : integer
   );
   port (
      clk_i     : in  std_logic;    -- Expects 25.175 MHz

      digits_i  : in  std_logic_vector(G_OVERLAY_BITS-1 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)
   );
end vga;

architecture Structural of vga is

   -- Define constants used for 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Pixel counters
   signal pix_x : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y : std_logic_vector(9 downto 0) := (others => '0');

begin
   
   --------------------------------------------------
   -- Generate horizontal and vertical pixel counters
   --------------------------------------------------

   p_pix_x : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x = H_TOTAL-1 then
            pix_x <= (others => '0');
         else
            pix_x <= pix_x + 1;
         end if;
      end if;
   end process p_pix_x;

   p_pix_y : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x = H_TOTAL-1  then
            if pix_y = V_TOTAL-1 then
               pix_y <= (others => '0');
            else
               pix_y <= pix_y + 1;
            end if;
         end if;
      end if;
   end process p_pix_y;


   --------------------------------------------------
   -- Instantiate digits generator
   --------------------------------------------------

   i_digits : entity work.digits
   generic map (
      G_OVERLAY_BITS => G_OVERLAY_BITS,
      G_FONT_FILE    => "font8x8.txt"
   )
   port map (
      clk_i     => clk_i,
      digits_i  => digits_i,
      pix_x_i   => pix_x,
      pix_y_i   => pix_y,
      vga_hs_o  => vga_hs_o,
      vga_vs_o  => vga_vs_o,
      vga_col_o => vga_col_o
   );

end architecture Structural;

