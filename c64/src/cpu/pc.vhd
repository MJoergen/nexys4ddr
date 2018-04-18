--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output, but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity pc is
   port (
      -- Clock
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;

      wr_pc_i : in  std_logic_vector( 5 downto 0);
      sr_i    : in  std_logic_vector( 7 downto 0);
      data_i  : in  std_logic_vector( 7 downto 0);
      addr_i  : in  std_logic_vector(15 downto 0);

      pc_o    : out std_logic_vector(15 downto 0)
   );
end pc;

architecture Structural of pc is

   signal pc_r : std_logic_vector(15 downto 0);

begin

   -- Program Counter register
   p_pc : process (clk_i)
      function sign_extend(arg : std_logic_vector(7 downto 0))
      return std_logic_vector is
         variable res : std_logic_vector(15 downto 0);
      begin
         res := (others => arg(7)); -- Copy sign bit to all bits.
         res(7 downto 0) := arg;
         return res;
      end function sign_extend;
   begin
      if rising_edge(clk_i) then
         if wr_pc_i(0) = '1' then
            case wr_pc_i(2 downto 1) is
               when "00" =>
                  pc_r <= pc_r + 1;                          -- Used during instruction fetch
               when "01" =>
                  pc_r <= addr_i;                            -- Used during JSR
               when "10" =>
                  pc_r <= data_i & addr_i(7 downto 0);       -- Used during jump absolute
               when "11" =>
                  pc_r <= pc_r + 1;                          -- Used during branch conditional
                  if (wr_pc_i(5 downto 3) = "000" and sr_i(7) = '0') or
                     (wr_pc_i(5 downto 3) = "001" and sr_i(7) = '1') or
                     (wr_pc_i(5 downto 3) = "010" and sr_i(6) = '0') or
                     (wr_pc_i(5 downto 3) = "011" and sr_i(6) = '1') or
                     (wr_pc_i(5 downto 3) = "100" and sr_i(0) = '0') or
                     (wr_pc_i(5 downto 3) = "101" and sr_i(0) = '1') or
                     (wr_pc_i(5 downto 3) = "110" and sr_i(1) = '0') or
                     (wr_pc_i(5 downto 3) = "111" and sr_i(1) = '1') then
                     pc_r <= pc_r + 1 + sign_extend(data_i);
                  end if;
               when others => null;
            end case;
         end if;
      end if;
   end process p_pc;

   -----------------------
   -- Drive output signals
   -----------------------

   pc_o <= pc_r;

end Structural;

