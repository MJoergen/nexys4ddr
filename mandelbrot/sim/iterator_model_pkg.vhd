library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This package contains a bit-accurate model of the iteration count calculated
-- by src/iterator.vhd. It is used by the testbenches, which compare the counts
-- from the design with this model. It is the same model as in model.py and
-- iterator_model.py.
--
-- The model calculates exactly what the iterator calculates, but in a simpler
-- way: x+y and x-y are calculated with enough bits, so the selection of the
-- multiplier inputs in the iterator is not needed here.

package iterator_model_pkg is

   -- Interpret the lowest 18 bits of v as a two's complement number. This
   -- models the 18-bit additions of the step in the dispatcher and the column
   -- modules, which wrap around.
   function wrap18 (v : integer) return integer;

   -- The iteration count for the point c = cx + i*cy, where cx and cy are 2.16
   -- fixed point numbers, given as integers (-2^17 to 2^17-1). The count is the
   -- number of the first iteration where x or y is outside the range -2 to 2
   -- (not including 2), or max_count if this does not happen.
   function iterator_count (cx : integer; cy : integer; max_count : integer)
      return integer;

end package iterator_model_pkg;

package body iterator_model_pkg is

   function wrap18 (v : integer) return integer is
   begin
      return ((v + 2**17) mod 2**18) - 2**17;
   end function wrap18;

   -- True if the top bits of v, from bit 'left' down to bit 'low', are all
   -- equal, i.e. if v is in range when the bits above 'low' are removed.
   function top_bits_equal (v : signed; low : natural) return boolean is
   begin
      return v(v'left downto low) = (v'left downto low => '0') or
             v(v'left downto low) = (v'left downto low => '1');
   end function top_bits_equal;

   function iterator_count (cx : integer; cy : integer; max_count : integer)
      return integer is
      variable cx_s       : signed(37 downto 0);  -- 6.32
      variable cy_div_2_s : signed(36 downto 0);  -- 5.32, this is cy/2
      variable x          : signed(17 downto 0);  -- 2.16
      variable y          : signed(17 downto 0);  -- 2.16
      variable new_x      : signed(37 downto 0);  -- 6.32
      variable new_y_half : signed(36 downto 0);  -- 5.32, this is new y/2
   begin
      cx_s       := shift_left(resize(to_signed(cx, 18), 38), 16);
      cy_div_2_s := shift_left(resize(to_signed(cy, 18), 37), 15);
      x          := (others => '0');
      y          := (others => '0');

      for n in 1 to max_count-1 loop
         -- new_x = (x+y)*(x-y) + cx, with x+y and x-y in 19 bits, so they
         -- do not wrap around
         new_x := (resize(x, 19) + resize(y, 19)) * (resize(x, 19) - resize(y, 19)) + cx_s;

         -- new_y/2 = x*y + cy/2
         new_y_half := resize(x * y, 37) + cy_div_2_s;

         -- The new x is in range (-2 <= x < 2) if it fits in 34 bits (2.32),
         -- and the new y/2 is in range (-1 <= y/2 < 1) if it fits in 33 bits
         -- (1.32).
         if not top_bits_equal(new_x, 33) or not top_bits_equal(new_y_half, 32) then
            return n;
         end if;

         x := new_x(33 downto 16);
         y := new_y_half(32 downto 15);
      end loop;

      return max_count;
   end function iterator_count;

end package body iterator_model_pkg;
