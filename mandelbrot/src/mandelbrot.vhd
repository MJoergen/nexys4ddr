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
      rstn_i    : in  std_logic;

      sw_i      : in  std_logic_vector(7 downto 0);
      led_o     : out std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end mandelbrot;

architecture structural of mandelbrot is

   constant startx  : std_logic_vector(17 downto 0) := "11" & X"0000";
   constant starty  : std_logic_vector(17 downto 0) := "11" & X"0000";
   constant stepx   : std_logic_vector(17 downto 0) := "00" & X"0100";
   constant stepy   : std_logic_vector(17 downto 0) := "00" & X"0100";

   signal main_clk  : std_logic;
   signal rst       : std_logic;

   signal start     : std_logic;
   signal active    : std_logic;
   signal done      : std_logic;

   signal wr_addr   : std_logic_vector(18 downto 0);
   signal wr_data   : std_logic_vector( 8 downto 0);
   signal wr_en     : std_logic;

   signal vga_clk   : std_logic;
   signal vga_pix_x : std_logic_vector(9 downto 0);
   signal vga_pix_y : std_logic_vector(9 downto 0);
   signal vga_hs    : std_logic;
   signal vga_vs    : std_logic;
   signal vga_col   : std_logic_vector(7 downto 0);

begin

   rst <= not rstn_i;
   
   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   i_clk : entity work.clk_wiz_0_clk_wiz
      port map (
         clk_in1  => clk_i,
         eth_clk  => open, -- Not needed yet.
         vga_clk  => vga_clk,
         main_clk => main_clk
      ); -- i_clk
  
  
  p_active : process (main_clk)
     begin
        if rising_edge(main_clk) then
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
         --G_NUM_ITERATORS => 240
         G_NUM_ITERATORS => 4
      )
      port map (
         clk_i     => main_clk,
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
         clk_i     => vga_clk,
         pix_x_o   => vga_pix_x,
         pix_y_o   => vga_pix_y
      ); -- i_pix


   --------------------------------------------------
   -- Instantiate display
   --------------------------------------------------

   i_disp : entity work.disp
      port map (
         wr_clk_i    => main_clk,
         wr_rst_i    => rst,
         wr_addr_i   => wr_addr,
         wr_data_i   => wr_data,
         wr_en_i     => wr_en,
         --
         vga_clk_i   => vga_clk,
         vga_rst_i   => rst,
         vga_pix_x_i => vga_pix_x,
         vga_pix_y_i => vga_pix_y,
         vga_hs_o    => vga_hs,
         vga_vs_o    => vga_vs,
         vga_col_o   => vga_col
      ); -- i_disp


   --------------------------
   -- Connect output signals
   --------------------------

   led_o(7 downto 3)  <= (others => '0');
   led_o(2)  <= active;
   led_o(1)  <= done;
   led_o(0)  <= start;
   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture structural;

