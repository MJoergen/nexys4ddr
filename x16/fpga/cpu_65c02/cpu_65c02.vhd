library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module of the CPU 65C02.

entity cpu_65c02 is
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      nmi_i  : in  std_logic;
      irq_i  : in  std_logic;
      addr_o : out std_logic_vector(15 downto 0);
      data_i : in  std_logic_vector( 7 downto 0);
      wren_o : out std_logic;
      rden_o : out std_logic;
      data_o : out std_logic_vector( 7 downto 0)
   );
end cpu_65c02;

architecture structural of cpu_65c02 is

begin

   wren_o <= '0';
   rden_o <= '0';
   addr_o <= (others => '0');
   data_o <= (others => '0');

end architecture structural;

