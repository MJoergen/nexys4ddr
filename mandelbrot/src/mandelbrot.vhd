library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can display eight binary digits on the VGA
-- output. The value of the binary digits are controlled by slide switches on
-- the board.

entity mandelbrot is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);
      led_o     : out std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end mandelbrot;

architecture structural of mandelbrot is

   signal clk     : std_logic;
   signal rst     : std_logic;

   signal start   : std_logic;
   signal active  : std_logic;
   signal startx  : std_logic_vector(17 downto 0);
   signal starty  : std_logic_vector(17 downto 0);
   signal stepx   : std_logic_vector(17 downto 0);
   signal stepy   : std_logic_vector(17 downto 0);
   signal done    : std_logic;

   signal wr_addr : std_logic_vector(18 downto 0);
   signal wr_data : std_logic_vector( 8 downto 0);
   signal wr_en   : std_logic;

   signal pix_x   : std_logic_vector(9 downto 0);
   signal pix_y   : std_logic_vector(9 downto 0);
   signal hs      : std_logic;
   signal vs      : std_logic;
   signal col     : std_logic_vector(7 downto 0);

begin
   
   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   i_clk : entity work.clk_wiz_0_clk_wiz
      port map (
         clk_in1  => clk_i,
         eth_clk  => open, -- Not needed yet.
         vga_clk  => clk,
         main_clk => open
      ); -- i_clk

   p_active : process (clk)
   begin
      if rising_edge(clk) then
         start <= '0';

         if sw_i(0) = '1' and active = '0' then
            active <= '1';
            start  <= '1';
         end if;

         if done = '1' then
            active <= '0';
         end if;

         if rst = '1' then
            active <= '0';
         end if;
      end if;
   end process p_active;

   --------------------------------------------------
   -- Instantiate job dispatcher
   --------------------------------------------------

   i_dispatcher : entity work.dispatcher
      generic map (
         G_MAX_COUNT     => 511,
         G_NUM_ROWS      => 480,
         G_NUM_COLS      => 640,
         G_NUM_ITERATORS => 240
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         start_i   => start,
         startx_i  => startx,
         starty_i  => starty,
         stepx_i   => stepx,
         stepy_i   => stepy,
         wr_addr_o => wr_addr,
         wr_data_o => wr_data,
         wr_en_o   => wr_en,
         done_o    => done
      ); -- i_dispatcher


   --------------------------------------------------
   -- Instantiate pixel counters
   --------------------------------------------------

   i_pix : entity work.pix
      port map (
         clk_i     => clk,
         pix_x_o   => pix_x,
         pix_y_o   => pix_y
      ); -- i_pix


   --------------------------------------------------
   -- Instantiate display
   --------------------------------------------------

   i_disp : entity work.disp
      port map (
         clk_i     => clk,
         rst_i     => rst,
         wr_addr_i => wr_addr,
         wr_data_i => wr_data,
         wr_en_i   => wr_en,
         pix_x_i   => pix_x,
         pix_y_i   => pix_y,
         hs_o      => hs,
         vs_o      => vs,
         col_o     => col
      ); -- i_disp


   --------------------------
   -- Connect output signals
   --------------------------

   led_o(7 downto 3)  <= (others => '0');
   led_o(2)  <= active;
   led_o(1)  <= done;
   led_o(0)  <= start;
   vga_hs_o  <= hs;
   vga_vs_o  <= vs;
   vga_col_o <= col;

end architecture structural;

