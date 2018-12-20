library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This calculates (sequentially) an entire column

entity column is
   generic (
      C_NUM_ROWS : integer
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;
      col_start_i  : in  std_logic;
      col_cx_i     : in  std_logic_vector(17 downto 0);
      col_starty_i : in  std_logic_vector(17 downto 0);
      col_stepy_i  : in  std_logic_vector(17 downto 0);
      col_done_o   : out std_logic;
      -- Read port
      row_i        : in  std_logic_vector(10 downto 0);
      mem_o        : out std_logic_vector( 8 downto 0)
   );
end entity column;

architecture rtl of column is

   signal row_start_r : std_logic;
   signal row_cx_r    : std_logic_vector(17 downto 0);
   signal row_cy_r    : std_logic_vector(17 downto 0);
   signal row_cnt_s   : std_logic_vector( 8 downto 0);
   signal row_done_s  : std_logic;
   signal row_num_r   : std_logic_vector(10 downto 0);

   signal col_done_r  : std_logic;

   -- This defines a type containing an entire column of data
   type column_mem_t is array (0 to 2047) of std_logic_vector(8 downto 0);
   signal column_mem : column_mem_t;

begin

   -----------------------
   -- Reading from memory
   -----------------------

   p_mem_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         mem_o <= column_mem(to_integer(row_i));
      end if;
   end process p_mem_out;


   ---------------------
   -- Writing to memory
   ---------------------

   p_column_mem : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if row_done_s = '1' then
            column_mem(to_integer(row_num_r)) <= row_cnt_s;
         end if;
      end if;
   end process p_column_mem;


   -----------------------------
   -- Simple state machine to
   -- iterate through each row.
   -----------------------------

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         row_start_r <= '0';
         col_done_r  <= '0';

         if col_start_i = '1' then
            row_cx_r    <= col_cx_i;
            row_cy_r    <= col_starty_i;
            row_start_r <= '1';
            row_num_r   <= (others => '0');
         end if;

         if row_done_s = '1' then
            row_num_r <= row_num_r + 1;
            row_cy_r  <= row_cy_r + col_stepy_i;

            if row_num_r + 1 = C_NUM_ROWS then
               col_done_r <= '1';
            end if;
         end if;
      end if;
   end process p_fsm;


   i_iterator : entity work.iterator
      port map (
         clk_i   => clk_i,
         rst_i   => rst_i,
         start_i => row_start_r,
         cx_i    => row_cx_r,
         cy_i    => row_cy_r,
         cnt_o   => row_cnt_s,
         done_o  => row_done_s
      ); -- i_iterator

   --------------------------
   -- Connect output signals
   --------------------------

   col_done_o <= col_done_r;

end architecture rtl;

