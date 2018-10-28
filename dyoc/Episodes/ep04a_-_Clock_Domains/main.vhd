library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.

-- In this version the design can display 6 hexadecimal digits (3 bytes) on the
-- VGA output. The first 2 bytes show the value of the address bus connected to
-- the internal memory.  The last byte shows the value read from the memory.

-- The address bus increments automatically. The speed is controlled by the
-- slide switches.

entity main is
   port (
      clk_i     : in  std_logic;
      wait_i    : in  std_logic;
      overlay_o : out std_logic_vector(23 downto 0)
   );
end main;

architecture Structural of main is

   -- Memory signals
   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector(7 downto 0);

begin
   
   --------------------------------------------------
   -- Generate memory address
   --------------------------------------------------
   
   addr_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            addr <= addr + 1;
         end if;
      end if;
   end process addr_proc;


   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   mem_inst : entity work.mem
   generic map (
      G_ADDR_BITS => 4  -- 16 bytes
   )
   port map (
      clk_i  => clk_i,
      addr_i => addr(3 downto 0),  -- Only select the relevant address bits
      data_o => data,
      wren_i => '0',             -- Unused at the moment
      data_i => (others => '0')  -- Unused at the moment
   ); -- mem_inst


   --------------------------------------------------
   -- Generate overlay data to be shown on VGA
   --------------------------------------------------

   overlay_o(23 downto 8) <= addr;
   overlay_o( 7 downto 0) <= data;

end architecture Structural;

