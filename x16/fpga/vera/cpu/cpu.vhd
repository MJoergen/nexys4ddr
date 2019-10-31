library ieee;
use ieee.std_logic_1164.all;

-- This is the CPU interface within the VERA.
--
-- It multiplexes the requests to the Video RAM, the palette RAM, and the
-- configuration settings.

entity cpu is
   port (
      clk_i          : in  std_logic;
      -- External CPU interface
      addr_i         : in  std_logic_vector( 2 downto 0);
      wr_en_i        : in  std_logic;
      wr_data_i      : in  std_logic_vector( 7 downto 0);
      rd_en_i        : in  std_logic;
      rd_data_o      : out std_logic_vector( 7 downto 0);

      -- Video RAM
      vram_addr_o    : out std_logic_vector(16 downto 0);
      vram_wr_en_o   : out std_logic;
      vram_wr_data_o : out std_logic_vector( 7 downto 0);
      vram_rd_en_o   : out std_logic;
      vram_rd_data_i : in  std_logic_vector( 7 downto 0);
      -- palette RAM
      pal_addr_o     : out std_logic_vector( 8 downto 0);
      pal_wr_en_o    : out std_logic;
      pal_wr_data_o  : out std_logic_vector( 7 downto 0);
      pal_rd_en_o    : out std_logic;
      pal_rd_data_i  : in  std_logic_vector( 7 downto 0);
      -- configruation settings
      map_base_o     : out std_logic_vector(17 downto 0);
      tile_base_o    : out std_logic_vector(17 downto 0)
   );
end cpu;

architecture structural of cpu is

   -- CPU accesses translated to the internal memory map.
   signal internal_addr_s    : std_logic_vector(19 downto 0);
   signal internal_wr_en_s   : std_logic;
   signal internal_wr_data_s : std_logic_vector( 7 downto 0);
   signal internal_rd_en_s   : std_logic;
   signal internal_rd_data_s : std_logic_vector( 7 downto 0);

   -- Read data
   signal config_rd_data_s   : std_logic_vector( 7 downto 0);
   signal vram_rd_en_d       : std_logic;
   signal pal_rd_en_d        : std_logic;

begin

   --------------------------------------------------
   -- Translate from external to internal memory map
   --------------------------------------------------

   i_mmu : entity work.mmu
      port map (
         clk_i          => clk_i,
         -- External memory map
         cpu_addr_i     => addr_i,
         cpu_wr_en_i    => wr_en_i,
         cpu_wr_data_i  => wr_data_i,
         cpu_rd_en_i    => rd_en_i,
         cpu_rd_data_o  => rd_data_o,
         -- Internal memory map
         vera_addr_o    => internal_addr_s,
         vera_wr_en_o   => internal_wr_en_s,
         vera_wr_data_o => internal_wr_data_s,
         vera_rd_en_o   => internal_rd_en_s,
         vera_rd_data_i => internal_rd_data_s
      ); -- i_cpu_interface


   --------------------------
   -- Configuration settings
   --------------------------

   i_config : entity work.config
      port map (
         clk_i       => clk_i,
         addr_i      => internal_addr_s,
         wr_en_i     => internal_wr_en_s,
         wr_data_i   => internal_wr_data_s,
         rd_en_i     => internal_rd_en_s,
         rd_data_o   => config_rd_data_s,
         map_base_o  => map_base_o,
         tile_base_o => tile_base_o
      ); -- i_config


   p_ram_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vram_rd_en_d <= vram_rd_en_o;
         pal_rd_en_d  <= pal_rd_en_o;
      end if;
   end process p_ram_read;

   -- Access Video RAM
   vram_addr_o    <= internal_addr_s(16 downto 0);
   vram_wr_en_o   <= '1' when internal_wr_en_s = '1' and internal_addr_s(19 downto 17) = "000" else '0';
   vram_wr_data_o <= internal_wr_data_s;
   vram_rd_en_o   <= '1' when internal_rd_en_s = '1' and internal_addr_s(19 downto 17) = "000" else '0';

   -- Access palette RAM
   pal_addr_o    <= internal_addr_s(8 downto 0);
   pal_wr_en_o   <= '1' when internal_wr_en_s = '1' and internal_addr_s(19 downto 12) = X"F1" else '0';
   pal_wr_data_o <= internal_wr_data_s;
   pal_rd_en_o   <= '1' when internal_rd_en_s = '1' and internal_addr_s(19 downto 12) = X"F1" else '0';

   -- Multiplex CPU read
   internal_rd_data_s <= vram_rd_data_i when vram_rd_en_d = '1' else
                         pal_rd_data_i  when pal_rd_en_d  = '1' else
                         config_rd_data_s;

end architecture structural;

