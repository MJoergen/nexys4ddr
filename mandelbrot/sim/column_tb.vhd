library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity column_tb is
end entity column_tb;

architecture simulation of column_tb is

   signal clk        : std_logic;
   signal rst        : std_logic;
   signal col_start  : std_logic;
   signal col_cx     : std_logic_vector(17 downto 0);
   signal col_starty : std_logic_vector(17 downto 0);
   signal col_stepy  : std_logic_vector(17 downto 0);
   signal col_done   : std_logic;
   signal row        : std_logic_vector(10 downto 0);
   signal mem        : std_logic_vector( 8 downto 0);

begin

   i_column : entity work.column
      generic map (
         C_NUM_ROWS => 10
      )
      port map (
         clk_i        => clk,
         rst_i        => rst,
         col_start_i  => col_start,
         col_cx_i     => col_cx,
         col_starty_i => col_starty,
         col_stepy_i  => col_stepy,
         col_done_o   => col_done,
         row_i        => row,
         mem_o        => mem
      ); -- i_column

end architecture simulation;

