library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity main_tb is
end main_tb;

architecture structural of main_tb is

   -- Clock
   signal main_clk  : std_logic;

   -- Generate pause signal
   signal main_wait_cnt : std_logic_vector(1 downto 0) := (others => '0');
   signal main_wait     : std_logic;

begin
   
   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   -- Generate clock
   main_clk_proc : process
   begin
      main_clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process main_clk_proc;


   --------------------------------------------------
   -- Generate wait signal
   --------------------------------------------------

   main_wait_cnt_proc : process (main_clk)
   begin
      if rising_edge(main_clk) then
         main_wait_cnt <= main_wait_cnt + 1;
      end if;
   end process main_wait_cnt_proc;

   -- Check for wrap around of counter.
   main_wait <= '0' when main_wait_cnt = 0  else '1';

   
   --------------------------------------------------
   -- Instantiate MAIN
   --------------------------------------------------

   main_inst : entity work.main
   generic map (
      G_RAM_INIT_FILE => "main/mem/ram.txt",
      G_OVERLAY_BITS  => 144
   )
   port map (
      clk_i     => main_clk,
      wait_i    => main_wait,
      overlay_o => open
   ); -- main_inst
   
end architecture structural;

