library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can execute all instructions.
-- It additionally features a 80x60 character display.
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

      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture Structural of comp is

   -- Clock divider for VGA
   signal vga_cnt  : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk  : std_logic;

   -- Reset
   signal rst : std_logic := '1';

   -- Generate pause signal
   -- 25 bits corresponds to 25Mhz / 2^25 = 1 Hz approx.
   signal sys_wait_cnt  : std_logic_vector(24 downto 0) := (others => '0');
   signal sys_wait      : std_logic;

   -- VGA debug overlay
   signal overlay       : std_logic;

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector(7 downto 0);
   signal cpu_data  : std_logic_vector(7 downto 0);
   signal cpu_rden  : std_logic;
   signal cpu_wren  : std_logic;
   signal cpu_debug : std_logic_vector(175 downto 0);
   signal cpu_wait  : std_logic;
   signal mem_wait  : std_logic;

   -- Output from VGA block
   signal vga_hs    : std_logic;
   signal vga_vs    : std_logic;
   signal vga_col   : std_logic_vector(7 downto 0);

   -- Interface between VGA and Memory
   signal char_addr : std_logic_vector(12 downto 0);
   signal char_data : std_logic_vector( 7 downto 0);
   signal col_addr  : std_logic_vector(12 downto 0);
   signal col_data  : std_logic_vector( 7 downto 0);

   -- Memory Mapped I/O
   signal memio_rd   : std_logic_vector(63 downto 0);
   signal memio_rden : std_logic_vector( 7 downto 0);
   signal memio_wr   : std_logic_vector(63 downto 0);

   -- Interrupt controller
   signal ic_irq     : std_logic_vector(7 downto 0);
   signal cpu_irq    : std_logic;

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   p_vga_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_cnt <= vga_cnt + 1;
      end if;
   end process p_vga_cnt;

   vga_clk <= vga_cnt(1);

   
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
   -- Generate wait signal
   --------------------------------------------------

   p_sys_wait_cnt : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         sys_wait_cnt <= sys_wait_cnt + sw_i;
      end if;
   end process p_sys_wait_cnt;

   -- Check for wrap around of counter.
   sys_wait <= '0' when (sys_wait_cnt + sw_i) < sys_wait_cnt else not sw_i(7);

   -- Generate wait signal for the CPU.
   cpu_wait <= mem_wait or sys_wait;

   
   --------------------------------------------------
   -- Control VGA debug overlay
   --------------------------------------------------

   overlay <= not sw_i(7);


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
      rst_i     => rst
   );

   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   generic map (
      G_ROM_SIZE   => 11, -- 2 Kbytes
      G_RAM_SIZE   => 12, -- 4 Kbytes
      G_CHAR_SIZE  => 13, -- 8 Kbytes
      G_COL_SIZE   => 13, -- 8 Kbytes
      G_MEMIO_SIZE =>  4, -- 16 bytes 
      --
      G_ROM_MASK   => X"F800",
      G_RAM_MASK   => X"0000",
      G_CHAR_MASK  => X"8000",
      G_COL_MASK   => X"A000",
      G_MEMIO_MASK => X"7FF0",
      --
      G_FONT_FILE  => "font8x8.txt",
      G_ROM_FILE   => "mem/rom.txt"
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
   -- Instantiate interrupt controller
   --------------------------------------------------

   i_ic : entity work.ic
   port map (
      clk_i   => vga_clk,
      irq_i   => ic_irq,    -- Eight independent interrupt sources
      irq_o   => cpu_irq,   -- Overall CPU interrupt

      mask_i  => memio_wr(63 downto 56),     -- IRQ mask
      stat_o  => memio_rd(63 downto 56),     -- IRQ status

      stat_clr_i => memio_rden(7)            -- Reading from IRQ status
   );


   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
   port map (
      clk_i     => vga_clk,
      overlay_i => overlay,
      digits_i  => cpu_debug,
      vga_hs_o  => vga_hs,
      vga_vs_o  => vga_vs,
      vga_col_o => vga_col,

      char_addr_o => char_addr,
      char_data_i => char_data,
      col_addr_o  => col_addr,
      col_data_i  => col_data,

      memio_i => memio_wr(31 downto 0),   -- From MEMIO
      memio_o => memio_rd(31 downto 0),   -- To MEMIO
      irq_o => ic_irq(0)
   );


   -------------------------
   -- Instantiate PS2 module
   -------------------------

   inst_ps2 : entity work.ps2
   port map (
      clk_i      => vga_clk,
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,
      data_o     => memio_rd(55 downto 48),  -- KBD DATA
      irq_o      => ic_irq(1)
   );


   memio_rd(47 downto 32) <= (others => '0');
   ic_irq(7 downto 2)     <= (others => '0');


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

