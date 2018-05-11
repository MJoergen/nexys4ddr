library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can execute a single instruction (LDA #)
-- from the memory.
-- Additionally, the CPU registers are shown on the VGA display.
-- The registers shown are:
-- * Data read from memory (1 byte)
-- * 'A' register (1 byte)
-- * Program Counter (2 bytes)
-- * Instruction Register (1 byte)
-- * Instruction Cycle Counter (1 byte).
--
-- The speed of the execution is controlled by the slide switches.

entity comp is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture Structural of comp is

   -- Clock divider for VGA
   signal vga_cnt  : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk  : std_logic;

   -- Generate pause signal
   -- 25 bits corresponds to 25Mhz / 2^25 = 1 Hz approx.
   signal mem_wait_cnt  : std_logic_vector(24 downto 0) := (others => '0');
   signal mem_wait      : std_logic;

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector(7 downto 0);
   signal cpu_data  : std_logic_vector(7 downto 0);
   signal cpu_wren  : std_logic;
   signal cpu_debug : std_logic_vector(47 downto 0);

   -- Output from VGA block
   signal vga_hs    : std_logic;
   signal vga_vs    : std_logic;
   signal vga_col   : std_logic_vector(7 downto 0);

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_cnt <= vga_cnt + 1;
      end if;
   end process;

   vga_clk <= vga_cnt(1);

   
   --------------------------------------------------
   -- Generate wait signal
   --------------------------------------------------

   process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         mem_wait_cnt <= mem_wait_cnt + sw_i;
      end if;
   end process;

   -- Check for wrap around of counter.
   mem_wait <= '0' when (mem_wait_cnt + sw_i) < mem_wait_cnt else '1';

   
   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   i_cpu : entity work.cpu
   port map (
      clk_i   => vga_clk,
      wait_i  => mem_wait,
      addr_o  => cpu_addr,
      data_i  => mem_data,
      wren_o  => cpu_wren,
      data_o  => cpu_data,
      debug_o => cpu_debug
   );

   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   generic map (
      G_ADDR_BITS => 4  -- 16 bytes
   )
   port map (
      clk_i  => vga_clk,
      addr_i => cpu_addr(3 downto 0),  -- Only select the relevant address bits
      data_o => mem_data,
      wren_i => cpu_wren,
      data_i => cpu_data
   );


   --------------------------------------------------
   -- Generate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
   port map (
      clk_i     => vga_clk,
      digits_i  => cpu_debug,
      vga_hs_o  => vga_hs,
      vga_vs_o  => vga_vs,
      vga_col_o => vga_col
   );


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

