library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity imem is
   port (
      ia_i : in  std_logic_vector(31 downto 0);  -- Instruction Address
      id_o : out std_logic_vector(31 downto 0)   -- Instruction Data
   );
end imem;

architecture Structural of imem is

   -- 1 KW = 4 KB of instruction memory.
   type MEM_TYPE is array (0 to 1023) of std_logic_vector(31 downto 0);
   signal memory : MEM_TYPE := (
      X"A01FF800", -- AND (r31, r31, r0)  
      X"903FF800", -- CMPEQ (r31, r31, r1)
      X"80410800", -- ADD (r1, r1, r2)    
      X"A4620800", -- OR (r2, r1, r3)     
      others => (others => '0'));

begin

   --assert ia_i(1 downto 0) = "00" report "Misaligned instruction" severity failure;

   -- 1 combinational read port.
   id_o <= memory(conv_integer(ia_i(31 downto 2)));

end Structural;

