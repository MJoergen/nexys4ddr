library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level instance of this "computer".
-- It consists of four blocks:
-- 1) The CPU controlling everything
-- 2) The ROM
-- 3) The VGA module (memory mapped)
-- 4) The RAM
-- 
-- The ROM, VGA, and RAM all respond upon read on the falling clock edge. This
-- "imitates" an asynchronous memory interface.

entity hack is

   generic (
      G_ROM_SIZE   : integer := 10;   -- Number of bits in ROM address
      G_RAM_SIZE   : integer := 10;   -- Number of bits in RAM address
      G_SIMULATION : boolean := false;
      G_ROM_FILE   : string := "rom.txt";
      G_RAM_FILE   : string := "ram.txt";
      G_CHAR_FILE  : string := "ProggyClean.txt"
   );
   port (
      -- Clock
      sys_clk_i  : in  std_logic;  -- 100 MHz

      -- Reset
      sys_rstn_i : in  std_logic;  -- Asserted low

      -- Input switches and push buttons
      sw_i       : in  std_logic_vector(15 downto 0);
      btn_i      : in  std_logic_vector( 4 downto 0);

      -- Output LEDs
      led_o      : out std_logic_vector(15 downto 0);

     -- Output to VGA monitor
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(11 downto 0)
  );

end hack;

architecture Structural of hack is

   -- Clocks and Reset
   signal clk_vga   : std_logic;
   signal rst_vga   : std_logic;
   signal clk_cpu   : std_logic;
   signal rst_cpu   : std_logic;
   
   -- Address Decoding
   signal cs_rom    : std_logic;
   signal cs_vga    : std_logic;
   signal cs_ram    : std_logic;

   -- Signals driven by the CPU.
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal cpu_wren  : std_logic;
   signal cpu_data  : std_logic_vector( 7 downto 0);
   signal cpu_rden  : std_logic;

   signal rom_data : std_logic_vector(7 downto 0);
   signal ram_data : std_logic_vector(7 downto 0);
   signal vga_data : std_logic_vector(7 downto 0);
   signal data     : std_logic_vector(7 downto 0);
   signal vga_wren : std_logic;
   signal ram_wren : std_logic;

   -- Additional signals
   signal vga_irq   : std_logic;
   signal cpu_debug : std_logic_vector(63 downto 0);

   signal btn_deb   : std_logic := '0';
   signal btn_pulse : std_logic := '0';

begin

   --led_o <= cpu_debug(47 downto 32);

   ------------------------------
   -- Instantiate Clock and Reset
   ------------------------------

   inst_clk_rst : entity work.clk_rst
   generic map (
      G_SIMULATION => G_SIMULATION
   )
   port map (
      sys_clk_i  => sys_clk_i,
      sys_rstn_i => sys_rstn_i,
      rst_cpu_o  => rst_cpu,
      rst_vga_o  => rst_vga,
      clk_cpu_o  => clk_cpu,
      clk_vga_o  => clk_vga
   );


   ------------------------------
   -- Instantiate Address Decoding
   ------------------------------

   inst_cs : entity work.cs
   port map (
      addr_i => cpu_addr,
      rom_o  => cs_rom,
      vga_o  => cs_vga,
      ram_o  => cs_ram
   );

   data <= rom_data when cs_rom = '1' else
           ram_data when cs_ram = '1' else
           vga_data when cs_vga = '1' else
           (others => '0');

   vga_wren <= cpu_wren and cs_vga;
   ram_wren <= cpu_wren and cs_ram; 

   ------------------------------
   -- Instantiate VGA module (only during synthesis)
   ------------------------------

   gen_vga: if true generate -- G_SIMULATION = false  generate
      inst_vga_module : entity work.vga_module
      generic map (
                     G_CHAR_FILE  => G_CHAR_FILE,
                     G_DO_RD_REG  => true,
                     G_RD_CLK_RIS => false    -- Register on falling edge.
                  )
      port map (
         vga_clk_i => clk_vga,
         vga_rst_i => rst_vga,
         hs_o  => vga_hs_o,
         vs_o  => vga_vs_o,
         col_o => vga_col_o,

         -- Configuration @ cpu_clk_i
         cpu_clk_i  => clk_cpu,
         cpu_rst_i  => rst_cpu,
         cpu_addr_i => cpu_addr(7 downto 0),
         cpu_wren_i => vga_wren,
         cpu_data_i => cpu_data,
         cpu_data_o => vga_data,

         cpu_irq_o => vga_irq,
         debug_o   => led_o(2 downto 0)
      );
   end generate gen_vga;


   ------------------------------
   -- Instantiate ROM
   ------------------------------

   inst_rom : entity work.mem_file
   generic map (
      G_ADDR_SIZE  => G_ROM_SIZE,
      G_DATA_SIZE  => 8,
      G_DO_RD_REG  => true,
      G_RD_CLK_RIS => false,   -- Register on falling edge.
      G_ROM_FILE   => G_ROM_FILE
   )
   port map (
      -- Write port not connected, because it is a ROM.
      wr_clk_i  => '0',
      wr_en_i   => '0',
      wr_addr_i => (others => '0'),
      wr_data_i => (others => '0'),

      rd_clk_i  => clk_cpu,
      rd_addr_i => cpu_addr(G_ROM_SIZE-1 downto 0),
      rd_data_o => rom_data
   );


   ------------------------------
   -- Instantiate RAM
   ------------------------------

   inst_ram : entity work.mem_file
   generic map (
      G_ADDR_SIZE  => G_RAM_SIZE,
      G_DATA_SIZE  => 8,
      G_DO_RD_REG  => true,
      G_RD_CLK_RIS => false,   -- Register on falling edge.
      G_ROM_FILE   => G_RAM_FILE       -- No initial contents of RAM.
   )
   port map (
      wr_clk_i  => clk_cpu,
      wr_en_i   => ram_wren,
      wr_addr_i => cpu_addr(G_RAM_SIZE-1 downto 0),
      wr_data_i => cpu_data,

      rd_clk_i  => clk_cpu,
      rd_addr_i => cpu_addr(G_RAM_SIZE-1 downto 0),
      rd_data_o => ram_data
   );


   ------------------------------
   -- Instantiate CPU
   ------------------------------

   inst_cpu : entity work.cpu_module
   port map (
      clk_i   => clk_cpu,
      rst_i   => rst_cpu,

      addr_o  => cpu_addr,

      rden_o  => cpu_rden,
      data_i  => data,

      wren_o  => cpu_wren,
      data_o  => cpu_data,

      irq_i   => vga_irq,
      debug_o => cpu_debug 
   );

   p_temp : process (clk_cpu)
   begin
      if rising_edge(clk_cpu) then
         if cpu_wren = '1' and cpu_addr = X"0005" then
            led_o(15 downto 8) <= cpu_data;
         end if;
      end if;
   end process p_temp;

   led_o(3) <= cpu_debug(59);

   inst_debounce : entity work.debounce
   port map (
      clk_i => clk_cpu,
      sig_i => btn_i(0),   -- Center button
      sig_o => btn_deb
   );

   inst_edgedetect : entity work.edgedetect
   port map (
      clk_i => clk_cpu,
      sig_i => btn_deb,
      sig_o => btn_pulse
   );

end Structural;

