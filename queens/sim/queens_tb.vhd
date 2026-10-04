library ieee;
use ieee.std_logic_1164.all;

entity queens_tb is
end entity queens_tb;

architecture simulation of queens_tb is

   constant G_NUM_QUEENS : integer := 4;

   subtype queens_t is std_logic_vector(G_NUM_QUEENS-1 downto 0);
   subtype board_t is std_logic_vector(G_NUM_QUEENS*G_NUM_QUEENS-1 downto 0);

   signal clk     : std_logic;
   signal rst     : std_logic;
   signal enable  : std_logic;
   signal running : std_logic := '1';

   signal board   : board_t;
   signal valid   : std_logic;
   signal done    : std_logic;

   signal count   : integer range 0 to 100000;

   subtype row_t is std_logic_vector(G_NUM_QUEENS-1 downto 0);
   type row_vector is array(natural range <>) of row_t;
   signal board_rows : row_vector(G_NUM_QUEENS-1 downto 0);

begin

   p_clk : process
   begin
      clk <= '1', '0' after 10 ns;
      wait for 20 ns;
      if running = '0' then
         wait;
      end if;
   end process p_clk;

   rst <= '1', '0' after 40 ns;

   p_enable : process (clk)
   begin
      if rising_edge(clk) then
         enable <= not enable;

         if rst = '1' then
            enable <= '0';
         end if;
      end if;
   end process p_enable;


   -------------------
   -- Instantiate DUT
   -------------------

   i_queens : entity work.queens
      generic map (
         G_NUM_QUEENS => G_NUM_QUEENS
      )
      port map (
         clk_i   => clk,
         rst_i   => rst,
         en_i    => enable,
         board_o => board,
         valid_o => valid,
         done_o  => done
      ); -- i_queens


   gen_rows: for row in 0 to G_NUM_QUEENS-1 generate
      board_rows(row) <= board(row*G_NUM_QUEENS + G_NUM_QUEENS-1 downto row*G_NUM_QUEENS);
   end generate;

   p_count : process (clk)
      variable rows_or  : std_logic_vector(G_NUM_QUEENS-1 downto 0);
      constant ROW_ONES : std_logic_vector(G_NUM_QUEENS-1 downto 0) := (others => '1');
   begin
      if rising_edge(clk) then
         if valid = '1' and enable = '1' then
            count <= count + 1;
         end if;

         rows_or := (others => '0');
         for row in 0 to G_NUM_QUEENS-1 loop
            rows_or := rows_or or board_rows(row);
         end loop;

         if rst /= '1' then
            assert (valid = '0' or (rows_or = ROW_ONES));
            assert (done = '0' or (count = 2));
         end if;

         if done = '1' then
            report "End of simulation.";
            running <= '0';
         end if;

         if rst = '1' then
            count <= 0;
         end if;
      end if;
   end process p_count;

end architecture simulation;

