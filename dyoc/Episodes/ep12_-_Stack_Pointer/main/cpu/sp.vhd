library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity sp is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      sp_sel_i : in  std_logic_vector(1 downto 0);

      sp_o     : out std_logic_vector(7 downto 0)
   );
end entity sp;

architecture structural of sp is

   constant SP_NOP : std_logic_vector(1 downto 0) := B"00";
   constant SP_INC : std_logic_vector(1 downto 0) := B"01";
   constant SP_DEC : std_logic_vector(1 downto 0) := B"10";

   -- Stack pointer
   signal sp : std_logic_vector(7 downto 0) := X"FF";

begin

   -- Stack Pointer
   sp_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case sp_sel_i is
               when SP_NOP => null;
               when SP_INC => sp <= sp + 1;
               when SP_DEC => sp <= sp - 1;
               when others => null;
            end case;
         end if;
      end if;
   end process sp_proc;

   -- Drive output signal
   sp_o <= sp;

end architecture structural;

