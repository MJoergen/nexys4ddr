library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the MAIN module. This contains the memory and the CPU.

entity main is
   generic (
      G_TIMER_CNT     : integer;
      G_ROM_INIT_FILE : string;
      G_OVERLAY_BITS  : integer
   );
   port (
      main_clk_i         : in  std_logic;
      main_rst_i         : in  std_logic;
      main_wait_i        : in  std_logic;
      main_vga_irq_i     : in  std_logic;
      main_kbd_irq_i     : in  std_logic;
      main_led_o         : out std_logic_vector(7 downto 0);
      main_overlay_o     : out std_logic_vector(G_OVERLAY_BITS-1 downto 0);
      main_memio_wr_o    : out std_logic_vector(8*32-1 downto 0);
      main_memio_rd_i    : in  std_logic_vector(8*32-1 downto 0);
      main_memio_clear_i : in  std_logic_vector(  32-1 downto 0);
      main_eth_wr_en_i   : in  std_logic;
      main_eth_wr_addr_i : in  std_logic_vector( 15 downto 0);
      main_eth_wr_data_i : in  std_logic_vector(  7 downto 0);
      main_eth_rd_en_i   : in  std_logic;
      main_eth_rd_addr_i : in  std_logic_vector( 15 downto 0);
      main_eth_rd_data_o : out std_logic_vector(  7 downto 0);
      --
      vga_clk_i          : in  std_logic;
      vga_char_addr_i    : in  std_logic_vector(12 downto 0);
      vga_char_data_o    : out std_logic_vector( 7 downto 0);
      vga_col_addr_i     : in  std_logic_vector(12 downto 0);
      vga_col_data_o     : out std_logic_vector( 7 downto 0)
   );
end main;

architecture structural of main is

   -- Data Path signals
   signal main_cpu_addr    : std_logic_vector(15 downto 0);
   signal main_mem_data    : std_logic_vector(7 downto 0);
   signal main_cpu_rden    : std_logic;
   signal main_cpu_data    : std_logic_vector(7 downto 0);
   signal main_cpu_wren    : std_logic;
   signal main_cpu_wait    : std_logic;
   signal main_mem_wait    : std_logic;

   -- Interrupt controller
   signal main_irq_mask    : std_logic_vector(7 downto 0);
   signal main_irq_status  : std_logic_vector(7 downto 0);
   signal main_irq_clear   : std_logic;

   signal main_irq_src     : std_logic_vector(7 downto 0);
   signal main_irq_cpu     : std_logic;
   signal main_timer_irq   : std_logic;

   signal main_memio_wr    : std_logic_vector(8*32-1 downto 0);
   signal main_memio_rd    : std_logic_vector(8*32-1 downto 0);
   signal main_memio_rden  : std_logic_vector(  32-1 downto 0);

begin

   main_cpu_wait <= main_wait_i or main_mem_wait;

   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   cpu_inst : entity work.cpu
   generic map (
      G_OVERLAY_BITS => G_OVERLAY_BITS 
   )
   port map (
      clk_i     => main_clk_i,
      rst_i     => main_rst_i,
      nmi_i     => '0',
      irq_i     => main_irq_cpu,
      wait_i    => main_cpu_wait,
      addr_o    => main_cpu_addr,
      data_i    => main_mem_data,
      wren_o    => main_cpu_wren,
      rden_o    => main_cpu_rden,
      data_o    => main_cpu_data,
      invalid_o => main_led_o,
      overlay_o => main_overlay_o
   ); -- cpu_inst


   --------------------------------------------------
   -- Instantiate Memory module
   --------------------------------------------------
   
   mem_inst : entity work.mem
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
      G_ROM_FILE   => G_ROM_INIT_FILE,
      G_MEMIO_INIT => X"00000000000000000000000000000000" &
                      X"FFFCE3E0433C1E178C82803022110A00"
   )
   port map (
      a_clk_i          => main_clk_i,
      a_cpu_addr_i     => main_cpu_addr,
      a_cpu_rden_i     => main_cpu_rden,
      a_cpu_data_o     => main_mem_data,
      a_cpu_wren_i     => main_cpu_wren,
      a_cpu_data_i     => main_cpu_data,
      a_cpu_wait_o     => main_mem_wait,
      a_memio_wr_o     => main_memio_wr,
      a_memio_rd_i     => main_memio_rd,
      a_memio_rden_o   => main_memio_rden,
      a_memio_clear_i  => main_memio_clear_i,
      a_eth_wr_en_i    => main_eth_wr_en_i,
      a_eth_wr_addr_i  => main_eth_wr_addr_i,
      a_eth_wr_data_i  => main_eth_wr_data_i,
      a_eth_rd_en_i    => main_eth_rd_en_i,
      a_eth_rd_addr_i  => main_eth_rd_addr_i,
      a_eth_rd_data_o  => main_eth_rd_data_o,
      --
      b_clk_i          => vga_clk_i,
      b_char_addr_i    => vga_char_addr_i,
      b_char_data_o    => vga_char_data_o,
      b_col_addr_i     => vga_col_addr_i,
      b_col_data_o     => vga_col_data_o
   ); -- mem_inst

   main_memio_wr_o <= main_memio_wr;
   main_memio_rd(30*8+7 downto 0)    <= main_memio_rd_i(30*8+7 downto 0);
   main_memio_rd(31*8+7 downto 31*8) <= main_irq_status;
   main_irq_mask  <= main_memio_wr(31*8+7 downto 31*8);
   main_irq_clear <= main_memio_rden(31);


   --------------------------------------------------
   -- Instantiate interrupt controller
   --------------------------------------------------

   ic_inst : entity work.ic
   port map (
      clk_i      => main_clk_i,
      irq_i      => main_irq_src,     -- Eight independent interrupt sources
      irq_o      => main_irq_cpu,     -- Overall CPU interrupt
      mask_i     => main_irq_mask,    -- IRQ mask
      stat_o     => main_irq_status,  -- IRQ status
      stat_clr_i => main_irq_clear    -- Reading from IRQ status
   ); -- ic_inst


   -------------------------
   -- Interrupt Sources
   -------------------------

   main_irq_src(0) <= main_timer_irq;
   main_irq_src(1) <= main_vga_irq_i;
   main_irq_src(2) <= main_kbd_irq_i;
   main_irq_src(7 downto 3) <= (others => '0');             -- Not used


   --------------------------------------------------
   -- Instantiate Timer
   --------------------------------------------------

   timer_inst : entity work.timer
   generic map (
      G_TIMER_CNT => G_TIMER_CNT
   )
   port map (
      clk_i => main_clk_i,
      irq_o => main_timer_irq
   ); -- timer_inst

end architecture structural;

