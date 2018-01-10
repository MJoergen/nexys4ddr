--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity cpu_module is
   port (
      -- Clock
      clk_i : in  std_logic;
      rst_i : in  std_logic;

      -- Memory and I/O interface
      addr_o : out std_logic_vector(15 downto 0);
      --
      rden_o : out std_logic;
      data_i : in  std_logic_vector(7 downto 0);
      --
      wren_o : in  std_logic;
      data_o : in  std_logic_vector(7 downto 0);

      -- Interrupt
      irq_i  : in  std_logic;

      -- Debug (to show on the VGA)
      debug_o : out std_logic_vector(63 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

   signal addr  : std_logic_vector(15 downto 0);
   signal rden  : std_logic;
   signal wren  : std_logic;
   signal data  : std_logic_vector(7 downto 0);
   signal debug : std_logic_vector(63 downto 0);

begin

   assert rden /= '1' or wren /= '1'
      report "Simultaneous read and write"
      severity failure;

end Structural;

