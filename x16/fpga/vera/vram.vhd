library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block contain the entire Video RAM.

-- At this early stage, I've only allocated 64 kB.
-- So only the area between 0x00000 - 0x0FFFF is valid.

entity vram is
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector(16 downto 0);  -- 17 bit address allows for 128 kB
      data_i : in  std_logic_vector( 7 downto 0);
      wren_i : in  std_logic;
      data_o : out std_logic_vector( 7 downto 0)
   );
end vram;

architecture structural of vram is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 65535) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal mem_r : mem_t := (others => (others => '0'));

   -- Data read from memory.
   signal data_r : std_logic_vector(7 downto 0);

begin

   -- Write process
   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            mem_r(to_integer(addr_i(15 downto 0))) <= data_i;
         end if;
      end if;
   end process p_write;

   -- Read process.
   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         data_r <= mem_r(to_integer(addr_i(15 downto 0)));
      end if;
   end process p_read;

   -- Drive output signals
   data_o <= data_r;

end structural;

