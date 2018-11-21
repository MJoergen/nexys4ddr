library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module drives the VGA interface of the design.
-- The screen resolution generated is 640x480 @ 60 Hz,
-- with 256 colours.
-- This module expects an input clock rate of approximately
-- 25.175 MHz. It will work with a clock rate of 25.0 MHz.
--
-- The VGA output displays seven rows of four hexadecimal digits (2 bytes)
-- converted from the input signal digits_i.
-- Additionally a short text description is shown in front of every row.

entity vga is
   generic (
      G_OVERLAY_BITS : integer;
      G_OPCODES_FILE : string;
      G_FONT_FILE    : string
   );
   port (
      clk_i       : in  std_logic;

      overlay_i   : in  std_logic;
      digits_i    : in  std_logic_vector(G_OVERLAY_BITS-1 downto 0);

      char_addr_o : out std_logic_vector(12 downto 0);
      char_data_i : in  std_logic_vector( 7 downto 0);
      col_addr_o  : out std_logic_vector(12 downto 0);
      col_data_i  : in  std_logic_vector( 7 downto 0);

      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic;
      vga_col_o   : out std_logic_vector(7 downto 0)
   );
end vga;

architecture structural of vga is

   -- Pixel counters
   signal pix_x : std_logic_vector(9 downto 0);
   signal pix_y : std_logic_vector(9 downto 0);

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
   -- Instantiate pixel counters
   --------------------------------------------------

   pix_inst : entity work.pix
   port map (
      clk_i   => clk_i,
      pix_x_o => pix_x,
      pix_y_o => pix_y
   ); -- pix_inst


   --------------------------------------------------
   -- Instantiate character display
   --------------------------------------------------

   chars_inst : entity work.chars
   generic map (
      G_FONT_FILE => G_FONT_FILE
   )
   port map (
      clk_i       => clk_i,

      pix_x_i     => pix_x,
      pix_y_i     => pix_y,

      char_addr_o => char_addr_o,
      char_data_i => char_data_i,
      col_addr_o  => col_addr_o,
      col_data_i  => col_data_i,

      -- This is just a default palette with a range of colours from black (0)
      -- to white (15).
      palette_i   => X"FFFCE3E0433C1E178C82803022110A00",

      pix_x_o     => char_pix_x,
      pix_y_o     => char_pix_y,
      vga_hs_o    => char_hs,
      vga_vs_o    => char_vs,
      vga_col_o   => char_col
   ); -- chars_inst


   --------------------------------------------------
   -- Instantiate CPU debug overlay
   --------------------------------------------------

   overlay_inst : entity work.overlay
   generic map (
      G_OVERLAY_BITS => G_OVERLAY_BITS,
      G_OPCODES_FILE => G_OPCODES_FILE,
      G_FONT_FILE    => G_FONT_FILE
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
   ); -- overlay_inst

   -- Optionally enable CPU debug overlay
   vga_hs_o  <= overlay_hs  when overlay_i = '1' else char_hs;
   vga_vs_o  <= overlay_vs  when overlay_i = '1' else char_vs;
   vga_col_o <= overlay_col when overlay_i = '1' else char_col;

end architecture structural;

