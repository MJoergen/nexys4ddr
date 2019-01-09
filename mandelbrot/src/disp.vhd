library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity disp is
   port (
      vga_clk_i    : in  std_logic;
      vga_rst_i    : in  std_logic;
      vga_pix_x_i  : in  std_logic_vector(9 downto 0);
      vga_pix_y_i  : in  std_logic_vector(9 downto 0);
      vga_col_d3_i : in  std_logic_vector(7 downto 0);
      vga_hs_o     : out std_logic;
      vga_vs_o     : out std_logic;
      vga_col_o    : out std_logic_vector(7 downto 0)
   );
end entity disp;

architecture rtl of disp is

   -- The following constants define a resolution of 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf

   -- Define pixel counter range
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Define VGA timing constants
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

   signal vga_pix_x_d  : std_logic_vector(9 downto 0);
   signal vga_pix_y_d  : std_logic_vector(9 downto 0);
   signal vga_hs_d     : std_logic;
   signal vga_vs_d     : std_logic;
   signal vga_col_d    : std_logic_vector(7 downto 0);

   signal vga_pix_x_d2 : std_logic_vector(9 downto 0);
   signal vga_pix_y_d2 : std_logic_vector(9 downto 0);
   signal vga_hs_d2    : std_logic;
   signal vga_vs_d2    : std_logic;

   signal vga_pix_x_d3 : std_logic_vector(9 downto 0);
   signal vga_pix_y_d3 : std_logic_vector(9 downto 0);
   signal vga_hs_d3    : std_logic;
   signal vga_vs_d3    : std_logic;
   signal vga_col_d3   : std_logic_vector(7 downto 0);

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

         vga_hs_d <= '0';
         vga_vs_d <= '0';

         if vga_pix_x_i >= HS_START and vga_pix_x_i < HS_START+HS_TIME then
            vga_hs_d   <= '1';
         end if;
         
         if vga_pix_y_i >= VS_START and vga_pix_y_i < VS_START+VS_TIME then
            vga_vs_d   <= '1';
         end if;

         vga_pix_x_d <= vga_pix_x_i;
         vga_pix_y_d <= vga_pix_y_i;
      end if;
   end process p_sync;


   ----------------------------------------------
   -- Add extra pipeline stage for memory output
   ----------------------------------------------

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
      variable addr_v : std_logic_vector(18 downto 0);
   begin
      if rising_edge(vga_clk_i) then
         vga_col_d4 <= (others => '0');

         -- Only set colour output inside visible area
         if vga_pix_x_d3 < H_PIXELS and vga_pix_y_d3 < V_PIXELS then
            vga_col_d4 <= vga_col_d3_i;
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

