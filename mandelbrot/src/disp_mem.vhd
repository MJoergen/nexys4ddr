library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity disp_mem is
   port (
      wr_clk_i    : in  std_logic;
      wr_rst_i    : in  std_logic;
      wr_addr_i   : in  std_logic_vector(18 downto 0);
      wr_data_i   : in  std_logic_vector( 7 downto 0);
      wr_en_i     : in  std_logic;
      --
      rd_clk_i    : in  std_logic;
      rd_rst_i    : in  std_logic;
      rd_addr_i   : in  std_logic_vector(18 downto 0);
      rd_data_o   : out std_logic_vector( 7 downto 0)
   );
end entity disp_mem;

architecture rtl of disp_mem is

   type mem_t is array (0 to 1024*512-1) of std_logic_vector(7 downto 0);
   signal mem : mem_t;

   signal wr_addr      : std_logic_vector(18 downto 0);
   signal wr_data      : std_logic_vector( 7 downto 0);
   signal wr_en        : std_logic;
   signal wr_addr_rst  : std_logic_vector(18 downto 0);
   signal wr_rst       : std_logic := '0';

   signal rd_data_r  : std_logic_vector(7 downto 0);
   signal rd_data_d  : std_logic_vector(7 downto 0);
   signal rd_data_dd : std_logic_vector(7 downto 0);

begin

   -------------------------
   -- Write to pixel memory
   -------------------------

   p_write_ctrl : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then

         wr_addr <= wr_addr_i;
         wr_data <= wr_data_i;
         wr_en   <= wr_en_i;

         if wr_rst = '1' then
            wr_addr <= wr_addr_rst;
            wr_data <= "01010101";
            wr_en   <= '1';

            wr_addr_rst <= wr_addr_rst + 1;

            if wr_addr_rst + 1 = 0 then
               wr_rst <= '0';
            end if;
         end if;

         if wr_rst_i = '1' then
            wr_addr_rst <= (others => '0');
            wr_rst      <= '1';
         end if;
      end if;
   end process p_write_ctrl;

   p_write : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then
         if wr_en = '1' then
            mem(to_integer(wr_addr)) <= wr_data;
         end if;
      end if;
   end process p_write;


   --------------------------
   -- Read from pixel memory
   --------------------------

   p_read : process (rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         rd_data_r  <= mem(to_integer(rd_addr_i));
         rd_data_d  <= rd_data_r;
         rd_data_dd <= rd_data_d;
      end if;
   end process p_read;

   rd_data_o <= rd_data_dd;

end architecture rtl;

