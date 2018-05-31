library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a Dual-Port memory
-- Port A is write-only
-- Port B is read-only

entity dmem is
   generic (
      G_ADDR_BITS : integer
   );
   port (
      clk_i  : in  std_logic;

      -- Port A
      a_addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      a_data_i : in  std_logic_vector(7 downto 0);
      a_wren_i : in  std_logic;

      -- Port B
      b_addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      b_data_o : out std_logic_vector(7 downto 0)
   );
end dmem;

architecture Structural of dmem is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 2**G_ADDR_BITS-1) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal mem : mem_t := (others => (others => '0'));

begin
  
   -- Port A
   p_port_a : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if a_wren_i = '1' then
            mem(conv_integer(a_addr_i)) <= a_data_i;
         end if;
      end if;
   end process p_port_a;

   -- Port B
   p_port_b : process (clk_i)
   begin
      if rising_edge(clk_i) then
         b_data_o <= mem(conv_integer(b_addr_i));
      end if;
   end process p_port_b;

end Structural;

