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
   signal wait_cnt_tot   : std_logic_vector(15 downto 0);

   signal wr_addr_s      : std_logic_vector(18 downto 0);
   signal wr_data_s      : std_logic_vector( 8 downto 0);
   signal wr_en_s        : std_logic;

   signal cnt            : std_logic_vector(31 downto 0);

   -- 23 bits = 8 million cycles @ 140.625 MHz = 17 times per second.
   signal upd_cnt        : std_logic_vector(22 downto 0);
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


   p_xy : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if upd = '1' then
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

         if rst_i = '1' then
            startx <= to_std_logic_vector(integer((C_START_X+4.0)*real(2**16)), 18);
            starty <= to_std_logic_vector(integer((C_START_Y+4.0)*real(2**16)), 18);
            stepx  <= to_std_logic_vector(integer(C_SIZE_X*real(2**16))/C_NUM_COLS, 18);
            stepy  <= to_std_logic_vector(integer(C_SIZE_Y*real(2**16))/C_NUM_ROWS, 18);
         end if;
      end if;
   end process p_xy;


   p_active : process (clk_i)
   begin
      if rising_edge(clk_i) then
         start <= '0';

         -- Start a new picture, as soon as the previous one is finished. The
         -- signal done stays high until the dispatcher has seen the start, so
         -- done is ignored while start is high. Otherwise done would cancel
         -- the new picture, and a second start would be generated.
         if active = '0' then
            active <= '1';
            start  <= '1';
         elsif done = '1' and start = '0' then
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

   -- The LEDs show one of two values, selected by sw_i(1):
   -- * The time since the start of the current picture. The counter cnt
   --   increments at 140.625 MHz while a picture is being calculated, and it is
   --   cleared when the next picture is started. Only bits 26 downto 11 are
   --   shown, so a single count on the LEDs is 14,56 us. The total amount wraps
   --   around after 0,95 seconds.
   -- * The total waiting time of all the column modules, summed up. This is the
   --   time spent waiting for the result to be acknowledged, in the same units
   --   (2^11 clock cycles). It is accumulated from reset, and is not cleared
   --   between pictures.
   led_o <= cnt(26 downto 11) when sw_i(1) = '1' else wait_cnt_tot;

   wr_addr_o <= wr_addr_s;
   wr_data_o <= wr_data_s(7 downto 0);
   wr_en_o   <= wr_en_s;

end architecture structural;
