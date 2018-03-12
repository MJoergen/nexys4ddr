library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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
   signal out_eof_d : std_logic;
   signal out_data  : std_logic_vector(7 downto 0);

   signal fsm_sof : std_logic;
   signal fsm_eof : std_logic;
   signal fsm_cnt : std_logic_vector(7 downto 0);

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
      variable same_v : std_logic;
      variable lst_v  : std_logic_vector(2 downto 0);
   begin
      if rising_edge(clk_i) then
         fifo_wr_en   <= '0';
         fifo_wr_data(31 downto 26) <= (others => '0');
         fifo_wr_data(15 downto 10) <= (others => '0');
         fifo_wr_data(9)            <= '0'; -- Never EOF on first byte
         fifo_wr_data(24)           <= '0'; -- Never SOF on second byte

         same_v := '0';
         if in_data_d = in_data_i then
            same_v := '1';
            if in_sof_i = '0' and fsm_cnt = X"FF" then
               same_v := '0';
            end if;
         end if;

         lst_v := in_sof_i & in_eof_i & same_v;

         if in_ena_i = '1' then
            case lst_v is
               when "000" =>
                  fifo_wr_data(7 downto 0)   <= in_data_d;
                  fifo_wr_data(8)            <= fsm_sof;
                  fifo_wr_data(23 downto 16) <= fsm_cnt;
                  fifo_wr_data(25)           <= fsm_eof;
                  fifo_wr_en <= '1';
                  fsm_sof    <= '0';
                  fsm_eof    <= '0';
                  fsm_cnt    <= (others => '0');

               when "001" =>
                  fsm_cnt <= fsm_cnt + 1;

               when "010" =>
                  fifo_wr_data(7 downto 0)   <= in_data_d;
                  fifo_wr_data(8)            <= fsm_sof;
                  fifo_wr_data(23 downto 16) <= fsm_cnt;
                  fifo_wr_data(25)           <= '0';
                  fifo_wr_en <= '1';
                  fsm_sof    <= '0';
                  fsm_eof    <= '1';
                  fsm_cnt    <= (others => '0');

               when "011" =>
                  fifo_wr_data(7 downto 0)   <= in_data_d;
                  fifo_wr_data(8)            <= fsm_sof;
                  fifo_wr_data(23 downto 16) <= fsm_cnt + 1;
                  fifo_wr_data(25)           <= '1';
                  fifo_wr_en <= '1';
                  fsm_sof    <= '0';
                  fsm_eof    <= '0';
                  fsm_cnt    <= (others => '0');

               when "100" | "101" =>
                  fsm_cnt <= (others => '0');
                  fsm_sof <= '1';
                  fsm_eof <= '0';

               when "110" | "111" =>
                  fifo_wr_data(7 downto 0)   <= in_data_i;
                  fifo_wr_data(8)            <= '1';
                  fifo_wr_data(23 downto 16) <= (others => '0');
                  fifo_wr_data(25)           <= '1';
                  fifo_wr_en <= '1';

               when others => null;
            end case;
         end if;

         if fsm_eof = '1' then
            fifo_wr_data(7 downto 0)   <= in_data_d;
            fifo_wr_data(8)            <= '0';
            fifo_wr_data(23 downto 16) <= (others => '0');
            fifo_wr_data(25)           <= '1';
            fifo_wr_en <= '1';
            fsm_eof <= '0';
         end if;

         if rst_i = '1' then
            fifo_wr_en <= '0';
            fsm_cnt    <= (others => '0');
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
   fifo_rd_en <= '1' when fifo_rd_empty = '0' and (out_eof = '0' or out_eof_d = '1')
                 else '0';

   -- Drive output signals
   proc_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         out_ena  <= fifo_rd_en;
         out_sof  <= fifo_rd_data(8) and fifo_rd_en;
         out_eof  <= fifo_rd_data(9) and fifo_rd_en;
         out_data <= fifo_rd_data(7 downto 0);
         out_eof_d <= out_eof;

         if rst_i = '1' then
            out_ena   <= '0';
            out_sof   <= '0';
            out_eof   <= '0';
            out_eof_d <= '0';
         end if;
      end if;
   end process proc_out;

   out_ena_o  <= out_ena;
   out_sof_o  <= out_sof;
   out_eof_o  <= out_eof;
   out_data_o <= out_data;

end Structural;

