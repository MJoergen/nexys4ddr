library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module generates a pair of free-running pixel coordinates.
-- To enable a 640x480 display, you must
-- choose G_PIX_X_COUNT = 800 amd G_PIX_Y_CUONT = 525
-- and supply a clock of 25.2 MHz.

entity pix is
   generic (
      G_PIX_X_COUNT : integer;
      G_PIX_Y_COUNT : integer
   );
   port (
      clk_i   : in  std_logic;

      -- Pixel counters
      pix_x_o : out std_logic_vector(9 downto 0);
      pix_y_o : out std_logic_vector(9 downto 0)
   );
end pix;

architecture structural of pix is

   -- Pixel counters
   signal pix_x_r : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y_r : std_logic_vector(9 downto 0) := (others => '0');

begin
   
   --------------------------------------------------
   -- Generate horizontal and vertical pixel counters
   --------------------------------------------------

   p_pix_x : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x_r = G_PIX_X_COUNT-1 then
            pix_x_r <= (others => '0');
         else
            pix_x_r <= pix_x_r + 1;
         end if;
      end if;
   end process p_pix_x;

   p_pix_y : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x_r = G_PIX_X_COUNT-1 then
            if pix_y_r = G_PIX_Y_COUNT-1 then
               pix_y_r <= (others => '0');
            else
               pix_y_r <= pix_y_r + 1;
            end if;
         end if;
      end if;
   end process p_pix_y;


   ------------------------
   -- Drive output signals
   ------------------------

   pix_x_o <= pix_x_r;
   pix_y_o <= pix_y_r;

end architecture structural;

