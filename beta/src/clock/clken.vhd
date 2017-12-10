library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clken is
   port (
      -- Clock
      clk_cpu_i   : in  std_logic;                    -- 100 MHz

      -- Switches
      sw_i        : in  std_logic_vector(15 downto 0);
      -- sw_i(0) = 0 is used for single-step mode.
      -- sw_i(0) = 1 means the clock is free-running.

      -- Buttons
      btnc_i      : in  std_logic;                       -- Used for singlestepping

      clk_en_o    : out std_logic;
      count_o     : out std_logic_vector(7 downto 0)     -- Debug output
   );
end clken;

architecture Structural of clken is

   signal counter       : std_logic_vector(25 downto 0) := (others => '0');
   signal button_down   : std_logic := '0';
   signal button_down_d : std_logic := '0';
   signaL clk_en        : std_logic := '0';

begin

   count_o <= counter(24 downto 17);

   p_counter : process (clk_cpu_i)
   begin
      if rising_edge(clk_cpu_i) then
         counter <= counter + conv_integer(sw_i(15 downto 1) & "00000000000") + 1;

         if counter(counter'left) = '1' and sw_i(0) = '1' then
            counter <= (others => '0');
         end if;

         if btnc_i = '1' then
            counter <= (others => '0');
         end if;
      end if;
   end process p_counter;


   p_button_down : process (clk_cpu_i)
   begin
      if rising_edge(clk_cpu_i) then
         if btnc_i = '1' or sw_i(0) = '1' then
            button_down <= '1';
         end if;

         if counter(counter'left) = '1' then
            button_down <= '0';
         end if;
      end if;
   end process p_button_down;


   p_clk_en : process (clk_cpu_i)
   begin
      if rising_edge(clk_cpu_i) then

         clk_en <= '0';
         if button_down_d = '0' and button_down = '1' then
            clk_en <= '1';
         end if;

         button_down_d <= button_down;
      end if;
   end process p_clk_en;

   clk_en_o <= clk_en;

end architecture Structural;

