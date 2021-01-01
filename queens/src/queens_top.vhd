library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity queens_top is
   generic (
      G_FREQ          : integer := 100*1000*1000; -- 100 MHz
      G_NUM_QUEENS    : integer := 8
   );
   port (
      -- Clock
      clk_i           : in  std_logic;

      -- Input switches
      sw_i            : in  std_logic_vector(7 downto 0);

      -- Output LEDs
      led_o           : out std_logic_vector(7 downto 0);

      -- Output segment display
      seg_ca_o        : out std_logic_vector(6 downto 0);
      seg_dp_o        : out std_logic;
      seg_an_o        : out std_logic_vector(3 downto 0);

      -- VGA port
      vga_hs_o        : out std_logic; 
      vga_vs_o        : out std_logic;
      vga_red_o       : out std_logic_vector(3 downto 0); 
      vga_green_o     : out std_logic_vector(3 downto 0); 
      vga_blue_o      : out std_logic_vector(3 downto 0)
   );
end entity queens_top;

architecture synthesis of queens_top is

  signal queens_en     : std_logic;

  signal vga_clk       : std_logic;   -- 108 MHz
  signal rst           : std_logic;

  signal hcount        : std_logic_vector(11 downto 0);
  signal vcount        : std_logic_vector(11 downto 0);
  signal blank         : std_logic;

  signal vga           : std_logic_vector(11 downto 0);

  signal clk_1kHz      : std_logic;
  signal seg3          : std_logic_vector(6 downto 0);  -- First segment
  signal seg2          : std_logic_vector(6 downto 0);  -- Second segment
  signal seg1          : std_logic_vector(6 downto 0);  -- Third segment
  signal seg0          : std_logic_vector(6 downto 0);  -- Fourth segment
  signal dp            : std_logic_vector(4 downto 1);

  signal num_solutions : std_logic_vector(13 downto 0);
  signal board         : std_logic_vector(G_NUM_QUEENS*G_NUM_QUEENS-1 downto 0);
  signal valid         : std_logic;
  signal done          : std_logic;

begin

   -- Input / output signals
   rst               <= sw_i(0);
   led_o(7 downto 0) <= sw_i(7 downto 0);

   vga_red_o   <= vga(11 downto 8);
   vga_green_o <= vga(7 downto 4);
   vga_blue_o  <= vga(3 downto 0);


   -- Generate VGA clock
   i_clk_wiz_0 : entity work.clk_wiz_0
      port map
      (
         clk_in1  => clk_i,
         clk_out1 => vga_clk
      ); -- i_clk_wiz_0


   -- Generate a single pulse for every time the board should be updated.
   i_counter : entity work.counter
      generic map (
         FREQ    => G_FREQ
      )
      port map (
         clk_i   => vga_clk,
         rst_i   => rst,
         speed_i => sw_i(7 downto 1),
         en_o    => queens_en
      ); -- i_counter


   -- This controls the board
   i_queens : entity work.queens
      generic map (
         NUM_QUEENS => G_NUM_QUEENS
      )
      port map ( 
         clk_i    => vga_clk,
         rst_i    => rst,
         en_i     => queens_en,
         board_o  => board,
         valid_o  => valid,
         done_o   => done
      ); -- i_queens


   -- This generates the image
   i_disp_queens : entity work.disp_queens
      generic map (
         NUM_QUEENS => G_NUM_QUEENS
      )
      port map (
         vga_clk_i  => vga_clk,
         hcount_i   => hcount,
         vcount_i   => vcount,
         blank_i    => blank,
         board_i    => board,
         vga_o      => vga
      ); -- i_disp_queens


   -- This generates the VGA timing signals
   i_vga_ctrl : entity work.vga_ctrl
      port map (
         vga_clk_i => vga_clk,
         rst_i     => rst,
         HS_o      => vga_hs_o,
         VS_o      => vga_vs_o,
         hcount_o  => hcount,
         vcount_o  => vcount,
         blank_o   => blank
      ); -- i_vga_ctrl


   p_num_solutions : process (vga_clk) is
   begin
      if rising_edge(vga_clk) then
         if valid = '1' and queens_en = '1' then
            num_solutions <= num_solutions + "00000000000001";
         end if;
         if rst = '1' then
            num_solutions <= (others => '0');
         end if;
      end if;
   end process p_num_solutions;


   i_seg : entity work.seg
      port map ( 
         clk_1kHz_i  => clk_1kHz,
         seg_ca_o    => seg_ca_o,
         seg_dp_o    => seg_dp_o,
         seg_an_o    => seg_an_o,
         seg3_i      => seg3,
         seg2_i      => seg2,
         seg1_i      => seg1,
         seg0_i      => seg0,
         dp_i        => dp
      ); -- i_seg


   i_int2seg : entity work.int2seg
      port map (
         int_i  => num_solutions,
         seg3_o => seg3,
         seg2_o => seg2,
         seg1_o => seg1,
         seg0_o => seg0,
         dp_o   => dp
      ); -- i_int2seg


   i_clk : entity work.clk
      generic map (
         SCALER => G_FREQ/1000
      )
      port map (
         clk_i => vga_clk,
         clk_o => clk_1kHz
      ); -- i_clk

end architecture synthesis;

