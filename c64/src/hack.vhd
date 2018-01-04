library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity hack is

   generic (
      G_SIMULATION : string;
      G_CHAR_FILE : string := "charset1.bin.txt"
   );
   port (
      -- Clock
      clk_i     : in  std_logic;  -- 100 MHz

      -- Reset
      rstn_i    : in  std_logic;  -- Asserted low

      -- Input switches and push buttons
      sw_i      : in  std_logic_vector (15 downto 0);
      btn_i     : in  std_logic_vector ( 4 downto 0);

     -- Output to VGA monitor
      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)
  );

end hack;

architecture Structural of hack is

   signal clk_vga : std_logic;
   signal rst_vga : std_logic := '1';  -- Asserted high.
   
   signal clk_cpu : std_logic;
   signal rst_cpu : std_logic := '1';  -- Asserted high.
   
   signal cpu_addr   : std_logic_vector(8 downto 0);
   signal cpu_cs_vga : std_logic;
   signal vga_data   : std_logic_vector(7 downto 0);
   signal cpu_wren   : std_logic;
   signal cpu_data   : std_logic_vector(7 downto 0);

begin

   ------------------------------
   -- Generate clocks. Speed up simulation by skipping the MMCME2_ADV
   ------------------------------

   gen_simulation: if G_SIMULATION = "yes"  generate
      clk_vga <= clk_i;
   end generate gen_simulation;

   gen_no_simulation: if G_SIMULATION /= "yes"  generate
      inst_clk_wiz_vga : entity work.clk_wiz_vga
      port map
      (
         clk_in1  => clk_i,   -- 100 MHz
         clk_out1 => clk_vga  -- 25 MHz
      );
   end generate gen_no_simulation;

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
   -- Instantiate VGA module
   ------------------------------

   inst_vga_module : entity work.vga_module
   generic map (
                  G_CHAR_FILE  => G_CHAR_FILE 
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
      addr_i => cpu_addr,
      cs_i   => cpu_cs_vga,
      data_o => vga_data,     -- Currently not connected.
      wren_i => cpu_wren,
      data_i => cpu_data
   );


   ------------------------------
   -- Instantiate Configuration
   ------------------------------

   inst_config : entity work.config
   generic map (
      G_SIMULATION => G_SIMULATION
   )
   port map (
      clk_i  => clk_cpu,
      rst_i  => rst_cpu,
      addr_o => cpu_addr,
      cs_o   => cpu_cs_vga,
      wren_o => cpu_wren,
      data_o => cpu_data
   );

end Structural;

