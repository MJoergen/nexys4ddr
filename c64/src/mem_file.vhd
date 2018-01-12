library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This is a generic memory instantiation from a text file.
-- It has separate read and write ports with tristate buffers.
-- You can choose whether to have registers on read port.
-- If yes, the memory will likely be implemented in BRAM.
-- If no, it will likely be implemented in LUTRAM.
-- Additionally, you can choose whether the register
-- on the read port is active on rising or falling clock edge.
-- The write port is always active on the rising edge.
entity mem_file is

   generic (
      G_ADDR_SIZE  : integer;     -- Number of bits in address
      G_DATA_SIZE  : integer;     -- Number of bits in data
      G_DO_RD_REG  : boolean;     -- Register on read port?
      G_RD_CLK_RIS : boolean;     -- Rising clock on read port?
      G_CHAR_FILE  : string       -- Initial memory contents
   );
   port (
      wr_clk_i  : in  std_logic;
      wr_en_i   : in  std_logic;
      wr_addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wr_data_i : in  std_logic_vector(G_DATA_SIZE-1 downto 0);

      rd_clk_i  : in  std_logic;
      rd_en_i   : in  std_logic;
      rd_addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );

end mem_file;

architecture Structural of mem_file is

   type t_mem is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return t_mem is
      FILE RamFile : text is in RamFileName;
      variable RamFileLine : line;
      variable RAM : t_mem := (others => (others => '0'));
   begin
      for i in t_mem'range loop
         readline (RamFile, RamFileLine);
         read (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   signal mem     : t_mem := InitRamFromFile(G_CHAR_FILE);

   signal rd_data : std_logic_vector(G_DATA_SIZE-1 downto 0);

begin

   -------------
   -- Write port
   -------------

   p_write : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then
         if wr_en_i = '1' then
            mem(conv_integer(wr_addr_i)) <= wr_data_i;
         end if;
      end if;
   end process p_write;


   ------------
   -- Read port
   ------------

   rd_data <= mem(conv_integer(rd_addr_i));

   gen_no_reg: if G_DO_RD_REG = false  generate
      rd_data_o <= rd_data when rd_en_i = '1' else (others => 'Z');
   end generate gen_no_reg;

   gen_rising_reg: if G_DO_RD_REG = true and G_RD_CLK_RIS = true  generate
      process (rd_clk_i)
      begin
         if rising_edge(rd_clk_i) then
            rd_data_o <= (others => 'Z');
            if rd_en_i = '1' then
               rd_data_o <= rd_data;
            end if;
         end if;
      end process;
   end generate gen_rising_reg;

   gen_falling_reg: if G_DO_RD_REG = true and G_RD_CLK_RIS = false  generate
      process (rd_clk_i)
      begin
         if falling_edge(rd_clk_i) then
            rd_data_o <= (others => 'Z');
            if rd_en_i = '1' then
               rd_data_o <= rd_data;
            end if;
         end if;
      end process;
   end generate gen_falling_reg;

end Structural;

