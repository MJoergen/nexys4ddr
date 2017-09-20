----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:01:12 01/11/2013 
-- Design Name: 
-- Module Name:    dragon - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity queens_tb is
end queens_tb;

architecture Behavioral of queens_tb is

    constant NUM_QUEENS : integer := 4;

    subtype queens_t is std_logic_vector(NUM_QUEENS-1 downto 0);
    subtype board_t is std_logic_vector(NUM_QUEENS*NUM_QUEENS-1 downto 0);

    signal clk    : std_logic;
    signal rst    : std_logic;
    signal enable : std_logic;
    signal valid  : std_logic;
    signal done   : std_logic;
    signal count  : integer range 0 to 100000;

    signal board  : board_t;

    subtype row_t is std_logic_vector(NUM_QUEENS-1 downto 0);
    type row_vector is array(natural range <>) of row_t;
    signal board_rows : row_vector(NUM_QUEENS-1 downto 0);

begin

    gen_rows: for row in 0 to NUM_QUEENS-1 generate
        board_rows(row) <= board(row*NUM_QUEENS + NUM_QUEENS-1 downto row*NUM_QUEENS);
    end generate;
 
    inst_queens : entity work.queens
        generic map (
            NUM_QUEENS => NUM_QUEENS
            )
        port map (
			clk_i   => clk,
			rst_i   => rst,
            en_i    => enable,
			board_o => board,
            valid_o => valid,
            done_o  => done
            );
  
    rst_driver : rst <= '1', '0' after 40 ns;

	clk_driver : process
	begin
        clk <= '1', '0' after 10 ns;
        wait for 20 ns;
    end process clk_driver;

    enable_driver : process(clk, rst)
    begin
        if rst = '1' then
            enable <= '0';
        elsif rising_edge(clk) then
            enable <= not enable;
        end if;
    end process enable_driver;

    valid_count : process (clk, rst)
        variable rows_or  : std_logic_vector(NUM_QUEENS-1 downto 0);
        constant ROW_ONES : std_logic_vector(NUM_QUEENS-1 downto 0) := (others => '1');
    begin
        if rst = '1' then
            count <= 0;
        elsif rising_edge(clk) then
            if valid = '1' and enable = '1' then
                count <= count + 1;
            end if;

            rows_or := (others => '0');
            for row in 0 to NUM_QUEENS-1 loop
                rows_or := rows_or or board_rows(row);
            end loop;

            assert (valid = '0' or (rows_or = ROW_ONES));
            assert (done = '0' or (count = 2));
            if done = '1' then
                assert false report "End of simulation.";
            end if;
        end if;
    end process valid_count;

end Behavioral;

