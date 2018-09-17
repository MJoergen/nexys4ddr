library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity dma is
   port (
      clk_i      : in  std_logic;
      rd_empty_i : in  std_logic;
      rd_en_o    : out std_logic;
      rd_sof_i   : in  std_logic;
      rd_eof_i   : in  std_logic;
      rd_data_i  : in  std_logic_vector(7 downto 0);
      rd_error_i : in  std_logic_vector(1 downto 0);

      wren_o     : out std_logic;
      addr_o     : out std_logic_vector(15 downto 0);
      data_o     : out std_logic_vector( 7 downto 0);
      memio_o    : out std_logic_vector(47 downto 0)
   );
end dma;

architecture Structural of dma is

   signal wren    : std_logic;
   signal addr    : std_logic_vector(15 downto 0);
   signal data    : std_logic_vector( 7 downto 0);
   --
   signal cnt     : std_logic_vector(15 downto 0);
   signal errors0 : std_logic_vector( 7 downto 0);
   signal errors1 : std_logic_vector( 7 downto 0);

   signal rd_en   : std_logic;

begin

   rd_en <= not rd_empty_i;

   memio_o(15 downto  0) <= addr;
   memio_o(31 downto 16) <= cnt;
   memio_o(39 downto 32) <= errors0;
   memio_o(47 downto 40) <= errors1;

   proc_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wren <= '0';
         if rd_en = '1' then
            if rd_eof_i = '1' then
               cnt <= cnt + 1;

               if rd_error_i(0) = '1' then
                  errors0 <= errors0 + 1;
               end if;

               if rd_error_i(1) = '1' then
                  errors1 <= errors1 + 1;
               end if;
            end if;

            if rd_sof_i = '1' then
               addr <= X"7000";
            else
               addr <= addr + 1;
            end if;
            wren <= '1';
            data <= rd_data_i;
         end if;
      end if;
   end process proc_read;


   -- Drive output signals
   wren_o <= wren;
   addr_o <= addr;
   data_o <= data;
   
end Structural;

