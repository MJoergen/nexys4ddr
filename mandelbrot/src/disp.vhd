library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity disp is
   port (
      wr_clk_i    : in  std_logic;
      wr_rst_i    : in  std_logic;
      wr_addr_i   : in  std_logic_vector(18 downto 0);
      wr_data_i   : in  std_logic_vector( 8 downto 0);
      wr_en_i     : in  std_logic;
      --
      vga_clk_i   : in  std_logic;
      vga_rst_i   : in  std_logic;
      vga_pix_x_i : in  std_logic_vector(9 downto 0);
      vga_pix_y_i : in  std_logic_vector(9 downto 0);
      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic;
      vga_col_o   : out std_logic_vector(7 downto 0)
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

   type mem_t is array (0 to 1024*512-1) of std_logic_vector(8 downto 0);
   signal mem : mem_t;

   signal vga_pix_x_d : std_logic_vector(9 downto 0);
   signal vga_pix_y_d : std_logic_vector(9 downto 0);
   signal vga_hs_d    : std_logic;
   signal vga_vs_d    : std_logic;
   signal vga_col_d   : std_logic_vector(7 downto 0);
   signal vga_col_dd  : std_logic_vector(7 downto 0);

   signal vga_hs_d2   : std_logic;
   signal vga_vs_d2   : std_logic;
   signal vga_col_d2  : std_logic_vector(7 downto 0);

begin

   p_write : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then
         if wr_en_i = '1' then
            mem(to_integer(wr_addr_i)) <= wr_data_i;
         end if;
      end if;
   end process p_write;


   p_read : process (vga_clk_i)
      variable addr_v : std_logic_vector(18 downto 0);
   begin
      if rising_edge(vga_clk_i) then
         addr_v := vga_pix_x_i & vga_pix_y_i(8 downto 0);
         vga_col_d <= mem(to_integer(addr_v))(7 downto 0);
         vga_col_dd <= vga_col_d;
      end if;
   end process p_read;


   p_pipe : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then

         -- Generate VGA synchronization signals
         if vga_pix_x_i >= HS_START and vga_pix_x_i < HS_START+HS_TIME then
            vga_hs_d   <= '1';
         end if;
         
         if vga_pix_y_i >= VS_START and vga_pix_y_i < VS_START+VS_TIME then
            vga_vs_d   <= '1';
         end if;

         vga_pix_x_d <= vga_pix_x_i;
         vga_pix_y_d <= vga_pix_y_i;
      end if;
   end process p_pipe;


   p_out : process (vga_clk_i)
      variable addr_v : std_logic_vector(18 downto 0);
   begin
      if rising_edge(vga_clk_i) then
         vga_hs_d2  <= '0';
         vga_vs_d2  <= '0';
         vga_col_d2 <= (others => '0');

         -- Only set colour output inside visible area
         if vga_pix_x_d < H_PIXELS and vga_pix_y_d < V_PIXELS then
            vga_col_d2 <= vga_col_dd;
         end if;

         vga_hs_d2 <= vga_hs_d;
         vga_vs_d2 <= vga_vs_d;
      end if;
   end process p_out;


   --------------------------
   -- Connect output signals
   --------------------------

   vga_hs_o  <= vga_hs_d2;
   vga_vs_o  <= vga_vs_d2;
   vga_col_o <= vga_col_d2;

end architecture rtl;

