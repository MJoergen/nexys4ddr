library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simple run-length-encoding compression algorithm

entity compress is

   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      in_ena_i    : in  std_logic;
      in_sof_i    : in  std_logic;
      in_eof_i    : in  std_logic;
      in_data_i   : in  std_logic_vector(7 downto 0);
      out_ena_o   : out std_logic;
      out_sof_o   : out std_logic;
      out_eof_o   : out std_logic;
      out_data_o  : out std_logic_vector(7 downto 0)
   );
end compress;

architecture Structural of compress is

   signal in_sof_d  : std_logic;
   signal in_eof_d  : std_logic;
   signal in_data_d : std_logic_vector(7 downto 0);

   signal fifo_wr_en     : std_logic;
   signal fifo_wr_data   : std_logic_vector(31 downto 0);
   signal fifo_rd_en     : std_logic;
   signal fifo_rd_data   : std_logic_vector(15 downto 0);
   signal fifo_rd_empty  : std_logic;

   signal out_ena   : std_logic;
   signal out_sof   : std_logic;
   signal out_eof   : std_logic;
   signal out_data  : std_logic_vector(7 downto 0);

begin

   proc_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if in_ena_i = '1' then
            in_sof_d  <= in_sof_i;
            in_eof_d  <= in_eof_i;
            in_data_d <= in_data_i;
         end if;
      end if;
   end process proc_delay;


   proc_input : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fifo_wr_en <= '0';

         if in_ena_i = '1' then
            if in_sof_i = '1' then
               -- First byte
               fifo_wr_data(7 downto 0) <= (others => '0');    -- Count number of occurences
               fifo_wr_data(8)          <= '0';                -- SOF
               fifo_wr_data(9)          <= '0';                -- EOF

               -- Second byte
               fifo_wr_data(15 downto 8) <= in_data_i;         -- Byte value
               fifo_wr_data(16)          <= '0';               -- SOF
               fifo_wr_data(17)          <= '0';               -- EOF
            elsif in_data_d /= in_data_i then
               fifo_wr_en <= '1';
            else
               fifo_wr_data(7 downto 0) <= fifo_wr_data(7 downto 0) + 1;
            end if;
         end if;
      end if;
   end process proc_input;


   -------------------------
   -- Instantiate output FIFO
   -------------------------

   inst_fifo : entity work.fifo_width_change
   generic map (
      G_WRPORT_SIZE => 32,
      G_RDPORT_SIZE => 16
      )
   port map (
      wr_clk_i   => clk_i,
      wr_rst_i   => rst_i,
      rd_clk_i   => clk_i,
      rd_rst_i   => rst_i,

      wr_en_i    => fifo_wr_en,
      wr_data_i  => fifo_wr_data,
      rd_en_i    => fifo_rd_en,
      rd_data_o  => fifo_rd_data,
      rd_empty_o => fifo_rd_empty
      );

   -- Read from fifo
   fifo_rd_en <= not fifo_rd_empty;

   -- Drive output signals
   proc_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         out_ena_o  <= fifo_rd_en;
         out_sof_o  <= fifo_rd_data(8);
         out_eof_o  <= fifo_rd_data(9);
         out_data_o <= fifo_rd_data(7 downto 0);
      end if;
   end process proc_out;

end Structural;

