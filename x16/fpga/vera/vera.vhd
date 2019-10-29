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

entity vera is
   port (
      clk_i     : in  std_logic;                       -- 25 MHz

      vga_hs_o  : out std_logic;                       -- VGA
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end vera;

architecture structural of vera is

   signal wr_addr_s   : std_logic_vector(16 downto 0);
   signal wr_en_s     : std_logic;
   signal wr_data_s   : std_logic_vector( 7 downto 0);

   signal mapbase_s   : std_logic_vector(16 downto 0);
   signal tilebase_s  : std_logic_vector(16 downto 0);

   signal vaddr_s     : std_logic_vector(16 downto 0);
   signal vread_s     : std_logic;
   signal vdata_s     : std_logic_vector( 7 downto 0);

   signal pix_x_s     : std_logic_vector( 9 downto 0);
   signal pix_y_s     : std_logic_vector( 9 downto 0);

   signal paddr_s     : std_logic_vector( 7 downto 0);
   signal pdata_s     : std_logic_vector(11 downto 0);
   signal pix_x_out_s : std_logic_vector( 9 downto 0);
   signal pix_y_out_s : std_logic_vector( 9 downto 0);
   signal col_out_s   : std_logic_vector(11 downto 0);

begin

   -- TBD. This is just a dummy block to simulate the CPU.
   -- Later, this block will be expanded to handle the
   -- address translation from CPU accesses to VERA accesses.
   i_cpu : entity work.cpu
      port map (
         clk_i     => clk_i,
         wr_addr_o => wr_addr_s,
         wr_en_o   => wr_en_s,
         wr_data_o => wr_data_s
      ); -- i_cpu

   -- TBD. For now these are just hard coded.
   mapbase_s  <= (others => '0');
   tilebase_s <= "0" & X"F800";

   -- TBD. We still need to add the configuration settings, i.e.
   -- writes to internal address 0xFxxxx.


   --------------------------------
   -- Instantiate 128 kB Video RAM
   --------------------------------

   i_vram : entity work.vram
      port map (
         clk_i     => clk_i,
         -- Writes from CPU:
         wr_addr_i => wr_addr_s,
         wr_en_i   => wr_en_s,
         wr_data_i => wr_data_s,
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
         clk_i  => clk_i,
         addr_i => paddr_s,
         data_o => pdata_s
      ); -- i_palette
   -- TBD: Currently, the palette RAM is hardcoded.
   -- Later, we should allow write access from the CPU.


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


   -------------------------------
   -- Instantiate mode 0 renderer
   -------------------------------

   i_mode0 : entity work.mode0
      port map (
         clk_i      => clk_i,
         pix_x_i    => pix_x_s,
         pix_y_i    => pix_y_s,
         mapbase_i  => mapbase_s,
         tilebase_i => tilebase_s,
         vaddr_o    => vaddr_s,
         vread_o    => vread_s,
         vdata_i    => vdata_s,
         paddr_o    => paddr_s,
         pdata_i    => pdata_s,
         pix_x_o    => pix_x_out_s,
         pix_y_o    => pix_y_out_s,
         col_o      => col_out_s
      ); -- i_mode0


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

