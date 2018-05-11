library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module models a single-port asynchronous RAM.
-- Even though there are separate signals for data
-- input and data output, simultaneous read and write
-- will not be used in this design.
--
-- Data read is present half way through the same clock cycle.
-- This is done by using a synchronous Block RAM, and reading
-- on the *falling* edge of the clock cycle.

entity mem is
   generic (
      -- Number of bits in the address bus. The size of the memory will
      -- be 2**G_ADDR_BITS bytes.
      G_ADDR_BITS : integer
   );
   port (
      clk_i  : in  std_logic;

      -- Current address selected.
      addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);

      -- Data contents at the selected address.
      -- Valid in same clock cycle.
      data_o : out std_logic_vector(7 downto 0);

      -- New data to (optionally) be written to the selected address.
      data_i : in  std_logic_vector(7 downto 0);

      -- '1' indicates we wish to perform a write at the selected address.
      wren_i : in  std_logic
   );
end mem;

architecture Structural of mem is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 2**G_ADDR_BITS-1) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal mem : mem_t := (
      X"A9", X"01",           -- LDA #$01
      X"8D", X"FF", X"00",    -- STA $00FF
      X"A9", X"00",           -- LDA #$00
      X"69", X"00",           -- ADC #$00
      X"AD", X"FF", X"00",    -- LDA $00FF
      X"69", X"01",           -- ADC #$01
      X"8D", X"FF", X"00",    -- STA $00FF
      X"4C", X"05", X"00",    -- JMP $0005

      others => X"00"
   );

   -- Data read from memory.
   signal data : std_logic_vector(7 downto 0);

begin

   -- Write process
   p_mem : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            mem(conv_integer(addr_i)) <= data_i;
         end if;
      end if;
   end process p_mem;

   -- Read process.
   -- Triggered on the *falling* clock edge in order to mimick an asynchronous
   -- memory.
   p_data : process (clk_i)
   begin
      if falling_edge(clk_i) then
         data <= mem(conv_integer(addr_i));
      end if;
   end process p_data;

   -- Drive output signals
   data_o <= data;

end Structural;

