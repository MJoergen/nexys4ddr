library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

   signal num_solutions : std_logic_vector(13 downto 0);
   signal num_positions : std_logic_vector(13 downto 0);
   signal value         : std_logic_vector(13 downto 0);
   signal board         : std_logic_vector(G_NUM_QUEENS*G_NUM_QUEENS-1 downto 0);
   signal valid         : std_logic;
   signal done          : std_logic;

begin

   -- Input / output signals
   rst               <= sw_i(0);
   led_o(7 downto 0) <= sw_i(7 downto 0);


   -- Generate VGA clock
   i_clk : entity work.clk
      port map
      (
         clk_i => clk_i,
         clk_o => vga_clk
      ); -- i_clk


   -- Generate a single pulse for every time the board should be updated.
   i_counter : entity work.counter
      generic map (
         G_COUNTER => G_FREQ
      )
      port map (
         clk_i  => vga_clk,
         rst_i  => rst,
         inc_i  => sw_i(7 downto 2),
         wrap_o => queens_en
      ); -- i_counter


   -- This controls the board
   i_queens : entity work.queens
      generic map (
         G_NUM_QUEENS => G_NUM_QUEENS
      )
      port map ( 
         clk_i    => vga_clk,
         rst_i    => rst,
         en_i     => queens_en,
         board_o  => board,
         valid_o  => valid,
         done_o   => done
      ); -- i_queens


   -- Display the current board on the VGA output
   i_vga : entity work.vga
      generic map (
         G_NUM_QUEENS => G_NUM_QUEENS
      )
      port map (
         clk_i       => vga_clk,
         rst_i       => rst,
         board_i     => board,
         vga_hs_o    => vga_hs_o,
         vga_vs_o    => vga_vs_o,
         vga_red_o   => vga_red_o,
         vga_green_o => vga_green_o,
         vga_blue_o  => vga_blue_o
      ); -- i_vga


   p_num_solutions : process (vga_clk) is
   begin
      if rising_edge(vga_clk) then
         if valid = '1' and queens_en = '1' then
            num_solutions <= std_logic_vector(unsigned(num_solutions) + 1);
         end if;
         if rst = '1' then
            num_solutions <= (others => '0');
         end if;
      end if;
   end process p_num_solutions;


   p_num_positions : process (vga_clk) is
   begin
      if rising_edge(vga_clk) then
         if queens_en = '1' then
            num_positions <= std_logic_vector(unsigned(num_positions) + 1);
         end if;
         if rst = '1' then
            num_positions <= (others => '0');
         end if;
      end if;
   end process p_num_positions;

   value <= num_solutions when sw_i(1) = '1' else
            num_positions;


   -- Displau current number of solutions on the 7-segment display
   i_display : entity work.display
      generic map (
         G_FREQ => G_FREQ
      )
      port map (
         clk_i    => clk_i,
         rst_i    => rst,
         value_i  => value,
         seg_ca_o => seg_ca_o,
         seg_dp_o => seg_dp_o,
         seg_an_o => seg_an_o
      ); -- i_display

end architecture synthesis;

