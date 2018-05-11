library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module implements the 6502 CPU.
-- The CPU expects read and writes to complete in the same cycle.
-- Whenever 'wait_i' is asserted (i.e. '1') then the CPU just waits,
-- without updating internal registers.

entity cpu is
   port (
      clk_i   : in  std_logic;

      -- Memory interface
      addr_o  : out std_logic_vector(15 downto 0);
      data_i  : in  std_logic_vector(7 downto 0);
      data_o  : out std_logic_vector(7 downto 0);
      wren_o  : out std_logic;
      -- The "wait_i" is '1' when the memory is not ready.
      -- While this is so, the CPU just stands still, waiting.
      wait_i  : in  std_logic;

      -- Debug output
      debug_o : out std_logic_vector(47 downto 0)
   );
end entity cpu;

architecture structural of cpu is

   signal a_sel : std_logic;

begin

   -----------------
   -- Instantiate datapath
   -----------------

   inst_datapath : entity work.datapath
   port map (
      clk_i   => clk_i,
      wait_i  => wait_i,

      addr_o  => addr_o,
      data_i  => data_i,
      data_o  => data_o,
      wren_o  => wren_o,

      a_sel_i => a_sel,

      debug_o => debug_o(47 downto 16)
   );


   -----------------
   -- Instantiate control logic
   -----------------

   inst_ctl : entity work.ctl
   port map (
      clk_i   => clk_i,
      wait_i  => wait_i,

      data_i  => data_i,

      a_sel_o => a_sel,

      debug_o => debug_o(15 downto 0)
   );


end architecture structural;

