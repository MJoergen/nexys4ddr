library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;

entity tb is
end tb;

architecture Structural of tb is

   signal halt : std_logic;

   signal clk      : std_logic;
   signal addr     : std_logic_vector(15 downto 0);
   signal wren     : std_logic;
   signal data_mem : std_logic_vector(7 downto 0);
   signal data_cpu : std_logic_vector(7 downto 0);

begin

   -- Generate clock
   p_clk : process
   begin
     if halt = '1' then
       wait;
     end if;

     clk <= '1', '0' after 5 ns; -- 100 MHz
     wait for 10 ns;
   end process p_clk;

   -- Instantiate memory
   i_mem : entity work.mem
   generic map (
      G_ADDR_BITS => 4
   )
   port map (
      clk_i  => clk,
      addr_i => addr(3 downto 0),
      wren_i => wren,
      data_i => data_cpu,
      data_o => data_mem
   );

   -- Instantiate CPU
   i_cpu : entity work.cpu
   port map (
      clk_i  => clk,
      wait_i => '0',
      addr_o => addr,
      data_i => data_mem,
      wren_o => wren,
      data_o => data_cpu
   );

   halt <= '0', '1' after 1 us;
   
end Structural;

