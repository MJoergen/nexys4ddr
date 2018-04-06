library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module contains all the memory and memory-mapped IO accessible by the
-- CPU.
-- Port A is connected to the CPU (and the Ethernet module).  Some memory (RAM
-- and ROM and CONF) have zero latency, i.e. value is ready upon next clock
-- cycle.  Other memory (DISP and FONT and MOB) have a one cycle read delay on
-- port A, where a_wait_o is asserted. This is because the VGA module needs to
-- read this memory, and hence uses an additional read port of the BRAM.
-- Port B is connected to the GPU. No address decoding is done, because reads
-- occur simultaneously, the DISP and FONT and MOB memories must all be
-- readable on the same clock cycle.

entity mem_module is

   generic (
      G_NEXYS4DDR : boolean;          -- True, when using the Nexys4DDR board.
      --
      G_ROM_SIZE  : integer;          -- Number of bits in ROM address
      G_RAM_SIZE  : integer;          -- Number of bits in RAM address
      G_DISP_SIZE : integer;          -- Number of bits in DISP address
      G_FONT_SIZE : integer;          -- Number of bits in FONT address
      G_MOB_SIZE  : integer;          -- Number of bits in MOB address
      G_CONF_SIZE : integer;          -- Number of bits in CONF address
      --
      G_ROM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in ROM address
      G_RAM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in RAM address
      G_DISP_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in DISP address
      G_FONT_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in FONT address
      G_MOB_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in MOB address
      G_CONF_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in CONF address
      --
      G_ROM_FILE  : string;           -- Contains the contents of the ROM memory.
      G_FONT_FILE : string            -- Contains the contents of the FONT memory.
   );
   port (
      -- Port A (Write and Read)
      a_clk_i     : in  std_logic;
      a_rst_i     : in  std_logic;
      a_addr_i    : in  std_logic_vector(15 downto 0);
      a_wren_i    : in  std_logic;
      a_data_i    : in  std_logic_vector( 7 downto 0);
      a_rden_i    : in  std_logic;
      a_data_o    : out std_logic_vector( 7 downto 0);
      a_wait_o    : out std_logic;
      a_irq_o     : out std_logic;
      a_kb_rden_o : out std_logic;
      a_kb_val_i  : in  std_logic_vector( 7 downto 0);

      -- Port B (Read only)
      b_clk_i       : in  std_logic;
      b_rst_i       : in  std_logic;
      b_disp_addr_i : in  std_logic_vector(G_DISP_SIZE-1 downto 0);
      b_disp_data_o : out std_logic_vector(7 downto 0);
      b_font_addr_i : in  std_logic_vector(G_FONT_SIZE-1 downto 0);
      b_font_data_o : out std_logic_vector(7 downto 0);
      b_mob_addr_i  : in  std_logic_vector(G_MOB_SIZE-2 downto 0);
      b_mob_data_o  : out std_logic_vector(15 downto 0);
      b_config_o    : out std_logic_vector(32*8-1 downto 0);
      b_irq_i       : in  std_logic
  );
end mem_module;

architecture Structural of mem_module is

   -------------------
   -- Port A
   -------------------

   signal a_rom_cs       : std_logic;
   signal a_rom_wr_en    : std_logic;
   signal a_rom_rd_en    : std_logic;
   signal a_rom_rd_data  : std_logic_vector(7 downto 0);

   signal a_ram_cs       : std_logic;
   signal a_ram_wr_en    : std_logic;
   signal a_ram_rd_en    : std_logic;
   signal a_ram_rd_data  : std_logic_vector(7 downto 0);

   signal a_disp_cs      : std_logic;
   signal a_disp_wr_en   : std_logic;
   signal a_disp_rd_en   : std_logic;
   signal a_disp_rd_data : std_logic_vector(7 downto 0);

   signal a_font_cs      : std_logic;
   signal a_font_wr_en   : std_logic;
   signal a_font_rd_en   : std_logic;
   signal a_font_rd_data : std_logic_vector(7 downto 0);

   signal a_mob_cs       : std_logic;
   signal a_mob_wr_en    : std_logic;
   signal a_mob_rd_en    : std_logic;
   signal a_mob_rd_data  : std_logic_vector(7 downto 0);

   signal a_conf_cs      : std_logic;
   signal a_conf_wr_en   : std_logic;
   signal a_conf_rd_en   : std_logic;
   signal a_conf_rd_data : std_logic_vector(7 downto 0);

   signal a_rden_d       : std_logic;

begin

   ------------------------------
   -- Instantiate ROM
   ------------------------------

   inst_rom : entity work.rom_file
   generic map (
      G_WR_CLK_RIS => true,         -- Write on rising clock edge
      G_RD_CLK_RIS => false,        -- Read on falling clock edge
      G_ADDR_SIZE  => G_ROM_SIZE,
      G_DATA_SIZE  => 8,
      G_ROM_FILE   => G_ROM_FILE
   )
   port map (
      wr_clk_i  => a_clk_i,
      wr_addr_i => a_addr_i(G_ROM_SIZE-1 downto 0),
      wr_en_i   => a_rom_wr_en,
      wr_data_i => a_data_i,
      rd_clk_i  => a_clk_i,
      rd_addr_i => a_addr_i(G_ROM_SIZE-1 downto 0),
      rd_en_i   => a_rom_rd_en,
      rd_data_o => a_rom_rd_data
   );


   ------------------------------
   -- Instantiate RAM
   ------------------------------

   inst_ram : entity work.mem
   generic map (
      G_ADDR_SIZE  => G_RAM_SIZE,
      G_DATA_SIZE  => 8
   )
   port map (
      a_clk_i    => a_clk_i,
      a_addr_i   => a_addr_i(G_RAM_SIZE-1 downto 0),
      a_rden_i   => a_ram_rd_en,
      a_rddata_o => a_ram_rd_data,
      a_wren_i   => a_ram_wr_en,
      a_wrdata_i => a_data_i

      -- Port B is not used
   );


   --------------------------------------------
   -- Instantiate the Character Display memory
   --------------------------------------------

   inst_disp : entity work.mem
   generic map (
      G_ADDR_SIZE => G_DISP_SIZE,
      G_DATA_SIZE => 8,
      G_INIT_VAL  => 32   -- 0x20 = space
   )
   port map (
      a_clk_i    => a_clk_i,
      a_addr_i   => a_addr_i(G_DISP_SIZE-1 downto 0),
      a_wren_i   => a_disp_wr_en,
      a_wrdata_i => a_data_i,
      a_rden_i   => a_disp_rd_en,
      a_rddata_o => a_disp_rd_data,

      b_clk_i    => b_clk_i,
      b_addr_i   => b_disp_addr_i,
      b_rden_i   => '1',
      b_data_o   => b_disp_data_o
   );


   ---------------------------------------
   -- Instantiate the Character Font block 
   ---------------------------------------

   inst_font : entity work.rom_file
   generic map (
      G_WR_CLK_RIS => true,         -- Write on rising clock edge
      G_RD_CLK_RIS => true,         -- Read on rising clock edge
      G_ADDR_SIZE  => G_FONT_SIZE,
      G_DATA_SIZE  => 8,
      G_ROM_FILE   => G_FONT_FILE 
   )
   port map (
      wr_clk_i     => a_clk_i,
      wr_addr_i    => a_addr_i(G_FONT_SIZE-1 downto 0),
      wr_en_i      => a_font_wr_en,
      wr_data_i    => a_data_i,

      rd_clk_i     => b_clk_i,
      rd_addr_i    => b_font_addr_i,
      rd_en_i      => '1',
      rd_data_o    => b_font_data_o
      --a_rden_i    => a_font_rd_en,
      --a_rddata_o  => a_font_rd_data,
   );


   ---------------------------------------
   -- Instantiate the Sprite Bitmap memory
   ---------------------------------------

   inst_mob : entity work.bitmaps_mem
   port map (
      cpu_clk_i   => a_clk_i,
      cpu_addr_i  => a_addr_i(G_MOB_SIZE-1 downto 0),
      cpu_wren_i  => a_mob_wr_en,
      cpu_data_i  => a_data_i,
      cpu_rden_i  => a_mob_rd_en,
      cpu_data_o  => a_mob_rd_data,

      -- Read port @ vga_clk_i
      vga_clk_i   => b_clk_i,
      vga_addr_i  => b_mob_addr_i,
      vga_data_o  => b_mob_data_o
   );


   ---------------------------------------
   -- Instantiate the CONF memory
   ---------------------------------------

   inst_conf_mem : entity work.conf_mem
   generic map (
      G_CONF_SIZE => G_CONF_SIZE 
   )
   port map (
      a_clk_i     => a_clk_i,
      a_rst_i     => a_rst_i,
      a_addr_i    => a_addr_i,
      a_wr_en_i   => a_conf_wr_en,
      a_wr_data_i => a_data_i,
      a_rd_en_i   => a_conf_rd_en,
      a_rd_data_o => a_conf_rd_data,
      a_irq_o     => a_irq_o,
      a_kb_rden_o => a_kb_rden_o,
      a_kb_val_i  => a_kb_val_i,
      b_clk_i     => b_clk_i,
      b_rst_i     => b_rst_i,
      b_config_o  => b_config_o,
      b_irq_i     => b_irq_i
  );


   -------------------------------
   -- Instantiate Address Decoding
   -------------------------------

   a_rom_cs  <= '1' when a_addr_i(15 downto G_ROM_SIZE)  = G_ROM_MASK( 15 downto G_ROM_SIZE)  else '0';
   a_ram_cs  <= '1' when a_addr_i(15 downto G_RAM_SIZE)  = G_RAM_MASK( 15 downto G_RAM_SIZE)  else '0';
   a_disp_cs <= '1' when a_addr_i(15 downto G_DISP_SIZE) = G_DISP_MASK(15 downto G_DISP_SIZE) else '0';
   a_font_cs <= '1' when a_addr_i(15 downto G_FONT_SIZE) = G_FONT_MASK(15 downto G_FONT_SIZE) else '0';
   a_mob_cs  <= '1' when a_addr_i(15 downto G_MOB_SIZE)  = G_MOB_MASK( 15 downto G_MOB_SIZE)  else '0';
   a_conf_cs <= '1' when a_addr_i(15 downto G_CONF_SIZE) = G_CONF_MASK(15 downto G_CONF_SIZE) else '0';

   a_rom_wr_en  <= a_wren_i and a_rom_cs;
   a_ram_wr_en  <= a_wren_i and a_ram_cs;
   a_disp_wr_en <= a_wren_i and a_disp_cs;
   a_font_wr_en <= a_wren_i and a_font_cs;
   a_mob_wr_en  <= a_wren_i and a_mob_cs;
   a_conf_wr_en <= a_wren_i and a_conf_cs;

   a_rom_rd_en  <= a_rden_i and a_rom_cs;
   a_ram_rd_en  <= a_rden_i and a_ram_cs;
   a_disp_rd_en <= a_rden_i and a_disp_cs;
   a_font_rd_en <= a_rden_i and a_font_cs;
   a_mob_rd_en  <= a_rden_i and a_mob_cs;
   a_conf_rd_en <= a_rden_i and a_conf_cs;

   a_data_o <= a_rom_rd_data  when a_rom_rd_en = '1' else
               a_ram_rd_data  when a_ram_rd_en = '1' else
               a_disp_rd_data when a_disp_rd_en = '1' else
               a_font_rd_data when a_font_rd_en = '1' else
               a_mob_rd_data  when a_mob_rd_en = '1' else
               a_conf_rd_data when a_conf_rd_en = '1' else
               (others => '0');


   -------------------------------
   -- Insert wait states
   -------------------------------

   process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         a_rden_d <= a_rden_i;
         a_wait_o <= '0';

         if a_disp_rd_en = '1' or a_font_rd_en = '1' or a_mob_rd_en = '1' then
            a_wait_o <= '1';
         end if;

         if a_rst_i = '1' then
            a_rden_d <= '0';
         end if;
      end if;
   end process;

end Structural;

