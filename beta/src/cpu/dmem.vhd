library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity dmem is
   port (
      clk_i  : in  std_logic;
      ma_i   : in  std_logic_vector(31 downto 0);  -- Memory Address
      moe_i  : in  std_logic;                      -- Memory Output Enable
      mrd_o  : out std_logic_vector(31 downto 0);  -- Memory Read Data
      wr_i   : in  std_logic;                      -- Write
      mwd_i  : in  std_logic_vector(31 downto 0)   -- Memory Write Data
   );
end dmem;

architecture Structural of dmem is

   -- 1 KW = 4 KB of data memory.
   type MEM_TYPE is array (0 to 1023) of std_logic_vector(31 downto 0);
   signal memory : MEM_TYPE := ( others => (others => '0'));

begin

   --assert ma_i(1 downto 0) = "00" report "Misaligned instruction" severity failure;

   -- 1 combinational read port.
   process (ma_i, moe_i)
   begin
      mrd_o <= (others => 'Z');
      if moe_i = '1' then
         mrd_o <= memory(conv_integer(ma_i(31 downto 2)));
      end if;
   end process;

   -- 1 clocked write port.
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_i = '1' then
            memory(conv_integer(ma_i(31 downto 2))) <= mwd_i;
         end if;
      end if;
   end process;

end Structural;

