library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity sync is
   port (
      clk_i    : in  std_logic;

      pix_x_o  : out std_logic_vector(9 downto 0);
      pix_y_o  : out std_logic_vector(9 downto 0)
   );
end sync;

architecture Structural of sync is

   -- Define constants used for 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Pixel counters
   signal pix_x  : std_logic_vector(9 downto 0);
   signal pix_y  : std_logic_vector(9 downto 0);

begin
   
   --------------------------------------------------
   -- Generate horizontal and vertical pixel counters
   --------------------------------------------------

   p_pix_x : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x = H_TOTAL-1 then
            pix_x <= (others => '0');
         else
            pix_x <= pix_x + 1;
         end if;
      end if;
   end process p_pix_x;

   p_pix_y : process (clk_i)
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
   end process p_pix_y;

   
   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   pix_x_o  <= pix_x;
   pix_y_o  <= pix_y;

end architecture Structural;

