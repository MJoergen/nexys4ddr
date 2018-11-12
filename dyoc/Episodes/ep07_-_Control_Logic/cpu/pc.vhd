library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity pc is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      pc_sel_i : in  std_logic_vector( 1 downto 0);
      hi_i     : in  std_logic_vector( 7 downto 0);
      lo_i     : in  std_logic_vector( 7 downto 0);

      pc_o     : out std_logic_vector(15 downto 0)
   );
end entity pc;

architecture structural of pc is

   constant PC_NOP : std_logic_vector(1 downto 0) := B"00";
   constant PC_INC : std_logic_vector(1 downto 0) := B"01";
   constant PC_HL  : std_logic_vector(1 downto 0) := B"10";
   
   signal pc : std_logic_vector(15 downto 0) := (others => '0');

begin

   -- Program Counter
   pc_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case pc_sel_i is
               when PC_NOP => null;
               when PC_INC => pc <= pc + 1;
               when PC_HL  => pc <= hi_i & lo_i;
               when others => null;
            end case;
         end if;
      end if;
   end process pc_proc;

   -- Drive output signal
   pc_o <= pc;

end architecture structural;

