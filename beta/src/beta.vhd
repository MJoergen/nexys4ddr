library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-------------------------------------------------------
-- This is the top-level entity for the Beta computer.
-- Currently, the only I/O is the VGA monitor used to
-- display the internal CPU registers etc.
-- The buttons and switches are to control the clock 
-- and singlestepping, as well as IRQ.
-- Later, perhaps more I/O will be added, e.g. an
-- Ethernet port.
-------------------------------------------------------

entity beta is
   port (
      -- Clock
      clk_i       : in  std_logic;                    -- 100 MHz
      rstn_i      : in  std_logic;                    -- Active low.

      -- VGA port
      vga_hs_o    : out std_logic; 
      vga_vs_o    : out std_logic;
      vga_red_o   : out std_logic_vector(3 downto 0); 
      vga_green_o : out std_logic_vector(3 downto 0); 
      vga_blue_o  : out std_logic_vector(3 downto 0);

      -- Switches
      sw_i        : in  std_logic_vector(15 downto 0);

      -- Buttons
      btnc_i      : in  std_logic;                       -- Used for singlestepping
      btnl_i      : in  std_logic                        -- IRQ
   );
end beta;

architecture Structural of beta is

   -- Signals driven by the Clock modules
   signal clk_cpu    : std_logic;
   signal clk_vga    : std_logic;
   signal clk_cpu_en : std_logic;
   signal clk_count  : std_logic_vector(7 downto 0);

   -- Signals driven by the CPU module
   signal cpu_ia   : std_logic_vector(  31 downto 0);
   signal cpu_ma   : std_logic_vector(  31 downto 0);
   signal cpu_moe  : std_logic;
   signal cpu_wr   : std_logic;
   signal cpu_mwd  : std_logic_vector(  31 downto 0);
   signal cpu_regs : std_logic_vector(1023 downto 0);

   -- Signals driven by the memory modules
   signal imem_id  : std_logic_vector(31 downto 0);
   signal dmem_mrd : std_logic_vector(31 downto 0);

begin

   -- This design uses two different clocks:
   -- vga_clk (108 MHz) drives the VGA output.
   -- cpu_clk (10 MHz) drives the CPU design.

   -- Generate VGA clock
   inst_clk_wiz_vga : entity work.clk_wiz_vga
   port map
   (
      clk_in1  => clk_i,   -- 100 MHz
      clk_out1 => clk_vga  -- 108 MHz
   );

   -- Generate CPU clock
   inst_clk_wiz_cpu : entity work.clk_wiz_cpu
   port map
   (
      clk_in1  => clk_i,   -- 100 MHz
      clk_out1 => clk_cpu  --  10 MHz
   );

   -- Clock enable, controlled by button and by timer.
   i_clken : entity work.clken
   port map (
      clk_cpu_i => clk_cpu,
      sw_i      => sw_i,
      btnc_i    => btnc_i,
      clk_en_o  => clk_cpu_en,
      count_o   => clk_count
   );


   -- Instantiate the VGA module controlling the VGA display port.
   i_vga_module : entity work.vga_module
   port map
   (
      clk_i     => clk_vga,
      hs_o      => vga_hs_o,
      vs_o      => vga_vs_o,
      red_o     => vga_red_o,
      green_o   => vga_green_o,
      blue_o    => vga_blue_o,
      regs_i    => cpu_regs,        -- CPU registers
      ia_i      => cpu_ia,          -- Instruction Address
      count_i   => clk_count,       -- Clock counter
      imem_id_i => imem_id,         -- Instruction Data
      irq_i     => btnl_i
   );

   -- Instantiate the CPU module
   i_cpu_module : entity work.cpu_module
   port map
   (
      clk_i   => clk_cpu,
      clken_i => clk_cpu_en,
      rstn_i  => rstn_i,
      irq_i   => btnl_i,
      ia_o    => cpu_ia,
      id_i    => imem_id,
      ma_o    => cpu_ma,
      moe_o   => cpu_moe,
      mrd_i   => dmem_mrd,
      wr_o    => cpu_wr,
      mwd_o   => cpu_mwd,
      regs_o  => cpu_regs
   );

   -- Instantiate Memory (Instruction and Data)
   i_mem : entity work.mem
   port map (
      clk_i   => clk_cpu,
      clken_i => clk_cpu_en,
      ma_i    => cpu_ma,
      moe_i   => cpu_moe,
      mrd_o   => dmem_mrd,
      wr_i    => cpu_wr,
      mwd_i   => cpu_mwd,
      ia_i    => cpu_ia,
      id_o    => imem_id
   );
   

end Structural;

