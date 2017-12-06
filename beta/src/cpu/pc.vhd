library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pc is
   port (
      cpu_clk_i   : in  std_logic;
      cpu_clken_i : in  std_logic;
      rstn_i      : in  std_logic;
      ia_o        : out std_logic_vector(31 downto 0)
   );
end pc;

architecture Structural of pc is

   signal ia : std_logic_vector(31 downto 0);

begin

   -- Program Counter aka Instruction Address
   p_ia : process (cpu_clk_i)
   begin
      if rising_edge(cpu_clk_i) then
         if cpu_clken_i = '1' then
            ia <= ia + 4;

         end if;
         if rstn_i = '0' then
            ia <= (others => '0');
         end if;
      end if;
   end process p_ia;

   ia_o <= ia;

end Structural;

