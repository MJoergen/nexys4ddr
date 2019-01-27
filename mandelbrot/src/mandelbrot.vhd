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

      btn_i     : in  std_logic_vector( 4 downto 0);  -- "CLRUD"
      sw_i      : in  std_logic_vector( 7 downto 0);
      led_o     : out std_logic_vector(15 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector( 7 downto 0)    -- RRRGGGBB
   );
end mandelbrot;

architecture structural of mandelbrot is

   constant C_MAX_COUNT     : integer := 511;
   constant C_NUM_ROWS      : integer := 480;
   constant C_NUM_COLS      : integer := 640;
   constant C_NUM_ITERATORS : integer := 240;

   constant C_START_X       : real := -1.6667;
   constant C_START_Y       : real := -1.0000;
   constant C_SIZE_X        : real :=  2.6667;
   constant C_SIZE_Y        : real :=  2.0000;

   signal startx         : std_logic_vector(17 downto 0);
   signal starty         : std_logic_vector(17 downto 0);
   signal stepx          : std_logic_vector(17 downto 0);
   signal stepy          : std_logic_vector(17 downto 0);

   signal main_clk       : std_logic;
   signal main_rst_delay : std_logic_vector(7 downto 0) := X"FF";
   signal main_rst       : std_logic;

   signal start          : std_logic;
   signal active         : std_logic;
   signal done           : std_logic;
   signal wait_cnt_tot   : std_logic_vector(15 downto 0);

   signal wr_addr        : std_logic_vector(18 downto 0);
   signal wr_data        : std_logic_vector( 8 downto 0);
   signal wr_en          : std_logic;

   signal vga_clk        : std_logic;
   signal vga_rst_delay  : std_logic_vector(7 downto 0) := X"FF";
   signal vga_rst        : std_logic;
   signal vga_addr_s     : std_logic_vector(18 downto 0);
   signal vga_data_s     : std_logic_vector(7 downto 0);
   signal vga_pix_x      : std_logic_vector(9 downto 0);
   signal vga_pix_y      : std_logic_vector(9 downto 0);
   signal vga_hs         : std_logic;
   signal vga_vs         : std_logic;
   signal vga_col        : std_logic_vector(7 downto 0);

   signal cnt            : std_logic_vector(31 downto 0);
   signal sw_d           : std_logic;
   signal sw_deb         : std_logic;

   -- 23 bits = 8 million cycles @ 150 MHz = 18 times pr second.
   signal main_upd_cnt   : std_logic_vector(22 downto 0);
   signal main_upd       : std_logic;
   signal btn_r          : std_logic_vector(4 downto 0);
   signal sw_r           : std_logic_vector(7 downto 0);

begin

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
  
  
   --------------------------------------------------
   -- Generate reset signals
   --------------------------------------------------

   p_main_rst : process (main_clk)
   begin
      if rising_edge(main_clk) then
         main_rst_delay <= main_rst_delay(6 downto 0) & "0";
         main_rst <= main_rst_delay(7);

         if rstn_i = '0' then
            main_rst_delay <= X"FF";
         end if;
      end if;
   end process p_main_rst;

   p_vga_rst : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_rst_delay <= vga_rst_delay(6 downto 0) & "0";
         vga_rst <= vga_rst_delay(7);

         if rstn_i = '0' then
            vga_rst_delay <= X"FF";
         end if;
      end if;
   end process p_vga_rst;


   p_main_upd : process (main_clk)
   begin
      if rising_edge(main_clk) then
         main_upd_cnt <= main_upd_cnt + 1;

         main_upd <= '0';
         if main_upd_cnt = 0 then
            main_upd <= '1';
         end if;
      end if;
   end process p_main_upd;


   p_xy : process (main_clk)
   begin
      if rising_edge(main_clk) then
         if main_upd = '1' then
            if btn_r(4) = '1' then
               if sw_r(2) = '1' then
                  stepx <= stepx + stepx(17 downto 6) + 1;
                  stepy <= stepy + stepy(17 downto 6) + 1;
               else
                  stepx <= stepx - stepx(17 downto 6) - 1;
                  stepy <= stepy - stepy(17 downto 6) - 1;
               end if;
            end if;

            if btn_r(3) = '1' then
               startx <= startx - stepx;
            end if;
            if btn_r(2) = '1' then
               startx <= startx + stepx;
            end if;
            if btn_r(1) = '1' then
               starty <= starty - stepy;
            end if;
            if btn_r(0) = '1' then
               starty <= starty + stepy;
            end if;
         end if;

         btn_r <= btn_i;
         sw_r  <= sw_i;

         if main_rst = '1' then
            startx <= to_std_logic_vector(integer((C_START_X+4.0)*real(2**16)), 18);
            starty <= to_std_logic_vector(integer((C_START_Y+4.0)*real(2**16)), 18);
            stepx  <= to_std_logic_vector(integer(C_SIZE_X*real(2**16))/C_NUM_COLS, 18);
            stepy  <= to_std_logic_vector(integer(C_SIZE_Y*real(2**16))/C_NUM_ROWS, 18);
         end if;
      end if;
   end process p_xy;


   p_debounce : process (main_clk)
   begin
      if rising_edge(main_clk) then
         sw_d <= sw_i(0);

         sw_deb <= '0';
         if sw_i(0) = '1' and sw_d = '0' then
            sw_deb <= '1';
         end if;
      end if;
   end process p_debounce;


   p_active : process (main_clk)
   begin
      if rising_edge(main_clk) then
         start <= '0';

         if active = '0' then
            active <= '1';
            start  <= '1';
         end if;

         if done = '1' then
            active <= '0';
         end if;

         if main_rst = '1' then
            active <= '0';
         end if;
      end if;
   end process p_active;


   p_cnt : process (main_clk)
   begin
      if rising_edge(main_clk) then
         if active = '1' then
            cnt <= cnt + 1;
         end if;

         if start = '1' then
            cnt <= (others => '0');
         end if;
      end if;
   end process p_cnt;


   --------------------------------------------------
   -- Instantiate job dispatcher
   --------------------------------------------------

   i_dispatcher : entity work.dispatcher
      generic map (
         G_MAX_COUNT     => C_MAX_COUNT,
         G_NUM_ROWS      => C_NUM_ROWS,
         G_NUM_COLS      => C_NUM_COLS,
         G_NUM_ITERATORS => C_NUM_ITERATORS
      )
      port map (
         clk_i           => main_clk,
         rst_i           => main_rst,
         start_i         => start,
         startx_i        => startx,
         starty_i        => starty,
         stepx_i         => stepx,
         stepy_i         => stepy,
         wr_addr_o       => wr_addr,
         wr_data_o       => wr_data,
         wr_en_o         => wr_en,
         done_o          => done,
         wait_cnt_tot_o  => wait_cnt_tot
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


   vga_addr_s <= vga_pix_x & vga_pix_y(8 downto 0);

   ------------------------------
   -- Instantiate display memory
   ------------------------------

   i_disp_mem : entity work.disp_mem
      port map (
         wr_clk_i  => main_clk,
         wr_rst_i  => main_rst,
         wr_addr_i => wr_addr,
         wr_data_i => wr_data(7 downto 0),
         wr_en_i   => wr_en,
         --
         rd_clk_i  => vga_clk,
         rd_rst_i  => vga_rst,
         rd_addr_i => vga_addr_s,
         rd_data_o => vga_data_s
      ); -- i_disp_mem


   --------------------------------------------------
   -- Instantiate display
   --------------------------------------------------

   i_disp : entity work.disp
      port map (
         vga_clk_i    => vga_clk,
         vga_rst_i    => vga_rst,
         vga_pix_x_i  => vga_pix_x,
         vga_pix_y_i  => vga_pix_y,
         vga_col_d3_i => vga_data_s,
         vga_hs_o     => vga_hs,
         vga_vs_o     => vga_vs,
         vga_col_o    => vga_col
      ); -- i_disp


   --------------------------
   -- Connect output signals
   --------------------------

   -- If cnt increments at 150 MHz, then a single count is 13,65 us. The total
   -- amount wraps around after 0,9 seconds.
   led_o <= cnt(26 downto 11) when sw_i(1) = '1' else wait_cnt_tot;

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture structural;

