-- This is a self-checking testbench for the frame rate (fps.vhd) and the
-- 7-segment display (seg.vhd). It has two instances of fps.
--
-- The first one does not average (G_AVG_CYCLES = 0), and drives the display.
-- It gives it a number of picture times, and for each one it checks:
-- * The digits and the blanking from fps are the expected frame rate, i.e.
--   the clock frequency divided by the time, rounded down, with leading zeros
--   blanked. Values that do not fit in 8 digits show 99999999.
-- * The display shows the same number: During a full refresh cycle each
--   digit that is not blanked is switched on with the right segments, the
--   blanked digits are never switched on, and at most one digit is on at a
--   time.
-- The times include the extremes (0, 1, and the largest time), the values
-- around a change of the frame rate, and random values over the whole range.
-- It also checks that a picture that ends during a calculation is shown after
-- it.
--
-- The second one averages over at least C_AVG_CYCLES clock cycles and at most
-- 15 pictures. It gives it random picture times (some much shorter than
-- C_AVG_CYCLES, some longer, and some zero), and checks that the frame rate
-- is calculated at the end of each sum, and only then, and that it is the
-- number of pictures times the clock frequency divided by the sum of the
-- times, rounded down (or 99999999 if larger).
--
-- The refresh of the display is made much faster than on the board, so a
-- full refresh cycle is 64 clock cycles.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fps_tb is
end entity fps_tb;

architecture simulation of fps_tb is

   constant C_CLK_FREQ     : natural := 188_235_294;  -- The earlier MAIN clock
   constant C_TIME_BITS    : natural := 27;
   constant C_REFRESH_BITS : natural := 6;
   constant C_MAX          : natural := 99_999_999;

   -- Longer than a calculation (79 clock cycles from valid_i to valid_o)
   constant C_CALC_CYCLES  : natural := 90;

   constant C_AVG_CYCLES   : natural := 10_000;
   constant C_FRAME_BITS   : natural := 4;

   type seg_table_t is array (0 to 9) of std_logic_vector(6 downto 0);
   constant C_SEG_TABLE : seg_table_t := (
      "0111111", "0000110", "1011011", "1001111", "1100110",
      "1101101", "1111101", "0000111", "1111111", "1101111");

   signal clk      : std_logic;
   signal rst      : std_logic := '1';
   signal time_s   : std_logic_vector(C_TIME_BITS-1 downto 0) := (others => '0');
   signal valid    : std_logic := '0';
   signal digits   : std_logic_vector(31 downto 0);
   signal blank    : std_logic_vector( 7 downto 0);
   signal fps_vld  : std_logic;
   signal avg_time : std_logic_vector(C_TIME_BITS-1 downto 0) := (others => '0');
   signal avg_vld  : std_logic := '0';
   signal avg_dig  : std_logic_vector(31 downto 0);
   signal avg_blk  : std_logic_vector( 7 downto 0);
   signal avg_out  : std_logic;
   signal test_done : boolean := false;
   signal seg_s    : std_logic_vector( 6 downto 0);
   signal seg_an   : std_logic_vector( 7 downto 0);

   function expected_fps(t : natural) return natural is
   begin
      if t = 0 or C_CLK_FREQ / t > C_MAX then
         return C_MAX;
      end if;
      return C_CLK_FREQ / t;
   end function expected_fps;

   -- The value of BCD digits
   function bcd_value(d : std_logic_vector(31 downto 0)) return natural is
      variable r : natural := 0;
   begin
      for i in 7 downto 0 loop
         r := 10*r + to_integer(unsigned(d(4*i+3 downto 4*i)));
      end loop;
      return r;
   end function bcd_value;

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
   -- Instantiate DUTs
   ----------------------------

   i_fps : entity work.fps
      generic map (
         G_CLK_FREQ   => C_CLK_FREQ,
         G_TIME_BITS  => C_TIME_BITS,
         G_AVG_CYCLES => 0,
         G_DIGITS     => 8
      )
      port map (
         clk_i    => clk,
         rst_i    => rst,
         time_i   => time_s,
         valid_i  => valid,
         digits_o => digits,
         blank_o  => blank,
         valid_o  => fps_vld
      ); -- i_fps

   i_avg : entity work.fps
      generic map (
         G_CLK_FREQ   => C_CLK_FREQ,
         G_TIME_BITS  => C_TIME_BITS,
         G_AVG_CYCLES => C_AVG_CYCLES,
         G_FRAME_BITS => C_FRAME_BITS,
         G_DIGITS     => 8
      )
      port map (
         clk_i    => clk,
         rst_i    => rst,
         time_i   => avg_time,
         valid_i  => avg_vld,
         digits_o => avg_dig,
         blank_o  => avg_blk,
         valid_o  => avg_out
      ); -- i_avg

   i_seg : entity work.seg
      generic map (
         G_REFRESH_BITS => C_REFRESH_BITS
      )
      port map (
         clk_i    => clk,
         digits_i => digits,
         blank_i  => blank,
         seg_o    => seg_s,
         seg_an_o => seg_an
      ); -- i_seg


   ----------------------------
   -- Stimulus and checking
   ----------------------------

   p_test : process
      variable seed1    : positive := 1;
      variable seed2    : positive := 2;
      variable r        : real;
      variable num_test : natural := 0;

      procedure start(t : natural) is
      begin
         time_s <= std_logic_vector(to_unsigned(t, C_TIME_BITS));
         valid  <= '1';
         wait until rising_edge(clk);
         valid  <= '0';
         time_s <= (others => 'X');
      end procedure start;

      -- Check that the outputs of fps and the display show the value v
      procedure check(v : natural; t : natural) is
         variable d_v       : natural;
         variable lead_v    : boolean;
         variable exp_blank : std_logic_vector(7 downto 0);
         variable seen_v    : std_logic_vector(7 downto 0);
         variable digit_v   : natural;
         variable ones_v    : natural;
      begin
         -- Expected digits and blanking
         lead_v := true;
         for i in 7 downto 0 loop
            d_v := (v / 10**i) mod 10;
            lead_v := lead_v and d_v = 0 and i > 0;
            exp_blank(i) := '1' when lead_v else '0';
            assert digits(4*i+3 downto 4*i) = std_logic_vector(to_unsigned(d_v, 4))
               report "Wrong digit " & integer'image(i) & " for time " &
                      integer'image(t) & ", expected " & integer'image(v)
               severity error;
         end loop;
         assert blank = exp_blank
            report "Wrong blanking for time " & integer'image(t) &
                   ", expected " & integer'image(v)
            severity error;

         -- Watch the display for a full refresh cycle (plus a little)
         seen_v := (others => '0');
         for c in 0 to 2**C_REFRESH_BITS + 4 loop
            wait until rising_edge(clk);
            ones_v := 0;
            for i in 0 to 7 loop
               if seg_an(i) = '0' then
                  ones_v := ones_v + 1;
                  seen_v(i) := '1';
                  assert exp_blank(i) = '0'
                     report "Blanked digit " & integer'image(i) &
                            " switched on for value " & integer'image(v)
                     severity error;
                  digit_v := (v / 10**i) mod 10;
                  assert seg_s = not C_SEG_TABLE(digit_v)
                     report "Wrong segments on digit " & integer'image(i) &
                            " for value " & integer'image(v)
                     severity error;
               end if;
            end loop;
            assert ones_v <= 1
               report "More than one digit switched on" severity error;
         end loop;
         assert seen_v = not exp_blank
            report "Not all digits shown for value " & integer'image(v)
            severity error;
         num_test := num_test + 1;
      end procedure check;

      procedure test(t : natural) is
      begin
         start(t);
         for i in 1 to C_CALC_CYCLES loop
            wait until rising_edge(clk);
         end loop;
         check(expected_fps(t), t);
      end procedure test;

      type time_list_t is array (natural range <>) of natural;
      constant C_TIMES : time_list_t := (
         941_177,            -- 5 ms: 199 (exactly 5 ms is 941176.5 cycles)
         941_176,            -- 200
         1_882_352,          -- 100
         1_882_353,          -- 99
         1_000,              -- 188235
         C_CLK_FREQ / 1000,  -- 1000
         2**C_TIME_BITS - 1, -- 1
         1, 2, 3,            -- Saturated, 94117647, 62745098
         0,                  -- Saturated
         C_CLK_FREQ / C_MAX, -- 1 (saturated)
         C_CLK_FREQ / C_MAX + 1,
         10, 100, 10_000, 100_000, 1_000_000);

   begin
      rst <= '1';
      wait for 100 ns;
      wait until rising_edge(clk);
      rst <= '0';
      wait until rising_edge(clk);

      -- After reset the display shows 0
      check(0, 0);

      for i in C_TIMES'range loop
         test(C_TIMES(i));
      end loop;

      -- A picture that ends during a calculation is shown after it
      start(941_176);
      for i in 1 to 10 loop
         wait until rising_edge(clk);
      end loop;
      start(1_959_183);
      wait until rising_edge(clk) and fps_vld = '1';
      assert bcd_value(digits) = 200
         report "Wrong value before the picture during a calculation"
         severity error;
      wait until rising_edge(clk) and fps_vld = '1';
      for i in 1 to 5 loop
         wait until rising_edge(clk);
      end loop;
      check(96, 1_959_183);

      -- Random times, spread evenly over the number of bits
      for i in 1 to 300 loop
         uniform(seed1, seed2, r);
         test(integer(trunc(2.0 ** (r * real(C_TIME_BITS)))) mod 2**C_TIME_BITS);
      end loop;

      report "Test finished, " & integer'image(num_test) & " values checked";
      test_done <= true;
      wait;
   end process p_test;

   -- Test of the average
   p_avg : process
      variable seed1    : positive := 3;
      variable seed2    : positive := 4;
      variable r        : real;
      variable t        : natural;
      variable cnt      : natural := 0;
      variable sum      : natural := 0;
      variable quot     : unsigned(63 downto 0);
      variable exp_v    : natural;
      variable done_v   : boolean;
      variable seen_v   : boolean;
      variable num_avg  : natural := 0;
   begin
      wait until rst = '0';
      wait until rising_edge(clk);

      for i in 1 to 1000 loop
         -- Mostly much shorter than C_AVG_CYCLES, sometimes longer or zero
         uniform(seed1, seed2, r);
         if r < 0.05 then
            t := 0;
         elsif r < 0.15 then
            t := C_AVG_CYCLES + integer(r * 1.0e6);
         elsif r < 0.4 then
            t := 1 + integer(r * 100.0);
         else
            t := 1 + integer(r * 3000.0);
         end if;

         -- The expected average
         cnt := cnt + 1;
         sum := sum + t;
         done_v := sum >= C_AVG_CYCLES or cnt = 2**C_FRAME_BITS - 1;
         if done_v then
            if sum = 0 then
               exp_v := C_MAX;
            else
               quot := to_unsigned(cnt, 32) * to_unsigned(C_CLK_FREQ, 32) / to_unsigned(sum, 64);
               if quot > C_MAX then
                  exp_v := C_MAX;
               else
                  exp_v := to_integer(quot);
               end if;
            end if;
            cnt := 0;
            sum := 0;
         end if;

         avg_time <= std_logic_vector(to_unsigned(t, C_TIME_BITS));
         avg_vld  <= '1';
         wait until rising_edge(clk);
         avg_vld  <= '0';
         avg_time <= (others => 'X');

         seen_v := false;
         for c in 1 to C_CALC_CYCLES loop
            wait until rising_edge(clk);
            if avg_out = '1' then
               assert not seen_v report "Two averages for one picture" severity error;
               seen_v := true;
               assert done_v and bcd_value(avg_dig) = exp_v
                  report "Wrong average " & integer'image(bcd_value(avg_dig)) &
                         ", expected " & integer'image(exp_v)
                  severity error;
            end if;
         end loop;
         assert seen_v = done_v
            report "Average missing or too early" severity error;
         if done_v then
            num_avg := num_avg + 1;
         end if;
      end loop;

      report "Average test finished, " & integer'image(num_avg) & " averages checked";
      if not test_done then
         wait until test_done;
      end if;
      std.env.stop;
   end process p_avg;

end architecture simulation;
