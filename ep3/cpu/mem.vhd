library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mem is
   generic (
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

   -- Just 2 kBytes of memory.
   type t_mem is array (0 to 2**G_ADDR_BITS-1) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal i_mem : t_mem := (
      X"AA",
      X"BB",
      X"CC",
      X"DD",
      X"EE",
      X"FF",
      others => X"00");

begin

   -- The write process is clocked
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            i_mem(conv_integer(addr_i)) <= data_i;
         end if;
      end if;
   end process;

   -- The read process is combinatorial
   data_o <= i_mem(conv_integer(addr_i));

end Structural;

