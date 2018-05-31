library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity tb is
end tb;

architecture Structural of tb is

   -- Clock
   signal clk  : std_logic;

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector(7 downto 0);
   signal cpu_data  : std_logic_vector(7 downto 0);
   signal cpu_wren  : std_logic;
   signal mem_stat  : std_logic_vector(7 downto 0);

   -- Debug output
   signal cpu_led   : std_logic_vector(7 downto 0);
   signal cpu_debug : std_logic_vector(175 downto 0);

   -- Generate pause signal
   signal mem_wait_cnt : std_logic_vector(0 downto 0) := (others => '0');
   signal mem_wait     : std_logic;

begin
   
   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   -- Generate clock
   clk_gen : process
   begin
      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process clk_gen;


   --------------------------------------------------
   -- Generate wait signal
   --------------------------------------------------

   process (clk)
   begin
      if rising_edge(clk) then
         mem_wait_cnt <= mem_wait_cnt + 1;
      end if;
   end process;

   -- Check for wrap around of counter.
   mem_wait <= '0' when mem_wait_cnt = 0  else '1';

   
   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   i_cpu : entity work.cpu
   port map (
      clk_i     => clk,
      wait_i    => mem_wait,
      addr_o    => cpu_addr,
      data_i    => mem_data,
      wren_o    => cpu_wren,
      data_o    => cpu_data,
      irq_i     => mem_stat(0),
      nmi_i     => mem_stat(1),
      rst_i     => '0',
      invalid_o => cpu_led,
      debug_o   => cpu_debug
   );

   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   port map (
      clk_i  => clk,
      addr_i => cpu_addr,  -- Only select the relevant address bits
      data_o => mem_data,
      wren_i => cpu_wren,
      data_i => cpu_data,
      stat_o => mem_stat
   );

end architecture Structural;

