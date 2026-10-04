library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.math_real.all;

-- This is a testbench for the rms module. It sweeps over all values of x and y
-- on the 640x480 screen, and reports the minimum and maximum relative error of
-- the approximation, compared to the exact value sqrt(x^2 + y^2).

entity rms_tb is
end rms_tb;

architecture simulation of rms_tb is

   constant C_RESOLUTION : integer := 7;

   signal x_s   : std_logic_vector(9 downto 0);
   signal y_s   : std_logic_vector(9 downto 0);
   signal rms_s : std_logic_vector(9+C_RESOLUTION downto 0);

begin

   i_rms : entity work.rms
      generic map (
         G_RESOLUTION => C_RESOLUTION,
         G_SIZE       => 10
      )
      port map (
         x_i   => x_s,
         y_i   => y_s,
         rms_o => rms_s
      );

   p_test : process
      variable exact_v : real;
      variable error_v : real;
      variable min_v   : real := 0.0;
      variable max_v   : real := 0.0;
   begin
      for x in 0 to 639 loop
         for y in 0 to 479 loop
            x_s <= to_stdlogicvector(x, 10);
            y_s <= to_stdlogicvector(y, 10);
            wait for 1 ns;

            if x > 0 or y > 0 then
               exact_v := sqrt(real(x*x + y*y));
               error_v := (real(to_integer(rms_s)) / 2.0**C_RESOLUTION - exact_v) / exact_v;
               min_v   := minimum(min_v, error_v);
               max_v   := maximum(max_v, error_v);
            end if;
         end loop;
      end loop;

      report "Relative error: min=" & real'image(min_v) & ", max=" & real'image(max_v);
      wait;
   end process p_test;

end architecture simulation;
