library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-----------------------------------------------------------------------------
-- This is the top level entity of the MC68000 processor.
-- Note: All signals in this implementation are asserted high.  This is
-- different from the origianl specification, where most signals are asserted
-- low.
--
-- Note that there is not address bit 0. This is instead handled by the
-- signals UDS and LDS.
--
-- The address bus is bidirectional, meaning that both the CPU and the
-- memory or I/O may at some point drive the signals. Care must be taken
-- so that at any time only one driver is active. This bus arbitration 
-- is controlled and initiated by the CPU.
--
-- To read from memory or I/O (see sections 5.1.1 and 5.8):
-- CPU performs the following in cycle 1:
--    rw_o   <= '1' (indicate read)
--    fc_o   <= ?? (set appropriate value here)
--    addr_o <= ?? (set appropriate value here)
--    as_o   <= '1' (indicate address valid)
--    uds_o  <= ?? (set appropriate value here)
--    lds_o  <= ?? (set appropriate value here)
-- Memory or I/O performs the following in cycle 2:
--    data_io <= ?? (sets appropriate value here)
--    dtack_i <= '1' (indicate data is valid)
-- CPU performs the following in cycle 3:
--    Latches data into internal registers
--    uds_o  <= '0' (set default value)
--    lds_o  <= '0' (set default value)
--    as_o   <= '0' (set default value)
-- Memory or I/O performe the following in cycle 4:
--    data_io <= 'Z' (set default value)
--    dtack_i <= '0' (set default value)
-----------------------------------------------------------------------------

entity cpu_module is
   port (
      -- Clock
      clk_i : in  std_logic;
      rst_i : in  std_logic;

      -- Address bus
      addr_o  : out std_logic_vector(23 downto 1);

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
      bgack_i : in  std_logic;   -- Bus Grant Acknowledge

      -- Interrupt control
      ipl_i   : in  std_logic_vector(2 downto 0);

      -- Processor status
      -- Bit 0 : Data
      -- Bit 1 : Program
      -- Bit 2 : Supervisor
      fc_o    : out std_logic_vector(2 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

begin

   -------------------------------------------------------------------------
   -- Bus arbitration control:
   -- This is only needed for DMA accesses, i.e.  where a peripheral block
   -- wants access to the address bus. This is not used in the current design.
   -- We deassert the grant, and ignore the request signals.
   -- Therefore the CPU is always the bus master, and the only peripherals
   -- are memory-mapped devices. No external bus master is needed, only
   -- the redirect (selection) of memory or I/O device.
   -------------------------------------------------------------------------

   bg_o <= '0';   -- Never grant bus access.

end Structural;

