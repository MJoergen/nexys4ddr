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
-- through the display memory. This module instantiates the clock generation,
-- the display memory, and the two modules above, and generates the resets.
--
-- The view is controlled by the buttons and switches on the board:
--   btn_i(4)         : Zoom in. If sw_i(2) is set then zoom out instead.
--   btn_i(3 downto 0): Move the view left, right, up and down.
--   sw_i(1)          : Select what the LEDs show.
-- While a button is pressed, the view is updated about 17 times per second.
-- The other switches are not used.

entity mandelbrot is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz
      rstn_i    : in  std_logic;

      btn_i     : in  std_logic_vector( 4 downto 0);  -- "CLRUD"
      sw_i      : in  std_logic_vector( 7 downto 0);
      led_o     : out std_logic_vector(15 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector( 7 downto 0)    -- RRRGGGBB
   );
end mandelbrot;

architecture structural of mandelbrot is

   signal main_clk       : std_logic;
   signal main_rst_delay : std_logic_vector(7 downto 0) := X"FF";
   signal main_rst       : std_logic;

   signal vga_clk        : std_logic;
   signal vga_rst_delay  : std_logic_vector(7 downto 0) := X"FF";
   signal vga_rst        : std_logic;

   signal wr_addr        : std_logic_vector(18 downto 0);
   signal wr_data        : std_logic_vector( 7 downto 0);
   signal wr_en          : std_logic;

   signal rd_addr        : std_logic_vector(18 downto 0);
   signal rd_data        : std_logic_vector( 7 downto 0);

begin

   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   i_clk : entity work.clk
      port map (
         clk_in1  => clk_i,
         vga_clk  => vga_clk,
         main_clk => main_clk
      ); -- i_clk


   --------------------------------------------------
   -- Generate reset signals
   --------------------------------------------------

   p_main_rst : process (main_clk)
   begin
      if rising_edge(main_clk) then
         main_rst_delay <= main_rst_delay(6 downto 0) & "0";
         main_rst <= main_rst_delay(7);

         if rstn_i = '0' then
            main_rst_delay <= X"FF";
         end if;
      end if;
   end process p_main_rst;

   p_vga_rst : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_rst_delay <= vga_rst_delay(6 downto 0) & "0";
         vga_rst <= vga_rst_delay(7);

         if rstn_i = '0' then
            vga_rst_delay <= X"FF";
         end if;
      end if;
   end process p_vga_rst;


   --------------------------------------------------
   -- Instantiate MAIN clock domain
   --------------------------------------------------

   i_main : entity work.main
      port map (
         clk_i     => main_clk,
         rst_i     => main_rst,
         btn_i     => btn_i,
         sw_i      => sw_i,
         led_o     => led_o,
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


   --------------------------------------------------
   -- Instantiate VGA clock domain
   --------------------------------------------------

   i_vga : entity work.vga
      port map (
         clk_i     => vga_clk,
         rst_i     => vga_rst,
         rd_addr_o => rd_addr,
         rd_data_i => rd_data,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o
      ); -- i_vga

end architecture structural;
