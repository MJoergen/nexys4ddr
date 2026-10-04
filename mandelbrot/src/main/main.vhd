library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module runs entirely in the MAIN clock domain (G_CLK_FREQ). It
-- controls the view (from the buttons and switches), runs the dispatcher that
-- calculates the picture, and writes the result to the display memory.
--
-- The view is controlled by the buttons and switches on the board:
--   btn_i(4)         : Zoom in. If sw_i(2) is set then zoom out instead.
--   btn_i(3 downto 0): Move the view left, right, up and down.
-- While a button is pressed, the view is updated every 2^23 clock cycles, i.e.
-- about 18 (150 MHz) or 22 (188.235 MHz) times per second.
-- The view is kept inside the range -2 to 2, see view.vhd.
-- Switches 0 and 1 select the colour palette, but they are used in vga.vhd, not
-- here. The other switches are not used.
--
-- The 7-segment display shows the frame rate, i.e. the number of pictures per
-- second, calculated from the time taken by the most recently finished
-- picture. The frame rate is also output (fps_*_o), and shown on the VGA output
-- by vga.vhd. fps_toggle_o is changed (in the same clock cycle) each time
-- fps_digits_o and fps_blank_o are changed.

entity main is
   generic (
      -- The frequency of the MAIN clock in Hz, used to calculate the frame
      -- rate. This depends on the board, so it is set by the top level module.
      G_CLK_FREQ      : natural;
      -- The number of job modules, i.e. iterators and DSPs. This depends on
      -- the size of the FPGA, so it is set by the top level module.
      G_NUM_ITERATORS : integer;
      -- The number of pixels in each write to the display memory, see
      -- dispatcher.vhd and disp_mem.vhd. A power of two, and the rows in a
      -- job (C_ROWS_IN_JOB) must be a multiple of it.
      G_PIXELS        : integer;
      -- The size of the picture, i.e. the resolution of the VGA output, and
      -- the address distance between two picture columns in the display
      -- memory, see dispatcher.vhd.
      G_NUM_COLS      : integer;
      G_NUM_ROWS      : integer;
      G_COL_STRIDE    : integer
   );
   port (
      clk_i     : in  std_logic;                      -- G_CLK_FREQ
      rst_i     : in  std_logic;

      btn_i     : in  std_logic_vector( 4 downto 0);  -- "CLRUD"
      sw_i      : in  std_logic_vector( 7 downto 0);
      seg_o     : out std_logic_vector( 6 downto 0);  -- "GFEDCBA"
      seg_an_o  : out std_logic_vector( 7 downto 0);

      -- The frame rate, see fps.vhd
      fps_digits_o : out std_logic_vector(31 downto 0);
      fps_blank_o  : out std_logic_vector( 7 downto 0);
      fps_toggle_o : out std_logic;

      -- Write port of the display memory
      wr_addr_o : out std_logic_vector(18 downto 0);
      wr_data_o : out std_logic_vector(9*G_PIXELS-1 downto 0);
      wr_en_o   : out std_logic
   );
end main;

architecture structural of main is

   constant C_MAX_COUNT     : integer := 511;
   -- Rows in each job given to a job module, see dispatcher.vhd. The
   -- number of rows of the picture must be a multiple of it.
   constant C_ROWS_IN_JOB   : integer := 120;

   -- The initial view. The size has the same aspect ratio (4:3) as the
   -- picture.

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

   signal wr_addr_s      : std_logic_vector(18 downto 0);
   signal wr_data_s      : std_logic_vector(9*G_PIXELS-1 downto 0);
   signal wr_en_s        : std_logic;

   -- Time taken by the current picture, in clock cycles
   signal cnt            : std_logic_vector(26 downto 0);

   -- The frame rate, in decimal
   signal fps_digits     : std_logic_vector(31 downto 0);
   signal fps_blank      : std_logic_vector( 7 downto 0);
   signal fps_valid      : std_logic;
   signal fps_toggle     : std_logic := '0';

   -- 23 bits = 8 million cycles, i.e. 18 (150 MHz) or 22 (188.235 MHz) times
   -- per second.
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
         G_NUM_COLS => G_NUM_COLS,
         G_NUM_ROWS => G_NUM_ROWS,
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


   --------------------------------------------------
   -- Calculate the frame rate, and show it on the
   -- 7-segment display
   --------------------------------------------------

   -- At the end of a picture, cnt is the time taken by the picture. The
   -- picture is recalculated continuously, so the frame rate is updated
   -- after every picture.
   -- cnt wraps around after 2^27 clock cycles (0.71 s), but a picture takes
   -- far less: even if every pixel needed the maximum count, the model
   -- (sim/model.py) gives about 2.0 million clock cycles (10.8 ms) on the
   -- Nexys 4 DDR, i.e. a frame rate of about 92, and 1.7 million on the
   -- MEGA65 R6.
   i_fps : entity work.fps
      generic map (
         G_CLK_FREQ  => G_CLK_FREQ,
         G_TIME_BITS => 27,
         G_DIGITS    => 8
      )
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         time_i   => cnt,
         valid_i  => pic_done,
         digits_o => fps_digits,
         blank_o  => fps_blank,
         valid_o  => fps_valid
      ); -- i_fps

   -- Tells the VGA clock domain that the frame rate has changed. The frame rate
   -- is constant for much longer than the time it takes to move it to the VGA
   -- clock domain, see nexys4ddr.vhd.
   p_fps_toggle : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if fps_valid = '1' then
            fps_toggle <= not fps_toggle;
         end if;
      end if;
   end process p_fps_toggle;

   fps_digits_o <= fps_digits;
   fps_blank_o  <= fps_blank;
   fps_toggle_o <= fps_toggle;

   i_seg : entity work.seg
      port map (
         clk_i    => clk_i,
         digits_i => fps_digits,
         blank_i  => fps_blank,
         seg_o    => seg_o,
         seg_an_o => seg_an_o
      ); -- i_seg


   --------------------------------------------------
   -- Instantiate job dispatcher
   --------------------------------------------------

   i_dispatcher : entity work.dispatcher
      generic map (
         G_MAX_COUNT     => C_MAX_COUNT,
         G_NUM_ROWS      => G_NUM_ROWS,
         G_NUM_COLS      => G_NUM_COLS,
         G_COL_STRIDE    => G_COL_STRIDE,
         G_ROWS_IN_JOB   => C_ROWS_IN_JOB,
         G_NUM_ITERATORS => G_NUM_ITERATORS,
         G_PIXELS        => G_PIXELS
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
         done_o          => done
      ); -- i_dispatcher


   --------------------------
   -- Connect output signals
   --------------------------

   -- The display memory holds the full 9-bit count, see palette_pkg.vhd.
   wr_addr_o <= wr_addr_s;
   wr_data_o <= wr_data_s;
   wr_en_o   <= wr_en_s;

end architecture structural;
