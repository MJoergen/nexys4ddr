library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block implements TILE mode 0, i.e. 16 colour text mode.
-- On input it has the free-running pixel counters.
-- On output it has colour of the corresponding pixel.
-- Because there may be several pipeline stages in this block, the output must
-- also include the pixel counters delayed accordingly.
--
-- This block needs to read the Video RAM twice:
-- 1. To get the character value at the corresponding pixel (using mapbase_i).
-- 2. To get the tile data for this character (using tilebase_i).

entity tile is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Pixel counters
      pix_x_i    : in  std_logic_vector( 9 downto 0);
      pix_y_i    : in  std_logic_vector( 9 downto 0);

      -- From Layer settings 
      mapbase_i  : in  std_logic_vector(16 downto 0);
      tilebase_i : in  std_logic_vector(16 downto 0);

      -- Interface to Video RAM
      vaddr_o    : out std_logic_vector(16 downto 0);
      vdata_i    : in  std_logic_vector( 7 downto 0);

      -- Interface to Palette RAM
      paddr_o    : out std_logic_vector( 7 downto 0);
      pdata_i    : in  std_logic_vector(11 downto 0);

      -- Pixel counters
      pix_x_o    : out std_logic_vector( 9 downto 0);
      pix_y_o    : out std_logic_vector( 9 downto 0);
      col_o      : out std_logic_vector(11 downto 0)
   );
end tile;

architecture rtl of tile is

begin
   
end architecture rtl;

