library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simple DMA. It will generate write requests to the memory, whenever there is input data available.
-- Since this DMA has priority over the CPU, writes are only generated every second clock cycle, to avoid
-- starving the CPU for long periods.

entity dma is
   port (
      clk_i      : in  std_logic;
      rd_empty_i : in  std_logic;
      rd_en_o    : out std_logic;
      rd_sof_i   : in  std_logic;
      rd_eof_i   : in  std_logic;
      rd_data_i  : in  std_logic_vector(7 downto 0);
      rd_error_i : in  std_logic_vector(1 downto 0);

      wr_en_o    : out std_logic;
      wr_addr_o  : out std_logic_vector(15 downto 0);
      wr_data_o  : out std_logic_vector( 7 downto 0);
      memio_i    : in  std_logic_vector(55 downto 0);
      memio_o    : out std_logic_vector(47 downto 0)
   );
end dma;

architecture Structural of dma is

   signal wr_en   : std_logic;
   signal wr_addr : std_logic_vector(15 downto 0);
   signal wr_data : std_logic_vector( 7 downto 0);
   --
   signal cnt     : std_logic_vector(15 downto 0) := (others => '0');
   signal errors0 : std_logic_vector( 7 downto 0) := (others => '0');
   signal errors1 : std_logic_vector( 7 downto 0) := (others => '0');

   signal rd_en   : std_logic := '0';

   signal eth_start  : std_logic_vector(15 downto 0);
   signal eth_end    : std_logic_vector(15 downto 0);
   signal eth_rdptr  : std_logic_vector(15 downto 0);
   signal eth_enable : std_logic;

begin

   eth_start  <= memio_i(15 downto  0);
   eth_end    <= memio_i(31 downto 16);
   eth_rdptr  <= memio_i(47 downto 32);
   eth_enable <= memio_i(48);

   -- This generates a read on every second cycle.
   proc_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rd_en <= not rd_empty_i and not rd_en;
      end if;
   end process proc_read;

   proc_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wr_en <= '0';
         if rd_en = '1' and eth_enable = '1' then
            if rd_eof_i = '1' then
               cnt <= cnt + 1;

               if rd_error_i(0) = '1' then
                  errors0 <= errors0 + 1;
               end if;

               if rd_error_i(1) = '1' then
                  errors1 <= errors1 + 1;
               end if;
            end if;

            wr_en <= '1';
            wr_data <= rd_data_i;
         end if;
      end if;
   end process proc_write;

   proc_wr_addr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en = '1' then
            wr_addr <= wr_addr + 1;
         end if;
         if eth_enable = '0' then
            wr_addr <= eth_start;
         end if;
      end if;
   end process proc_wr_addr;


   -- Drive output signals
   rd_en_o   <= rd_en;
   wr_en_o   <= wr_en;
   wr_addr_o <= wr_addr;
   wr_data_o <= wr_data;

   memio_o(15 downto  0) <= wr_addr;
   memio_o(31 downto 16) <= cnt;
   memio_o(39 downto 32) <= errors0;
   memio_o(47 downto 40) <= errors1;

end Structural;

