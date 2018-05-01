library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mem is
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector(15 downto 0);
      wren_i : in  std_logic;
      data_i : in  std_logic_vector(7 downto 0);
      data_o : out std_logic_vector(7 downto 0)
   );
end mem;

architecture Structural of mem is

   type t_mem is array (0 to 65535) of std_logic_vector(7 downto 0);

   signal i_mem : t_mem := (
      X"A9",   -- LDA #
      X"07",

      X"AD",   -- LDA a
      X"02",
      X"00",

      X"8D",   -- STA a
      X"08",
      X"00",

      X"8D",   -- STA a
      X"08",
      X"00",

      X"4C",   -- JMP a
      X"02",
      X"00",

      others => X"00");

begin

   -----------------
   -- Port A
   -----------------

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            i_mem(conv_integer(addr_i)) <= data_i;
         end if;
      end if;
   end process;

   data_o <= i_mem(conv_integer(addr_i));

end Structural;

