--------------------------------------
-- The Program Counter
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity pc is
   port (
           clk_i    : in  std_logic;
           rst_i    : in  std_logic;
           pc_o     : out std_logic_vector(15 downto 0);
           j_ena_i  : in  std_logic;
           j_addr_i : in  std_logic_vector(15 downto 0)
   );
end pc;

architecture Structural of pc is

   signal pc : std_logic_vector(15 downto 0);

begin

   p_pc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pc <= pc + 1;
         if j_ena_i = '1' then
            pc <= j_addr_i;
         end if;

         if rst_i = '1' then
            pc <= X"FC00";
         end if;
      end if;
   end process p_pc;

   pc_o <= pc;

end architecture Structural;

