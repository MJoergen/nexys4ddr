library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga is
   generic (
      G_NUM_QUEENS : integer := 8
   );
   port (
      -- Clock and reset
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;

      -- Board to display
      board_i     : in  std_logic_vector(G_NUM_QUEENS*G_NUM_QUEENS-1 downto 0);

      -- VGA port
      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic;
      vga_red_o   : out std_logic_vector(3 downto 0);
      vga_green_o : out std_logic_vector(3 downto 0);
      vga_blue_o  : out std_logic_vector(3 downto 0)
   );
end entity vga;

architecture synthesis of vga is

   signal hcount : std_logic_vector(11 downto 0);
   signal vcount : std_logic_vector(11 downto 0);
   signal blank  : std_logic;

   signal color  : std_logic_vector(11 downto 0);

begin

   -- This generates the VGA timing signals
   i_vga_ctrl : entity work.vga_ctrl
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         hcount_o => hcount,
         vcount_o => vcount,
         blank_o  => blank,
         HS_o     => vga_hs_o,
         VS_o     => vga_vs_o
      ); -- i_vga_ctrl

   -- This generates the image
   i_vga_disp_queens : entity work.vga_disp_queens
      generic map (
         G_NUM_QUEENS => G_NUM_QUEENS
      )
      port map (
         clk_i    => clk_i,
         board_i  => board_i,
         hcount_i => hcount,
         vcount_i => vcount,
         blank_i  => blank,
         vga_o    => color
      ); -- i_disp_queens

   vga_red_o   <= color(11 downto 8);
   vga_green_o <= color(7 downto 4);
   vga_blue_o  <= color(3 downto 0);

end architecture synthesis;

