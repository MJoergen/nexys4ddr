library ieee;
use ieee.std_logic_1164.all;

entity display is
   generic (
      G_FREQ : integer
   );
   port (
      -- Clock and reset
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;

      -- Input value
      value_i  : in  std_logic_vector(13 downto 0);

      -- Output segment display
      seg_ca_o : out std_logic_vector(6 downto 0);
      seg_dp_o : out std_logic;
      seg_an_o : out std_logic_vector(3 downto 0)
   );
end entity display;

architecture synthesis of display is

   signal seg3 : std_logic_vector(6 downto 0);  -- First segment
   signal seg2 : std_logic_vector(6 downto 0);  -- Second segment
   signal seg1 : std_logic_vector(6 downto 0);  -- Third segment
   signal seg0 : std_logic_vector(6 downto 0);  -- Fourth segment
   signal dp   : std_logic_vector(4 downto 1);

begin

   i_display_int2seg : entity work.display_int2seg
      port map (
         int_i  => value_i,
         seg3_o => seg3,
         seg2_o => seg2,
         seg1_o => seg1,
         seg0_o => seg0,
         dp_o   => dp
      ); -- i_int2seg


   i_display_seg : entity work.display_seg
      generic map (
         G_FREQ => G_FREQ
      )
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         seg3_i   => seg3,
         seg2_i   => seg2,
         seg1_i   => seg1,
         seg0_i   => seg0,
         dp_i     => dp,
         seg_ca_o => seg_ca_o,
         seg_dp_o => seg_dp_o,
         seg_an_o => seg_an_o
      ); -- i_seg

end architecture synthesis;

