-----------------------------------------------------------------
-- Description:
-- This is the top level entity of the AM (Ask-Michael) computer.
-- The computer is built around a (partial) implementation of
-- the M68000 processor.
-- This computer is designed to run on both a BASYS2 board and 
-- a NEXYS4DDR board, both from Digilent.
--
-- The computer consists of the following parts:
-- * MC68000 CPU
-- * Memory
-- * VGA driver
-- * USB keyboard input
--
-- All peripherals are memory-mapped according to the following
-- address layout:
-- 0x000000 - 0x000FFF : Memory (4 kB)
-- 0x010000 - 0x010FFF : VGA driver (4 kB)
-- 0x020000 - 0x020000 : USB Keyboard input (1 byte)
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity am is

   generic (
      G_SIMULATION : string := ""   -- Set to "yes" during simulation
   );
   port (
      -- Extyernal crystal Clock.
      -- On the BASYS2 board, the clock is 25.000 MHz
      -- On the NEXYS4DDR board, the clock is 100.000 MHz
      clk_i     : in  std_logic;

      -- Reset.
      -- This is only present on the NEXYS4DDR board.
      rstn_i    : in  std_logic;  -- Asserted low

      -- Input switches and push buttons
      sw_i      : in  std_logic_vector (7 downto 0);
      btn_i     : in  std_logic_vector (3 downto 0);

     -- Output to VGA monitor
      -- On the BASYS2 board, only 8 bits VGA colors are used.
      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)
  );

end am;

architecture Structural of am is
   
   ---------------------------------------------------------------
   -- Clock domains:
   -- This design uses two clock domains: One for the VGA
   -- (25 MHz gives a 640x480 pixel screen at 60 Hz refresh rate),
   -- and another for the rest of the system. This is so that
   -- the CPU can be clocked at a much higher frequency than the
   -- 25 MHz used by the VGA.
   ---------------------------------------------------------------

   signal clk_vga : std_logic;
   signal rst_vga : std_logic := '1';  -- Asserted high.
   
   signal clk_cpu : std_logic;
   signal rst_cpu : std_logic := '1';  -- Asserted high.


   -----------------------------------
   -- Signals driven by the CPU module
   -----------------------------------
   
   -- Address bus
   signal cpu_addr    : std_logic_vector(23 downto 0);

   -- Data bus (bidirectional)
   signal cpu_data    : std_logic_vector(15 downto 0);

   -- Asynchronous bus control
   signal cpu_as      : std_logic;   -- Address Strobe
   signal cpu_rw      : std_logic;   -- Read Write
   signal cpu_uds     : std_logic;   -- Upper Data Strobe
   signal cpu_lds     : std_logic;   -- Lower Data Strobe
   signal cpu_dtack   : std_logic;   -- Data Transfer Acknowledge

   -- Bus arbitration control
   signal cpu_br      : std_logic;   -- Bus Request
   signal cpu_bg      : std_logic;   -- Bus Grant
   signal cpu_bgack   : std_logic;   -- Bus Grant Acknowledge

begin

   ---------------------------------------------------------------
   -- Generate clocks. Speed up simulation by skipping the MMCME2_ADV
   ---------------------------------------------------------------

   gen_simulation: if G_SIMULATION = "yes"  generate
      clk_vga <= clk_i;
   end generate gen_simulation;

   gen_no_simulation: if G_SIMULATION /= "yes"  generate
      -- This is only needed on the NEXYS4DDR board, because
      -- the BASYS2 board already has a 25 MHz clock signal.
      inst_clk_wiz_vga : entity work.clk_wiz_vga
      port map
      (
         clk_in1  => clk_i,   -- 100 MHz
         clk_out1 => clk_vga  -- 25 MHz
      );
   end generate gen_no_simulation;

   -- TBD: The CPU clock should be derived from an MMCME2_ADV, to
   -- increase the clock speed of the CPU.
   clk_cpu <= clk_i;


   ------------------------------
   -- Generate synchronous resets
   ------------------------------

   p_rst_cpu : process (clk_cpu)
   begin
      if rising_edge(clk_cpu) then
         rst_cpu <= not rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_rst_cpu;

   p_rst_vga : process (clk_vga)
   begin
      if rising_edge(clk_vga) then
         rst_vga <= not rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_rst_vga;
   

   ------------------------------
   -- Instantiate CPU module
   ------------------------------

   inst_cpu_module : entity work.cpu_module
   port map (
      clk_i => clk_cpu,
      rst_i => rst_cpu,

      addr_o  => cpu_addr,
      data_io => cpu_data,
      as_o    => cpu_as,
      rw_o    => cpu_rw,
      uds_o   => cpu_uds,
      lds_o   => cpu_lds,
      dtack_i => cpu_dtack,
      br_i    => cpu_br,
      bg_o    => cpu_bg,
      bgack_i => cpu_bgack
   );



   ------------------------------
   -- Instantiate VGA module
   ------------------------------

   inst_vga_module : entity work.vga_module
   generic map (
                  G_CHAR_FILE  => ""
               )
   port map (
      vga_clk_i => clk_vga,
      vga_rst_i => rst_vga,
      cpu_clk_i => clk_cpu,
      cpu_rst_i => rst_cpu,
      hs_o  => vga_hs_o,
      vs_o  => vga_vs_o,
      col_o => vga_col_o,

      -- Configuration @ cpu_clk_i
      addr_i => (others => '0'),
      cs_i   => '0',
      data_o => open,     -- Currently not connected.
      wren_i => '0',
      data_i => (others => '0')
   );

end Structural;

