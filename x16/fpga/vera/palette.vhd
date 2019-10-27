library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a file containing the palette memory.
-- A performs a mapping from 8-bit values to 12-bit colours.
-- TODO: Add a write port.

entity palette is
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector( 7 downto 0);
      data_o : out std_logic_vector(11 downto 0)
   );
end palette;

architecture rtl of palette is

   -- This defines a type containing an array of words.
   type mem_t is array (0 to 255) of std_logic_vector(11 downto 0);

   -- Default palette. Copied from x16-emulator.
   signal mem_r : mem_t := ( 
      X"000", X"FFF", X"800", X"AFE", X"C4C", X"0C5", X"00A", X"EE7",
      X"D85", X"640", X"F77", X"333", X"777", X"AF6", X"08F", X"BBB",
      X"000", X"111", X"222", X"333", X"444", X"555", X"666", X"777",
      X"888", X"999", X"AAA", X"BBB", X"CCC", X"DDD", X"EEE", X"FFF",
      X"211", X"433", X"644", X"866", X"A88", X"C99", X"FBB", X"211",
      X"422", X"633", X"844", X"A55", X"C66", X"F77", X"200", X"411",
      X"611", X"822", X"A22", X"C33", X"F33", X"200", X"400", X"600",
      X"800", X"A00", X"C00", X"F00", X"221", X"443", X"664", X"886",
      X"AA8", X"CC9", X"FEB", X"211", X"432", X"653", X"874", X"A95",
      X"CB6", X"FD7", X"210", X"431", X"651", X"862", X"A82", X"CA3",
      X"FC3", X"210", X"430", X"640", X"860", X"A80", X"C90", X"FB0",
      X"121", X"343", X"564", X"786", X"9A8", X"BC9", X"DFB", X"121",
      X"342", X"463", X"684", X"8A5", X"9C6", X"BF7", X"120", X"241",
      X"461", X"582", X"6A2", X"8C3", X"9F3", X"120", X"240", X"360",
      X"480", X"5A0", X"6C0", X"7F0", X"121", X"343", X"465", X"686",
      X"8A8", X"9CA", X"BFC", X"121", X"242", X"364", X"485", X"5A6",
      X"6C8", X"7F9", X"020", X"141", X"162", X"283", X"2A4", X"3C5",
      X"3F6", X"020", X"041", X"061", X"082", X"0A2", X"0C3", X"0F3",
      X"122", X"344", X"466", X"688", X"8AA", X"9CC", X"BFF", X"122",
      X"244", X"366", X"488", X"5AA", X"6CC", X"7FF", X"022", X"144",
      X"166", X"288", X"2AA", X"3CC", X"3FF", X"022", X"044", X"066",
      X"088", X"0AA", X"0CC", X"0FF", X"112", X"334", X"456", X"668",
      X"88A", X"9AC", X"BCF", X"112", X"224", X"346", X"458", X"56A",
      X"68C", X"79F", X"002", X"114", X"126", X"238", X"24A", X"35C",
      X"36F", X"002", X"014", X"016", X"028", X"02A", X"03C", X"03F",
      X"112", X"334", X"546", X"768", X"98A", X"B9C", X"DBF", X"112",
      X"324", X"436", X"648", X"85A", X"96C", X"B7F", X"102", X"214",
      X"416", X"528", X"62A", X"83C", X"93F", X"102", X"204", X"306",
      X"408", X"50A", X"60C", X"70F", X"212", X"434", X"646", X"868",
      X"A8A", X"C9C", X"FBE", X"211", X"423", X"635", X"847", X"A59",
      X"C6B", X"F7D", X"201", X"413", X"615", X"826", X"A28", X"C3A",
      X"F3C", X"201", X"403", X"604", X"806", X"A08", X"C09", X"F0B"
   );

begin

   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         data_o <= mem_r(to_integer(addr_i));
      end if;
   end process p_read;

end rtl;

