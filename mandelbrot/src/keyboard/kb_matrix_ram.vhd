-- Original MEGA65 keyboard driver file by Paul Gardner-Stephen
-- see AUTHORS details and license
--
-- Modified for gbc4mega65 by sy2002 in January 2021
-- Added to MiSTer2MEGA65 based on the modified gbc4mega65 form by sy2002 in July 2021

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity kb_matrix_ram is
  port (ClkA : in std_logic;
        addressa : in integer range 0 to 15;
        dia : in std_logic_vector(7 downto 0);
        wea : in std_logic_vector(7 downto 0);
        addressb : in integer range 0 to 15;
        dob : out std_logic_vector(7 downto 0)
        );
end entity kb_matrix_ram;

architecture Behavioral of kb_matrix_ram is

  type ram_t is array (0 to 15) of std_logic_vector(7 downto 0);
  signal ram : ram_t := (others => x"FF");

begin

--process for read and write operation.
   PROCESS(ClkA)
   BEGIN
    if(rising_edge(ClkA)) then
      for i in 0 to 7 loop
        if wea(i) = '1' then
          ram(addressa)(i) <= dia(i);
          --report "Writing bit " & integer'image(i) & " of byte " & integer'image(addressa) & " with " & std_logic'image(dia(i));
        end if;
      end loop;
    end if;
   END PROCESS;
  
   PROCESS(addressb)
   BEGIN
     dob <= ram(addressb);
     --report "Reading byte " & integer'image(addressb) & " with value $" & to_hstring(ram(addressb));
   END PROCESS;

end architecture Behavioral;

