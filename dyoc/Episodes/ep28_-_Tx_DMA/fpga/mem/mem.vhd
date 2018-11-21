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
      clk_i           : in  std_logic;

      -- Port A - connected to CPU
      a_addr_i        : in  std_logic_vector(15 downto 0);
      a_data_o        : out std_logic_vector( 7 downto 0);
      a_rden_i        : in  std_logic;
      a_data_i        : in  std_logic_vector( 7 downto 0);
      a_wren_i        : in  std_logic;
      a_wait_o        : out std_logic;

      -- Port B - connected to VGA, Ethernet, and Memory Mapped I/O
      b_char_addr_i   : in  std_logic_vector(12 downto 0);
      b_char_data_o   : out std_logic_vector( 7 downto 0);
      b_col_addr_i    : in  std_logic_vector(12 downto 0);
      b_col_data_o    : out std_logic_vector( 7 downto 0);
      b_eth_wr_en_i   : in  std_logic;
      b_eth_wr_addr_i : in  std_logic_vector(15 downto 0);
      b_eth_wr_data_i : in  std_logic_vector( 7 downto 0);
      b_eth_rd_en_i   : in  std_logic;
      b_eth_rd_addr_i : in  std_logic_vector(15 downto 0);
      b_eth_rd_data_o : out std_logic_vector( 7 downto 0);
      b_memio_wr_o    : out std_logic_vector(8*32-1 downto 0);
      b_memio_clear_i : in  std_logic_vector(  32-1 downto 0);
      b_memio_rd_i    : in  std_logic_vector(8*32-1 downto 0);
      b_memio_rden_o  : out std_logic_vector(  32-1 downto 0)
   );
end mem;

architecture structural of mem is

   signal rom_data  : std_logic_vector(7 downto 0);
   signal rom_cs    : std_logic;
   --
   signal ram_wren  : std_logic;
   signal ram_data  : std_logic_vector(7 downto 0);
   signal ram_cs    : std_logic;
   --
   signal char_wren : std_logic;
   signal char_data : std_logic_vector(7 downto 0);
   signal char_cs   : std_logic;
   --
   signal col_wren  : std_logic;
   signal col_data  : std_logic_vector(7 downto 0);
   signal col_cs    : std_logic;
   --
   signal memio_wren : std_logic;
   signal memio_data : std_logic_vector(7 downto 0);
   signal memio_cs   : std_logic;
   --
   signal ram_wr_en   : std_logic;
   signal ram_rd_addr : std_logic_vector(G_RAM_SIZE-1 downto 0);
   signal ram_wr_addr : std_logic_vector(G_RAM_SIZE-1 downto 0);
   signal ram_wr_data : std_logic_vector( 7 downto 0);

   signal a_wait   : std_logic;
   signal a_wait_d : std_logic;

begin

   ----------------------
   -- Address decoding
   ----------------------

   rom_cs   <= '1' when a_addr_i(15 downto G_ROM_SIZE)   = G_ROM_MASK(   15 downto G_ROM_SIZE)   else '0';
   ram_cs   <= '1' when a_addr_i(15 downto G_RAM_SIZE)   = G_RAM_MASK(   15 downto G_RAM_SIZE)   else '0';
   char_cs  <= '1' when a_addr_i(15 downto G_CHAR_SIZE)  = G_CHAR_MASK(  15 downto G_CHAR_SIZE)  else '0';
   col_cs   <= '1' when a_addr_i(15 downto G_COL_SIZE)   = G_COL_MASK(   15 downto G_COL_SIZE)   else '0';
   memio_cs <= '1' when a_addr_i(15 downto G_MEMIO_SIZE) = G_MEMIO_MASK( 15 downto G_MEMIO_SIZE) else '0';

   ram_wren   <= (a_wren_i and ram_cs   and not (a_wait and not a_wait_d)) or b_eth_wr_en_i;
   char_wren  <=  a_wren_i and char_cs  and not (a_wait and not a_wait_d);
   col_wren   <=  a_wren_i and col_cs   and not (a_wait and not a_wait_d);
   memio_wren <=  a_wren_i and memio_cs and not (a_wait and not a_wait_d);


   process (a_addr_i, a_rden_i, memio_cs, a_wait_d)
   begin
      b_memio_rden_o <= (others => '0');
      b_memio_rden_o(to_integer(a_addr_i(G_MEMIO_SIZE-2 downto 0))) <=
         a_rden_i and memio_cs and a_wait_d and a_addr_i(G_MEMIO_SIZE-1);
   end process;

   --------------------
   -- Insert wait state
   --------------------

   a_wait <= (a_rden_i and (char_cs or col_cs or memio_cs)) or
             (a_wren_i and b_eth_wr_en_i and ram_cs);


   p_a_wait_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         a_wait_d <= a_wait;
      end if;
   end process p_a_wait_d;

   a_wait_o <= '1' when a_wait = '1' and a_wait_d = '0' else
               '0';

   -- Multiplex read from CPU and Ethernet
   process (a_addr_i, b_eth_rd_en_i, b_eth_rd_addr_i)
   begin
      ram_rd_addr <= a_addr_i(G_RAM_SIZE-1 downto 0);

      if b_eth_rd_en_i = '1' then
         ram_rd_addr <= b_eth_rd_addr_i(G_RAM_SIZE-1 downto 0);
      end if;
   end process;

   -- Multiplex writes from CPU and Ethernet
   process (a_wren_i, a_addr_i, a_data_i, b_eth_wr_en_i, b_eth_wr_addr_i, b_eth_wr_data_i)
   begin
      ram_wr_addr <= a_addr_i(G_RAM_SIZE-1 downto 0);
      ram_wr_data <= a_data_i;
      ram_wr_en   <= a_wren_i;

      if b_eth_wr_en_i = '1' then
         ram_wr_addr <= b_eth_wr_addr_i(G_RAM_SIZE-1 downto 0);
         ram_wr_data <= b_eth_wr_data_i;
         ram_wr_en   <= b_eth_wr_en_i;
      end if;
   end process;


   ----------------------
   -- Instantiate the ROM
   ----------------------

   i_rom : entity work.rom
   generic map (
      G_INIT_FILE => G_ROM_FILE,
      G_ADDR_BITS => G_ROM_SIZE
   )
   port map (
      clk_i  => clk_i,
      addr_i => a_addr_i(G_ROM_SIZE-1 downto 0),
      data_o => rom_data
   );


   -------------------------------------
   -- Instantiate the Memory Mapped I/O
   -------------------------------------

   i_memio : entity work.memio
   generic map (
      G_ADDR_BITS => G_MEMIO_SIZE,
      G_INIT_VAL  => G_MEMIO_INIT
   )
   port map (
      clk_i           => clk_i,
      a_addr_i        => a_addr_i(G_MEMIO_SIZE-1 downto 0),
      a_data_o        => memio_data,
      a_data_i        => a_data_i,
      a_wren_i        => memio_wren,
      b_memio_o       => b_memio_wr_o, -- From MEMIO
      b_memio_clear_i => b_memio_clear_i,
      b_memio_i       => b_memio_rd_i  -- To MEMIO
   );


   -----------------------------------
   -- Instantiate the character memory
   -----------------------------------

   i_char : entity work.dmem
   generic map (
      G_ADDR_BITS => G_CHAR_SIZE
   )
   port map (
      clk_i    => clk_i,
      a_addr_i => a_addr_i(G_CHAR_SIZE-1 downto 0),
      a_data_o => char_data,
      a_data_i => a_data_i,
      a_wren_i => char_wren,
      b_addr_i => b_char_addr_i,
      b_data_o => b_char_data_o
   );


   -----------------------------------
   -- Instantiate the colour memory
   -----------------------------------

   i_col : entity work.dmem
   generic map (
      G_ADDR_BITS => G_COL_SIZE,
      G_INIT_VAL  => X"0F"    -- Default is white text on black background.
   )
   port map (
      clk_i    => clk_i,
      a_addr_i => a_addr_i(G_COL_SIZE-1 downto 0),
      a_data_o => col_data,
      a_data_i => a_data_i,
      a_wren_i => col_wren,
      b_addr_i => b_col_addr_i,
      b_data_o => b_col_data_o
   );


   ----------------------
   -- Instantiate the RAM
   ----------------------

   i_ram : entity work.ram
   generic map (
      G_ADDR_BITS => G_RAM_SIZE
   )
   port map (
      clk_i     => clk_i,
      rd_addr_i => ram_rd_addr,
      wr_addr_i => ram_wr_addr,
      data_o    => ram_data,
      data_i    => ram_wr_data,
      wren_i    => ram_wren
   );

   -- Connect output signals

   b_eth_rd_data_o <= ram_data when b_eth_rd_en_i = '1' else
                      X"00";   -- Default value is needed to avoid inferring a latch.
   
   a_data_o <= rom_data   when rom_cs   = '1' else
               memio_data when memio_cs = '1' else
               ram_data   when ram_cs   = '1' else
               char_data  when char_cs  = '1' else
               col_data   when col_cs   = '1' else
               X"00";   -- Default value is needed to avoid inferring a latch.
  
end structural;

