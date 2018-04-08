library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This memory reads on falling clock edge.

entity dmem is

   generic (
      G_ADDR_SIZE : integer;      -- Number of bits in address
      G_DATA_SIZE : integer;      -- Number of bits in data
      G_MEM_VAL   : integer := 0  -- Initial value of memory contents
   );
   port (
      clk_i : in  std_logic;
      rst_i : in  std_logic;

      addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wr_en_i   : in  std_logic;
      wr_data_i : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      rd_en_i   : in  std_logic;
      rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );

end dmem;

architecture Structural of dmem is

   type t_mem is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   signal i_dmem : t_mem := (others => std_logic_vector(to_unsigned(G_MEM_VAL, G_DATA_SIZE)));

   signal rd_data : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

begin

   -- Write process, rising clock edge
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            i_dmem(conv_integer(addr_i)) <= wr_data_i;
         end if;
      end if;
   end process;

   -- Read process, falling clock edge
   process (clk_i)
   begin
      if falling_edge(clk_i) then
         if rd_en_i = '1' then
            rd_data <= i_dmem(conv_integer(addr_i));
         end if;
      end if;
   end process;

   rd_data_o <= rd_data;

end Structural;

