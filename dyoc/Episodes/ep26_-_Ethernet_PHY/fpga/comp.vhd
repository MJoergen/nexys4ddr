library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can execute all instructions.
-- It additionally features a 80x60 character display and connects to an
-- onboard Ethernet PHY.
--
-- The speed of the execution is controlled by the slide switches.
-- Simultaneously, the CPU debug is shown as an overlay over the text screen.
-- If switch 7 is turned on, the CPU operates at full speed, and the
-- CPU debug overlay is switched off.

entity comp is
   generic (
      G_SIM_MODEL : boolean := false;  -- This is set to true in the simulation test bench.
      G_FONT_FILE : string := "font8x8.txt"
   );
   port (
      clk_i      : in  std_logic;                      -- 100 MHz

      -- CPU reset (push button). Active low.
      rstn_i     : in  std_logic;

      -- Input switches
      sw_i       : in  std_logic_vector(7 downto 0);

      -- Output LED's
      led_o      : out std_logic_vector(7 downto 0);

      -- Keyboard
      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      -- Connected to Ethernet PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_o    : out   std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic;
   
      -- Output to VGA monitor
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture Structural of comp is

   -- Clock divider for VGA and Ethnernet
   signal clk_cnt  : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk  : std_logic;
   signal eth_clk  : std_logic;

   -- Reset
   signal rst : std_logic := '1';   -- Make sure reset is asserted after power-up.

   -- Wait signal is used to slow down the CPU
   signal sys_wait : std_logic;

   -- VGA debug overlay
   signal vga_overlay_en : std_logic;
   signal vga_overlay    : std_logic_vector(207 downto 0);

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector( 7 downto 0);
   signal cpu_data  : std_logic_vector( 7 downto 0);
   signal cpu_rden  : std_logic;
   signal cpu_wren  : std_logic;
   signal cpu_debug : std_logic_vector(175 downto 0);
   signal cpu_wait  : std_logic;
   signal mem_wait  : std_logic;

   -- Interface between VGA and Memory
   signal char_addr : std_logic_vector(12 downto 0);
   signal char_data : std_logic_vector( 7 downto 0);
   signal col_addr  : std_logic_vector(12 downto 0);
   signal col_data  : std_logic_vector( 7 downto 0);

   -- Memory Mapped I/O
   signal memio_rd   : std_logic_vector(8*32-1 downto 0);
   signal memio_rden : std_logic_vector(  32-1 downto 0);
   signal memio_wr   : std_logic_vector(8*32-1 downto 0);

   signal vga_memio_palette   : std_logic_vector(16*8-1 downto 0);
   signal vga_memio_pix_y_int : std_logic_vector( 2*8-1 downto 0);
   signal vga_memio_pix_x     : std_logic_vector( 2*8-1 downto 0);
   signal vga_memio_pix_y     : std_logic_vector( 2*8-1 downto 0);

   signal kbd_memio_data : std_logic_vector( 1*8-1 downto 0);

   signal irq_memio_mask   : std_logic_vector( 1*8-1 downto 0);
   signal irq_memio_status : std_logic_vector( 1*8-1 downto 0);
   signal irq_memio_clear  : std_logic;

   signal cpu_memio_latch : std_logic_vector( 1*8-1 downto 0);
   signal cpu_memio_cyc   : std_logic_vector( 4*8-1 downto 0);

   -- Interrupt controller
   signal ic_irq    : std_logic_vector(7 downto 0);
   signal cpu_irq   : std_logic;
   signal vga_irq   : std_logic;
   signal kbd_irq   : std_logic;
   signal timer_irq : std_logic := '0';

   signal kbd_debug : std_logic_vector(15 downto 0);
   signal eth_debug : std_logic_vector(15 downto 0);

begin

   --------------------------------------------------
   -- Divide input clock (100 MHz) by 2 and 4, to generate
   -- 50 MHz (for Ethernet) and 25 MHz (for VGA).
   -- The VGA clock should ideally be 25.175 MHz, but
   -- this is close enough.
   --------------------------------------------------

   p_clk_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         clk_cnt <= clk_cnt + 1;
      end if;
   end process p_clk_cnt;

   eth_clk <= clk_cnt(0);
   vga_clk <= clk_cnt(1);


   --------------------------------------------------
   -- Generate Reset
   --------------------------------------------------

   p_rst : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         rst <= not rstn_i;
      end if;
   end process p_rst;


   --------------------------------------------------
   -- Instantiate interrupt controller
   --------------------------------------------------

   i_ic : entity work.ic
   port map (
      clk_i   => vga_clk,
      irq_i   => ic_irq,    -- Eight independent interrupt sources
      irq_o   => cpu_irq,   -- Overall CPU interrupt

      mask_i     => irq_memio_mask,      -- IRQ mask
      stat_o     => irq_memio_status,    -- IRQ status
      stat_clr_i => irq_memio_clear      -- Reading from IRQ status
   );


   --------------------------------------------------
   -- Instantiate Timer
   --------------------------------------------------

   i_timer : entity work.timer
   generic map (
      G_TIMER_CNT => 250000    -- Generate interrupt every 0.01 seconds
   )
   port map (
      clk_i => vga_clk,
      irq_o => timer_irq
   );


   --------------------------------------------------
   -- Instantiate Waiter
   --------------------------------------------------

   i_waiter : entity work.waiter
   port map (
      clk_i  => vga_clk,
      inc_i  => sw_i, 
      wait_o => sys_wait
   );

   -- Generate wait signal for the CPU.
   cpu_wait <= mem_wait or sys_wait;


   --------------------------------------------------
   -- Control VGA debug overlay
   --------------------------------------------------

   vga_overlay_en <= not sw_i(7);


   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------

   i_cpu : entity work.cpu
   port map (
      clk_i         => vga_clk,
      wait_i        => cpu_wait,
      addr_o        => cpu_addr,
      rden_o        => cpu_rden,
      data_i        => mem_data,
      wren_o        => cpu_wren,
      data_o        => cpu_data,
      invalid_o     => led_o,
      debug_o       => cpu_debug,
      irq_i         => cpu_irq,
      nmi_i         => '0', -- Not used at the moment
      rst_i         => rst,
      memio_cyc_o   => cpu_memio_cyc,
      memio_latch_i => cpu_memio_latch
   );


   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------

   i_mem : entity work.mem
   generic map (
      G_ROM_SIZE   => 14, -- 16 Kbytes
      G_RAM_SIZE   => 15, -- 32 Kbytes
      G_CHAR_SIZE  => 13, -- 8 Kbytes
      G_COL_SIZE   => 13, -- 8 Kbytes
      G_MEMIO_SIZE =>  6, -- 64 bytes
      --
      G_ROM_MASK   => X"C000",
      G_RAM_MASK   => X"0000",
      G_CHAR_MASK  => X"8000",
      G_COL_MASK   => X"A000",
      G_MEMIO_MASK => X"7FC0",
      --
      G_ROM_FILE   => "../rom.txt",
      G_MEMIO_INIT => X"00000000000000000000000000000000" &
                      X"FFFCE3E0433C1E178C82803022110A00"
   )
   port map (
      clk_i    => vga_clk,
      --
      a_addr_i => cpu_addr,  -- Only select the relevant address bits
      a_data_o => mem_data,
      a_rden_i => cpu_rden,
      a_wren_i => cpu_wren,
      a_data_i => cpu_data,
      a_wait_o => mem_wait,
      --
      b_char_addr_i => char_addr,
      b_char_data_o => char_data,
      b_col_addr_i  => col_addr,
      b_col_data_o  => col_data,
      --
      b_memio_rd_i   => memio_rd,    -- To MEMIO
      b_memio_rden_o => memio_rden,  -- To MEMIO
      b_memio_wr_o   => memio_wr     -- From MEMIO
   );


   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
   generic map (
      G_FONT_FILE => G_FONT_FILE
   )
   port map (
      clk_i     => vga_clk,
      overlay_i => vga_overlay_en,
      digits_i  => vga_overlay,
      vga_hs_o  => vga_hs_o,
      vga_vs_o  => vga_vs_o,
      vga_col_o => vga_col_o,

      char_addr_o => char_addr,
      char_data_i => char_data,
      col_addr_o  => col_addr,
      col_data_i  => col_data,

      memio_palette_i   => vga_memio_palette,
      memio_pix_y_int_i => vga_memio_pix_y_int,
      memio_pix_x_o     => vga_memio_pix_x,
      memio_pix_y_o     => vga_memio_pix_y,
      irq_o             => vga_irq
   );


   ------------------------------
   -- Instantiate keyboard module
   ------------------------------

   inst_keyboard : entity work.keyboard
   port map (
      clk_i      => vga_clk,
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,

      data_o     => kbd_memio_data,
      irq_o      => kbd_irq,

      debug_o    => kbd_debug
   );


   ------------------------------
   -- Instantiate Ethernet module
   ------------------------------

   inst_ethernet : entity work.ethernet
   port map (
      eth_clk_i    => eth_clk,
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      eth_intn_i   => eth_intn_i,
      eth_mdio_io  => eth_mdio_io,
      eth_mdc_o    => eth_mdc_o,
      eth_rstn_o   => eth_rstn_o,
      eth_refclk_o => eth_refclk_o,
      eth_debug_o  => eth_debug
   );


   --------------------------------------------------
   -- Memory Mapped I/O
   -- This must match the mapping in prog/include/memorymap.h
   --------------------------------------------------

   -- 7FC0 - 7FCF : VGA_PALETTE
   -- 7FD0 - 7FD1 : VGA_PIX_Y_INT
   -- 7FD2        : CPU_CYC_LATCH
   -- 7FD3 - 7FDE : Not used
   -- 7FDF        : IRQ_MASK
   vga_memio_palette   <= memio_wr(15*8+7 downto  0*8);
   vga_memio_pix_y_int <= memio_wr(17*8+7 downto 16*8);
   cpu_memio_latch     <= memio_wr(18*8+7 downto 18*8);
   --                     memio_wr(30*8+7 downto 19*8);      -- Not used
   irq_memio_mask      <= memio_wr(31*8+7 downto 31*8);

   -- 7FE0 - 7FE1 : VGA_PIX_X
   -- 7FE2 - 7FE3 : VGA_PIX_Y
   -- 7FE4 - 7FE7 : CPU_CYC
   -- 7FE8        : KBD_DATA
   -- 7FE9 - 7FFE : Not used
   -- 7FFF        : IRQ_STATUS
   memio_rd( 1*8+7 downto  0*8) <= vga_memio_pix_x;
   memio_rd( 3*8+7 downto  2*8) <= vga_memio_pix_y;
   memio_rd( 7*8+7 downto  4*8) <= cpu_memio_cyc;
   memio_rd( 8*8+7 downto  8*8) <= kbd_memio_data;
   memio_rd(30*8+7 downto  9*8) <= (others => '0');   -- Not used
   memio_rd(31*8+7 downto 31*8) <= irq_memio_status;
   irq_memio_clear <= memio_rden(31);


   -------------------------
   -- Interrupt Sources
   -------------------------

   ic_irq(0) <= timer_irq;
   ic_irq(1) <= vga_irq;
   ic_irq(2) <= kbd_irq;
   ic_irq(7 downto 3) <= (others => '0');             -- Not used


   -------------------------
   -- VGA overlay
   -------------------------

   vga_overlay(175 downto   0) <= cpu_debug;
   vga_overlay(191 downto 176) <= kbd_debug;
   vga_overlay(207 downto 192) <= eth_debug;

end architecture Structural;

