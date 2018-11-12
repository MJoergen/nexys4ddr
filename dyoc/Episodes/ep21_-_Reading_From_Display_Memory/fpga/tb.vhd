library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb is
end tb;

architecture Structural of tb is

   -- Clock
   signal clk  : std_logic;

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector(7 downto 0);
   signal cpu_data  : std_logic_vector(7 downto 0);
   signal cpu_wren  : std_logic;
   signal cpu_rden  : std_logic;
   signal rst       : std_logic;

   -- Debug output
   signal cpu_led   : std_logic_vector(7 downto 0);
   signal cpu_debug : std_logic_vector(175 downto 0);

   -- Generate pause signal
   signal mem_wait_cnt : std_logic_vector(0 downto 0) := (others => '0');
   signal mem_wait     : std_logic;

   -- Connected to VGA (not used)
   signal char_addr : std_logic_vector(12 downto 0) := (others => '0');
   signal char_data : std_logic_vector( 7 downto 0);
   signal col_addr  : std_logic_vector(12 downto 0) := (others => '0');
   signal col_data  : std_logic_vector( 7 downto 0);

begin
   
   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   -- Generate clock
   clk_gen : process
   begin
      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process clk_gen;


   --------------------------------------------------
   -- Generate Reset
   --------------------------------------------------

   rst <= '1', '0' after 15 ns;


   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   i_cpu : entity work.cpu
   port map (
      clk_i     => clk,
      wait_i    => mem_wait,
      addr_o    => cpu_addr,
      rden_o    => cpu_rden,
      data_i    => mem_data,
      wren_o    => cpu_wren,
      data_o    => cpu_data,
      irq_i     => '0',
      nmi_i     => '0',
      rst_i     => rst,
      invalid_o => cpu_led,
      debug_o   => cpu_debug
   );

   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   generic map (
      G_ROM_SIZE  => 14, -- 16 Kbytes
      G_RAM_SIZE  => 15, -- 32 Kbytes
      G_CHAR_SIZE => 13, -- 8 Kbytes
      G_COL_SIZE  => 13, -- 8 Kbytes
      --
      G_ROM_MASK  => X"C000",
      G_RAM_MASK  => X"0000",
      G_CHAR_MASK => X"8000",
      G_COL_MASK  => X"A000",
      --
      G_ROM_FILE  => "../rom.txt"
   )
   port map (
      clk_i         => clk,
      a_addr_i      => cpu_addr,  -- Only select the relevant address bits
      a_rden_i      => cpu_rden,
      a_data_o      => mem_data,
      a_wren_i      => cpu_wren,
      a_data_i      => cpu_data,
      a_wait_o      => mem_wait,
      b_char_addr_i => char_addr,
      b_char_data_o => char_data,
      b_col_addr_i  => col_addr,
      b_col_data_o  => col_data
   );

end architecture Structural;

