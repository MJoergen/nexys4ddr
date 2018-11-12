library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity pc is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      pc_sel_i : in  std_logic_vector( 5 downto 0);
      hi_i     : in  std_logic_vector( 7 downto 0);
      lo_i     : in  std_logic_vector( 7 downto 0);
      sr_i     : in  std_logic_vector( 7 downto 0);
      data_i   : in  std_logic_vector( 7 downto 0);

      pc_o     : out std_logic_vector(15 downto 0)
   );
end entity pc;

architecture structural of pc is

   constant PC_NOP : std_logic_vector(2 downto 0) := B"000";
   constant PC_INC : std_logic_vector(2 downto 0) := B"001";
   constant PC_HL  : std_logic_vector(2 downto 0) := B"010";
   constant PC_HL1 : std_logic_vector(2 downto 0) := B"011";
   constant PC_SR  : std_logic_vector(2 downto 0) := B"100";
   constant PC_BPL : std_logic_vector(2 downto 0) := B"000";
   constant PC_BMI : std_logic_vector(2 downto 0) := B"001";
   constant PC_BVC : std_logic_vector(2 downto 0) := B"010";
   constant PC_BVS : std_logic_vector(2 downto 0) := B"011";
   constant PC_BCC : std_logic_vector(2 downto 0) := B"100";
   constant PC_BCS : std_logic_vector(2 downto 0) := B"101";
   constant PC_BNE : std_logic_vector(2 downto 0) := B"110";
   constant PC_BEQ : std_logic_vector(2 downto 0) := B"111";
   
   -- The Status Register contains: SV-BDIZC
   constant SR_C : integer := 0;
   constant SR_Z : integer := 1;
   constant SR_V : integer := 6;
   constant SR_S : integer := 7;

   signal pc : std_logic_vector(15 downto 0) := X"F800";

   -- Convert signed 8-bit number to signed 16-bit number
   function sign_extend(arg : std_logic_vector(7 downto 0))
   return std_logic_vector is
      variable res : std_logic_vector(15 downto 0);
   begin
      res := (others => arg(7)); -- Copy sign bit to all bits.
      res(7 downto 0) := arg;
      return res;
   end function sign_extend;

begin

   -- Program Counter
   pc_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case pc_sel_i(2 downto 0) is
               when PC_NOP => null;
               when PC_INC => pc <= pc + 1;
               when PC_HL  => pc <= hi_i & lo_i;
               when PC_HL1 => pc <= (hi_i & lo_i) + 1;
               when PC_SR  =>
                  if (pc_sel_i(5 downto 3) = PC_BPL and sr_i(SR_S) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BMI and sr_i(SR_S) = '1') or
                     (pc_sel_i(5 downto 3) = PC_BVC and sr_i(SR_V) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BVS and sr_i(SR_V) = '1') or
                     (pc_sel_i(5 downto 3) = PC_BCC and sr_i(SR_C) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BCS and sr_i(SR_C) = '1') or
                     (pc_sel_i(5 downto 3) = PC_BNE and sr_i(SR_Z) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BEQ and sr_i(SR_Z) = '1') then
                     pc <= pc + 1 + sign_extend(data_i);
                  else
                     pc <= pc + 1;  -- If branch is not taken, just go to the next instruction.
                  end if;
               when others => null;
            end case;
         end if;
      end if;
   end process pc_proc;


   -- Drive output signal
   pc_o <= pc;

end architecture structural;

