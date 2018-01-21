library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This is a generic memory with two separate ports.
-- Port A writes on the rising edge and reads on the falling edge.
-- Port B reads on the rising edge.
entity mem is

   generic (
      G_ADDR_SIZE  : integer;     -- Number of bits in address
      G_DATA_SIZE  : integer      -- Number of bits in data
   );
   port (
      a_clk_i    : in  std_logic;
      a_addr_i   : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      a_wren_i   : in  std_logic;
      a_wrdata_i : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      a_rden_i   : in  std_logic;
      a_rddata_o : out std_logic_vector(G_DATA_SIZE-1 downto 0);

      -- Port B only reads
      b_clk_i    : in  std_logic := '0';
      b_addr_i   : in  std_logic_vector(G_ADDR_SIZE-1 downto 0) := (others => '0');
      b_rden_i   : in  std_logic := '0';
      b_data_o   : out std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0')
   );

end mem;

architecture Structural of mem is

   type t_mem is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   signal mem : t_mem := (others => (others => '0'));

begin

   -------------
   -- Port A
   -------------

   -- Write on the rising edge
   p_a_wr : process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         if a_wren_i = '1' then
            mem(conv_integer(a_addr_i)) <= a_wrdata_i;
         end if;
      end if;
   end process p_a_wr;

   -- Read on the falling edge
   p_a_rd : process (a_clk_i)
   begin
      if falling_edge(a_clk_i) then
         if a_rden_i = '1' then
            a_rddata_o <= mem(conv_integer(a_addr_i));
         end if;
      end if;
   end process p_a_rd;


   ------------
   -- Port B
   ------------

   -- Read on the rising edge
   p_b_rd : process (b_clk_i)
   begin
      if rising_edge(b_clk_i) then
         if b_rden_i = '1' then
            b_data_o <= mem(conv_integer(b_addr_i));
         end if;
      end if;
   end process p_b_rd;
 
end Structural;

