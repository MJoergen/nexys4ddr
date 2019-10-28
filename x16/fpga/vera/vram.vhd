library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block contain the entire Video RAM.

-- At this early stage, I've only allocated 64 kB.
-- So only the area between 0x00000 - 0x0FFFF is valid.

entity vram is
   port (
      clk_i     : in  std_logic;
      -- Write port
      wr_addr_i : in  std_logic_vector(16 downto 0);  -- 17 bit address allows for 128 kB
      wr_en_i   : in  std_logic;
      wr_data_i : in  std_logic_vector( 7 downto 0);
      -- Read port
      rd_addr_i : in  std_logic_vector(16 downto 0);  -- 17 bit address allows for 128 kB
      rd_en_i   : in  std_logic;
      rd_data_o : out std_logic_vector( 7 downto 0)
   );
end vram;

architecture structural of vram is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 65535) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal mem_r : mem_t := (others => (others => '0'));

begin

   -- Write process
   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            mem_r(to_integer(wr_addr_i(15 downto 0))) <= wr_data_i;
         end if;
      end if;
   end process p_write;

   -- Read process.
   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rd_en_i = '1' then
            rd_data_o <= mem_r(to_integer(rd_addr_i(15 downto 0)));
         end if;
      end if;
   end process p_read;

end structural;

