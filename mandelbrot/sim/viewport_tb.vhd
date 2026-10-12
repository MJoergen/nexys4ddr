-- This is a self-checking testbench for the view control. It holds the buttons
-- down for many updates, and checks after every update:
-- * The view is inside the range -2 to 2 (not including 2): The first column
--   (row) is at least -2, and the last column (row) is less than 2.
-- * The size of a pixel is at least one LSB, and the same in both directions.
-- * The new view is the expected one, calculated by a simple model. Zooming
--   keeps the centre fixed (the pixel in column C_CENTRE_X and row
--   C_CENTRE_Y), unless the view is moved to keep it inside the range.
-- * The outputs all change in the same clock cycle.
-- It also checks the initial view, that panning and zooming reach the ends of
-- the range and stop there (also when starting from the other end), and that a
-- pulse on upd_i during an update is ignored, but one just after an update is
-- not.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity viewport_tb is
end entity viewport_tb;

architecture simulation of viewport_tb is

   constant C_NUM_COLS : positive := 640;
   constant C_NUM_ROWS : positive := 480;

   -- The pan step in pixels, 1/320 of the number of columns (see viewport.vhd)
   constant C_PAN_PIXELS : positive := C_NUM_COLS/320;

   -- The column and row of the pixel that is kept fixed when zooming
   constant C_CENTRE_X : natural := C_NUM_COLS/2;
   constant C_CENTRE_Y : natural := C_NUM_ROWS/2;

   constant C_MIN      : integer := -2**17;    -- -2
   constant C_MAX      : integer :=  2**17-1;  --  2-2^-16

   -- The number of clock cycles to wait for an update to finish
   constant C_UPD_CYCLES : positive := 32;

   -- The view: the position of the first column and row (signed 2.16), and
   -- the size of a pixel
   type view_t is record
      sx : integer;
      sy : integer;
      dx : integer;
      dy : integer;
   end record view_t;

   signal clk      : std_logic;
   signal rst      : std_logic := '1';
   signal upd      : std_logic := '0';
   signal btn      : std_logic_vector(4 downto 0) := (others => '0');
   signal zoom_out : std_logic := '0';
   signal startx   : std_logic_vector(17 downto 0);
   signal starty   : std_logic_vector(17 downto 0);
   signal stepx    : std_logic_vector(17 downto 0);
   signal stepy    : std_logic_vector(17 downto 0);

   -- Button bits, "CLRUD"
   constant C_BTN_C : std_logic_vector(4 downto 0) := "10000";
   constant C_BTN_L : std_logic_vector(4 downto 0) := "01000";
   constant C_BTN_R : std_logic_vector(4 downto 0) := "00100";
   constant C_BTN_U : std_logic_vector(4 downto 0) := "00010";
   constant C_BTN_D : std_logic_vector(4 downto 0) := "00001";
   constant C_NONE  : std_logic_vector(4 downto 0) := "00000";

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;


   ----------------------------
   -- Stimulus and checking
   ----------------------------

   p_test : process

      -- The current view (the outputs of the DUT)
      impure function cur_view return view_t is
      begin
         return (sx => to_integer(signed(startx)),
                 sy => to_integer(signed(starty)),
                 dx => to_integer(unsigned(stepx)),
                 dy => to_integer(unsigned(stepy)));
      end function cur_view;

      impure function sx return integer is
      begin
         return cur_view.sx;
      end function sx;
      impure function sy return integer is
      begin
         return cur_view.sy;
      end function sy;
      impure function dx return integer is
      begin
         return cur_view.dx;
      end function dx;
      impure function dy return integer is
      begin
         return cur_view.dy;
      end function dy;

      -- The position of the pixel that is kept fixed when zooming
      impure function centre_x return integer is
      begin
         return sx + C_CENTRE_X*dx;
      end function centre_x;
      impure function centre_y return integer is
      begin
         return sy + C_CENTRE_Y*dy;
      end function centre_y;

      function image (v : view_t) return string is
      begin
         return "(" & integer'image(v.sx) & ", " & integer'image(v.sy) & ", " &
                integer'image(v.dx) & ", " & integer'image(v.dy) & ")";
      end function image;

      -- The expected new size of a pixel when zooming
      function zoom (step : integer; out_v : std_logic) return integer is
      begin
         if out_v = '1' then
            return step + step/64 + 1;
         else
            return step - step/64 - 1;
         end if;
      end function zoom;

      -- The expected new position in one direction. The arguments are the
      -- position, the (new) size of a pixel, the number of pixels, and whether
      -- to pan towards larger or smaller values. The values are signed 2.16.
      -- The view moves by C_PAN_PIXELS pixels.
      function pan (pos : integer; step : integer; num : integer;
                    plus : boolean; minus : boolean) return integer is
         variable res_v : integer := pos;
      begin
         if plus then
            res_v := pos + C_PAN_PIXELS*step;
         elsif minus then
            res_v := maximum(pos - C_PAN_PIXELS*step, C_MIN);
         end if;
         return minimum(res_v, C_MAX - (num-1)*step);
      end function pan;

      -- The expected view after one update, with the buttons b
      function next_view (v : view_t; b : std_logic_vector(4 downto 0);
                          out_v : std_logic) return view_t is
         variable res_v : view_t := v;
      begin
         if b(4) = '1' then
            if zoom(v.dx, out_v) >= 1 and zoom(v.dy, out_v) >= 1 and
               zoom(v.dx, out_v)*(C_NUM_COLS-1) <= C_MAX - C_MIN and
               zoom(v.dy, out_v)*(C_NUM_ROWS-1) <= C_MAX - C_MIN
            then
               res_v.dx := zoom(v.dx, out_v);
               res_v.dy := zoom(v.dy, out_v);

               -- Keep the centre fixed, but not before the start of the range
               res_v.sx := maximum(v.sx + (v.dx - res_v.dx)*C_CENTRE_X, C_MIN);
               res_v.sy := maximum(v.sy + (v.dy - res_v.dy)*C_CENTRE_Y, C_MIN);
            end if;
         end if;
         res_v.sx := pan(res_v.sx, res_v.dx, C_NUM_COLS, b(2) = '1', b(3) = '1');
         res_v.sy := pan(res_v.sy, res_v.dy, C_NUM_ROWS, b(0) = '1', b(1) = '1');
         return res_v;
      end function next_view;

      -- Check that the view is in range
      procedure check_range is
      begin
         assert sx >= C_MIN and sx + (C_NUM_COLS-1)*dx <= C_MAX
            report "View out of range in x: startx = " & integer'image(sx) &
                   ", stepx = " & integer'image(dx)
            severity error;
         assert sy >= C_MIN and sy + (C_NUM_ROWS-1)*dy <= C_MAX
            report "View out of range in y: starty = " & integer'image(sy) &
                   ", stepy = " & integer'image(dy)
            severity error;
         assert dx >= 1 and dy >= 1
            report "Size of a pixel less than one LSB"
            severity error;
         assert dx = dy
            report "Different size of a pixel in x and y"
            severity error;
      end procedure check_range;

      -- Wait until just after the next rising edge of the clock
      procedure clk_cycle is
      begin
         wait until rising_edge(clk);
         wait for 1 ns;
      end procedure clk_cycle;

      -- Pulse upd for one clock cycle, and wait for the update to finish. If
      -- second is larger than zero, pulse upd again, second clock cycles after
      -- the first pulse. Returns the number of clock cycles in which the view
      -- changed, and the last clock cycle (counted from the first pulse) in
      -- which it changed.
      procedure run_update (second  : in  integer;
                            changes : out integer;
                            last    : out integer) is
         variable prev_v : view_t;
         variable view_v : view_t;
      begin
         changes := 0;
         last    := -1;
         prev_v  := cur_view;
         upd     <= '1';
         for i in 0 to second + C_UPD_CYCLES loop
            clk_cycle;    -- The DUT samples upd in this clock cycle
            upd <= '0';
            if i+1 = second then
               upd <= '1';
            end if;

            view_v := cur_view;
            if view_v /= prev_v then
               changes := changes + 1;
               last    := i;
            end if;
            prev_v := view_v;
         end loop;
      end procedure run_update;

      -- Hold the buttons down for a number of updates, and check the view
      -- after each update.
      procedure hold (b : std_logic_vector(4 downto 0); out_v : std_logic;
                      num : integer) is
         variable expected_v : view_t;
         variable changes_v  : integer;
         variable last_v     : integer;
      begin
         btn      <= b;
         zoom_out <= out_v;
         clk_cycle;
         for i in 1 to num loop
            expected_v := next_view(cur_view, b, out_v);
            run_update(0, changes_v, last_v);

            check_range;

            assert cur_view = expected_v
               report "Wrong view after update " & integer'image(i) &
                      ": got " & image(cur_view) & ", expected " & image(expected_v)
               severity error;

            assert changes_v <= 1
               report "The outputs changed in " & integer'image(changes_v) &
                      " different clock cycles during an update"
               severity error;
         end loop;
         btn <= C_NONE;
      end procedure hold;

      -- Check that a second pulse on upd during an update is ignored, and that
      -- one just after the update is not. The view is panned to the right, so
      -- that it changes in every update.
      procedure test_second_pulse is
         variable expected_v : view_t;
         variable changes_v  : integer;
         variable len_v      : integer;
         variable last_v     : integer;
      begin
         btn      <= C_BTN_R;
         zoom_out <= '0';
         clk_cycle;

         -- The clock cycle (counted from the pulse) in which the outputs
         -- change, i.e. the length of an update
         expected_v := next_view(cur_view, C_BTN_R, '0');
         run_update(0, changes_v, len_v);
         assert changes_v = 1 and cur_view = expected_v
            report "Wrong view after a single update"
            severity error;
         report "An update takes " & integer'image(len_v) & " clock cycles";

         for k in 1 to len_v+1 loop
            if k <= len_v then
               -- The second pulse is during the update, and is ignored
               expected_v := next_view(cur_view, C_BTN_R, '0');
            else
               -- The second pulse is just after the update, so there are two
               -- updates
               expected_v := next_view(next_view(cur_view, C_BTN_R, '0'), C_BTN_R, '0');
            end if;

            run_update(k, changes_v, last_v);

            assert cur_view = expected_v
               report "Wrong view with a second pulse after " & integer'image(k) &
                      " clock cycles: got " & image(cur_view) &
                      ", expected " & image(expected_v)
               severity error;
         end loop;
         btn <= C_NONE;
      end procedure test_second_pulse;

      procedure do_reset is
      begin
         rst <= '1';
         wait until rising_edge(clk);
         wait until rising_edge(clk);
         rst <= '0';
         wait until rising_edge(clk);
      end procedure do_reset;

      variable cx0_v : integer;
      variable cy0_v : integer;

   begin
      do_reset;

      -- The initial view, as in main.vhd
      assert sx = -109229 and sy = -65536 and dx = 273 and dy = 273
         report "Wrong initial view"
         severity error;
      check_range;

      -- Without buttons nothing changes
      hold(C_NONE, '0', 3);

      -- A pulse on upd during an update is ignored
      test_second_pulse;

      -- Zoom in. The centre stays fixed.
      cx0_v := centre_x;
      cy0_v := centre_y;
      hold(C_BTN_C, '0', 100);
      assert centre_x = cx0_v and centre_y = cy0_v and dx < 273
         report "Zoom in did not keep the centre fixed"
         severity error;

      -- Zoom out until the view can not get larger. The centre is fixed until
      -- the left edge reaches the start of the range, and then the view moves
      -- right.
      hold(C_BTN_C, '1', 200);
      assert sx = C_MIN and zoom(dx, '1')*(C_NUM_COLS-1) > C_MAX - C_MIN
         report "Zoom out did not reach the full range in x"
         severity error;

      -- Pan in all directions to the ends of the range
      hold(C_BTN_D, '0', 300);
      assert sy + (C_NUM_ROWS-1)*dy = C_MAX
         report "Pan down did not stop at the end"
         severity error;
      hold(C_BTN_U, '0', 300);
      assert sy = C_MIN
         report "Pan up did not stop at the end"
         severity error;
      hold(C_BTN_R, '0', 10);
      hold(C_BTN_L, '0', 20);
      assert sx = C_MIN
         report "Pan left did not stop at the end"
         severity error;

      -- Zoom in until the size of a pixel is one LSB. The centre stays fixed.
      cx0_v := centre_x;
      cy0_v := centre_y;
      hold(C_BTN_C, '0', 400);
      assert dx = 1 and dy = 1 and centre_x = cx0_v and centre_y = cy0_v
         report "Zoom in did not stop at one LSB, with the centre fixed"
         severity error;

      -- Pan at maximum zoom, right and down at the same time
      cx0_v := sx;
      cy0_v := sy;
      hold(C_BTN_R or C_BTN_D, '0', 200);
      assert sx = cx0_v + 200*C_PAN_PIXELS and sy = cy0_v + 200*C_PAN_PIXELS
         report "Wrong pan at maximum zoom"
         severity error;

      -- Zoom out a little, and pan all the way to the right and bottom, both at
      -- the same time
      hold(C_BTN_C, '1', 60);
      hold(C_BTN_R or C_BTN_D, '0', 6000);
      assert sx + (C_NUM_COLS-1)*dx = C_MAX and sy + (C_NUM_ROWS-1)*dy = C_MAX
         report "Pan right and down did not stop at the end"
         severity error;

      -- Zoom out from the bottom right corner. The view moves left and up, so
      -- the right and bottom edges stay in range.
      hold(C_BTN_C, '1', 400);
      assert zoom(dx, '1')*(C_NUM_COLS-1) > C_MAX - C_MIN
         report "Zoom out from the right edge did not reach the full range"
         severity error;

      -- Zoom in and pan at the same time, with both left and right (right has
      -- priority) and both up and down (down has priority)
      hold(C_BTN_C or C_BTN_L or C_BTN_R or C_BTN_U or C_BTN_D, '0', 100);

      -- Reset returns to the initial view
      do_reset;
      assert sx = -109229 and sy = -65536 and dx = 273 and dy = 273
         report "Wrong view after reset"
         severity error;

      report "viewport_tb: finished";
      std.env.finish;
   end process p_test;


   -------------------
   -- Instantiate DUT
   -------------------

   i_viewport : entity work.viewport
      generic map (
         G_NUM_COLS => C_NUM_COLS,
         G_NUM_ROWS => C_NUM_ROWS,
         G_START_X  => -1.6667,
         G_START_Y  => -1.0000,
         G_SIZE_X   =>  2.6667,
         G_SIZE_Y   =>  2.0000
      )
      port map (
         clk_i      => clk,
         rst_i      => rst,
         upd_i      => upd,
         btn_i      => btn,
         zoom_out_i => zoom_out,
         startx_o   => startx,
         starty_o   => starty,
         stepx_o    => stepx,
         stepy_o    => stepy
      ); -- i_viewport

end architecture simulation;
