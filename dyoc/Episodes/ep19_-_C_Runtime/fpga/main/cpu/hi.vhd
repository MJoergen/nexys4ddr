library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity hi is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      hi_sel_i : in  std_logic_vector(2 downto 0);
      data_i   : in  std_logic_vector(7 downto 0);
      lo_i     : in  std_logic_vector(7 downto 0);
      xr_i     : in  std_logic_vector(7 downto 0);
      yr_i     : in  std_logic_vector(7 downto 0);

      hi_o     : out std_logic_vector(7 downto 0)
   );
end entity hi;

architecture structural of hi is

   constant HI_NOP    : std_logic_vector(2 downto 0) := B"000";
   constant HI_DATA   : std_logic_vector(2 downto 0) := B"001";
   constant HI_ADDX   : std_logic_vector(2 downto 0) := B"010";
   constant HI_ADDY   : std_logic_vector(2 downto 0) := B"011";
   constant HI_INC    : std_logic_vector(2 downto 0) := B"100";

   -- Address Hi register
   signal hi : std_logic_vector(7 downto 0);

   signal hilo_addx_s : std_logic_vector(15 downto 0);
   signal hilo_addy_s : std_logic_vector(15 downto 0);
   signal hilo_inc_s  : std_logic_vector(15 downto 0);
   
begin

   hilo_addx_s <= (hi & lo_i) + xr_i;
   hilo_addy_s <= (hi & lo_i) + yr_i;
   hilo_inc_s  <= (hi & lo_i) + 1;
   
   -- 'Hi' register
   hi_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case hi_sel_i is
               when HI_NOP  => null;
               when HI_DATA => hi <= data_i;
               when HI_ADDX => hi <= hilo_addx_s(15 downto 8);
               when HI_ADDY => hi <= hilo_addy_s(15 downto 8);
               when HI_INC  => hi <= hilo_inc_s(15 downto 8);
               when others  => null;
            end case;
         end if;
      end if;
   end process hi_proc;

   -- Drive output signals
   hi_o <= hi;

end architecture structural;

