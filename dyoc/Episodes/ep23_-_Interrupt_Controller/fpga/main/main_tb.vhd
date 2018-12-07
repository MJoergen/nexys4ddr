library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity main_tb is
end main_tb;

architecture structural of main_tb is

   -- Clock and reset
   signal main_clk           : std_logic;
   signal main_rst           : std_logic;

   -- Generate pause signal
   signal main_wait_cnt      : std_logic_vector(1 downto 0) := (others => '0');
   signal main_wait          : std_logic;

   signal main_vga_irq       : std_logic;

   signal main_memio_wr      : std_logic_vector(255 downto 0);
   signal main_vga_pix_y_int : std_logic_vector(15 downto 0);
   signal main_vga_pix_y     : std_logic_vector(15 downto 0) := X"FFFD";
   signal main_vga_palette_0 : std_logic_vector(7 downto 0);
   signal eq                 : std_logic;
   signal eq_d               : std_logic;

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


   ---------------
   -- VGA counter
   ---------------

   main_vga_pix_y_proc : process
   begin
      wait for 1.3 us;

      while true loop
         main_vga_pix_y <= main_vga_pix_y + 1;
         wait for 7 us;
      end loop;
   end process main_vga_pix_y_proc;

   main_vga_pix_y_int <= main_memio_wr(17*8+7 downto 16*8);
   main_vga_palette_0 <= main_memio_wr(7 downto 0);

   main_vga_irq_proc : process (main_clk)
   begin
      if rising_edge(main_clk) then
         eq <= '0';
         if main_vga_pix_y = main_vga_pix_y_int then
            eq <= '1';
         end if;

         eq_d <= eq;

         main_vga_irq <= '0';
         if eq_d = '0' and eq = '1' then
            main_vga_irq <= '1';
         end if;
      end if;
   end process main_vga_irq_proc;


   --------------------------------------------------
   -- Instantiate MAIN
   --------------------------------------------------

   main_inst : entity work.main
   generic map (
      G_TIMER_CNT     => 701,
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
      main_memio_wr_o => main_memio_wr,
      main_memio_rd_i => (others => '0'),
      --
      vga_clk_i       => '0',
      vga_char_addr_i => (others => '0'),
      vga_char_data_o => open,
      vga_col_addr_i  => (others => '0'),
      vga_col_data_o  => open
   ); -- main_inst
   
end architecture structural;

