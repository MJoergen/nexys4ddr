library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module drives the VGA interface of the design.
-- The screen resolution generated is 640x480 @ 60 Hz,
-- with 256 colours.
-- This module expects an input clock rate of approximately
-- 25.175 MHz. It will work with a clock rate of 25.0 MHz.

entity vga is
   port (
      clk_i       : in  std_logic;    -- Expects 25.175 MHz

      overlay_i   : in  std_logic;
      digits_i    : in  std_logic_vector(175 downto 0);

      char_addr_o : out std_logic_vector(12 downto 0);
      char_data_i : in  std_logic_vector( 7 downto 0);
      col_addr_o  : out std_logic_vector(12 downto 0);
      col_data_i  : in  std_logic_vector( 7 downto 0);

      memio_i     : in  std_logic_vector(18*8-1 downto 0);
      memio_o     : out std_logic_vector( 4*8-1 downto 0);

      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic;
      vga_col_o   : out std_logic_vector(7 downto 0)
   );
end vga;

architecture Structural of vga is

   signal colour_palette       : std_logic_vector(16*8-1 downto 0);
   signal pix_y_line_interrupt : std_logic_vector(15 downto 0);

   -- Define constants used for 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Pixel counters
   signal pix_x : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y : std_logic_vector(9 downto 0) := (others => '0');

   signal char_addr : std_logic_vector(12 downto 0);
   signal char_data : std_logic_vector( 7 downto 0);
   signal col_addr  : std_logic_vector(12 downto 0);
   signal col_data  : std_logic_vector( 7 downto 0);

   -- Output from Chars module.
   signal char_pix_x : std_logic_vector(9 downto 0);
   signal char_pix_y : std_logic_vector(9 downto 0);
   signal char_hs    : std_logic;
   signal char_vs    : std_logic;
   signal char_col   : std_logic_vector(7 downto 0);

   -- Output from Overlay module.
   signal overlay_hs  : std_logic;
   signal overlay_vs  : std_logic;
   signal overlay_col : std_logic_vector(7 downto 0);

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
   -- Instantiate character display
   --------------------------------------------------

   i_chars : entity work.chars
   generic map (
      G_FONT_FILE => "font8x8.txt"
   )
   port map (
      clk_i       => clk_i,

      pix_x_i     => pix_x,
      pix_y_i     => pix_y,

      char_addr_o => char_addr_o,
      char_data_i => char_data_i,
      col_addr_o  => col_addr_o,
      col_data_i  => col_data_i,

      palette_i   => colour_palette,

      pix_x_o     => char_pix_x,
      pix_y_o     => char_pix_y,
      vga_hs_o    => char_hs,
      vga_vs_o    => char_vs,
      vga_col_o   => char_col
   );


   --------------------------------------------------
   -- Instantiate CPU debug overlay
   --------------------------------------------------

   i_overlay : entity work.overlay
   generic map (
      G_FONT_FILE => "font8x8.txt"
   )
   port map (
      clk_i     => clk_i,
      digits_i  => digits_i,
      pix_x_i   => char_pix_x,
      pix_y_i   => char_pix_y,
      vga_hs_i  => char_hs,
      vga_vs_i  => char_vs,
      vga_col_i => char_col,
      vga_hs_o  => overlay_hs,
      vga_vs_o  => overlay_vs,
      vga_col_o => overlay_col
   );

   -- Optionally enable CPU debug overlay
   vga_hs_o  <= overlay_hs  when overlay_i = '1' else char_hs;
   vga_vs_o  <= overlay_vs  when overlay_i = '1' else char_vs;
   vga_col_o <= overlay_col when overlay_i = '1' else char_col;


   --------------------
   -- Memory Mapped I/O
   --------------------

   colour_palette       <= memio_i(15*8+7 downto  0*8);
   pix_y_line_interrupt <= memio_i(17*8+7 downto 16*8);

   memio_o( 7 downto  0) <= pix_x(7 downto 0);
   memio_o(15 downto  8) <= "000000" & pix_x(9 downto 8);
   memio_o(23 downto 16) <= pix_y(7 downto 0);
   memio_o(31 downto 24) <= "000000" & pix_y(9 downto 8);


end architecture Structural;

