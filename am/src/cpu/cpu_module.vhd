library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-----------------------------------------------------------------------------
-- This is the top level entity of the MC68000 processor.
-- Note: All signals in this implementation are asserted high.  This is
-- different from the origianl specification, where most signals are asserted
-- low.
-----------------------------------------------------------------------------

entity cpu_module is
   port (
      -- Clock
      clk_i : in  std_logic;
      rst_i : in  std_logic;

      -- Address bus
      addr_o  : out std_logic_vector(23 downto 0);

      -- Data bus (bidirectional)
      data_io : inout std_logic_vector(15 downto 0);

      -- Asynchronous bus control
      as_o    : out std_logic;   -- Address Strobe
      rw_o    : out std_logic;   -- Read Write
      uds_o   : out std_logic;   -- Upper Data Strobe
      lds_o   : out std_logic;   -- Lower Data Strobe
      dtack_i : in  std_logic;   -- Data Transfer Acknowledge

      -- Bus arbitration control
      br_i    : in  std_logic;   -- Bus Request
      bg_o    : out std_logic;   -- Bus Grant
      bgack_i : in  std_logic    -- Bus Grant Acknowledge
   );
end cpu_module;

architecture Structural of cpu_module is

begin

end Structural;

