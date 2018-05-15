library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This is a generic ROM instantiation from a text file.
-- One port is read/write, and the other is read-only.

entity mem_file is
   generic (
      G_NEXYS4DDR  : boolean;
      G_ADDR_SIZE  : integer;     -- Number of bits in address
      G_DATA_SIZE  : integer;     -- Number of bits in data
      G_MEM_FILE   : string       -- Initial memory contents
   );
   port (
      a_clk_i     : in  std_logic;
      a_addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      a_wr_en_i   : in  std_logic;
      a_wr_data_i : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      a_rd_en_i   : in  std_logic;
      a_rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0);

      -- Port B only reads
      b_clk_i     : in  std_logic;
      b_addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      b_rd_en_i   : in  std_logic;
      b_rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end mem_file;

architecture Structural of mem_file is

   type t_rom is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return t_rom is
      FILE RamFile : text is in RamFileName;
      variable RamFileLine : line;
      variable RAM : t_rom := (others => (others => '0'));
   begin
      for i in t_rom'range loop
         readline (RamFile, RamFileLine);
         read (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   signal i_mem_file      : t_rom := InitRamFromFile(G_MEM_FILE);
   signal i_mem_file_copy : t_rom := InitRamFromFile(G_MEM_FILE);

   signal a_rd_data : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');
   signal b_rd_data : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

begin

   gen_nexys4ddr : if G_NEXYS4DDR generate
      -----------------
      -- Port A
      -----------------

      process (a_clk_i)
      begin
         if rising_edge(a_clk_i) then
            if a_wr_en_i = '1' then
               i_mem_file(conv_integer(a_addr_i)) <= a_wr_data_i;
            end if;
            
            if a_rd_en_i = '1' then
               a_rd_data <= i_mem_file(conv_integer(a_addr_i));
            end if;
         end if;
      end process;

      a_rd_data_o <= a_rd_data;


      -----------------
      -- Port B
      -----------------

      process (b_clk_i)
      begin
         if rising_edge(b_clk_i) then
            if b_rd_en_i = '1' then
               b_rd_data <= i_mem_file(conv_integer(b_addr_i));
            end if;
         end if;
      end process;

      b_rd_data_o <= b_rd_data;
 
   end generate gen_nexys4ddr;

   gen_basys2 : if not G_NEXYS4DDR generate
      -----------------
      -- Instance i_mem_file
      -----------------

      -- Port A : Write
      process (a_clk_i)
      begin
         if rising_edge(a_clk_i) then
            if a_wr_en_i = '1' then
               i_mem_file(conv_integer(a_addr_i)) <= a_wr_data_i;
            end if;
         end if;
      end process;

      -- Port B : Read
      process (a_clk_i)
      begin
         if rising_edge(a_clk_i) then
            if a_rd_en_i = '1' then
               a_rd_data <= i_mem_file(conv_integer(a_addr_i));
            end if;
         end if;
      end process;

      a_rd_data_o <= a_rd_data;


      -----------------
      -- Instance i_mem_file_copy
      -----------------

      -- Port A : Write
      process (a_clk_i)
      begin
         if rising_edge(a_clk_i) then
            if a_wr_en_i = '1' then
               i_mem_file_copy(conv_integer(a_addr_i)) <= a_wr_data_i;
            end if;
         end if;
      end process;

      -- Port B : Read
      process (b_clk_i)
      begin
         if rising_edge(b_clk_i) then
            if b_rd_en_i = '1' then
               b_rd_data <= i_mem_file_copy(conv_integer(b_addr_i));
            end if;
         end if;
      end process;

      b_rd_data_o <= b_rd_data;
 
   end generate gen_basys2;

end Structural;

