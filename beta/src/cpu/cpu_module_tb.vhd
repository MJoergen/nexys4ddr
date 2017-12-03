library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu_module_tb is
end cpu_module_tb;

architecture Structural of cpu_module_tb is

   signal clk  : std_logic;                      -- 10 MHz
   signal rstn : std_logic;                      -- Active low
   signal sw   : std_logic_vector(15 downto 0);
   signal val  : std_logic_vector(31 downto 0);

   signal test_running : boolean := true;

begin

    -- Generate clock
   clk_gen : process
   begin
      if not test_running then
         wait;
      end if;

      clk <= '1', '0' after 50 ns; -- 10 MHz
      wait for 100 ns;
   end process clk_gen;

   -- Generate reset
   rstn <= '0', '1' after 450 ns;

   -- Generate input switches
   sw <= (others => '0');


   -- Instantiate the DUT
   i_dut : entity work.cpu_module
   port map (
      clk_i   => clk,
      rstn_i  => rstn,
      sw_i    => sw,
      val_o   => val
   );


   -- This is the main test
   p_main : process
   begin
      wait for 1 us;
      test_running <= false;
      wait;
   end process p_main;

end Structural;

