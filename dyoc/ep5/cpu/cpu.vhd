library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity cpu is
   port (
      clk_i   : in  std_logic;

      addr_o  : out std_logic_vector(15 downto 0);
      data_i  : in  std_logic_vector(7 downto 0);
      data_o  : out std_logic_vector(7 downto 0);
      wren_o  : out std_logic;

      debug_o : out std_logic_vector(39 downto 0)
   );
end entity cpu;

architecture structural of cpu is

   -----------------
   -- Data path
   -----------------

   -- Program Counter
   signal pc : std_logic_vector(15 downto 0) := (others => '0');

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0);
   signal a_sel : std_logic;
   

   -----------------
   -- Control path
   -----------------

   -- Instruction Register
   signal ir : std_logic_vector(7 downto 0);

   -- Instruction Cycle Counter
   signal cnt : std_logic_vector(2 downto 0) := (others => '0');

   -- Asserted on last clock cycle of a given instruction.
   signal last : std_logic;

begin

   -----------------
   -- Debug Output
   -----------------

   debug_o(15 downto  0) <= pc;  -- Two bytes
   debug_o(23 downto 16) <= ar;  -- One byte
   debug_o(31 downto 24) <= ir;  -- One byte
   debug_o(34 downto 32) <= cnt; -- One byte
   debug_o(39 downto 35) <= (others => '0');


   -----------------
   -- Data path
   -----------------

   addr_o <= pc;
   wren_o <= '0';
   data_o <= (others => '0');

   -- Program Counter
   p_pc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pc <= pc + 1;                 -- Increment program counter every clock cycle
      end if;
   end process p_pc;

   -- 'A' register
   p_ar : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if a_sel = '1' then
            ar <= data_i;
         end if;
      end if;
   end process p_ar;


   -----------------
   -- Control path
   -----------------

   -- Instruction Cycle Counter
   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if last = '1' then
            cnt <= (others => '0');    -- Reset counter at end of every instruction.
         else
            cnt <= cnt + 1;
         end if;
      end if;
   end process p_cnt;

   -- Instruction Register
   p_ir : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cnt = 0 then
            ir <= data_i;              -- Only load instruction register at beginning of instruction.
         end if;
      end if;
   end process p_ir;

   -- Generate Control Signals
   a_sel <= '1' when cnt = 1 and ir = X"A9" else   -- Load 'A' register in second cycle of the "LDA #" instruction.
            '0';

   last <= '1' when cnt = 1 and ir = X"A9" else    -- The "LDA #" instruction only lasts two clock cycles.
           '0';

end architecture structural;

