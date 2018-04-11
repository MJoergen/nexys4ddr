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
      rst_i      : in  std_logic;

      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      key_o      : out std_logic_vector(7 downto 0);
      valid_o    : out std_logic
   );
end ps2;

architecture Structural of ps2 is

   signal data   : std_logic_vector(7 downto 0);
   signal cnt    : integer range 0 to 10 := 0;
   signal valid  : std_logic := '0';

   signal ps2_clk_r  : std_logic;
   signal ps2_data_r : std_logic;

   signal ps2_clk_d : std_logic;

begin

   inst_debounce_clk : entity work.debounce 
   generic map (
      G_SIMULATION => false,
      G_COUNT_MAX  => 100
   )
   port map (
      clk_i => clk_i,
      in_i  => ps2_clk_i,
      out_o => ps2_clk_r
   );

   inst_debounce_data : entity work.debounce 
   generic map (
      G_SIMULATION => false,
      G_COUNT_MAX  => 100
   )
   port map (
      clk_i => clk_i,
      in_i  => ps2_data_i,
      out_o => ps2_data_r
   );


   -- For edge detection we need to store the previous value.
   p_ps2_clk_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         ps2_clk_d <= ps2_clk_r;
      end if;
   end process p_ps2_clk_d;


   -- TODO: This could check the parity
   p_data_flag : process (clk_i)
   begin
      if rising_edge(clk_i) then
         valid <= '0';

         if ps2_clk_d = '1' and ps2_clk_r = '0' then
            case cnt is
               when  0 => null;  -- Ignore start bit
               when  1 => data(0) <= ps2_data_r;
               when  2 => data(1) <= ps2_data_r;
               when  3 => data(2) <= ps2_data_r;
               when  4 => data(3) <= ps2_data_r;
               when  5 => data(4) <= ps2_data_r;
               when  6 => data(5) <= ps2_data_r;
               when  7 => data(6) <= ps2_data_r;
               when  8 => data(7) <= ps2_data_r;
               when  9 => null;  -- Ignore parity bit
               when 10 => valid <= '1';
            end case;
         end if;
      end if;
   end process p_data_flag;


   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ps2_clk_d = '1' and ps2_clk_r = '0' then
            if cnt <= 9 then
               cnt <= cnt + 1;
            else
               cnt <= 0;
            end if;

--            -- Wait for stop bit
--            if cnt=10 and ps2_data_r /= '1' then
--               cnt <= 10;
--            end if;
--
--            -- Wait for start bit
--            if cnt=0 and ps2_data_r /= '0' then
--               cnt <= 0;
--            end if;
         end if;

         if rst_i = '1' then
            cnt <= 0;
         end if;
      end if;
   end process p_cnt;

   valid_o <= valid;
   key_o   <= data;

end Structural;

