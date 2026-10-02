library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This is a self-checking testbench for the view control. It holds the buttons
-- down for many updates, and checks after every update:
-- * The view is inside the range -2 to 2 (not including 2): The first column
--   (row) is at least -2, and the last column (row) is less than 2.
-- * The size of a pixel is at least one LSB, and the same in both directions.
-- * The new view is the expected one, calculated by a simple model.
-- It also checks the initial view, and that panning and zooming reach the ends
-- of the range and stop there (also when starting from the other end).

entity view_tb is
end entity view_tb;

architecture simulation of view_tb is

   constant C_NUM_COLS : integer := 640;
   constant C_NUM_ROWS : integer := 480;

   constant C_MIN      : integer := -2**17;    -- -2
   constant C_MAX      : integer :=  2**17-1;  --  2-2^-16

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

      impure function sx return integer is
      begin
         return to_integer(signed(startx));
      end function;
      impure function sy return integer is
      begin
         return to_integer(signed(starty));
      end function;
      impure function dx return integer is
      begin
         return to_integer(unsigned(stepx));
      end function;
      impure function dy return integer is
      begin
         return to_integer(unsigned(stepy));
      end function;

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
      function pan (pos : integer; step : integer; num : integer;
                    plus : boolean; minus : boolean) return integer is
         variable res : integer := pos;
      begin
         if plus then
            res := pos + step;
         elsif minus then
            res := maximum(pos - step, C_MIN);
         end if;
         return minimum(res, C_MAX - (num-1)*step);
      end function pan;

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

      -- Hold the buttons down for a number of updates, and check the view
      -- after each update.
      procedure hold (b : std_logic_vector(4 downto 0); out_v : std_logic;
                      num : integer) is
         variable ox, oy, odx, ody : integer;
         variable ndx, ndy         : integer;
      begin
         btn      <= b;
         zoom_out <= out_v;
         for i in 1 to num loop
            ox := sx; oy := sy; odx := dx; ody := dy;

            -- The expected new view
            ndx := odx;
            ndy := ody;
            if b(4) = '1' then
               if zoom(odx, out_v) >= 1 and zoom(ody, out_v) >= 1 and
                  zoom(odx, out_v)*(C_NUM_COLS-1) <= C_MAX - C_MIN and
                  zoom(ody, out_v)*(C_NUM_ROWS-1) <= C_MAX - C_MIN
               then
                  ndx := zoom(odx, out_v);
                  ndy := zoom(ody, out_v);
               end if;
            end if;

            wait until rising_edge(clk);
            upd <= '1';
            wait until rising_edge(clk);
            upd <= '0';
            wait until rising_edge(clk);

            check_range;

            assert dx = ndx and dy = ndy and
                   sx = pan(ox, ndx, C_NUM_COLS, b(2) = '1', b(3) = '1') and
                   sy = pan(oy, ndy, C_NUM_ROWS, b(0) = '1', b(1) = '1')
               report "Wrong view after update " & integer'image(i) &
                      ": got (" & integer'image(sx) & ", " & integer'image(sy) &
                      ", " & integer'image(dx) & ", " & integer'image(dy) &
                      "), expected (" &
                      integer'image(pan(ox, ndx, C_NUM_COLS, b(2) = '1', b(3) = '1')) & ", " &
                      integer'image(pan(oy, ndy, C_NUM_ROWS, b(0) = '1', b(1) = '1')) & ", " &
                      integer'image(ndx) & ", " & integer'image(ndy) & ")"
               severity error;
         end loop;
         btn <= C_NONE;
      end procedure hold;

      procedure do_reset is
      begin
         rst <= '1';
         wait until rising_edge(clk);
         wait until rising_edge(clk);
         rst <= '0';
         wait until rising_edge(clk);
      end procedure do_reset;

   begin
      do_reset;

      -- The initial view, as in main.vhd
      assert sx = -109229 and sy = -65536 and dx = 273 and dy = 273
         report "Wrong initial view" severity error;
      check_range;

      -- Without buttons nothing changes
      hold(C_NONE, '0', 3);

      -- Zoom out until the view can not get larger. The top left corner is
      -- fixed until the right edge reaches the end of the range, and then the
      -- view moves left.
      hold(C_BTN_C, '1', 60);
      assert sx + (C_NUM_COLS-1)*dx = C_MAX and zoom(dx, '1')*(C_NUM_COLS-1) > C_MAX - C_MIN
         report "Zoom out did not reach the full range in x" severity error;

      -- Pan in all directions to the ends of the range
      hold(C_BTN_D, '0', 300);
      assert sy + (C_NUM_ROWS-1)*dy = C_MAX report "Pan down did not stop at the end" severity error;
      hold(C_BTN_U, '0', 300);
      assert sy = C_MIN report "Pan up did not stop at the end" severity error;
      hold(C_BTN_R, '0', 10);
      hold(C_BTN_L, '0', 20);
      assert sx = C_MIN report "Pan left did not stop at the end" severity error;

      -- Zoom in until the size of a pixel is one LSB. The top left corner is
      -- fixed.
      hold(C_BTN_C, '0', 400);
      assert dx = 1 and dy = 1 and sx = C_MIN and sy = C_MIN
         report "Zoom in did not stop at one LSB" severity error;

      -- Pan at maximum zoom, right and down at the same time
      hold(C_BTN_R or C_BTN_D, '0', 200);
      assert sx = C_MIN + 200 and sy = C_MIN + 200
         report "Wrong pan at maximum zoom" severity error;

      -- Zoom out a little, and pan all the way to the right and bottom, both at
      -- the same time
      hold(C_BTN_C, '1', 60);
      hold(C_BTN_R or C_BTN_D, '0', 6000);
      assert sx + (C_NUM_COLS-1)*dx = C_MAX and sy + (C_NUM_ROWS-1)*dy = C_MAX
         report "Pan right and down did not stop at the end" severity error;

      -- Zoom out from the bottom right corner. The view moves left and up.
      hold(C_BTN_C, '1', 400);
      assert sx + (C_NUM_COLS-1)*dx = C_MAX and zoom(dx, '1')*(C_NUM_COLS-1) > C_MAX - C_MIN
         report "Zoom out from the right edge did not reach the full range" severity error;

      -- Zoom in and pan at the same time, with both left and right (right has
      -- priority) and both up and down (down has priority)
      hold(C_BTN_C or C_BTN_L or C_BTN_R or C_BTN_U or C_BTN_D, '0', 100);

      -- Reset returns to the initial view
      do_reset;
      assert sx = -109229 and sy = -65536 and dx = 273 and dy = 273
         report "Wrong view after reset" severity error;

      report "view_tb: finished";
      std.env.finish;
   end process p_test;


   -------------------
   -- Instantiate DUT
   -------------------

   i_view : entity work.view
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
      ); -- i_view

end architecture simulation;
