library ieee;
use ieee.std_logic_1164.all;

entity display_seg is
   generic (
      G_FREQ : integer
   );
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      dp_i     : in  std_logic_vector (3 downto 0);
      seg3_i   : in  std_logic_vector (6 downto 0);  -- First segment
      seg2_i   : in  std_logic_vector (6 downto 0);  -- Second segment
      seg1_i   : in  std_logic_vector (6 downto 0);  -- Third segment
      seg0_i   : in  std_logic_vector (6 downto 0);  -- Fourth segment
      seg_ca_o : out std_logic_vector (6 downto 0);
      seg_dp_o : out std_logic;
      seg_an_o : out std_logic_vector (3 downto 0)
   );
end entity display_seg;

architecture synthesis of display_seg is

   signal clk_en : std_logic;
   signal digit  : integer range 0 to 3;

begin

   i_counter : entity work.counter
   generic map (
      G_COUNTER => G_FREQ/1000
   )
   port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      inc_i  => "000001",
      wrap_o => clk_en
   ); -- i_counter


   count: process (clk_i)
   begin
      if rising_edge(clk_i) then
         if clk_en = '1' then
            if digit = 0 then
               digit <= 3;
            else
               digit <= digit - 1;
            end if;
         end if;
      end if;
   end process;

   with digit select
      seg_dp_o <= not dp_i(3) when 3,
                  not dp_i(2) when 2,
                  not dp_i(1) when 1,
                  not dp_i(0) when others;

   with digit select
      seg_ca_o <= seg3_i when 3,
                  seg2_i when 2,
                  seg1_i when 1,
                  seg0_i when others;

   with digit select
      seg_an_o <= "0111" when 3,
                  "1011" when 2,
                  "1101" when 1,
                  "1110" when others;

end architecture synthesis;

