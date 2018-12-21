library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity disp is
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      wr_addr_i : in  std_logic_vector(18 downto 0);
      wr_data_i : in  std_logic_vector( 8 downto 0);
      wr_en_i   : in  std_logic;
      pix_x_i   : in  std_logic_vector(9 downto 0);
      pix_y_i   : in  std_logic_vector(9 downto 0);
      hs_o      : out std_logic;
      vs_o      : out std_logic;
      col_o     : out std_logic_vector(7 downto 0)
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

   signal hs  : std_logic;
   signal vs  : std_logic;
   signal col : std_logic_vector(7 downto 0);

begin

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            mem(to_integer(wr_addr_i)) <= wr_data_i;
         end if;
      end if;
   end process p_write;


   p_out : process (clk_i)
      variable addr_v : std_logic_vector(18 downto 0);
   begin
      if rising_edge(clk_i) then
         hs  <= '0';
         vs  <= '0';
         col <= (others => '0');

         if pix_x_i >= H_PIXELS or pix_y_i >= V_PIXELS then
            addr_v := pix_x_i & pix_y_i(8 downto 0);
            col <= mem(to_integer(addr_v))(7 downto 0);
         end if;

         if pix_x_i >= HS_START and pix_x_i < HS_START+HS_TIME then
            hs <= '0';
         end if;
         
         if pix_y_i >= VS_START and pix_y_i < VS_START+VS_TIME then
            vs <= '0';
         end if;
      end if;
   end process p_out;


   --------------------------
   -- Connect output signals
   --------------------------

   hs_o  <= hs;
   vs_o  <= vs;
   col_o <= col;

end architecture rtl;

