library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity pix is
   port (
      clk_i    : in  std_logic;    -- Expects 25.175 MHz

      pix_x_o  : out std_logic_vector(9 downto 0);
      pix_y_o  : out std_logic_vector(9 downto 0)
   );
end pix;

architecture structural of pix is

   -- Define pixel counter range
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Pixel counters
   signal pix_x : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y : std_logic_vector(9 downto 0) := (others => '0');

begin
   
   ---------------------------------------------------
   -- Generate horizontal and vertical pixel counters
   ---------------------------------------------------

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

   pix_x_o <= pix_x;
   pix_y_o <= pix_y;

end architecture structural;

