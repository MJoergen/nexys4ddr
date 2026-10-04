-- This module converts the times taken by the pictures (in clock cycles) to
-- the frame rate in pictures per second, as a decimal number for the 7-segment
-- display. The time of each picture is given on time_i, with a pulse on
-- valid_i.
--
-- The frame rate is averaged, so the number shown does not change after
-- every picture: The times of the pictures are added up, until the sum is at
-- least G_AVG_CYCLES (or 2^G_FRAME_BITS-1 pictures have been added up). Then
-- the frame rate of these pictures is calculated, and a new sum is started.
-- With G_AVG_CYCLES = G_CLK_FREQ/2 the frame rate is updated about twice per
-- second, and it is the average of the last half second. With G_AVG_CYCLES =
-- 0 it is updated after every picture.
--
-- The frame rate is (number of pictures) * G_CLK_FREQ / (sum of the times),
-- rounded down to an integer. If it does not fit in G_DIGITS digits (or the
-- sum is zero), the largest value that fits (all nines) is shown instead.
--
-- The calculation takes 2*C_QUOT_BITS+3 clock cycles (77 for the MAIN clock),
-- and it starts in the clock cycle after the last picture of the average.
-- Pictures that end during a calculation start the next sum. Pictures that
-- end while a finished sum waits for a calculation are ignored, but that only
-- happens if a picture takes fewer clock cycles than a calculation.
-- The calculation is done one bit per clock cycle, because a single-cycle
-- division is far too slow for the MAIN clock:
-- * The division is a restoring division, which needs one subtraction (of
--   C_SUM_BITS+1 bits) for each bit of the quotient.
-- * The quotient is converted to decimal (BCD) with the double dabble
--   algorithm: For each bit, 3 is added to each digit which is 5 or more, and
--   then the digits and the binary value are shifted left together by one bit.
--
-- The outputs are changed together at the end of the calculation, and they
-- keep their value until the next calculation is finished. digits_o holds one
-- BCD digit for each 4 bits, the least significant digit in bits 3 downto 0.
-- blank_o has one bit for each digit, and is set for the leading zeros (but
-- never for the least significant digit). valid_o is high for one clock cycle,
-- when the outputs are changed.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity fps is
   generic (
      G_CLK_FREQ   : natural;       -- Clock cycles per second
      G_TIME_BITS  : natural;       -- Width of time_i
      G_AVG_CYCLES : natural;       -- Minimum time averaged over
      G_FRAME_BITS : natural := 10; -- Width of the number of pictures averaged
      G_DIGITS     : natural := 8
   );
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      time_i   : in  std_logic_vector(G_TIME_BITS-1 downto 0);
      valid_i  : in  std_logic;
      -- The initial values are the same as after reset, so the display
      -- module does not read undefined values before reset (in simulation).
      digits_o : out std_logic_vector(4*G_DIGITS-1 downto 0) := (others => '0');
      blank_o  : out std_logic_vector(G_DIGITS-1 downto 0) := (0 => '0', others => '1');
      valid_o  : out std_logic := '0'
   );
end entity fps;

architecture rtl of fps is

   -- The number of bits needed for the value n
   function num_bits(n : natural) return natural is
      variable v : natural := n;
      variable r : natural := 0;
   begin
      while v > 0 loop
         v := v / 2;
         r := r + 1;
      end loop;
      return r;
   end function num_bits;

   function maximum(a, b : natural) return natural is
   begin
      if a > b then
         return a;
      end if;
      return b;
   end function maximum;

   -- The largest number of pictures in an average
   constant C_MAX_FRAMES : natural := 2**G_FRAME_BITS - 1;

   -- The width of the sum of the times. The sum is less than G_AVG_CYCLES
   -- before the last time is added.
   constant C_SUM_BITS  : natural := maximum(num_bits(G_AVG_CYCLES), G_TIME_BITS) + 1;

   -- The width of the dividend (pictures * G_CLK_FREQ), and of the quotient
   constant C_QUOT_BITS : natural := G_FRAME_BITS + num_bits(G_CLK_FREQ);

   -- The largest value shown, i.e. all nines, but at most 2^31-1
   function max_value return natural is
      variable r : natural := 0;
   begin
      for i in 1 to G_DIGITS loop
         if r > (natural'high - 9) / 10 then
            return natural'high;
         end if;
         r := 10*r + 9;
      end loop;
      return r;
   end function max_value;

   constant C_MAX   : natural := max_value;

   -- The sum of the current average: the number of pictures, the number of
   -- pictures times G_CLK_FREQ, and the sum of the times.
   signal sum_cnt   : natural range 0 to C_MAX_FRAMES := 0;
   signal sum_num   : std_logic_vector(C_QUOT_BITS-1 downto 0) := (others => '0');
   signal sum_time  : std_logic_vector(C_SUM_BITS-1 downto 0) := (others => '0');

   type state_t is (IDLE_ST, DIV_ST, SAT_ST, BCD_ST, OUT_ST);
   signal state     : state_t := IDLE_ST;

   signal bit_cnt   : natural range 0 to C_QUOT_BITS-1;

   -- During the division, quot holds the remaining bits of the dividend,
   -- followed by the bits of the quotient found so far. At the end of the
   -- division it holds the quotient. During the conversion it is shifted out
   -- into bcd, one bit per clock cycle.
   signal quot      : std_logic_vector(C_QUOT_BITS-1 downto 0);
   signal remainder : std_logic_vector(C_SUM_BITS-1 downto 0);
   signal divisor   : std_logic_vector(C_SUM_BITS-1 downto 0);
   signal bcd       : std_logic_vector(4*G_DIGITS-1 downto 0);

begin

   p_fps : process (clk_i)
      variable full_v : boolean;
      variable rem_v  : std_logic_vector(C_SUM_BITS downto 0);
      variable diff_v : std_logic_vector(C_SUM_BITS+1 downto 0);
      variable bcd_v  : std_logic_vector(4*G_DIGITS-1 downto 0);
      variable zero_v : boolean;
   begin
      if rising_edge(clk_i) then
         valid_o <= '0';

         -- The sum is finished, when it has enough time or pictures
         full_v := sum_cnt > 0 and (sum_time >= G_AVG_CYCLES or sum_cnt = C_MAX_FRAMES);

         if valid_i = '1' and not full_v then
            sum_cnt  <= sum_cnt + 1;
            sum_num  <= sum_num + G_CLK_FREQ;
            sum_time <= sum_time + time_i;
         end if;

         case state is
            when IDLE_ST =>
               if full_v then
                  divisor   <= sum_time;
                  quot      <= sum_num;
                  remainder <= (others => '0');
                  bit_cnt   <= C_QUOT_BITS-1;
                  state     <= DIV_ST;

                  -- Start a new sum (with this picture, if one ends now)
                  sum_cnt  <= 0;
                  sum_num  <= (others => '0');
                  sum_time <= (others => '0');
                  if valid_i = '1' then
                     sum_cnt  <= 1;
                     sum_num  <= to_stdlogicvector(G_CLK_FREQ, C_QUOT_BITS);
                     sum_time <= resize(time_i, C_SUM_BITS);
                  end if;
               end if;

            when DIV_ST =>
               -- Shift the next bit of the dividend into the remainder, and
               -- subtract the divisor, if the remainder is large enough.
               rem_v  := remainder & quot(C_QUOT_BITS-1);
               diff_v := ('0' & rem_v) - ("00" & divisor);
               if diff_v(C_SUM_BITS+1) = '0' then
                  remainder <= diff_v(C_SUM_BITS-1 downto 0);
                  quot      <= quot(C_QUOT_BITS-2 downto 0) & '1';
               else
                  remainder <= rem_v(C_SUM_BITS-1 downto 0);
                  quot      <= quot(C_QUOT_BITS-2 downto 0) & '0';
               end if;

               if bit_cnt = 0 then
                  state <= SAT_ST;
               else
                  bit_cnt <= bit_cnt - 1;
               end if;

            when SAT_ST =>
               -- A zero divisor gives a quotient of all ones, which is
               -- saturated here too.
               if quot > C_MAX then
                  quot <= to_stdlogicvector(C_MAX, C_QUOT_BITS);
               end if;
               bcd     <= (others => '0');
               bit_cnt <= C_QUOT_BITS-1;
               state   <= BCD_ST;

            when BCD_ST =>
               bcd_v := bcd;
               for i in 0 to G_DIGITS-1 loop
                  if bcd_v(4*i+3 downto 4*i) >= 5 then
                     bcd_v(4*i+3 downto 4*i) := bcd_v(4*i+3 downto 4*i) + 3;
                  end if;
               end loop;
               bcd  <= bcd_v(4*G_DIGITS-2 downto 0) & quot(C_QUOT_BITS-1);
               quot <= quot(C_QUOT_BITS-2 downto 0) & '0';

               if bit_cnt = 0 then
                  state <= OUT_ST;
               else
                  bit_cnt <= bit_cnt - 1;
               end if;

            when OUT_ST =>
               digits_o <= bcd;
               zero_v := true;
               for i in G_DIGITS-1 downto 1 loop
                  zero_v := zero_v and bcd(4*i+3 downto 4*i) = 0;
                  blank_o(i) <= '1' when zero_v else '0';
               end loop;
               blank_o(0) <= '0';
               valid_o    <= '1';
               state <= IDLE_ST;
         end case;

         if rst_i = '1' then
            state    <= IDLE_ST;
            sum_cnt  <= 0;
            sum_num  <= (others => '0');
            sum_time <= (others => '0');
            valid_o  <= '0';
            digits_o <= (others => '0');
            blank_o  <= (0 => '0', others => '1');
         end if;
      end if;
   end process p_fps;

end architecture rtl;
