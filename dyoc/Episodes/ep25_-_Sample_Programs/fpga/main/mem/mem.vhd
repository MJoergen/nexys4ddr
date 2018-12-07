library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module controls the memory map of the computer
-- by instantiating the different memory components
-- needed (RAM, ROM, etc), and by handling the necessary
-- address decoding.

entity mem is
   generic (
      G_ROM_SIZE   : integer;          -- Number of bits in ROM address
      G_RAM_SIZE   : integer;          -- Number of bits in RAM address
      G_CHAR_SIZE  : integer;          -- Number of bits in CHAR address
      G_COL_SIZE   : integer;          -- Number of bits in COL address
      G_MEMIO_SIZE : integer;          -- Number of bits in MEMIO address
      --
      G_ROM_MASK   : std_logic_vector(15 downto 0);  -- Value of upper bits in ROM address
      G_RAM_MASK   : std_logic_vector(15 downto 0);  -- Value of upper bits in RAM address
      G_CHAR_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in CHAR address
      G_COL_MASK   : std_logic_vector(15 downto 0);  -- Value of upper bits in COL address
      G_MEMIO_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in MEMIO address
      --
      G_ROM_FILE   : string;           -- Contains the contents of the ROM memory.
      --
      -- Initial contents of the Memory Mapped I/O
      G_MEMIO_INIT : std_logic_vector(8*32-1 downto 0)
   );
   port (
      -- Port A - connected to CPU and Memory Mapped I/O
      a_clk_i        : in  std_logic;
      a_addr_i       : in  std_logic_vector(15 downto 0);
      a_data_o       : out std_logic_vector( 7 downto 0);
      a_rden_i       : in  std_logic;
      a_data_i       : in  std_logic_vector( 7 downto 0);
      a_wren_i       : in  std_logic;
      a_wait_o       : out std_logic;
      a_memio_wr_o   : out std_logic_vector(8*32-1 downto 0);
      a_memio_rd_i   : in  std_logic_vector(8*32-1 downto 0);
      a_memio_rden_o : out std_logic_vector(  32-1 downto 0);

      -- Port B - connected to VGA
      b_clk_i        : in  std_logic;
      b_char_addr_i  : in  std_logic_vector(12 downto 0);
      b_char_data_o  : out std_logic_vector( 7 downto 0);
      b_col_addr_i   : in  std_logic_vector(12 downto 0);
      b_col_data_o   : out std_logic_vector( 7 downto 0)
   );
end mem;

architecture structural of mem is

   signal a_rom_data  : std_logic_vector(7 downto 0);
   signal a_rom_cs    : std_logic;
   --
   signal a_ram_wren  : std_logic;
   signal a_ram_data  : std_logic_vector(7 downto 0);
   signal a_ram_cs    : std_logic;
   --
   signal a_char_wren : std_logic;
   signal a_char_data : std_logic_vector(7 downto 0);
   signal a_char_cs   : std_logic;
   --
   signal a_col_wren  : std_logic;
   signal a_col_data  : std_logic_vector(7 downto 0);
   signal a_col_cs    : std_logic;
   --
   signal a_memio_wren : std_logic;
   signal a_memio_data : std_logic_vector(7 downto 0);
   signal a_memio_cs   : std_logic;

   signal a_wait   : std_logic;
   signal a_wait_d : std_logic;

begin

   ---------------------
   -- Insert wait state
   ---------------------

   a_wait <= a_rden_i and (a_char_cs or a_col_cs or a_memio_cs);

   a_wait_d_proc : process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         a_wait_d <= a_wait;
      end if;
   end process a_wait_d_proc;

   a_wait_o <= '1' when a_wait = '1' and a_wait_d = '0' else
               '0';

   -----------------------
   -- Instantiate the ROM
   -----------------------

   rom_inst : entity work.rom
   generic map (
      G_INIT_FILE => G_ROM_FILE,
      G_ADDR_BITS => G_ROM_SIZE
   )
   port map (
      clk_i  => a_clk_i,
      addr_i => a_addr_i(G_ROM_SIZE-1 downto 0),
      data_o => a_rom_data
   ); -- rom_inst


   -------------------------------------
   -- Instantiate the Memory Mapped I/O
   -------------------------------------

   memio_inst : entity work.memio
   generic map (
      G_ADDR_BITS => G_MEMIO_SIZE,
      G_INIT_VAL  => G_MEMIO_INIT
   )
   port map (
      clk_i   => a_clk_i,
      addr_i  => a_addr_i(G_MEMIO_SIZE-1 downto 0),
      data_o  => a_memio_data,
      data_i  => a_data_i,
      wren_i  => a_memio_wren,
      memio_o => a_memio_wr_o, -- From MEMIO
      memio_i => a_memio_rd_i  -- To MEMIO
   ); -- memio_inst


   ------------------------------------
   -- Instantiate the character memory
   ------------------------------------

   char_inst : entity work.dmem
   generic map (
      G_ADDR_BITS => G_CHAR_SIZE
   )
   port map (
      a_clk_i  => a_clk_i,
      a_addr_i => a_addr_i(G_CHAR_SIZE-1 downto 0),
      a_data_o => a_char_data,
      a_data_i => a_data_i,
      a_wren_i => a_char_wren,
      --
      b_clk_i  => b_clk_i,
      b_addr_i => b_char_addr_i,
      b_data_o => b_char_data_o
   ); -- char_inst


   ---------------------------------
   -- Instantiate the colour memory
   ---------------------------------

   col_inst : entity work.dmem
   generic map (
      G_ADDR_BITS => G_COL_SIZE,
      G_INIT_VAL  => X"0F"    -- Default is white text on black background.
   )
   port map (
      a_clk_i  => a_clk_i,
      a_addr_i => a_addr_i(G_COL_SIZE-1 downto 0),
      a_data_o => a_col_data,
      a_data_i => a_data_i,
      a_wren_i => a_col_wren,
      --
      b_clk_i  => b_clk_i,
      b_addr_i => b_col_addr_i,
      b_data_o => b_col_data_o
   ); -- col_inst


   -----------------------
   -- Instantiate the RAM
   -----------------------

   ram_inst : entity work.ram
   generic map (
      G_ADDR_BITS => G_RAM_SIZE
   )
   port map (
      clk_i  => a_clk_i,
      addr_i => a_addr_i(G_RAM_SIZE-1 downto 0),
      data_o => a_ram_data,
      data_i => a_data_i,
      wren_i => a_ram_wren
   ); -- ram_inst


   --------------------
   -- Address decoding
   --------------------

   a_rom_cs   <= '1' when a_addr_i(15 downto G_ROM_SIZE)   = G_ROM_MASK(   15 downto G_ROM_SIZE)   else '0';
   a_ram_cs   <= '1' when a_addr_i(15 downto G_RAM_SIZE)   = G_RAM_MASK(   15 downto G_RAM_SIZE)   else '0';
   a_char_cs  <= '1' when a_addr_i(15 downto G_CHAR_SIZE)  = G_CHAR_MASK(  15 downto G_CHAR_SIZE)  else '0';
   a_col_cs   <= '1' when a_addr_i(15 downto G_COL_SIZE)   = G_COL_MASK(   15 downto G_COL_SIZE)   else '0';
   a_memio_cs <= '1' when a_addr_i(15 downto G_MEMIO_SIZE) = G_MEMIO_MASK( 15 downto G_MEMIO_SIZE) else '0';

   a_ram_wren   <= a_wren_i and a_ram_cs;
   a_char_wren  <= a_wren_i and a_char_cs;
   a_col_wren   <= a_wren_i and a_col_cs;
   a_memio_wren <= a_wren_i and a_memio_cs;


   process (a_addr_i, a_rden_i, a_memio_cs, a_wait, a_wait_d)
   begin
      a_memio_rden_o <= (others => '0');
      a_memio_rden_o(to_integer(a_addr_i(G_MEMIO_SIZE-2 downto 0))) <=
         a_rden_i and a_memio_cs and a_wait and not a_wait_d and a_addr_i(G_MEMIO_SIZE-1);
   end process;

   a_data_o <= a_rom_data   when a_rom_cs   = '1' else
               a_memio_data when a_memio_cs = '1' else
               a_ram_data   when a_ram_cs   = '1' else
               a_char_data  when a_char_cs  = '1' else
               a_col_data   when a_col_cs   = '1' else
               X"00";   -- Default value is needed to avoid inferring a latch.
  
end structural;

