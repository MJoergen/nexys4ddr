library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a simple VGA controller generating
-- pixel coordinates and synchronizarion signals
-- corresponding to a 1280x1024 screen resolution.
-- The input clock must be 108 MHz.
entity vga is
   port (
      clk_i   : in  std_logic;   -- 108 MHz

      hs_o    : out std_logic;   -- Horizontal synchronization
      vs_o    : out std_logic;   -- Vertical synchronization
      pix_x_o : out std_logic_vector(10 downto 0);  -- Pixel coordiante x
      pix_y_o : out std_logic_vector(10 downto 0)   -- Pixel coordiante y
   );
end vga;

architecture structural of vga is

   -- Define constants used for 1280x1024 @ 60 Hz.
   -- Requires a clock of 108 MHz.
   -- See the 1280x1024 @ 60 Hz entry in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf
   constant H_PIXELS : integer := 1280;
   constant V_PIXELS : integer := 1024;
   --
   constant H_TOTAL  : integer := 1688;
   constant HS_START : integer := 1328;
   constant HS_TIME  : integer := 112;
   --
   constant V_TOTAL  : integer := 1066;
   constant VS_START : integer := 1025;
   constant VS_TIME  : integer := 3;

   -- Pixel counters
   signal pix_x_r : std_logic_vector(10 downto 0) := (others => '0');
   signal pix_y_r : std_logic_vector(10 downto 0) := (others => '0');

begin

   ---------------------------------------------------
   -- Generate horizontal and vertical pixel counters
   ---------------------------------------------------

   p_pix_x : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x_r = H_TOTAL-1 then
            pix_x_r <= (others => '0');
         else
            pix_x_r <= pix_x_r + 1;
         end if;
      end if;
   end process p_pix_x;

   p_pix_y : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x_r = H_TOTAL-1  then
            if pix_y_r = V_TOTAL-1 then
               pix_y_r <= (others => '0');
            else
               pix_y_r <= pix_y_r + 1;
            end if;
         end if;
      end if;
   end process p_pix_y;

   
   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   hs_o    <= '1' when pix_x_r >= HS_START and pix_x_r < HS_START+HS_TIME else '0';
   vs_o    <= '1' when pix_y_r >= VS_START and pix_y_r < VS_START+VS_TIME else '0';
   pix_x_o <= pix_x_r;
   pix_y_o <= pix_y_r;

end architecture structural;

