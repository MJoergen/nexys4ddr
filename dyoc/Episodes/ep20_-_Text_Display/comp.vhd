library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can execute all instructions.

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

architecture Structural of comp is

   -- Clock divider for VGA
   signal vga_cnt  : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk  : std_logic;

   -- Reset
   signal rst : std_logic := '1';

   -- Generate pause signal
   -- 25 bits corresponds to 25Mhz / 2^25 = 1 Hz approx.
   signal mem_wait_cnt  : std_logic_vector(24 downto 0) := (others => '0');
   signal mem_wait      : std_logic;

   -- VGA debug overlay
   signal overlay       : std_logic;

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector(7 downto 0);
   signal cpu_data  : std_logic_vector(7 downto 0);
   signal cpu_wren  : std_logic;
   signal cpu_debug : std_logic_vector(175 downto 0);

   -- Output from VGA block
   signal vga_hs    : std_logic;
   signal vga_vs    : std_logic;
   signal vga_col   : std_logic_vector(7 downto 0);

   signal char_addr : std_logic_vector(12 downto 0);
   signal char_data : std_logic_vector( 7 downto 0);
   signal col_addr  : std_logic_vector(12 downto 0);
   signal col_data  : std_logic_vector( 7 downto 0);

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

   p_mem_wait_cnt : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         mem_wait_cnt <= mem_wait_cnt + sw_i;
      end if;
   end process p_mem_wait_cnt;

   -- Check for wrap around of counter.
   mem_wait <= '0' when (mem_wait_cnt + sw_i) < mem_wait_cnt else not sw_i(7);

   
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
      wait_i    => mem_wait,
      addr_o    => cpu_addr,
      data_i    => mem_data,
      wren_o    => cpu_wren,
      data_o    => cpu_data,
      invalid_o => led_o,
      debug_o   => cpu_debug,
      irq_i     => '0', -- Not used at the moment
      nmi_i     => '0', -- Not used at the moment
      rst_i     => rst
   );

   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   generic map (
      G_ROM_SIZE  => 11, -- 2 Kbytes
      G_RAM_SIZE  => 12, -- 4 Kbytes
      G_CHAR_SIZE => 13, -- 8 Kbytes
      G_COL_SIZE  => 13, -- 8 Kbytes
      --
      G_ROM_MASK  => X"F800",
      G_RAM_MASK  => X"0000",
      G_CHAR_MASK => X"8000",
      G_COL_MASK  => X"A000",
      --
      G_FONT_FILE => "font8x8.txt",
      G_ROM_FILE  => "mem/rom.txt"
   )
   port map (
      clk_i         => vga_clk,
      a_addr_i      => cpu_addr,  -- Only select the relevant address bits
      a_data_o      => mem_data,
      a_wren_i      => cpu_wren,
      a_data_i      => cpu_data,
      b_char_addr_i => char_addr,
      b_char_data_o => char_data,
      b_col_addr_i  => col_addr,
      b_col_data_o  => col_data
   );


   --------------------------------------------------
   -- Generate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
   port map (
      clk_i       => vga_clk,
      overlay_i   => overlay,
      digits_i    => cpu_debug,
      char_addr_o => char_addr,
      char_data_i => char_data,
      col_addr_o  => col_addr,
      col_data_i  => col_data,
      vga_hs_o    => vga_hs,
      vga_vs_o    => vga_vs,
      vga_col_o   => vga_col
   );


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

