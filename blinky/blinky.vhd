library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity top is
   port (
      clk_i       : in  std_logic;
      sw_i        : in  std_logic_vector(7 downto 0);
      led_o       : out std_logic_vector(7 downto 0);
      seg_ca_o    : out std_logic_vector(6 downto 0);
      seg_dp_o    : out std_logic;
      seg_an_o    : out std_logic_vector(3 downto 0);
      vga_red_o   : out std_logic_vector(3 downto 0);
      vga_green_o : out std_logic_vector(3 downto 0);
      vga_blue_o  : out std_logic_vector(3 downto 0);
      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic
   );
end entity top;

architecture synthesis of top is

   signal counter : std_logic_vector(27 downto 0);

begin

   p_counter : process (clk_i)
   begin
      if rising_edge(clk_i) then
         counter <= std_logic_vector(unsigned(counter) + conv_integer(sw_i));
      end if;
   end process;

   led_o <= counter(27 downto 20);

end architecture synthesis;

