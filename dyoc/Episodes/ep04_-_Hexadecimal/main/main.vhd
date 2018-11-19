library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the MAIN module. This currently contains the memory
-- and will later contain the CPU too.

entity main is
   port (
      clk_i    : in  std_logic; 
      wait_i   : in  std_logic;
      digits_o : out std_logic_vector(23 downto 0)
   );
end main;

architecture structural of main is

   -- Memory signals
   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector( 7 downto 0);

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
   -- Instantiate RAM
   --------------------------------------------------
   
   ram_inst : entity work.ram
   generic map (
      G_ADDR_BITS => 4  -- 16 bytes
   )
   port map (
      clk_i  => clk_i,
      addr_i => addr(3 downto 0),  -- Only select the relevant address bits
      data_o => data,
      wren_i => '0',             -- Unused at the moment
      data_i => (others => '0')  -- Unused at the moment
   ); -- ram_inst


   --------------------------------------------------
   -- Generate data to be shown on VGA
   --------------------------------------------------

   digits_o(23 downto 8) <= addr;
   digits_o( 7 downto 0) <= data;

end architecture structural;

