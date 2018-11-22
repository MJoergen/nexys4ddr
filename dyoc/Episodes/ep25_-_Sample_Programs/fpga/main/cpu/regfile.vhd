library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity regfile is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;

      ar_sel_i : in  std_logic;
      xr_sel_i : in  std_logic;
      yr_sel_i : in  std_logic;
      sp_sel_i : in  std_logic_vector(1 downto 0);
      val_i    : in  std_logic_vector(7 downto 0);

      ar_o     : out std_logic_vector(7 downto 0);
      xr_o     : out std_logic_vector(7 downto 0);
      yr_o     : out std_logic_vector(7 downto 0);
      sp_o     : out std_logic_vector(7 downto 0)
   );
end entity regfile;

architecture structural of regfile is

   constant SP_NOP    : std_logic_vector(1 downto 0) := B"00";
   constant SP_INC    : std_logic_vector(1 downto 0) := B"01";
   constant SP_DEC    : std_logic_vector(1 downto 0) := B"10";
   constant SP_XR     : std_logic_vector(1 downto 0) := B"11";
   --
   constant REG_AR    : std_logic_vector(1 downto 0) := B"00";
   constant REG_XR    : std_logic_vector(1 downto 0) := B"01";
   constant REG_YR    : std_logic_vector(1 downto 0) := B"10";
   constant REG_SP    : std_logic_vector(1 downto 0) := B"11";

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0) := (others => '0');

   -- 'X' register
   signal xr : std_logic_vector(7 downto 0) := (others => '0');

   -- 'Y' register
   signal yr : std_logic_vector(7 downto 0) := (others => '0');

   -- Stack Pointer
   signal sp : std_logic_vector(7 downto 0) := X"FF";

begin

   -- 'A' register
   p_ar : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if ar_sel_i = '1' then
               ar <= val_i;
            end if;
         end if;
      end if;
   end process p_ar;

   -- 'X' register
   p_xr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if xr_sel_i = '1' then
               xr <= val_i;
            end if;
         end if;
      end if;
   end process p_xr;

   -- 'Y' register
   p_yr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if yr_sel_i = '1' then
               yr <= val_i;
            end if;
         end if;
      end if;
   end process p_yr;

   -- Stack Pointer
   p_sp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case sp_sel_i is
               when SP_NOP => null;
               when SP_INC => sp <= sp + 1;
               when SP_DEC => sp <= sp - 1;
               when SP_XR  => sp <= xr;
               when others => null;
            end case;
         end if;
      end if;
   end process p_sp;

   -- Drive output signals
   ar_o <= ar;
   xr_o <= xr;
   yr_o <= yr;
   sp_o <= sp;

end architecture structural;

