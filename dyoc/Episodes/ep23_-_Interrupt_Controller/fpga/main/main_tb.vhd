library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity main_tb is
end main_tb;

architecture structural of main_tb is

   -- Clock and reset
   signal main_clk     : std_logic;
   signal main_rst     : std_logic;
   signal main_vga_irq : std_logic;

   -- Generate pause signal
   signal main_wait_cnt : std_logic_vector(1 downto 0) := (others => '0');
   signal main_wait     : std_logic;

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

   main_vga_irq_proc : process
   begin
      main_vga_irq <= '0';
      wait for 7 us;
      wait until main_clk = '1';
      main_vga_irq <= '1';
      wait until main_clk = '1';
      main_vga_irq <= '0';
      wait until main_clk = '1';
   end process main_vga_irq_proc;



   --------------------------------------------------
   -- Instantiate MAIN
   --------------------------------------------------

   main_inst : entity work.main
   generic map (
      G_ROM_INIT_FILE => "../rom.txt",
      G_OVERLAY_BITS  => 176
   )
   port map (
      main_clk_i      => main_clk,
      main_rst_i      => main_rst,
      main_wait_i     => '0',
      main_vga_irq_i  => main_vga_irq,
      main_led_o      => open,
      main_overlay_o  => open,
      main_memio_wr_o => open,
      main_memio_rd_i => (others => '0'),
      --
      vga_clk_i       => '0',
      vga_char_addr_i => (others => '0'),
      vga_char_data_o => open,
      vga_col_addr_i  => (others => '0'),
      vga_col_data_o  => open
   ); -- main_inst
   
end architecture structural;

