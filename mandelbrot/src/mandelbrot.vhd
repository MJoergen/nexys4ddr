library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- The design calculates the Mandelbrot set, and shows it on the VGA output
-- (640x480). The picture is calculated by the dispatcher and stored in the
-- display memory. As soon as one picture is finished, the calculation of the
-- next picture is started, so the picture is recalculated continuously.
--
-- The design is split into two modules, one for each clock domain: main.vhd
-- (MAIN clock) and vga.vhd (VGA clock). The two domains communicate only
-- through the display memory. This module instantiates the clock and reset
-- generation, the display memory, and the two modules above.
--
-- The buttons, switches and the 7-segment display are handled by main.vhd,
-- see the description there, except switches 3 and 4, which select the colour
-- palette in vga.vhd (see palette_pkg.vhd). The decimal point of the 7-segment
-- display is not used, so it is switched off here.

entity mandelbrot is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz
      rstn_i    : in  std_logic;

      btn_i     : in  std_logic_vector( 4 downto 0);  -- "CLRUD"
      sw_i      : in  std_logic_vector( 7 downto 0);
      seg_o     : out std_logic_vector( 6 downto 0);  -- "GFEDCBA", active low
      seg_dp_o  : out std_logic;                      -- Active low
      seg_an_o  : out std_logic_vector( 7 downto 0);  -- Active low

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector( 7 downto 0)    -- RRRGGGBB
   );
end mandelbrot;

architecture structural of mandelbrot is

   -- The number of column modules. The XC7A100T has 240 DSPs, one for each
   -- column module.
   constant C_NUM_ITERATORS : integer := 240;

   signal main_clk       : std_logic;
   signal main_rst       : std_logic;

   signal vga_clk        : std_logic;
   signal vga_rst        : std_logic;

   signal wr_addr        : std_logic_vector(18 downto 0);
   signal wr_data        : std_logic_vector( 8 downto 0);
   signal wr_en          : std_logic;

   signal rd_addr        : std_logic_vector(18 downto 0);
   signal rd_data        : std_logic_vector( 8 downto 0);

begin

   --------------------------------------------------
   -- Instantiate clock and reset generation
   --------------------------------------------------

   i_clk_rst : entity work.clk_rst
      port map (
         clk_i      => clk_i,
         rstn_i     => rstn_i,
         main_clk_o => main_clk,
         main_rst_o => main_rst,
         vga_clk_o  => vga_clk,
         vga_rst_o  => vga_rst
      ); -- i_clk_rst


   --------------------------------------------------
   -- Instantiate MAIN clock domain
   --------------------------------------------------

   i_main : entity work.main
      generic map (
         G_NUM_ITERATORS => C_NUM_ITERATORS
      )
      port map (
         clk_i     => main_clk,
         rst_i     => main_rst,
         btn_i     => btn_i,
         sw_i      => sw_i,
         seg_o     => seg_o,
         seg_an_o  => seg_an_o,
         wr_addr_o => wr_addr,
         wr_data_o => wr_data,
         wr_en_o   => wr_en
      ); -- i_main


   ------------------------------
   -- Instantiate display memory
   ------------------------------

   i_disp_mem : entity work.disp_mem
      port map (
         wr_clk_i  => main_clk,
         wr_rst_i  => main_rst,
         wr_addr_i => wr_addr,
         wr_data_i => wr_data,
         wr_en_i   => wr_en,
         --
         rd_clk_i  => vga_clk,
         rd_rst_i  => vga_rst,
         rd_addr_i => rd_addr,
         rd_data_o => rd_data
      ); -- i_disp_mem


   seg_dp_o <= '1';


   --------------------------------------------------
   -- Instantiate VGA clock domain
   --------------------------------------------------

   i_vga : entity work.vga
      port map (
         clk_i     => vga_clk,
         rst_i     => vga_rst,
         rd_addr_o => rd_addr,
         rd_data_i => rd_data,
         palette_i => sw_i(4 downto 3),
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o
      ); -- i_vga

end architecture structural;
