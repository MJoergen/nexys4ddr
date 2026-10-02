library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a purely combinational adder with overflow detection. It adds two
-- signed (two's complement) numbers of SIZE bits each. The result is also SIZE
-- bits wide, and wraps around if it does not fit, in which case ovf_o is set.
--
-- It is used twice in the iterator (see iterator.vhd), with SIZE = 36, to
-- calculate the next values of x and y (in 4.32 fixed point representation):
--   new_x   = (x+y)*(x-y) + cx
--   new_y/2 = x*y + cy/2
-- The overflow flag is used to detect that the iteration has left the range
-- that can be represented, i.e. that the point is not in the Mandelbrot set,
-- and the iterator then stops.

entity add_overflow is
   generic (
      SIZE : integer
   );
   port (
      a_i    : in  std_logic_vector(SIZE-1 downto 0);  -- Signed
      b_i    : in  std_logic_vector(SIZE-1 downto 0);  -- Signed
      r_o    : out std_logic_vector(SIZE-1 downto 0);  -- Signed. Wraps around on overflow.
      ovf_o  : out std_logic                           -- Signed overflow
   );
end entity add_overflow;

architecture rtl of add_overflow is

begin

   r_o <= a_i + b_i;

   -- Signed overflow can only happen when the two operands have the same sign,
   -- and it has happened if the sign of the result is different from the sign
   -- of the operands. When the operands have different signs the result always
   -- fits.
   ovf_o <= not(a_i(SIZE-1) xor b_i(SIZE-1)) and
            (a_i(SIZE-1) xor r_o(SIZE-1));

end architecture rtl;
