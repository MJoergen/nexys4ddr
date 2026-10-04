-- This module generates the pixel coordinates for the video mode G_MODE (see
-- video_pkg.vhd). The pixel (0, 0) is the top left pixel of the visible area.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.video_pkg.all;

entity pix is
   generic (
      G_MODE  : video_mode_t
   );
   port (
      clk_i   : in  std_logic;

      -- Pixel counters
      pix_x_o : out std_logic_vector(10 downto 0);
      pix_y_o : out std_logic_vector(10 downto 0)
   );
end pix;

architecture structural of pix is

   constant H_TOTAL : integer := h_total(G_MODE);
   constant V_TOTAL : integer := v_total(G_MODE);

   -- Pixel counters
   signal pix_x : std_logic_vector(10 downto 0) := (others => '0');
   signal pix_y : std_logic_vector(10 downto 0) := (others => '0');

begin

   assert H_TOTAL <= 2**11 and V_TOTAL <= 2**11
      report "The pixel counters only support up to 2048 pixels and lines"
      severity failure;

   --------------------------------------------------
   -- Generate horizontal and vertical pixel counters
   --------------------------------------------------

   pix_x_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x = H_TOTAL-1 then
            pix_x <= (others => '0');
         else
            pix_x <= pix_x + 1;
         end if;
      end if;
   end process pix_x_proc;

   pix_y_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x = H_TOTAL-1  then
            if pix_y = V_TOTAL-1 then
               pix_y <= (others => '0');
            else
               pix_y <= pix_y + 1;
            end if;
         end if;
      end if;
   end process pix_y_proc;


   ------------------------
   -- Drive output signals
   ------------------------

   pix_x_o <= pix_x;
   pix_y_o <= pix_y;

end architecture structural;
