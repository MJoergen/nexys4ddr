library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity xr is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      xr_sel_i : in  std_logic;
      alu_ar_i : in  std_logic_vector(7 downto 0);

      xr_o     : out std_logic_vector(7 downto 0)
   );
end entity xr;

architecture structural of xr is

   -- 'X' register
   signal xr : std_logic_vector(7 downto 0);

begin

   -- 'X' register
   xr_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if xr_sel_i = '1' then
               xr <= alu_ar_i;
            end if;
         end if;
      end if;
   end process xr_proc;

   -- Drive output signal
   xr_o <= xr;

end architecture structural;

