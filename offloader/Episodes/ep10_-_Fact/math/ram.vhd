library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity ram is
   generic (
      G_ADDR_SIZE : integer;
      G_DATA_SIZE : integer
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      wr_en_i     : in  std_logic;
      wr_addr_i   : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wr_data_i   : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      rd_en_i     : in  std_logic;
      rd_addr_i   : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      rd_data_o   : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end ram;

architecture Structural of ram is

   type ram_vector is array (natural range <>) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   signal ram_memory : ram_vector(2**G_ADDR_SIZE-1 downto 0);

begin

   p_ram : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            ram_memory(to_integer(wr_addr_i)) <= wr_data_i;
         end if;

         if rd_en_i = '1' then
            rd_data_o <= ram_memory(to_integer(rd_addr_i));
         end if;
      end if;
   end process p_ram;

end Structural;

