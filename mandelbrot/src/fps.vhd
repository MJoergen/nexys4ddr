library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module converts the time taken by a picture (in clock cycles) to the
-- frame rate in pictures per second, as a decimal number for the 7-segment
-- display. The frame rate is G_CLK_FREQ / time_i, rounded down to an integer.
-- If it does not fit in G_DIGITS digits (or time_i is zero), the largest
-- value that fits (all nines) is shown instead.
--
-- A new value is calculated for each pulse on valid_i. The calculation takes
-- 2*C_BITS+2 clock cycles (58 for the MAIN clock), and pulses on valid_i
-- during a calculation are ignored. It is done one bit per clock cycle,
-- because a single-cycle division is far too slow for the MAIN clock:
-- * The division is a restoring division, which needs one subtraction (of
--   G_TIME_BITS+1 bits) for each bit of the quotient.
-- * The quotient is converted to decimal (BCD) with the double dabble
--   algorithm: For each bit, 3 is added to each digit which is 5 or more, and
--   then the digits and the binary value are shifted left together by one bit.
--
-- The outputs are changed together at the end of the calculation, and they
-- keep their value until the next calculation is finished. digits_o holds one
-- BCD digit for each 4 bits, the least significant digit in bits 3 downto 0.
-- blank_o has one bit for each digit, and is set for the leading zeros (but
-- never for the least significant digit).

entity fps is
   generic (
      G_CLK_FREQ  : natural;       -- Clock cycles per second
      G_TIME_BITS : natural;       -- Width of time_i
      G_DIGITS    : natural := 8
   );
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      time_i   : in  std_logic_vector(G_TIME_BITS-1 downto 0);
      valid_i  : in  std_logic;
      digits_o : out std_logic_vector(4*G_DIGITS-1 downto 0);
      blank_o  : out std_logic_vector(G_DIGITS-1 downto 0)
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

   -- The width of the quotient, which is at most G_CLK_FREQ
   constant C_BITS  : natural := num_bits(G_CLK_FREQ);

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

   type state_t is (IDLE_ST, DIV_ST, SAT_ST, BCD_ST, OUT_ST);
   signal state     : state_t := IDLE_ST;

   signal bit_cnt   : natural range 0 to C_BITS-1;

   -- During the division, quot holds the remaining bits of the dividend,
   -- followed by the bits of the quotient found so far. At the end of the
   -- division it holds the quotient. During the conversion it is shifted out
   -- into bcd, one bit per clock cycle.
   signal quot      : std_logic_vector(C_BITS-1 downto 0);
   signal remainder : std_logic_vector(G_TIME_BITS-1 downto 0);
   signal divisor   : std_logic_vector(G_TIME_BITS-1 downto 0);
   signal bcd       : std_logic_vector(4*G_DIGITS-1 downto 0);

begin

   p_fps : process (clk_i)
      variable rem_v  : std_logic_vector(G_TIME_BITS downto 0);
      variable diff_v : std_logic_vector(G_TIME_BITS+1 downto 0);
      variable bcd_v  : std_logic_vector(4*G_DIGITS-1 downto 0);
      variable zero_v : boolean;
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST =>
               if valid_i = '1' then
                  divisor   <= time_i;
                  quot      <= to_stdlogicvector(G_CLK_FREQ, C_BITS);
                  remainder <= (others => '0');
                  bit_cnt   <= C_BITS-1;
                  state     <= DIV_ST;
               end if;

            when DIV_ST =>
               -- Shift the next bit of the dividend into the remainder, and
               -- subtract the divisor, if the remainder is large enough.
               rem_v  := remainder & quot(C_BITS-1);
               diff_v := ('0' & rem_v) - ("00" & divisor);
               if diff_v(G_TIME_BITS+1) = '0' then
                  remainder <= diff_v(G_TIME_BITS-1 downto 0);
                  quot      <= quot(C_BITS-2 downto 0) & '1';
               else
                  remainder <= rem_v(G_TIME_BITS-1 downto 0);
                  quot      <= quot(C_BITS-2 downto 0) & '0';
               end if;

               if bit_cnt = 0 then
                  state <= SAT_ST;
               else
                  bit_cnt <= bit_cnt - 1;
               end if;

            when SAT_ST =>
               -- A zero divisor gives a quotient of all ones, which is
               -- saturated here too.
               if to_integer(quot) > C_MAX then
                  quot <= to_stdlogicvector(C_MAX, C_BITS);
               end if;
               bcd     <= (others => '0');
               bit_cnt <= C_BITS-1;
               state   <= BCD_ST;

            when BCD_ST =>
               bcd_v := bcd;
               for i in 0 to G_DIGITS-1 loop
                  if bcd_v(4*i+3 downto 4*i) >= 5 then
                     bcd_v(4*i+3 downto 4*i) := bcd_v(4*i+3 downto 4*i) + 3;
                  end if;
               end loop;
               bcd  <= bcd_v(4*G_DIGITS-2 downto 0) & quot(C_BITS-1);
               quot <= quot(C_BITS-2 downto 0) & '0';

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
               state <= IDLE_ST;
         end case;

         if rst_i = '1' then
            state    <= IDLE_ST;
            digits_o <= (others => '0');
            blank_o  <= (0 => '0', others => '1');
         end if;
      end if;
   end process p_fps;

end architecture rtl;
