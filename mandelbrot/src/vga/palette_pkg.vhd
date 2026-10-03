library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- This package contains the colour palettes for the VGA output. The display
-- memory holds the iteration count of each pixel (9 bits), and the palette
-- converts it to the colour shown (RRRGGGBB). Points in the set have the count
-- 511 (C_SET), and they get the colour of the set. The other counts are
-- converted using only their lowest 8 bits.
--
-- There are four palettes, selected by switches 3 and 4 (the value of sel):
--   0 : The count itself is the colour. Mostly blue and green, because most
--       counts are small, and the set is white.
--   1 : Rainbow. The hue goes once around the colour circle for every 16
--       counts.
--   2 : Fire. Black, red, orange, yellow, and white, with the square root of
--       the lowest 8 bits of the count, i.e. once for the values 0 to 63, and
--       again for 64 to 255.
--   3 : Blue, white, orange, and dark brown, with the logarithm of the lowest
--       8 bits of the count, i.e. once for the values 0 to 6, again for 7 to
--       62, and again for 63 to 255.
-- In the palettes 1 to 3 the set is black. In palette 0 it is white.
--
-- The palettes are calculated from these formulas when the design is
-- elaborated, so they are easy to change. They are tables of 256 entries, so
-- they are implemented in LUTs.

package palette_pkg is

   type palette_t is array (0 to 255) of std_logic_vector(7 downto 0);
   type palettes_t is array (0 to 3) of palette_t;

   constant C_PALETTES : palettes_t;

   -- The count of the points in the set
   constant C_SET : integer := 511;

   -- The colour of the set in each palette
   type colours_t is array (0 to 3) of std_logic_vector(7 downto 0);
   constant C_SET_COLOURS : colours_t := (X"FF", X"00", X"00", X"00");

   -- The colour of the count cnt in the palette sel
   function palette_colour (sel : std_logic_vector(1 downto 0);
                            cnt : std_logic_vector(8 downto 0))
      return std_logic_vector;

end package palette_pkg;

package body palette_pkg is

   -- Convert a colour with the components r, g, and b (between 0.0 and 1.0)
   -- to RRRGGGBB, rounding to the nearest level.
   function to_332 (r : real; g : real; b : real) return std_logic_vector is
      variable r_v : natural := natural(floor(r*7.0 + 0.5));
      variable g_v : natural := natural(floor(g*7.0 + 0.5));
      variable b_v : natural := natural(floor(b*3.0 + 0.5));
   begin
      return std_logic_vector(to_unsigned(r_v, 3)) &
             std_logic_vector(to_unsigned(g_v, 3)) &
             std_logic_vector(to_unsigned(b_v, 2));
   end function to_332;

   -- The fractional part of x (x is not negative)
   function frac (x : real) return real is
   begin
      return x - floor(x);
   end function frac;

   -- x limited to the range 0.0 to 1.0
   function clamp (x : real) return real is
   begin
      if x < 0.0 then
         return 0.0;
      elsif x > 1.0 then
         return 1.0;
      else
         return x;
      end if;
   end function clamp;

   -- 0: The count itself
   function make_count return palette_t is
      variable res : palette_t;
   begin
      for i in 0 to 255 loop
         res(i) := std_logic_vector(to_unsigned(i, 8));
      end loop;
      return res;
   end function make_count;

   -- 1: Rainbow, i.e. the hue of a fully saturated colour, period 16
   function make_rainbow return palette_t is
      variable res : palette_t;
      variable h   : real;     -- Hue times 6, between 0 and 6
      variable f   : real;
   begin
      for i in 0 to 255 loop
         h := real(i mod 16) / 16.0 * 6.0;
         f := frac(h);
         case integer(floor(h)) is
            when 0      => res(i) := to_332(1.0,     f,       0.0);
            when 1      => res(i) := to_332(1.0 - f, 1.0,     0.0);
            when 2      => res(i) := to_332(0.0,     1.0,     f);
            when 3      => res(i) := to_332(0.0,     1.0 - f, 1.0);
            when 4      => res(i) := to_332(f,       0.0,     1.0);
            when others => res(i) := to_332(1.0,     0.0,     1.0 - f);
         end case;
      end loop;
      return res;
   end function make_rainbow;

   -- 2: Fire, with the square root of the count
   function make_fire return palette_t is
      variable res : palette_t;
      variable t   : real;
   begin
      for i in 0 to 255 loop
         t := frac(sqrt(real(i)) / 8.0);
         res(i) := to_332(clamp(3.0*t), clamp(3.0*t - 1.0), clamp(3.0*t - 2.0));
      end loop;
      return res;
   end function make_fire;

   -- 3: Blue, white, orange, and dark brown, with the logarithm of the count
   function make_blue_orange return palette_t is
      type stops_t is array (0 to 5) of real;
      -- The colour at the positions t (0.0 to 1.0) of the gradient
      constant C_T : stops_t := (0.0,  0.16, 0.42, 0.64, 0.86, 1.0);
      constant C_R : stops_t := (0.0,  0.13, 0.93, 1.0,  0.0,  0.0);
      constant C_G : stops_t := (0.03, 0.42, 1.0,  0.67, 0.01, 0.03);
      constant C_B : stops_t := (0.4,  0.8,  1.0,  0.0,  0.0,  0.4);
      variable res : palette_t;
      variable t   : real;
      variable f   : real;
   begin
      for i in 0 to 255 loop
         t := frac(log2(real(i + 1)) / 3.0);
         for s in 0 to 4 loop
            if t >= C_T(s) and t <= C_T(s+1) then
               f := (t - C_T(s)) / (C_T(s+1) - C_T(s));
               res(i) := to_332(C_R(s) + (C_R(s+1) - C_R(s))*f,
                                C_G(s) + (C_G(s+1) - C_G(s))*f,
                                C_B(s) + (C_B(s+1) - C_B(s))*f);
               exit;
            end if;
         end loop;
      end loop;
      return res;
   end function make_blue_orange;

   constant C_PALETTES : palettes_t :=
      (make_count, make_rainbow, make_fire, make_blue_orange);

   function palette_colour (sel : std_logic_vector(1 downto 0);
                            cnt : std_logic_vector(8 downto 0))
      return std_logic_vector is
   begin
      if to_integer(unsigned(cnt)) = C_SET then
         return C_SET_COLOURS(to_integer(unsigned(sel)));
      end if;
      return C_PALETTES(to_integer(unsigned(sel)))(to_integer(unsigned(cnt(7 downto 0))));
   end function palette_colour;

end package body palette_pkg;
