library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity ctl is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;

      data_i   : in  std_logic_vector(7 downto 0);

      ar_sel_o : out std_logic;

      debug_o  : out std_logic_vector(15 downto 0)
   );
end entity ctl;

architecture structural of ctl is

   -- Instruction Register
   signal ir : std_logic_vector(7 downto 0);

   -- Instruction Cycle Counter
   signal cnt : std_logic_vector(2 downto 0) := (others => '0');

   -- Asserted on last clock cycle of a given instruction.
   signal last : std_logic;

begin

   -- Instruction Cycle Counter
   cnt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if last = '1' then
               cnt <= (others => '0');    -- Reset counter at end of every instruction.
            else
               cnt <= cnt + 1;
            end if;
         end if;
      end if;
   end process cnt_proc;

   -- Instruction Register
   ir_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if cnt = 0 then
               ir <= data_i;              -- Only load instruction register at beginning of instruction.
            end if;
         end if;
      end if;
   end process ir_proc;

   -- Generate Control Signals
   ar_sel_o <= '1' when cnt = 1 and ir = X"A9" else   -- Load 'A' register in second cycle of the "LDA #" instruction.
               '0';

   last <= '1' when cnt = 1 else                   -- All instructions last two clock cycles.
           '0';


   ------------------
   -- Overlay Output
   ------------------

   debug_o( 2 downto  0) <= cnt;    -- One byte
   debug_o( 7 downto  3) <= (others => '0');
   debug_o(15 downto  8) <= data_i when cnt = 0 else ir;     -- One byte

end architecture structural;

