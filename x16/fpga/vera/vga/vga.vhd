library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module of the VGA module in the VERA.
-- It generates a display with 640x480 pixels at 60 Hz refresh rate.

entity vga is
   port (
      clk_i          : in  std_logic;                       -- 25.2 MHz
      -- video RAM
      vram_addr_o    : out std_logic_vector(16 downto 0);
      vram_rd_en_o   : out std_logic;
      vram_rd_data_i : in  std_logic_vector( 7 downto 0);
      -- palette RAM
      pal_addr_o     : out std_logic_vector( 7 downto 0);
      pal_rd_en_o    : out std_logic;
      pal_rd_data_i  : in  std_logic_vector(11 downto 0);
      -- configuration settings
      map_base_i     : in  std_logic_vector(17 downto 0);
      tile_base_i    : in  std_logic_vector(17 downto 0);
      -- VGA output
      hs_o           : out std_logic;
      vs_o           : out std_logic;
      col_o          : out std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end vga;

architecture structural of vga is

   signal pix_x_s     : std_logic_vector( 9 downto 0);
   signal pix_y_s     : std_logic_vector( 9 downto 0);
   signal pix_x_out_s : std_logic_vector( 9 downto 0);
   signal pix_y_out_s : std_logic_vector( 9 downto 0);
   signal col_out_s   : std_logic_vector(11 downto 0);

begin

   ------------------------------
   -- Instantiate pixel counters
   ------------------------------

   i_pix : entity work.pix
      generic map (
         G_PIX_X_COUNT => 800,
         G_PIX_Y_COUNT => 525
      )
      port map (
         clk_i   => clk_i,
         pix_x_o => pix_x_s,
         pix_y_o => pix_y_s
      ); -- i_pix


   ------------------------------
   -- Instantiate layer renderer
   ------------------------------

   i_layer : entity work.layer
      port map (
         clk_i          => clk_i,
         pix_x_i        => pix_x_s,
         pix_y_i        => pix_y_s,
         vram_addr_o    => vram_addr_o,
         vram_rd_en_o   => vram_rd_en_o,
         vram_rd_data_i => vram_rd_data_i,
         pal_addr_o     => pal_addr_o,
         pal_rd_en_o    => pal_rd_en_o,
         pal_rd_data_i  => pal_rd_data_i,
         mapbase_i      => map_base_i(16 downto 0),
         tilebase_i     => tile_base_i(16 downto 0),
         pix_x_o        => pix_x_out_s,
         pix_y_o        => pix_y_out_s,
         col_o          => col_out_s
      ); -- i_layer


   ------------------------------
   -- Instantiate VGA signalling
   ------------------------------

   i_sync : entity work.sync
      port map (
         clk_i     => clk_i,
         pix_x_i   => pix_x_out_s,
         pix_y_i   => pix_y_out_s,
         col_i     => col_out_s,
         vga_hs_o  => hs_o,
         vga_vs_o  => vs_o,
         vga_col_o => col_o
      ); -- i_sync

end architecture structural;

