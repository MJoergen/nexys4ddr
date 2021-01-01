library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity display_int2seg is
   port (
      int_i  : in  std_logic_vector(13 downto 0);
      seg3_o : out std_logic_vector( 6 downto 0);
      seg2_o : out std_logic_vector( 6 downto 0);
      seg1_o : out std_logic_vector( 6 downto 0);
      seg0_o : out std_logic_vector( 6 downto 0);
      dp_o   : out std_logic_vector( 4 downto 1)
   );
end entity display_int2seg;

architecture synthesis of display_int2seg is

   signal remain1 : std_logic_vector( 7 downto 0);
   signal remain2 : std_logic_vector(10 downto 0);
   signal remain3 : std_logic_vector(13 downto 0);

begin

   i_seg3 : entity work.display_digit
      generic map (
         G_INC  => 1000,
         G_BITS => 14
      )
      port map (
         value_i  => int_i,
         remain_o => remain3,
         seg_o    => seg3_o
      );

   i_seg2 : entity work.display_digit
      generic map (
         G_INC  => 100,
         G_BITS => 11
      )
      port map (
         value_i  => remain3(10 downto 0),
         remain_o => remain2,
         seg_o    => seg2_o
      );

   i_seg1 : entity work.display_digit
      generic map (
         G_INC  => 10,
         G_BITS => 8
      )
      port map (
         value_i  => remain2(7 downto 0),
         remain_o => remain1,
         seg_o    => seg1_o
      );

   i_seg0 : entity work.display_digit
      generic map (
         G_INC  => 1,
         G_BITS => 5
      )
      port map (
         value_i  => remain1(4 downto 0),
         remain_o => open,
         seg_o    => seg0_o
      );

   dp_o <= "0000";

end architecture synthesis;

