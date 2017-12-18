library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu_module_tb is
end cpu_module_tb;

architecture Structural of cpu_module_tb is

   signal clk   : std_logic;                      -- 10 MHz
   signal rstn  : std_logic;                      -- Active low
   signal irq   : std_logic;

   signal ia    : std_logic_vector(  31 downto 0);  -- Instruction Address
   signal id    : std_logic_vector(  31 downto 0);  -- Instruction Data
   signal ma    : std_logic_vector(  31 downto 0);  -- Memory Address
   signal moe   : std_logic;                        -- Memory Output Enable
   signal mrd   : std_logic_vector(  31 downto 0);  -- Memory Read Data
   signal wr    : std_logic;                        -- Write
   signal mwd   : std_logic_vector(  31 downto 0);  -- Memory Write Data
   signal regs  : std_logic_vector(1023 downto 0);

   signal test_running : boolean := true;
   signal instructions : integer;
   signal branch : std_logic := '0';
   signal ia_prev : std_logic_vector(31 downto 0) := (others => '0');

   -- Clock divider
   signal clken   : std_logic := '0';
   signal counter : std_logic_vector(0 downto 0) := (others => '0');

begin

   -- Generate reset
   rstn <= '0', '1' after 450 ns;

   -- Generate clock
   clk_gen : process
   begin
      if not test_running then
         wait;
      end if;

      clk <= '1', '0' after 50 ns; -- 10 MHz
      wait for 100 ns;
   end process clk_gen;

   -- Generate clock divider
   p_divider : process (clk)
   begin
      if rising_edge(clk) then
         clken <= '0';
         if counter = 0 then
            clken <= '1';
         end if;
         counter <= counter + 1;
      end if;
   end process p_divider;

   -- Instantiate the DUT
   i_dut : entity work.cpu_module
   port map (
      clk_i   => clk,
      clken_i => clken,
      rstn_i  => rstn,
      irq_i   => irq,
      ia_o    => ia,
      id_i    => id,
      ma_o    => ma,
      moe_o   => moe,
      mrd_i   => mrd,
      wr_o    => wr,
      mwd_o   => mwd,
      regs_o  => regs
   );

   -- Instantiate Memory (Data and instruction)
   i_mem : entity work.mem
   port map (
      clk_i   => clk,
      clken_i => clken,
      ma_i    => ma,
      moe_i   => moe,
      mrd_o   => mrd,
      wr_i    => wr,
      mwd_i   => mwd,
      ia_i    => ia,
      id_o    => id
   );


   -- This is the main test
   p_main : process
   begin
      if ia = X"0000000C" or ia = X"8000000C" then
         report "Test FAILED";
         test_running <= false;
         wait;
      end if;

      if ia = X"000003C4" or ia = X"800003C4" then
         report "Test PASSED";
         test_running <= false;
         wait;
      end if;

      wait until clk = '0';
      wait until clk = '1';

   end process p_main;

   -- Count instructions
   p_count : process (clk, rstn)
   begin
      if rising_edge(clk) then
         if clken = '1' then
            instructions <= instructions + 1;
         end if;
         if rstn = '0' then
            instructions <= 0;
         end if;
      end if;
   end process p_count;

   p_branches : process (clk, rstn)
   begin
      if rising_edge(clk) then
         branch <= '0';
         if clken = '1' then
            ia_prev <= ia;
            if ia /= ia_prev+4 then
               branch <= '1';
            end if;
         end if;
      end if;
   end process p_branches;

   -- Generate Interrupt
   p_irq : process
   begin
      irq <= '0';
      wait until rising_edge(clk);

      wait until instructions = 10-1;
      irq <= '1';
      wait until rising_edge(clk) and clken = '1';
      irq <= '0';

      wait until instructions = 273-1;
      irq <= '1';
      wait until rising_edge(clk) and clken = '1';
      irq <= '0';

      wait;
   end process p_irq;

end Structural;

