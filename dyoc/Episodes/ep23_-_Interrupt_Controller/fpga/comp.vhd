library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can execute all instructions.
-- It additionally features a 80x60 character display, and an
-- interrupt controller.
--
-- The speed of the execution is controlled by the slide switches.
-- Simultaneously, the CPU debug is shown as an overlay over the text screen.
-- If switch 7 is turned on, the CPU operates at full speed, and the
-- CPU debug overlay is switched off.

entity comp is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);
      led_o     : out std_logic_vector(7 downto 0);
      rstn_i    : in  std_logic;

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture structural of comp is

   constant C_TIMER_CNT     : integer := 25000;
   constant C_OVERLAY_BITS  : integer := 176;
   constant C_ROM_INIT_FILE : string := "../rom.txt";
   constant C_OPCODES_FILE  : string := "opcodes.txt";
   constant C_FONT_FILE     : string := "font8x8.txt";

   -- MAIN Clock domain
   signal main_clk      : std_logic;
   signal main_rst      : std_logic;
   signal main_rst_shr  : std_logic_vector(7 downto 0) := X"FF";
   signal main_wait     : std_logic;
   signal main_vga_irq  : std_logic;
   signal main_overlay  : std_logic_vector(C_OVERLAY_BITS-1 downto 0);
   signal main_memio_wr : std_logic_vector(255 downto 0);
   signal main_memio_rd : std_logic_vector(255 downto 0);

   -- VGA Clock doamin
   signal vga_clk             : std_logic;
   signal vga_overlay_en      : std_logic;
   signal vga_overlay         : std_logic_vector(C_OVERLAY_BITS-1 downto 0);
   signal vga_char_addr       : std_logic_vector( 12 downto 0);
   signal vga_char_data       : std_logic_vector(  7 downto 0);
   signal vga_col_addr        : std_logic_vector( 12 downto 0);
   signal vga_col_data        : std_logic_vector(  7 downto 0);
   signal vga_memio_rd        : std_logic_vector( 31 downto 0);
   signal vga_memio_wr        : std_logic_vector(255 downto 0);
   signal vga_memio_palette   : std_logic_vector(127 downto 0);
   signal vga_memio_pix_y_int : std_logic_vector( 2*8-1 downto 0);
   signal vga_memio_pix_x     : std_logic_vector( 15 downto 0);
   signal vga_memio_pix_y     : std_logic_vector( 15 downto 0);
   signal vga_irq             : std_logic;

begin

   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   clk_inst : entity work.clk_wiz_0_clk_wiz
   port map (
      clk_in1  => clk_i,
      eth_clk  => open, -- Not needed yet.
      vga_clk  => vga_clk,
      main_clk => main_clk
   ); -- clk_inst


   --------------------------------------------------
   -- Generate Reset
   --------------------------------------------------

   main_rst_proc : process (main_clk)
   begin
      if rising_edge(main_clk) then
         -- Hold reset asserted for a number of clock cycles.
         main_rst     <= main_rst_shr(0);
         main_rst_shr <= "0" & main_rst_shr(main_rst_shr'left downto 1);

         if rstn_i = '0' then
            main_rst_shr <= (others => '1');
         end if;
      end if;
   end process main_rst_proc;


   --------------------------------------------------
   -- Instantiate Waiter
   --------------------------------------------------

   waiter_inst : entity work.waiter
   port map (
      clk_i  => main_clk,
      inc_i  => sw_i,
      wait_o => main_wait
   ); -- waiter_inst


   --------------------------------------------------
   -- Instantiate MAIN module
   --------------------------------------------------

   main_inst : entity work.main
   generic map (
      G_TIMER_CNT     => C_TIMER_CNT,
      G_ROM_INIT_FILE => C_ROM_INIT_FILE,
      G_OVERLAY_BITS  => C_OVERLAY_BITS
   )
   port map (
      main_clk_i      => main_clk,
      main_rst_i      => main_rst,
      main_wait_i     => main_wait,
      main_vga_irq_i  => main_vga_irq,
      main_led_o      => led_o,
      main_overlay_o  => main_overlay,
      main_memio_wr_o => main_memio_wr,
      main_memio_rd_i => main_memio_rd,
      --
      vga_clk_i       => vga_clk,
      vga_char_addr_i => vga_char_addr,
      vga_char_data_o => vga_char_data,
      vga_col_addr_i  => vga_col_addr,
      vga_col_data_o  => vga_col_data
   ); -- main_inst
   

   --------------------------------------------------
   -- Control VGA debug overlay
   --------------------------------------------------

   vga_overlay_en <= not sw_i(7);


   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   vga_inst : entity work.vga
   generic map (
      G_OVERLAY_BITS => C_OVERLAY_BITS,
      G_OPCODES_FILE => C_OPCODES_FILE,
      G_FONT_FILE    => C_FONT_FILE
   )
   port map (
      clk_i             => vga_clk,
      overlay_i         => vga_overlay_en,
      digits_i          => vga_overlay,
      --
      char_addr_o       => vga_char_addr,
      char_data_i       => vga_char_data,
      col_addr_o        => vga_col_addr,
      col_data_i        => vga_col_data,
      --
      memio_palette_i   => vga_memio_palette,
      memio_pix_y_int_i => vga_memio_pix_y_int,
      memio_pix_x_o     => vga_memio_pix_x,
      memio_pix_y_o     => vga_memio_pix_y,
      --
      vga_hs_o          => vga_hs_o,
      vga_vs_o          => vga_vs_o,
      vga_col_o         => vga_col_o,
      --
      irq_o             => vga_irq
   ); -- vga_inst


   cdc_pulse_vga_irq_inst : entity work.cdc_pulse
   port map (
      src_clk_i   => vga_clk,
      src_pulse_i => vga_irq,
      dst_clk_i   => main_clk,
      dst_pulse_o => main_vga_irq
   ); -- cdc_pulse_vga_irq_inst


   --------------------------------------------------
   -- Instantiate clock crossing from MAIN to VGA
   --------------------------------------------------

   cdc_overlay_inst : entity work.cdc
   generic map (
      G_WIDTH => C_OVERLAY_BITS
   )
   port map (
      src_clk_i  => main_clk,
      src_data_i => main_overlay,
      dst_clk_i  => vga_clk,
      dst_data_o => vga_overlay
   ); -- cdc_overlay_inst
   

   --------------------------------------------------
   -- Memory Mapped I/O
   -- This must match the mapping in prog/include/memorymap.h
   --------------------------------------------------

   vga_memio_palette   <= vga_memio_wr(15*8+7 downto  0*8);  -- 7FC0 - 7FCF : VGA_PALETTE
   vga_memio_pix_y_int <= vga_memio_wr(17*8+7 downto 16*8);  -- 7FD0 - 7FD1 : VGA_PIX_Y_INT
                                                             -- 7FD2 - 7FDF : Not used

   vga_memio_rd(1*8+7 downto 0*8)    <= vga_memio_pix_x;     -- 7FE0 - 7FE1 : VGA_PIX_X
   vga_memio_rd(3*8+7 downto 2*8)    <= vga_memio_pix_y;     -- 7FE2 - 7FE3 : VGA_PIX_Y
   main_memio_rd(31*8+7 downto  4*8) <= (others => '0');     -- 7FE4 - 7FFF : Not used


   -----------------------------------
   -- Clock domain crossing for MEMIO
   -----------------------------------

   cdc_vga_memio_inst : entity work.cdc
   generic map (
      G_WIDTH => 256
   )
   port map (
      src_clk_i  => main_clk,
      src_data_i => main_memio_wr,
      dst_clk_i  => vga_clk,
      dst_data_o => vga_memio_wr
   ); -- cdc_vga_memio_main_inst

   cdc_main_memio_inst : entity work.cdc
   generic map (
      G_WIDTH => 4*8
   )
   port map (
      src_clk_i  => vga_clk,
      src_data_i => vga_memio_rd,
      dst_clk_i  => main_clk,
      dst_data_o => main_memio_rd(3*8+7 downto 0*8)
   ); -- cdc_main_memio_vga_inst

end architecture structural;

