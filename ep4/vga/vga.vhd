library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga is
   port (
      clk_i    : in  std_logic;

      digits_i : in  std_logic_vector(23 downto 0);

      hs_o     : out std_logic;
      vs_o     : out std_logic;
      col_o    : out std_logic_vector(7 downto 0)
   );
end vga;

architecture Structural of vga is

   -- VGA signals
   signal pix_x  : std_logic_vector(9 downto 0);
   signal pix_y  : std_logic_vector(9 downto 0);
   signal hs     : std_logic;
   signal vs     : std_logic;
   signal col    : std_logic_vector(7 downto 0);

begin
   
   --------------------------------------------------
   -- Generate horizontal and vertical sync signals
   --------------------------------------------------

   i_sync : entity work.sync
   port map (
      clk_i   => clk_i,
      pix_x_o => pix_x,
      pix_y_o => pix_y,
      hs_o    => hs,
      vs_o    => vs
   );

   
   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   i_digits : entity work.digits
   port map (
      clk_i    => clk_i,
      pix_x_i  => pix_x,
      pix_y_i  => pix_y,
      digits_i => digits_i,
      col_o    => col
   );


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   hs_o  <= hs;
   vs_o  <= vs;
   col_o <= col;

end architecture Structural;

