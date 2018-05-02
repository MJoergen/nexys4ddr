library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga is
   port (
      clk_i     : in  std_logic;

      digits_i  : in  std_logic_vector(23 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)
   );
end vga;

architecture Structural of vga is

   -- VGA signals
   signal pix_x   : std_logic_vector(9 downto 0);
   signal pix_y   : std_logic_vector(9 downto 0);
   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;
   signal vga_col : std_logic_vector(7 downto 0);

begin
   
   --------------------------------------------------
   -- Generate horizontal and vertical sync signals
   --------------------------------------------------

   i_sync : entity work.sync
   port map (
      clk_i    => clk_i,
      pix_x_o  => pix_x,
      pix_y_o  => pix_y,
      vga_hs_o => vga_hs,
      vga_vs_o => vga_vs
   );

   
   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   i_digits : entity work.digits
   port map (
      clk_i     => clk_i,
      pix_x_i   => pix_x,
      pix_y_i   => pix_y,
      digits_i  => digits_i,
      vga_col_o => vga_col
   );


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

