-- This module generates the VGA output signals for the video mode G_MODE (see
-- video_pkg.vhd) from the pixel counters. The value of the pixel at (vga_pix_x_i, vga_pix_y_i), i.e.
-- its iteration count (9 bits), must be given on vga_col_d3_i three
-- clock cycles later, which is the read latency of the display memory. It is
-- converted to the colour by the palette selected by vga_palette_i (see
-- palette_pkg.vhd). The colour is only output inside the visible area.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.palette_pkg.all;
use work.video_pkg.all;

entity disp is
   generic (
      G_MODE       : video_mode_t
   );
   port (
      vga_clk_i    : in  std_logic;
      vga_rst_i    : in  std_logic;
      vga_pix_x_i  : in  std_logic_vector(10 downto 0);
      vga_pix_y_i  : in  std_logic_vector(10 downto 0);
      vga_col_d3_i : in  std_logic_vector(8 downto 0);
      vga_palette_i: in  std_logic_vector(1 downto 0);
      vga_hs_o     : out std_logic;
      vga_vs_o     : out std_logic;
      vga_col_o    : out std_logic_vector(7 downto 0)
   );
end entity disp;

architecture rtl of disp is

   -- Define visible screen size
   constant H_PIXELS : integer := G_MODE.h_visible;
   constant V_PIXELS : integer := G_MODE.v_visible;

   -- Define VGA timing constants. The sync pulses are at the level
   -- G_MODE.sync_active, e.g. active low (negative polarity) for 640x480.
   constant HS_START : integer := G_MODE.h_visible + G_MODE.h_front;
   constant HS_TIME  : integer := G_MODE.h_sync;
   constant VS_START : integer := G_MODE.v_visible + G_MODE.v_front;
   constant VS_TIME  : integer := G_MODE.v_sync;

   signal vga_pix_x_d  : std_logic_vector(10 downto 0) := (others => '0');
   signal vga_pix_y_d  : std_logic_vector(10 downto 0) := (others => '0');
   signal vga_hs_d     : std_logic;
   signal vga_vs_d     : std_logic;

   signal vga_pix_x_d2 : std_logic_vector(10 downto 0) := (others => '0');
   signal vga_pix_y_d2 : std_logic_vector(10 downto 0) := (others => '0');
   signal vga_hs_d2    : std_logic;
   signal vga_vs_d2    : std_logic;

   signal vga_pix_x_d3 : std_logic_vector(10 downto 0) := (others => '0');
   signal vga_pix_y_d3 : std_logic_vector(10 downto 0) := (others => '0');
   signal vga_hs_d3    : std_logic;
   signal vga_vs_d3    : std_logic;

   signal vga_hs_d4    : std_logic;
   signal vga_vs_d4    : std_logic;
   signal vga_col_d4   : std_logic_vector(7 downto 0);

begin

   ----------------------------------------
   -- Generate VGA synchronization signals
   ----------------------------------------

   p_sync : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then

         vga_hs_d <= not G_MODE.sync_active;
         vga_vs_d <= not G_MODE.sync_active;

         if vga_pix_x_i >= HS_START and vga_pix_x_i < HS_START+HS_TIME then
            vga_hs_d   <= G_MODE.sync_active;
         end if;

         if vga_pix_y_i >= VS_START and vga_pix_y_i < VS_START+VS_TIME then
            vga_vs_d   <= G_MODE.sync_active;
         end if;

         vga_pix_x_d <= vga_pix_x_i;
         vga_pix_y_d <= vga_pix_y_i;
      end if;
   end process p_sync;


   ------------------------------------------------------------------
   -- Add two more pipeline stages, so the total delay of three clock
   -- cycles matches the read latency of the display memory
   ------------------------------------------------------------------

   p_pipe : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_hs_d2    <= vga_hs_d;
         vga_vs_d2    <= vga_vs_d;
         vga_pix_x_d2 <= vga_pix_x_d;
         vga_pix_y_d2 <= vga_pix_y_d;

         vga_hs_d3    <= vga_hs_d2;
         vga_vs_d3    <= vga_vs_d2;
         vga_pix_x_d3 <= vga_pix_x_d2;
         vga_pix_y_d3 <= vga_pix_y_d2;
      end if;
   end process p_pipe;


   ---------------------------
   -- Generate output signals
   ---------------------------

   p_out : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_col_d4 <= (others => '0');

         -- Only set colour output inside visible area
         if vga_pix_x_d3 < H_PIXELS and vga_pix_y_d3 < V_PIXELS then
            vga_col_d4 <= palette_colour(vga_palette_i, vga_col_d3_i);
         end if;

         vga_hs_d4 <= vga_hs_d3;
         vga_vs_d4 <= vga_vs_d3;
      end if;
   end process p_out;


   --------------------------
   -- Connect output signals
   --------------------------

   vga_hs_o  <= vga_hs_d4;
   vga_vs_o  <= vga_vs_d4;
   vga_col_o <= vga_col_d4;

end architecture rtl;

