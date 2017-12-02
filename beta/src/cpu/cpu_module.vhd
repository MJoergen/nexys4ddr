library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cpu_module is
   port (
      -- Clock
      clk_i : in  std_logic;                    -- 100 MHz
      val_o : out std_logic_vector(31 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

   -- Program counter
   signal pc : std_logic_vector(31 downto 0) := (others => '0');

begin

   p_pc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pc <= pc + 1;
      end if;
   end process p_pc;

   val_o <= pc;
 
end Structural;

