library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.math_real.all;

-- This is a testbench for the rms module. It sweeps over all values of x and y
-- on the 1280x1024 screen, and reports the minimum and maximum relative error of
-- the approximation, compared to the exact value sqrt(x^2 + y^2).

entity rms_tb is
end rms_tb;

architecture simulation of rms_tb is

   constant C_RESOLUTION : integer := 7;

   signal clk_s : std_logic := '0';
   signal x_s   : std_logic_vector(10 downto 0);
   signal y_s   : std_logic_vector(10 downto 0);
   signal rms_s : std_logic_vector(10+C_RESOLUTION downto 0);

begin

   i_rms : entity work.rms
      generic map (
         G_RESOLUTION => C_RESOLUTION,
         G_SIZE       => 11
      )
      port map (
         clk_i => clk_s,
         x_i   => x_s,
         y_i   => y_s,
         rms_o => rms_s
      );

   -- The rms module is pipelined, so a new value is applied in every clock
   -- cycle. The output belongs to the value applied 2 clock cycles earlier,
   -- i.e. the value has passed through 3 rising clock edges.
   p_test : process
      constant C_NUM_VALUES : integer := 1280*1024;
      variable x_v     : integer;
      variable y_v     : integer;
      variable exact_v : real;
      variable error_v : real;
      variable min_v   : real := 0.0;
      variable max_v   : real := 0.0;
   begin
      for n in 0 to C_NUM_VALUES+1 loop
         if n < C_NUM_VALUES then
            x_s <= to_stdlogicvector(n / 1024, 11);
            y_s <= to_stdlogicvector(n mod 1024, 11);
         end if;
         wait for 1 ns;
         clk_s <= '1';
         wait for 1 ns;
         clk_s <= '0';

         -- Check the value applied 2 clock cycles earlier.
         x_v := (n-2) / 1024;
         y_v := (n-2) mod 1024;
         if n >= 3 then
            exact_v := sqrt(real(x_v*x_v + y_v*y_v));
            error_v := (real(to_integer(rms_s)) / 2.0**C_RESOLUTION - exact_v) / exact_v;
            min_v   := minimum(min_v, error_v);
            max_v   := maximum(max_v, error_v);
         end if;
      end loop;

      report "Relative error: min=" & real'image(min_v) & ", max=" & real'image(max_v);
      wait;
   end process p_test;

end architecture simulation;
