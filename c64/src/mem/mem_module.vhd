library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module contains all the memory and memory-mapped IO accessible by the
-- CPU.
-- Port A is connected to the CPU (and the Ethernet module).  Some memory (RAM
-- and ROM and CONF) have zero latency, i.e. value is ready upon next clock
-- cycle.  Other memory (DISP and MOB and CONF and FONT) have a one cycle read
-- delay on port A, where a_wait_o is asserted. This is because the VGA module
-- needs to read this memory, and hence uses an additional read port of the
-- BRAM.  Port B is connected to the VGA. No address decoding is done, because
-- reads occur simultaneously, the DISP and MOB and CONF and FONT memories must
-- all be readable on the same clock cycle.
--
-- RAM  : Read on falling clock edge. No wait state.
-- DISP : Read on rising clock edge. 1 wait state.
-- COL  : Read on rising clock edge. 1 wait state.
-- MOB  : Read on rising clock edge. 1 wait state.
-- CONF : Read on rising clock edge. 1 wait state.
-- FONT : Read on rising clock edge. 1 wait state.
-- ROM  : Read on falling clock edge. No wait state.

entity mem_module is

   generic (
      G_NEXYS4DDR : boolean;          -- True, when using the Nexys4DDR board.
      --
      G_RAM_SIZE  : integer;          -- Number of bits in RAM address
      G_DISP_SIZE : integer;          -- Number of bits in DISP address
      G_COL_SIZE  : integer;          -- Number of bits in COL address
      G_MOB_SIZE  : integer;          -- Number of bits in MOB address
      G_CONF_SIZE : integer;          -- Number of bits in CONF address
      G_FONT_SIZE : integer;          -- Number of bits in FONT address
      G_ROM_SIZE  : integer;          -- Number of bits in ROM address
      --
      G_RAM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in RAM address
      G_DISP_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in DISP address
      G_COL_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in COL address
      G_MOB_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in MOB address
      G_CONF_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in CONF address
      G_FONT_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in FONT address
      G_ROM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in ROM address
      --
      G_FONT_FILE : string;           -- Contains the contents of the FONT memory.
      G_ROM_FILE  : string            -- Contains the contents of the ROM memory.
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
      --
      a_kb_rden_o : out std_logic;
      a_kb_val_i  : in  std_logic_vector( 7 downto 0);

      -- Port B (Read only)
      b_clk_i       : in  std_logic;
      b_rst_i       : in  std_logic;
      b_disp_addr_i : in  std_logic_vector(G_DISP_SIZE-1 downto 0);
      b_disp_data_o : out std_logic_vector(7 downto 0);
      b_col_addr_i  : in  std_logic_vector(G_COL_SIZE-1 downto 0);
      b_col_data_o  : out std_logic_vector(7 downto 0);
      b_mob_addr_i  : in  std_logic_vector(G_MOB_SIZE-2 downto 0);
      b_mob_data_o  : out std_logic_vector(15 downto 0);
      b_config_o    : out std_logic_vector((2**G_CONF_SIZE)*8-1 downto 0);
      b_font_addr_i : in  std_logic_vector(G_FONT_SIZE-1 downto 0);
      b_font_data_o : out std_logic_vector(7 downto 0);
      b_vcount_i    : in  std_logic_vector(10 downto 0);
      b_hcount_i    : in  std_logic_vector(10 downto 0);
      b_collision_i : in  std_logic_vector(3 downto 0)
  );
end mem_module;

architecture Structural of mem_module is

   -------------------
   -- Port A
   -------------------

   signal a_wait    : std_logic;
   signal a_wait_d  : std_logic;
   signal a_kb_rden : std_logic;

   signal a_wr_en   : std_logic_vector( 6 downto 0);
   signal a_rd_en   : std_logic_vector( 6 downto 0);
   signal a_rd_data : std_logic_vector(55 downto 0);

begin

   ------------------------------
   -- Instantiate RAM
   ------------------------------

   inst_ram : entity work.dmem
   generic map (
      G_ADDR_SIZE  => G_RAM_SIZE,
      G_DATA_SIZE  => 8,
      G_MEM_VAL    => 0    -- Initial value
   )
   port map (
      clk_i     => a_clk_i,
      rst_i     => a_rst_i,
      addr_i    => a_addr_i(G_RAM_SIZE-1 downto 0),
      wr_en_i   => a_wr_en(0),
      wr_data_i => a_data_i,
      rd_en_i   => a_rd_en(0),
      rd_data_o => a_rd_data(7 downto 0)
   );


   --------------------------------------------
   -- Instantiate the Character Display memory
   --------------------------------------------

   inst_disp : entity work.mem
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_ADDR_SIZE => G_DISP_SIZE,
      G_DATA_SIZE => 8,
      G_INIT_VAL  => 32   -- 0x20 = space
   )
   port map (
      a_clk_i     => a_clk_i,
      a_addr_i    => a_addr_i(G_DISP_SIZE-1 downto 0),
      a_wr_en_i   => a_wr_en(1),
      a_wr_data_i => a_data_i,
      a_rd_en_i   => a_rd_en(1),
      a_rd_data_o => a_rd_data(15 downto 8),

      b_clk_i     => b_clk_i,
      b_addr_i    => b_disp_addr_i,
      b_rd_en_i   => '1',
      b_rd_data_o => b_disp_data_o
   );


   --------------------------------------------
   -- Instantiate the Character Colour memory
   --------------------------------------------

   inst_col : entity work.mem
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_ADDR_SIZE => G_COL_SIZE,
      G_DATA_SIZE => 8,
      G_INIT_VAL  => 255
   )
   port map (
      a_clk_i     => a_clk_i,
      a_addr_i    => a_addr_i(G_COL_SIZE-1 downto 0),
      a_wr_en_i   => a_wr_en(6),
      a_wr_data_i => a_data_i,
      a_rd_en_i   => a_rd_en(6),
      a_rd_data_o => a_rd_data(55 downto 48),

      b_clk_i     => b_clk_i,
      b_addr_i    => b_col_addr_i,
      b_rd_en_i   => '1',
      b_rd_data_o => b_col_data_o
   );


   ---------------------------------------
   -- Instantiate the Sprite Bitmap memory
   ---------------------------------------

   inst_mob : entity work.bitmaps_mem
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR
   )
   port map (
      cpu_clk_i   => a_clk_i,
      cpu_addr_i  => a_addr_i(G_MOB_SIZE-1 downto 0),
      cpu_wren_i  => a_wr_en(2),
      cpu_data_i  => a_data_i,
      cpu_rden_i  => a_rd_en(2),
      cpu_data_o  => a_rd_data(23 downto 16),

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
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_CONF_SIZE => G_CONF_SIZE 
   )
   port map (
      a_clk_i       => a_clk_i,
      a_rst_i       => a_rst_i,
      a_addr_i      => a_addr_i,
      a_wr_en_i     => a_wr_en(3),
      a_wr_data_i   => a_data_i,
      a_rd_en_i     => a_rd_en(3),
      a_rd_data_o   => a_rd_data(31 downto 24),
      a_irq_o       => a_irq_o,
      a_kb_rden_o   => a_kb_rden,
      a_kb_val_i    => a_kb_val_i,
      b_clk_i       => b_clk_i,
      b_rst_i       => b_rst_i,
      b_config_o    => b_config_o,
      b_vcount_i    => b_vcount_i,
      b_hcount_i    => b_hcount_i,
      b_collision_i => b_collision_i
   );


   ---------------------------------------
   -- Instantiate the Character Font block 
   ---------------------------------------

   inst_font : entity work.mem_file
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_ADDR_SIZE => G_FONT_SIZE,
      G_DATA_SIZE => 8,
      G_MEM_FILE  => G_FONT_FILE 
   )
   port map (
      a_clk_i     => a_clk_i,
      a_addr_i    => a_addr_i(G_FONT_SIZE-1 downto 0),
      a_wr_en_i   => a_wr_en(4),
      a_wr_data_i => a_data_i,
      a_rd_en_i   => a_rd_en(4),
      a_rd_data_o => a_rd_data(39 downto 32),

      b_clk_i     => b_clk_i,
      b_addr_i    => b_font_addr_i,
      b_rd_en_i   => '1',
      b_rd_data_o => b_font_data_o
   );


   ------------------------------
   -- Instantiate ROM
   ------------------------------

   inst_rom : entity work.dmem_file
   generic map (
      G_ADDR_SIZE  => G_ROM_SIZE,
      G_DATA_SIZE  => 8,
      G_MEM_FILE   => G_ROM_FILE
   )
   port map (
      clk_i     => a_clk_i,
      rst_i     => a_rst_i,
      addr_i    => a_addr_i(G_ROM_SIZE-1 downto 0),
      wr_en_i   => a_wr_en(5),
      wr_data_i => a_data_i,
      rd_en_i   => a_rd_en(5),
      rd_data_o => a_rd_data(47 downto 40)
   );


   -------------------------------
   -- Instantiate Address Decoding
   -------------------------------

   inst_addr_decode : entity work.addr_decode
   generic map (
      G_RAM_SIZE  => G_RAM_SIZE,
      G_DISP_SIZE => G_DISP_SIZE,
      G_COL_SIZE  => G_COL_SIZE,
      G_MOB_SIZE  => G_MOB_SIZE,
      G_CONF_SIZE => G_CONF_SIZE,
      G_FONT_SIZE => G_FONT_SIZE,
      G_ROM_SIZE  => G_ROM_SIZE,
      G_RAM_MASK  => G_RAM_MASK,
      G_DISP_MASK => G_DISP_MASK,
      G_COL_MASK  => G_COL_MASK,
      G_MOB_MASK  => G_MOB_MASK,
      G_CONF_MASK => G_CONF_MASK,
      G_FONT_MASK => G_FONT_MASK,
      G_ROM_MASK  => G_ROM_MASK  
   )
   port map (
      a_addr_i    => a_addr_i,
      a_wren_i    => a_wren_i,
      a_rden_i    => a_rden_i,
      a_rd_data_i => a_rd_data,
      a_wr_en_o   => a_wr_en,
      a_rd_en_o   => a_rd_en,
      a_rd_data_o => a_data_o
  );


   -------------------------------
   -- Insert wait states
   -------------------------------

   process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         a_wait_d <= a_wait;

         if a_rst_i = '1' then
            a_wait_d <= '0';
         end if;
      end if;
   end process;


   a_wait <= '1' when a_rd_en(1) = '1' or    -- DISP
                      a_rd_en(2) = '1' or    -- MOB
                      a_rd_en(3) = '1' or    -- CONF
                      a_rd_en(4) = '1' or    -- FONT
                      a_rd_en(6) = '1' else  -- COL
             '0';

   a_wait_o <= '1' when a_wait = '1' and a_wait_d = '0' else
               '0';

   a_kb_rden_o <= a_kb_rden and not a_wait_d;

end Structural;

