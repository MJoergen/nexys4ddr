library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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
   port (
      clk_i        : in  std_logic;                      -- 100 MHz

      -- CPU reset (push button). Active low.
      rstn_i       : in  std_logic;

      -- Input switches
      sw_i         : in  std_logic_vector(7 downto 0);

      -- Output LED's
      led_o        : out std_logic_vector(7 downto 0);

      -- Keyboard / mouse
      ps2_clk_i    : in  std_logic;
      ps2_data_i   : in  std_logic;

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
      vga_hs_o     : out std_logic;
      vga_vs_o     : out std_logic;
      vga_col_o    : out std_logic_vector(7 downto 0)    -- RRRGGGBB
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
   signal sys_wait      : std_logic;

   -- VGA debug overlay
   signal vga_overlay_en : std_logic;
   signal vga_overlay    : std_logic_vector(191 downto 0);

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

   -- Interface between Ethernet and Memory
   signal eth_user_data : std_logic_vector(64*8-1 downto 0);

   -- Memory Mapped I/O
   signal memio_rd   : std_logic_vector(8*128-1 downto 0);
   signal memio_rden : std_logic_vector(  128-1 downto 0);
   signal memio_wr   : std_logic_vector(8*128-1 downto 0);

   signal vga_memio_wr : std_logic_vector(18*8-1 downto 0);
   signal irq_memio_wr : std_logic_vector( 1*8-1 downto 0);
   signal cpu_memio_wr : std_logic_vector( 1*8-1 downto 0);

   signal vga_memio_rd : std_logic_vector( 4*8-1 downto 0);
   signal cpu_memio_rd : std_logic_vector( 4*8-1 downto 0);
   signal kbd_memio_rd : std_logic_vector( 1*8-1 downto 0);
   signal irq_memio_rd : std_logic_vector( 1*8-1 downto 0);
   signal irq_memio_rden : std_logic;

   -- Interrupt controller
   signal ic_irq    : std_logic_vector(7 downto 0);
   signal cpu_irq   : std_logic;
   signal vga_irq   : std_logic;
   signal kbd_irq   : std_logic;
   signal timer_irq : std_logic := '0';

   signal kbd_debug : std_logic_vector(15 downto 0);

begin

   --------------------------------------------------
   -- Divide input clock (100 MHz) by 2 and 4, to generate
   -- 50 MHz (for Ethernet) and 25 MHz (for VGA).
   -- The VGA clock should ideally be 25.175 MHz, but
   -- this is close enough.
   --------------------------------------------------

   p_vga_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         clk_cnt <= clk_cnt + 1;
      end if;
   end process p_vga_cnt;

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
   -- Instantiate Waiter
   --------------------------------------------------

   i_waiter : entity work.waiter
   port map (
      clk_i   => vga_clk,
      inc_i   => sw_i,
      wait_o  => sys_Wait
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
      clk_i     => vga_clk,
      wait_i    => cpu_wait,
      addr_o    => cpu_addr,
      rden_o    => cpu_rden,
      data_i    => mem_data,
      wren_o    => cpu_wren,
      data_o    => cpu_data,
      invalid_o => led_o,
      debug_o   => cpu_debug,
      irq_i     => cpu_irq,
      nmi_i     => '0', -- Not used at the moment
      rst_i     => rst,
      memio_o   => cpu_memio_rd,
      memio_i   => cpu_memio_wr
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
      G_MEMIO_SIZE =>  8, -- 256 bytes
      --
      G_ROM_MASK   => X"C000",
      G_RAM_MASK   => X"0000",
      G_CHAR_MASK  => X"8000",
      G_COL_MASK   => X"A000",
      G_MEMIO_MASK => X"7F00",
      --
      G_FONT_FILE  => "font8x8.txt",
      G_ROM_FILE   => "../rom.txt",
      --
      G_MEMIO_INIT => X"00000000000000000000000000000000" &
                      X"00000000000000000000000000000000" &
                      X"00000000000000000000000000000000" &
                      X"00000000000000000000000000000000" &
                      X"00000000000000000000000000000000" &
                      X"00000000000000000000000000000000" &
                      X"00000000000000000000000000000000" &
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
      b_eth_wren_i   => eth_wren,
      b_eth_addr_i   => eth_addr,
      b_eth_data_i   => eth_data,
      --
      b_memio_rd_i   => memio_rd,    -- To MEMIO
      b_memio_rden_o => memio_rden,  -- To MEMIO
      b_memio_wr_o   => memio_wr     -- From MEMIO
   );


   --------------------------------------------------
   -- Instantiate interrupt controller
   --------------------------------------------------

   i_ic : entity work.ic
   port map (
      clk_i   => vga_clk,
      irq_i   => ic_irq,    -- Eight independent interrupt sources
      irq_o   => cpu_irq,   -- Overall CPU interrupt

      mask_i     => irq_memio_wr,      -- IRQ mask
      stat_o     => irq_memio_rd,      -- IRQ status
      stat_clr_i => irq_memio_rden     -- Reading from IRQ status
   );


   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
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

      memio_i => vga_memio_wr,
      memio_o => vga_memio_rd,
      irq_o   => vga_irq
   );


   ------------------------------
   -- Instantiate keyboard module
   ------------------------------

   inst_keyboard : entity work.keyboard
   port map (
      clk_i      => vga_clk,
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,

      data_o     => kbd_memio_rd,
      irq_o      => kbd_irq,

      debug_o    => kbd_debug
   );


   ------------------------------
   -- Instantiate Ethernet modul
   ------------------------------

   inst_ethernet : entity work.ethernet
   port map (
      clk_i        => eth_clk,
      user_data_o  => eth_user_data,
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      eth_intn_i   => eth_intn_i,
      eth_mdio_io  => eth_mdio_io,
      eth_mdc_o    => eth_mdc_o,
      eth_rstn_o   => eth_rstn_o,
      eth_refclk_o => eth_refclk_o
   );


   --------------------------------------------------
   -- Clock domain crossing
   --------------------------------------------------

--   xpm_cdc_array_single_inst: XPM_CDC_ARRAY_SINGLE
--   generic map (
--                  DEST_SYNC_FF   => 2,
--                  SIM_ASSERT_CHK => 1,
--                  SRC_INPUT_REG  => 0, -- integer; 0=do not register input, 1=register input
--                  WIDTH          => 32*16 -- integer; range: 1-1024
--               )
--   port map (
--               src_clk  => '0',   -- Not used
--               src_in   => eth_smi_data,
--               dest_clk => vga_clk,
--               dest_out => smi_memio_rd
--            );

   --------------------------------------------------
   -- Generate timer interrupt
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
   -- Memory Mapped I/O
   -- This must match the mapping in prog/include/memorymap.h
   --------------------------------------------------

   -- 7F00 - 7F0F : VGA_PALETTE
   -- 7F10 - 7F11 : VGA_PIX_Y_INT
   -- 7F12 - 7F1E : Not used
   -- 7F1F        : IRQ_MASK
   -- 7F20 - 7F7F : Not used
   vga_memio_wr <= memio_wr( 17*8+7 downto 0*8);
   cpu_memio_wr <= memio_wr( 18*8+7 downto 18*8);
   --              memio_wr( 30*8+7 downto 19*8);      -- Not used
   irq_memio_wr <= memio_wr( 31*8+7 downto 31*8);
   --              memio_wr(127*8+7 downto 32*8);      -- Not used

   -- 7F80 - 7F81 : VGA_PIX_X
   -- 7F82 - 7F83 : VGA_PIX_Y
   -- 7F84 - 7F87 : CPU_CYC
   -- 7F88        : KBD_DATA
   -- 7F89 - 7F9E : Not used
   -- 7F9F        : IRQ_STATUS
   -- 7FA0 - 7FBF : Not used
   -- 7FC0 - 7FFF : Ethernet SMI
   memio_rd(  3*8+7 downto  0*8) <= vga_memio_rd;
   memio_rd(  7*8+7 downto  4*8) <= cpu_memio_rd;
   memio_rd(  8*8+7 downto  8*8) <= kbd_memio_rd;
   memio_rd( 30*8+7 downto  9*8) <= (others => '0');   -- Not used
   memio_rd( 31*8+7 downto 31*8) <= irq_memio_rd;
   memio_rd( 63*8+7 downto 32*8) <= (others => '0');   -- Not used
   memio_rd(127*8+7 downto 64*8) <= eth_user_data;
   irq_memio_rden <= memio_rden(31);


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

end architecture Structural;

