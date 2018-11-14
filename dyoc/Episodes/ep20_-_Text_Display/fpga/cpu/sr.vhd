library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity sr is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      sr_sel_i : in  std_logic_vector(3 downto 0);
      alu_sr_i : in  std_logic_vector(7 downto 0);
      data_i   : in  std_logic_vector(7 downto 0);

      sr_o     : out std_logic_vector(7 downto 0)
   );
end entity sr;

architecture structural of sr is

   -- The Status Register contains: SV-BDIZC
   constant SR_C : integer := 0;
   constant SR_Z : integer := 1;
   constant SR_I : integer := 2;
   constant SR_D : integer := 3;
   constant SR_B : integer := 4;
   constant SR_R : integer := 5;    -- Bit 5 is reserved.
   constant SR_V : integer := 6;
   constant SR_S : integer := 7;

   constant SR_NOP  : std_logic_vector(3 downto 0) := B"0000";
   constant SR_ALU  : std_logic_vector(3 downto 0) := B"0001";
   constant SR_DATA : std_logic_vector(3 downto 0) := B"0010";
   constant SR_CLC  : std_logic_vector(3 downto 0) := B"1000";
   constant SR_SEC  : std_logic_vector(3 downto 0) := B"1001";
   constant SR_CLI  : std_logic_vector(3 downto 0) := B"1010";
   constant SR_SEI  : std_logic_vector(3 downto 0) := B"1011";
   constant SR_CLV  : std_logic_vector(3 downto 0) := B"1100";
   constant SR_CLD  : std_logic_vector(3 downto 0) := B"1110";
   constant SR_SED  : std_logic_vector(3 downto 0) := B"1111";

   -- Status register
   signal sr : std_logic_vector(7 downto 0) := X"00";

begin

   -- Status register
   sr_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case sr_sel_i is
               when SR_NOP  => null;
               when SR_ALU  => sr <= alu_sr_i;
               when SR_DATA => sr <= data_i;
               when SR_CLC  => sr(SR_C) <= '0';
               when SR_SEC  => sr(SR_C) <= '1';
               when SR_CLI  => sr(SR_I) <= '0';
               when SR_SEI  => sr(SR_I) <= '1';
               when SR_CLV  => sr(SR_V) <= '0';
               when SR_CLD  => sr(SR_D) <= '0';
               when SR_SED  => sr(SR_D) <= '1';
               when others => null;
            end case;
         end if;
      end if;
   end process sr_proc;

   -- Drive output signal
   sr_o <= sr;

end architecture structural;

