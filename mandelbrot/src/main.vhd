library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module runs entirely in the MAIN clock domain (140.625 MHz). It
-- controls the view (from the buttons and switches), runs the dispatcher that
-- calculates the picture, and writes the result to the display memory.
--
-- The view is controlled by the buttons and switches on the board:
--   btn_i(4)         : Zoom in. If sw_i(2) is set then zoom out instead.
--   btn_i(3 downto 0): Move the view left, right, up and down.
--   sw_i(1)          : Select what the LEDs show.
-- While a button is pressed, the view is updated about 17 times per second.
-- The view is kept inside the range -2 to 2, see view.vhd.
-- The other switches are not used.

entity main is
   port (
      clk_i     : in  std_logic;                      -- 140.625 MHz
      rst_i     : in  std_logic;

      btn_i     : in  std_logic_vector( 4 downto 0);  -- "CLRUD"
      sw_i      : in  std_logic_vector( 7 downto 0);
      led_o     : out std_logic_vector(15 downto 0);

      -- Write port of the display memory
      wr_addr_o : out std_logic_vector(18 downto 0);
      wr_data_o : out std_logic_vector( 7 downto 0);
      wr_en_o   : out std_logic
   );
end main;

architecture structural of main is

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

   signal start          : std_logic;
   signal active         : std_logic;
   signal done           : std_logic;
   signal pic_done       : std_logic;
   signal wait_cnt_tot   : std_logic_vector(15 downto 0);

   signal wr_addr_s      : std_logic_vector(18 downto 0);
   signal wr_data_s      : std_logic_vector( 8 downto 0);
   signal wr_en_s        : std_logic;

   signal cnt            : std_logic_vector(26 downto 0);

   -- Values shown on the LEDs, latched at the end of each picture.
   signal pic_time       : std_logic_vector(15 downto 0);
   signal pic_wait       : std_logic_vector(15 downto 0);
   signal wait_cnt_prev  : std_logic_vector(15 downto 0);

   -- 23 bits = 8 million cycles @ 140.625 MHz = 17 times per second.
   signal upd_cnt        : std_logic_vector(22 downto 0) := (others => '0');
   signal upd            : std_logic;
   signal btn_r          : std_logic_vector(4 downto 0);
   signal sw_r           : std_logic_vector(7 downto 0);

begin

   p_upd : process (clk_i)
   begin
      if rising_edge(clk_i) then
         upd_cnt <= upd_cnt + 1;

         upd <= '0';
         if upd_cnt = 0 then
            upd <= '1';
         end if;
      end if;
   end process p_upd;


   p_btn : process (clk_i)
   begin
      if rising_edge(clk_i) then
         btn_r <= btn_i;
         sw_r  <= sw_i;
      end if;
   end process p_btn;


   --------------------------------------------------
   -- Instantiate view control
   --------------------------------------------------

   i_view : entity work.view
      generic map (
         G_NUM_COLS => C_NUM_COLS,
         G_NUM_ROWS => C_NUM_ROWS,
         G_START_X  => C_START_X,
         G_START_Y  => C_START_Y,
         G_SIZE_X   => C_SIZE_X,
         G_SIZE_Y   => C_SIZE_Y
      )
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         upd_i      => upd,
         btn_i      => btn_r,
         zoom_out_i => sw_r(2),
         startx_o   => startx,
         starty_o   => starty,
         stepx_o    => stepx,
         stepy_o    => stepy
      ); -- i_view


   -- The current picture is finished. The signal done stays high until the
   -- dispatcher has seen the start, so done is ignored while start is high.
   -- Otherwise done would cancel the new picture, and a second start would be
   -- generated. This is high for a single clock cycle for each picture.
   pic_done <= active and done and not start;

   p_active : process (clk_i)
   begin
      if rising_edge(clk_i) then
         start <= '0';

         -- Start a new picture, as soon as the previous one is finished.
         if active = '0' then
            active <= '1';
            start  <= '1';
         elsif pic_done = '1' then
            active <= '0';
         end if;

         if rst_i = '1' then
            active <= '0';
            start  <= '0';
         end if;
      end if;
   end process p_active;


   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if active = '1' then
            cnt <= cnt + 1;
         end if;

         if start = '1' then
            cnt <= (others => '0');
         end if;
      end if;
   end process p_cnt;


   -- Latch the values shown on the LEDs at the end of each picture. The
   -- picture is recalculated continuously, so the counters themselves change
   -- too fast to be read on the LEDs.
   -- * pic_time is the time taken by the picture.
   -- * pic_wait is the total waiting time of all the column modules during the
   --   picture. The sum of the wait counters (wait_cnt_tot) is accumulated from
   --   reset, so this is the difference from the value at the end of the
   --   previous picture. The subtraction is modulo 2^16, so it is correct even
   --   if wait_cnt_tot has wrapped around.
   p_leds : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pic_done = '1' then
            pic_time      <= cnt(26 downto 11);
            pic_wait      <= wait_cnt_tot - wait_cnt_prev;
            wait_cnt_prev <= wait_cnt_tot;
         end if;

         if rst_i = '1' then
            pic_time      <= (others => '0');
            pic_wait      <= (others => '0');
            wait_cnt_prev <= (others => '0');
         end if;
      end if;
   end process p_leds;


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
         clk_i           => clk_i,
         rst_i           => rst_i,
         start_i         => start,
         startx_i        => startx,
         starty_i        => starty,
         stepx_i         => stepx,
         stepy_i         => stepy,
         wr_addr_o       => wr_addr_s,
         wr_data_o       => wr_data_s,
         wr_en_o         => wr_en_s,
         done_o          => done,
         wait_cnt_tot_o  => wait_cnt_tot
      ); -- i_dispatcher


   --------------------------
   -- Connect output signals
   --------------------------

   -- The LEDs show one of two values for the most recently finished picture,
   -- selected by sw_i(1):
   -- * The time taken by the picture. The counter cnt increments at
   --   140.625 MHz while a picture is being calculated, and only bits 26
   --   downto 11 are shown, so a single count on the LEDs is 14.56 us. The
   --   value wraps around after 0.95 seconds.
   -- * The total waiting time of all the column modules during the picture,
   --   summed up. This is the time spent waiting for the result to be
   --   acknowledged, in the same units (2^11 clock cycles).
   led_o <= pic_time when sw_r(1) = '1' else pic_wait;

   -- The display memory is only 8 bits wide, so only the lower 8 bits of the
   -- count are written. They are used directly as the colour (RRRGGGBB).
   wr_addr_o <= wr_addr_s;
   wr_data_o <= wr_data_s(7 downto 0);
   wr_en_o   <= wr_en_s;

end architecture structural;
