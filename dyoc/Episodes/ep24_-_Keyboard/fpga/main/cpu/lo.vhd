library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity lo is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      lo_sel_i : in  std_logic_vector(2 downto 0);
      data_i   : in  std_logic_vector(7 downto 0);
      hi_i     : in  std_logic_vector(7 downto 0);
      xr_i     : in  std_logic_vector(7 downto 0);
      yr_i     : in  std_logic_vector(7 downto 0);

      lo_o     : out std_logic_vector(7 downto 0)
   );
end entity lo;

architecture structural of lo is

   constant LO_NOP    : std_logic_vector(2 downto 0) := B"000";
   constant LO_DATA   : std_logic_vector(2 downto 0) := B"001";
   constant LO_ADDX   : std_logic_vector(2 downto 0) := B"010";
   constant LO_ADDY   : std_logic_vector(2 downto 0) := B"011";
   constant LO_INC    : std_logic_vector(2 downto 0) := B"100";

   -- Address Lo register
   signal lo : std_logic_vector(7 downto 0);
   
   signal hilo_addx_s : std_logic_vector(15 downto 0);
   signal hilo_addy_s : std_logic_vector(15 downto 0);
   signal hilo_inc_s  : std_logic_vector(15 downto 0);
   
begin

   hilo_addx_s <= (hi_i & lo) + xr_i;
   hilo_addy_s <= (hi_i & lo) + yr_i;
   hilo_inc_s  <= (hi_i & lo) + 1;
   
   -- 'Lo' register
   lo_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case lo_sel_i is
               when LO_NOP  => null;
               when LO_DATA => lo <= data_i;
               when LO_ADDX => lo <= hilo_addx_s(7 downto 0);
               when LO_ADDY => lo <= hilo_addy_s(7 downto 0);
               when LO_INC  => lo <= hilo_inc_s(7 downto 0);
               when others  => null;
            end case;
         end if;
      end if;
   end process lo_proc;

   -- Drive output signals
   lo_o <= lo;

end architecture structural;

