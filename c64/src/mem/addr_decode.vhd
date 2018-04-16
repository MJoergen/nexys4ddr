library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity addr_decode is
   generic (
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
      G_ROM_MASK  : std_logic_vector(15 downto 0)   -- Value of upper bits in ROM address
   );
   port (
      a_addr_i    : in  std_logic_vector(15 downto 0);
      a_wren_i    : in  std_logic;
      a_rden_i    : in  std_logic;
      a_rd_data_i : in  std_logic_vector(7*8-1 downto 0);

      a_wr_en_o   : out std_logic_vector(6 downto 0);
      a_rd_en_o   : out std_logic_vector(6 downto 0);
      a_rd_data_o : out std_logic_vector(7 downto 0)
  );
end addr_decode;

architecture Structural of addr_decode is

   -------------------
   -- Port A
   -------------------

   signal a_cs    : std_logic_vector(6 downto 0);
   signal a_wr_en : std_logic_vector(6 downto 0);
   signal a_rd_en : std_logic_vector(6 downto 0);

begin

   a_cs(0) <= '1' when a_addr_i(15 downto G_RAM_SIZE)  = G_RAM_MASK( 15 downto G_RAM_SIZE)  else '0';
   a_cs(1) <= '1' when a_addr_i(15 downto G_DISP_SIZE) = G_DISP_MASK(15 downto G_DISP_SIZE) else '0';
   a_cs(2) <= '1' when a_addr_i(15 downto G_MOB_SIZE)  = G_MOB_MASK( 15 downto G_MOB_SIZE)  else '0';
   a_cs(3) <= '1' when a_addr_i(15 downto G_CONF_SIZE) = G_CONF_MASK(15 downto G_CONF_SIZE) else '0';
   a_cs(4) <= '1' when a_addr_i(15 downto G_FONT_SIZE) = G_FONT_MASK(15 downto G_FONT_SIZE) else '0';
   a_cs(5) <= '1' when a_addr_i(15 downto G_ROM_SIZE)  = G_ROM_MASK( 15 downto G_ROM_SIZE)  else '0';
   a_cs(6) <= '1' when a_addr_i(15 downto G_COL_SIZE)  = G_COL_MASK( 15 downto G_COL_SIZE)  else '0';

   assert a_cs /= "0000000" report "Bus error" severity warning;

   a_wr_en <= a_cs and (6 downto 0 => a_wren_i);
   a_rd_en <= a_cs and (6 downto 0 => a_rden_i);

   a_rd_data_o <= a_rd_data_i( 7 downto  0) when a_rd_en(0) = '1' else    -- RAM
                  a_rd_data_i(15 downto  8) when a_rd_en(1) = '1' else    -- DISP
                  a_rd_data_i(23 downto 16) when a_rd_en(2) = '1' else    -- MOB
                  a_rd_data_i(31 downto 24) when a_rd_en(3) = '1' else    -- CONF
                  a_rd_data_i(39 downto 32) when a_rd_en(4) = '1' else    -- FONT
                  a_rd_data_i(47 downto 40) when a_rd_en(5) = '1' else    -- ROM
                  a_rd_data_i(55 downto 48) when a_rd_en(6) = '1' else    -- COL
                  (others => '0');

--   The below apparently is not any faster.
--   a_rd_data_o <= 
--      (a_rd_data_i( 7 downto  0) and (7 downto 0 => a_rd_en(0))) or     -- RAM
--      (a_rd_data_i(15 downto  8) and (7 downto 0 => a_rd_en(1))) or     -- DISP
--      (a_rd_data_i(23 downto 16) and (7 downto 0 => a_rd_en(2))) or     -- MOB
--      (a_rd_data_i(31 downto 24) and (7 downto 0 => a_rd_en(3))) or     -- CONF
--      (a_rd_data_i(39 downto 32) and (7 downto 0 => a_rd_en(4))) or     -- FONT
--      (a_rd_data_i(47 downto 40) and (7 downto 0 => a_rd_en(5)));       -- ROM

   a_wr_en_o <= a_wr_en;
   a_rd_en_o <= a_rd_en;

end Structural;

