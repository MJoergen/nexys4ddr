--------------------------------------
-- The Control Logic
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ctl is
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      data_i : in  std_logic_vector( 7 downto 0);
      ctl_o  : out std_logic_vector(10 downto 0)
   );
end ctl;

architecture Structural of ctl is

   signal cnt_r  : std_logic_vector(2 downto 0);
   signal inst_r : std_logic_vector(7 downto 0);

begin

   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt_r <= cnt_r + 1;

         if rst_i = '1' then
            cnt_r <= (others => '0');
         end if;
      end if;
   end process p_cnt;

   p_inst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cnt_r = 0 then
            inst_r <= data_i;
         end if;
      end if;
   end process p_inst;

end architecture Structural;

