library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity main_tb is
end main_tb;

architecture structural of main_tb is

   -- Clock and reset
   signal main_clk : std_logic;
   signal main_rst : std_logic;

   -- Generate pause signal
   signal main_wait_cnt : std_logic_vector(1 downto 0) := (others => '0');
   signal main_wait     : std_logic;

   signal main_vga_irq : std_logic;
   signal main_kbd_irq : std_logic;

begin
   
   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   main_clk_proc : process
   begin
      main_clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process main_clk_proc;


   --------------------------------------------------
   -- Generate reset
   --------------------------------------------------

   main_rst_proc : process
   begin
      main_rst <= '1';
      wait for 100 ns;

      -- Make sure reset is deasserted synchronuous to the clock
      wait until main_clk = '1';
      main_rst <= '0';
      wait;
   end process main_rst_proc;


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
      G_TIMER_CNT        => 25000,
      G_ROM_INIT_FILE    => "../rom.txt",
      G_OVERLAY_BITS     => 176
   )
   port map (
      main_clk_i         => main_clk,
      main_rst_i         => main_rst,
      main_wait_i        => main_wait,
      main_vga_irq_i     => main_vga_irq,
      main_kbd_irq_i     => main_kbd_irq,
      main_led_o         => open,
      main_overlay_o     => open,
      main_memio_wr_o    => open,
      main_memio_rd_i    => (others => '0'),
      main_memio_clear_i => (others => '0'),
      main_eth_wr_en_i   => '0',
      main_eth_wr_addr_i => (others => '0'),
      main_eth_wr_data_i => (others => '0'),
      --
      vga_clk_i          => '0',
      vga_char_addr_i    => (others => '0'),
      vga_char_data_o    => open,
      vga_col_addr_i     => (others => '0'),
      vga_col_data_o     => open
   ); -- main_inst
   
end architecture structural;

