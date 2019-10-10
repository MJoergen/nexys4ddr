library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a simple VGA controller generating
-- pixel coordinates and synchronizarion signals
-- corresponding to a 640x480 screen resolution.
-- The input clock must be 25.175 MHz, but plain 25 MHz will work.
entity vga is
   port (
      clk_i   : in  std_logic;   -- 25 MHz

      hs_o    : out std_logic;   -- Horizontal synchronization
      vs_o    : out std_logic;   -- Vertical synchronization
      pix_x_o : out std_logic_vector(9 downto 0);  -- Pixel coordiante x
      pix_y_o : out std_logic_vector(9 downto 0)   -- Pixel coordiante y
   );
end vga;

architecture structural of vga is

   -- Define constants used for 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;
   --
   constant H_TOTAL  : integer := 800;
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   --
   constant V_TOTAL  : integer := 525;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

   -- Pixel counters
   signal pix_x_r : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y_r : std_logic_vector(9 downto 0) := (others => '0');

   signal hs_r    : std_logic;
   signal vs_r    : std_logic;

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
   -- Generate horizontal sync signal
   --------------------------------------------------

   p_hs : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x_r >= HS_START and pix_x_r < HS_START+HS_TIME then
            hs_r <= '0';
         else
            hs_r <= '1';
         end if;
      end if;
   end process p_hs;


   --------------------------------------------------
   -- Generate vertical sync signal
   --------------------------------------------------

   p_vs : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_y_r >= VS_START and pix_y_r < VS_START+VS_TIME then
            vs_r <= '0';
         else
            vs_r <= '1';
         end if;
      end if;
   end process p_vs;

   
   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   hs_o    <= hs_r;
   vs_o    <= vs_r;
   pix_x_o <= pix_x_r;
   pix_y_o <= pix_y_r;

end architecture structural;

