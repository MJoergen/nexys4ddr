library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end vga;

architecture Structural of vga is

   -- Define constants used for 640x480 @ 60 Hz.
   -- Requires a clock of approx 25 MHz.
   -- See http://caxapa.ru/thumbs/361638/DMTv1r11.pdf
   constant SIZE_X   : integer := 640;
   constant HS_FIRST : integer := 655;
   constant HS_LAST  : integer := 750;
   constant COUNT_X  : integer := 800;
   constant SIZE_Y   : integer := 480;
   constant VS_FIRST : integer := 489;
   constant VS_LAST  : integer := 490;
   constant COUNT_Y  : integer := 525;

   -- Clock divider
   signal cnt : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk : std_logic;

   -- Pixel counters
   signal pix_x : std_logic_vector(9 downto 0);
   signal pix_y : std_logic_vector(9 downto 0);

   -- Synchronization
   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;

   -- Pixel colour
   signal vga_col : std_logic_vector(7 downto 0);

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   --------------------------------------------------

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt <= cnt + 1;
      end if;
   end process;

   vga_clk <= cnt(1);


   --------------------------------------------------
   -- Genrate horizontal and vertical pixel counters
   --------------------------------------------------

   p_pix_x : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         if pix_x = COUNT_X-1 then
            pix_x <= (others => '0');
         else
            pix_x <= pix_x + 1;
         end if;
      end if;
   end process p_pix_x;

   p_pix_y : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         if pix_x = COUNT_X-1  then
            if pix_y = COUNT_Y-1 then
               pix_y <= (others => '0');
            else
               pix_y <= pix_y + 1;
            end if;
         end if;
      end if;
   end process p_pix_y;

   
   --------------------------------------------------
   -- Genrate horizontal and vertical sync signals
   --------------------------------------------------

   p_hs : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_hs <= '0';
         if pix_x >= HS_FIRST and pix_x <= HS_LAST then
            vga_hs <= '1';
         end if;
      end if;
   end process p_hs;

   p_vs : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_vs <= '0';
         if pix_y >= VS_FIRST and pix_y <= VS_LAST then
            vga_vs <= '1';
         end if;
      end if;
   end process p_vs;

   
   --------------------------------------------------
   -- Genrate pixel colour
   --------------------------------------------------

   p_col : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_col <= (others => '0');

         if pix_x < SIZE_X and pix_y < SIZE_Y then
            vga_col(7 downto 4) <= pix_x(7 downto 4);
            vga_col(3 downto 0) <= pix_y(7 downto 4);
         end if;
      end if;
   end process p_col;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

