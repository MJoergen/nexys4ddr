library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block implements a single layer.
-- Currently, it only supports TILE mode 0, i.e. 16 colour text mode.
-- Furthermore, it is hardcoded that:
-- * MAPW  = 2, which means 128 tiles wide
-- * MAPH  = 1, which means 64 tiles high
-- * TILEW = 0, which means 8 pixels wide
-- * TILEH = 0, which means 8 pixels high
--
-- In this mode, the map data consists of 64 rows of 128 values, where
-- each value is two bytes. The first byte indicates the tile index,
-- the second value indicates the colour index.
-- In the colour index, bits 7-4 is the background colour, while
-- bits 3-0 is the foreground colour.
--
-- On input it has the free-running pixel counters, as well as the base
-- addresses for the MAP and TILE areas.
-- On output it has colour of the corresponding pixel.
-- Because there are several pipeline stages in this block, the output must
-- also include the pixel counters delayed accordingly.
--
-- This block needs to read the Video RAM three times for each tile:
-- 1. To get the tile index at the corresponding pixel (using mapbase_i).
-- 2. To get the colour index at the corresponding pixel (using mapbase_i).
-- 3. To get the tile data for this character (using tilebase_i).
-- Additionally, it needs to read the colour from the palette RAM at every pixel.
--
-- Since each tile is 8 pixels wide (and hence eight clock cycles),
-- the reads from Video RAM are staged.

entity layer is
   port (
      clk_i          : in  std_logic;

      -- Input pixel counters
      pix_x_i        : in  std_logic_vector( 9 downto 0);
      pix_y_i        : in  std_logic_vector( 9 downto 0);

      -- Interface to Video RAM
      vram_addr_o    : out std_logic_vector(16 downto 0);
      vram_rd_en_o   : out std_logic;
      vram_rd_data_i : in  std_logic_vector( 7 downto 0);

      -- Interface to Palette RAM
      pal_addr_o     : out std_logic_vector( 7 downto 0);
      pal_rd_en_o    : out std_logic;
      pal_rd_data_i  : in  std_logic_vector(11 downto 0);

      -- From Layer settings 
      mapbase_i      : in  std_logic_vector(16 downto 0);
      tilebase_i     : in  std_logic_vector(16 downto 0);

      -- Output pixel counters and colour
      pix_x_o        : out std_logic_vector( 9 downto 0);
      pix_y_o        : out std_logic_vector( 9 downto 0);
      col_o          : out std_logic_vector(11 downto 0)
   );
end layer;

architecture rtl of layer is

   -- Stage 0
   signal pix_x_0r        : std_logic_vector( 9 downto 0);
   signal pix_y_0r        : std_logic_vector( 9 downto 0);

   -- Stage 1
   signal pix_x_1r        : std_logic_vector( 9 downto 0);
   signal pix_y_1r        : std_logic_vector( 9 downto 0);

   -- Stage 2
   signal pix_x_2r        : std_logic_vector( 9 downto 0);
   signal pix_y_2r        : std_logic_vector( 9 downto 0);

   -- Stage 3
   signal pix_x_3r        : std_logic_vector( 9 downto 0);
   signal pix_y_3r        : std_logic_vector( 9 downto 0);
   signal colour_value_3r : std_logic_vector( 7 downto 0);

   -- Stage 4
   signal pix_x_4r        : std_logic_vector( 9 downto 0);
   signal pix_y_4r        : std_logic_vector( 9 downto 0);
   signal colour_value_4r : std_logic_vector( 7 downto 0);
   signal tile_value_4r   : std_logic_vector( 7 downto 0);

   -- Stage 5
   signal pix_x_5r        : std_logic_vector( 9 downto 0);
   signal pix_y_5r        : std_logic_vector( 9 downto 0);

begin

   ---------------------------------------
   -- Perform staged reads from Video RAM
   -- 1. To get the tile index at the corresponding pixel (using mapbase_i).
   -- 2. To get the colour index at the corresponding pixel (using mapbase_i).
   -- 3. To get the tile data for this character (using tilebase_i).
   ---------------------------------------

   p_stages : process (clk_i)
      variable map_row_v    : std_logic_vector( 5 downto 0);   --  64 tiles high
      variable map_column_v : std_logic_vector( 6 downto 0);   -- 128 tiles wide
      variable map_offset_v : std_logic_vector(16 downto 0);
      variable map_value_v  : std_logic_vector( 7 downto 0);   -- Tile index

      variable tile_row_v    : std_logic_vector( 2 downto 0);  -- 8 pixels high
      variable tile_column_v : std_logic_vector( 2 downto 0);  -- 8 pixels wide
      variable tile_offset_v : std_logic_vector(16 downto 0);
   begin
      if rising_edge(clk_i) then
         vram_rd_en_o <= '0';

         pix_x_0r <= pix_x_i;
         pix_y_0r <= pix_y_i;

         pix_x_1r <= pix_x_0r;
         pix_y_1r <= pix_y_0r;

         pix_x_2r <= pix_x_1r;
         pix_y_2r <= pix_y_1r;

         pix_x_3r <= pix_x_2r;
         pix_y_3r <= pix_y_2r;

         pix_x_4r <= pix_x_3r;
         pix_y_4r <= pix_y_3r;

         -- Stage 0. Read tile index from Video RAM. Ready in stage 2.
         if pix_x_i(2 downto 0) = 0 then
            map_row_v    := pix_y_i(8 downto 3);
            map_column_v := pix_x_i(9 downto 3);
            map_offset_v := "000" & map_row_v & map_column_v & "0";

            vram_addr_o  <= mapbase_i + map_offset_v;
            vram_rd_en_o <= '1';
         end if;

         -- Stage 1. Read colour index from Video RAM. Ready in stage 3.
         if pix_x_i(2 downto 0) = 1 then

            map_row_v    := pix_y_i(8 downto 3);
            map_column_v := pix_x_i(9 downto 3);
            map_offset_v := "000" & map_row_v & map_column_v & "1";

            vram_addr_o  <= mapbase_i + map_offset_v;
            vram_rd_en_o <= '1';
         end if;

         -- Stage 2. Read tile data from Video RAM. Ready in stage 4.
         if pix_x_i(2 downto 0) = 2 then
            map_value_v := vram_rd_data_i;            -- Store tile index for this tile.
            tile_row_v := pix_y_i(2 downto 0);
            tile_offset_v := "000000" & map_value_v & tile_row_v;

            vram_addr_o  <= tilebase_i + tile_offset_v;
            vram_rd_en_o <= '1';
         end if;

         -- Stage 3. Store colour value.
         if pix_x_i(2 downto 0) = 3 then
            colour_value_3r <= vram_rd_data_i;        -- Store colour index for this tile.
         end if;

         -- Stage 4. Store tile value.
         if pix_x_i(2 downto 0) = 4 then
            colour_value_4r <= colour_value_3r;       -- Make sure colour and tile values
                                                      -- are properly synchronized.
            tile_value_4r   <= vram_rd_data_i;        -- Store data for this tile.
         end if;
      end if;
   end process p_stages;


   -------------------------
   -- Read from palette RAM
   -------------------------

   p_colour : process (clk_i)
      variable tile_column_v : integer range 0 to 7;  -- 8 pixels wide
      variable pixel_v       : std_logic;
      variable tile_offset_v : std_logic_vector(16 downto 0);
   begin
      if rising_edge(clk_i) then
         pal_rd_en_o <= '1';

         tile_column_v := 7-to_integer(pix_x_4r(2 downto 0));     -- Subtract from 7, because the MSB of the tile data
                                                                  -- corresponds to the lowest pixel coordinate.

         pixel_v := tile_value_4r(tile_column_v);                 -- Get value of this particular pixel.

         -- Read pixel colour from palette RAM.
         if pixel_v = '0' then
            pal_addr_o <= "0000" & colour_value_4r(7 downto 4);   -- background
         else
            pal_addr_o <= "0000" & colour_value_4r(3 downto 0);   -- foreground
         end if;

         pix_x_5r <= pix_x_4r;
         pix_y_5r <= pix_y_4r;
      end if;
   end process p_colour;


   --------------------
   -- Output registers
   --------------------

   p_output : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pix_x_o <= pix_x_5r;
         pix_y_o <= pix_y_5r;
         col_o   <= pal_rd_data_i;
      end if;
   end process p_output;

end architecture rtl;

