library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity zp is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      zp_sel_i : in  std_logic_vector(1 downto 0);
      data_i   : in  std_logic_vector(7 downto 0);
      xr_i     : in  std_logic_vector(7 downto 0);
      zp_o     : out std_logic_vector(7 downto 0)
   );
end entity zp;

architecture structural of zp is

   constant ZP_NOP    : std_logic_vector(1 downto 0) := B"00";
   constant ZP_DATA   : std_logic_vector(1 downto 0) := B"01";
   constant ZP_ADDX   : std_logic_vector(1 downto 0) := B"10";
   constant ZP_INC    : std_logic_vector(1 downto 0) := B"11";

   -- Zero-page register
   signal zp : std_logic_vector(7 downto 0);

begin

   -- 'Zp' register
   p_zp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case zp_sel_i is
               when ZP_NOP  => null;
               when ZP_DATA => zp <= data_i;
               when ZP_ADDX => zp <= zp + xr_i;
               when ZP_INC  => zp <= zp + 1;
               when others  => null;
            end case;
         end if;
      end if;
   end process p_zp;

   -- Drive output signals
   zp_o <= zp;

end architecture structural;

