--------------------------------------
-- This is a simple PS2 writer
-- It assert the valid_o signal for one clock cycle
-- whenever a new bytecode has been received.
-- There is no synchronization check or parity check.
-- There is no glitch detection (debouncing).

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ps2_tb is
   port (
      -- Clock
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      data_i     : in  std_logic_vector(7 downto 0);
      valid_i    : in  std_logic;

      ps2_clk_o  : out std_logic;
      ps2_data_o : out std_logic
   );
end ps2_tb;

architecture Structural of ps2_tb is

   signal clk_cnt  : std_logic_vector(6 downto 0);

   signal cnt    : integer range 0 to 11 := 0;

   signal ps2_clk   : std_logic;
   signal ps2_clk_d : std_logic;
   signal ps2_data  : std_logic := '0';

begin

   proc_ps2_clk : process (clk_i)
   begin
      if rising_edge(clk_i) then
         clk_cnt <= clk_cnt + 1;

         if clk_cnt = 0 and cnt > 0 then
            ps2_clk <= not ps2_clk;
         end if;

         if rst_i = '1' or valid_i = '1' then
            clk_cnt <= (others => '0');
            ps2_clk <= '1';
         end if;
      end if;
   end process proc_ps2_clk;


   proc_ps2_clk_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         ps2_clk_d <= ps2_clk;
      end if;
   end process proc_ps2_clk_d;


   proc_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cnt = 0 and valid_i = '1' then
            cnt <= 1;
         end if;

         if ps2_clk_d = '0' and ps2_clk = '1' and cnt > 0 then
            if cnt <= 10 then
               cnt <= cnt + 1;
            else
               cnt <= 0;
            end if;
         end if;

         if rst_i = '1' then
            cnt <= 0;
         end if;
      end if;
   end process proc_cnt;

   proc_ps2_data : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if ps2_clk_d = '0' and ps2_clk = '1' then
            case cnt is
               when  0 => ps2_data <= '0';      -- Start bit
               when  1 => ps2_data <= data_i(0);
               when  2 => ps2_data <= data_i(1);
               when  3 => ps2_data <= data_i(2);
               when  4 => ps2_data <= data_i(3);
               when  5 => ps2_data <= data_i(4);
               when  6 => ps2_data <= data_i(5);
               when  7 => ps2_data <= data_i(6);
               when  8 => ps2_data <= data_i(7);
               when  9 => ps2_data <= '1';      -- Parity bit (ignore)
               when 10 => ps2_data <= '1';      -- Stop bit
               when 11 => ps2_data <= '1';      -- ???
            end case;
         end if;
      end if;
   end process proc_ps2_data;

   ps2_clk_o  <= ps2_clk;
   ps2_data_o <= ps2_data;

end Structural;

