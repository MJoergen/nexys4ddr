library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity mem is
   generic (
      -- Number of bits in the address bus. The size of the memory will
      -- be 2**G_ADDR_BITS bytes.
      G_ADDR_BITS : integer
   );
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      wren_i : in  std_logic;
      data_i : in  std_logic_vector(7 downto 0);
      data_o : out std_logic_vector(7 downto 0)
   );
end mem;

architecture Structural of mem is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 2**G_ADDR_BITS-1) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal mem : mem_t := (
      X"A1",   -- Just some random data for now.
      X"B2",
      X"C3",
      X"D4",
      X"E5",
      X"F6",
      X"1A",
      X"2B",
      X"3C",
      X"4D",
      X"5E",
      X"6F",
      others => X"00");

   -- Data read from memory.
   signal data : std_logic_vector(7 downto 0);

begin

   -- Write process
   p_mem : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            mem(conv_integer(addr_i)) <= data_i;
         end if;
      end if;
   end process p_mem;

   -- Read process
   p_data : process (clk_i)
   begin
      if falling_edge(clk_i) then
         data <= mem(conv_integer(addr_i));
      end if;
   end process p_data;

   -- Drive output signals
   data_o <= data;

end Structural;

