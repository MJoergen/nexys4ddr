library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block contains the entire Video RAM.

-- At this early stage, I've only allocated 64 kB.
-- So only the area between 0x00000 - 0x0FFFF is valid.

entity vram is
   port (
      -- CPU port
      cpu_clk_i     : in  std_logic;
      cpu_addr_i    : in  std_logic_vector(16 downto 0);  -- 17 bit address allows for 128 kB
      cpu_wr_en_i   : in  std_logic;
      cpu_wr_data_i : in  std_logic_vector( 7 downto 0);
      cpu_rd_en_i   : in  std_logic;
      cpu_rd_data_o : out std_logic_vector( 7 downto 0);
      -- VGA port
      vga_clk_i     : in  std_logic;
      vga_rd_addr_i : in  std_logic_vector(16 downto 0);  -- 17 bit address allows for 128 kB
      vga_rd_en_i   : in  std_logic;
      vga_rd_data_o : out std_logic_vector( 7 downto 0)
   );
end vram;

architecture structural of vram is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 65535) of std_logic_vector(7 downto 0); -- TBD: Change size to 128 kB.

   -- Initialize memory contents
   signal mem_r : mem_t := (others => X"66");   -- Default value. TBD: This is a hack to get a blue background colour.

begin

   -- CPU access
   p_cpu : process (cpu_clk_i)
   begin
      if falling_edge(cpu_clk_i) then
         if cpu_wr_en_i = '1' then
            mem_r(to_integer(cpu_addr_i(15 downto 0))) <= cpu_wr_data_i;  -- TBD: Currently only supports 64 kB.
         end if;

         if cpu_rd_en_i = '1' then
            cpu_rd_data_o <= mem_r(to_integer(cpu_addr_i(15 downto 0)));  -- TBD: Currently only supports 64 kB.
         end if;
      end if;
   end process p_cpu;

   -- VGA access.
   p_vga : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if vga_rd_en_i = '1' then
            vga_rd_data_o <= mem_r(to_integer(vga_rd_addr_i(15 downto 0)));  -- TBD: Currently only supports 64 kB.
         end if;
      end if;
   end process p_vga;

end structural;

