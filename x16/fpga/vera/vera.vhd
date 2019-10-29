library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module of the VERA.
-- It generates a display with 640x480 pixels at 60 Hz refresh rate.
--
-- For now this block is completely self-contained, i.e. relies only on a
-- single stable clock signal.
--
-- Later, I will add a CPU interface to allow the CPU read/write access to the
-- VERA. The clock domain crossings between the CPU and VERA will be handled at
-- top level, so that the entire VERA module itself is a single clock domain.
--
-- External memory map (visible to the CPU):
-- 0x9F20 : VERA_ADDR_LO
-- 0x9F21 : VERA_ADDR_MID
-- 0x9F22 : VERA_ADDR_HI
-- 0x9F23 : VERA_DATA0
-- 0x9F24 : VERA_DATA1
-- 0x9F25 : VERA_CTRL
-- 0x9F26 : VERA_IEN
-- 0x9F27 : VERA_ISR
-- 
-- Internal memory map:
-- 0x00000 - 0x1FFFF : Video RAM
-- 0x20000 - 0xEFFFF : Reserved
-- 0xF0000 - 0xF001F : Display composer
-- 0xF1000 - 0xF11FF : Palette
-- 0xF2000 - 0xF200F : Layer 1
-- 0xF3000 - 0xF300F : Layer 2
-- 0xF4000 - 0xF400F : Sprite registers
-- 0xF5000 - 0xF53FF : Sprite attributes
-- 0xF6000 - 0xF6FFF : Reserved for audio
-- 0xF7000 - 0xF7001 : SPI
-- 0xF8000 - 0xFFFFF : Reserved
--
-- TBD: For now only the Video RAM and a few of the layer registers are
-- supported. The rest of the internal memory map is empty.

entity vera is
   port (
      clk_i     : in  std_logic;                       -- 25 MHz

      vga_hs_o  : out std_logic;                       -- VGA
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end vera;

architecture structural of vera is

   -- TBD: These should really be input signals.
   signal cpu_wr_addr_s  : std_logic_vector( 2 downto 0);
   signal cpu_wr_en_s    : std_logic;
   signal cpu_wr_data_s  : std_logic_vector( 7 downto 0);

   -- These signals are part of the internal memory map.
   signal wr_addr_s      : std_logic_vector(19 downto 0);
   signal wr_en_s        : std_logic;
   signal wr_data_s      : std_logic_vector( 7 downto 0);

   signal vram_wr_addr_r : std_logic_vector(16 downto 0);
   signal vram_wr_en_r   : std_logic;
   signal vram_wr_data_r : std_logic_vector( 7 downto 0);

   signal pal_wr_addr_r  : std_logic_vector( 8 downto 0);
   signal pal_wr_en_r    : std_logic;
   signal pal_wr_data_r  : std_logic_vector( 7 downto 0);

   signal map_base_r     : std_logic_vector(17 downto 0);
   signal tile_base_r    : std_logic_vector(17 downto 0);

   signal vaddr_s        : std_logic_vector(16 downto 0);
   signal vread_s        : std_logic;
   signal vdata_s        : std_logic_vector( 7 downto 0);

   signal pix_x_s        : std_logic_vector( 9 downto 0);
   signal pix_y_s        : std_logic_vector( 9 downto 0);

   signal paddr_s        : std_logic_vector( 7 downto 0);
   signal pdata_s        : std_logic_vector(11 downto 0);
   signal pix_x_out_s    : std_logic_vector( 9 downto 0);
   signal pix_y_out_s    : std_logic_vector( 9 downto 0);
   signal col_out_s      : std_logic_vector(11 downto 0);

begin

   -- TBD. This is just a dummy block to simulate the CPU.
   -- Later, these signals will become input signals.
   i_cpu_dummy : entity work.cpu_dummy
      port map (
         clk_i     => clk_i,
         wr_addr_o => cpu_wr_addr_s,
         wr_en_o   => cpu_wr_en_s,
         wr_data_o => cpu_wr_data_s
      ); -- i_cpu_dummy


   --------------------------------------------------
   -- Translate from external to internal memory map
   --------------------------------------------------

   i_cpu_interface : entity work.cpu_interface
      port map (
         clk_i          => clk_i,
         cpu_wr_addr_i  => cpu_wr_addr_s, -- External memory map
         cpu_wr_en_i    => cpu_wr_en_s,
         cpu_wr_data_i  => cpu_wr_data_s,
         vera_wr_addr_o => wr_addr_s,     -- Internal memory map
         vera_wr_en_o   => wr_en_s,
         vera_wr_data_o => wr_data_s
      ); -- i_cpu_interface


   -----------------------
   -- Internal memory map
   -----------------------

   p_internal_memory_map : process (clk_i)
   begin
      if rising_edge(clk_i) then
         map_base_r( 1 downto 0) <= "00";
         tile_base_r(1 downto 0) <= "00";

         vram_wr_addr_r <= (others => '0');
         vram_wr_en_r   <= '0';
         vram_wr_data_r <= (others => '0');

         pal_wr_addr_r <= (others => '0');
         pal_wr_en_r   <= '0';
         pal_wr_data_r <= (others => '0');

         if wr_en_s = '1' then
            case wr_addr_s(19 downto 17) is
               when "000" =>                                                  -- Video RAM
                  vram_wr_addr_r <= wr_addr_s(16 downto 0);
                  vram_wr_en_r   <= '1';
                  vram_wr_data_r <= wr_data_s;
               when "111" =>
                  case wr_addr_s(19 downto 12) is
                     when X"F0" => null;                                      -- Display composer
                     when X"F1" => pal_wr_addr_r <= wr_addr_s(8 downto 0);    -- Palette
                                   pal_wr_en_r   <= '1';
                                   pal_wr_data_r <= wr_data_s;
                     when X"F2" => null;                                      -- Layer 0
                     when X"F3" => 
                        case wr_addr_s is                                     -- Layer 1
                           when X"F3002" => map_base_r(  9 downto  2) <= wr_data_s; -- L1_MAP_BASE_L
                           when X"F3003" => map_base_r( 17 downto 10) <= wr_data_s; -- L1_MAP_BASE_H
                           when X"F3004" => tile_base_r( 9 downto  2) <= wr_data_s; -- L1_TILE_BASE_L
                           when X"F3005" => tile_base_r(17 downto 10) <= wr_data_s; -- L1_TILE_BASE_H
                           when others => null;
                        end case;
                     when X"F4" => null;                                      -- Sprite
                     when X"F5" => null;                                      -- Sprite attributes
                     when X"F6" => null;                                      -- Audio
                     when X"F7" => null;                                      -- SPI
                     when X"F8" => null;                                      -- UART
                     when others => null;
                  end case;
               when others => null;
            end case;
         end if;
      end if;
   end process p_internal_memory_map;


   --------------------------------
   -- Instantiate 128 kB Video RAM
   --------------------------------

   i_vram : entity work.vram
      port map (
         clk_i     => clk_i,
         -- Writes from CPU:
         wr_addr_i => vram_wr_addr_r,
         wr_en_i   => vram_wr_en_r,
         wr_data_i => vram_wr_data_r,
         -- TBD: We should add Read from CPU here.

         -- Reads from the Mode 0 block:
         rd_addr_i => vaddr_s,
         rd_en_i   => vread_s,
         rd_data_o => vdata_s
      ); -- i_vram


   ---------------------------
   -- Instantiate palette RAM
   ---------------------------

   i_palette : entity work.palette
      port map (
         clk_i     => clk_i,
         -- Writes from CPU:
         wr_addr_i => pal_wr_addr_r,
         wr_en_i   => pal_wr_en_r,
         wr_data_i => pal_wr_data_r,

         -- Reads from the Mode 0 block:
         rd_addr_i => paddr_s,
         rd_data_o => pdata_s
      ); -- i_palette


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
         clk_i      => clk_i,
         pix_x_i    => pix_x_s,
         pix_y_i    => pix_y_s,
         mapbase_i  => map_base_r(16 downto 0),
         tilebase_i => tile_base_r(16 downto 0),
         vaddr_o    => vaddr_s,
         vread_o    => vread_s,
         vdata_i    => vdata_s,
         paddr_o    => paddr_s,
         pdata_i    => pdata_s,
         pix_x_o    => pix_x_out_s,
         pix_y_o    => pix_y_out_s,
         col_o      => col_out_s
      ); -- i_layer


   ------------------------------
   -- Instantiate VGA signalling
   ------------------------------

   i_vga : entity work.vga
      port map (
         clk_i     => clk_i,
         pix_x_i   => pix_x_out_s,
         pix_y_i   => pix_y_out_s,
         col_i     => col_out_s,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o
      ); -- i_vga

end architecture structural;

