--------------------------------------
-- This is a simple PS2 reader.
-- It assert the valid_o signal for one clock cycle
-- whenever a new bytecode has been received.
-- There is no synchronization check or parity check.
-- There is no glitch detection (debouncing).

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ps2 is
   port (
      -- Clock
      clk_i      : in  std_logic;

      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      key_o      : out std_logic_vector(7 downto 0);
      valid_o    : out std_logic
   );
end ps2;

architecture Structural of ps2 is

   signal data   : std_logic_vector(7 downto 0);
   signal cnt    : integer range 0 to 10 := 0;
   signal flag   : std_logic := '0';
   signal flag_d : std_logic := '0';

   signal ps2_clk_d : std_logic;

begin

   -- For edge detection we need to store the previous value.
   p_ps2_clk_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         ps2_clk_d <= ps2_clk_i;
      end if;
   end process p_ps2_clk_d;


   -- TODO: This could check the parity, as well as start and stop bits.
   p_data_flag : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ps2_clk_d = '1' and ps2_clk_i = '0' then
            case cnt is
               when  0 => null;
               when  1 => data(0) <= ps2_data_i;
               when  2 => data(1) <= ps2_data_i;
               when  3 => data(2) <= ps2_data_i;
               when  4 => data(3) <= ps2_data_i;
               when  5 => data(4) <= ps2_data_i;
               when  6 => data(5) <= ps2_data_i;
               when  7 => data(6) <= ps2_data_i;
               when  8 => data(7) <= ps2_data_i;
               when  9 => flag <= '1';
               when 10 => flag <= '0';
            end case;
         end if;
      end if;
   end process p_data_flag;


   -- TODO: This could reset counter in case of synchronization loss.
   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ps2_clk_d = '1' and ps2_clk_i = '0' then
            if cnt <= 9 then
               cnt <= cnt + 1;
            else
               cnt <= 0;
            end if;
         end if;
      end if;
   end process p_cnt;


   -- For edge detection we need to store the previous value.
   p_flag_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         flag_d <= flag;
      end if;
   end process p_flag_d;


   -- Aseert valid_o for exactly one clock cycle.
   p_valid : process (clk_i)
   begin
      if rising_edge(clk_i) then
         valid_o <= '0';
         if flag_d = '0' and flag = '1' then
            valid_o <= '1';
         end if;
      end if;
   end process p_valid;

   key_o <= data;

end Structural;

