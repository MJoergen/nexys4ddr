library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu_module_tb is
end cpu_module_tb;

architecture Structural of cpu_module_tb is

   signal clk  : std_logic;                      -- 10 MHz
   signal rstn : std_logic;                      -- Active low

   signal ia   : std_logic_vector(31 downto 0);  -- Instruction Address
   signal id   : std_logic_vector(31 downto 0);  -- Instruction Data
   signal ma   : std_logic_vector(31 downto 0);  -- Memory Address
   signal moe  : std_logic;                      -- Memory Output Enable
   signal mrd  : std_logic_vector(31 downto 0);  -- Memory Read Data
   signal wr   : std_logic;                      -- Write
   signal mwd  : std_logic_vector(31 downto 0);  -- Memory Write Data
   signal val  : std_logic_vector(31 downto 0);

   signal test_running : boolean := true;

begin

    -- Generate clock
   clk_gen : process
   begin
      if not test_running then
         wait;
      end if;

      clk <= '1', '0' after 50 ns; -- 10 MHz
      wait for 100 ns;
   end process clk_gen;

   -- Generate reset
   rstn <= '0', '1' after 450 ns;

   -- Instantiate the DUT
   i_dut : entity work.cpu_module
   port map (
      clk_i  => clk,
      rstn_i => rstn,
      ia_o   => ia,
      id_i   => id,
      ma_o   => ma,
      moe_o  => moe,
      mrd_i  => mrd,
      wr_o   => wr,
      mwd_o  => mwd,
      val_o  => val
   );

   -- Instantiate Instruction Memory
   i_imem : entity work.imem
   port map (
      ia_i => ia,
      id_o => id
   );

   -- Instantiate Data Memory
   i_dmem : entity work.dmem
   port map (
      clk_i => clk,
      ma_i  => ma,
      moe_i => moe,
      mrd_o => mrd,
      wr_i  => wr,
      mwd_i => mwd
   );


   -- This is the main test
   p_main : process
   begin
      wait for 1 us;
      test_running <= false;
      wait;
   end process p_main;

end Structural;

