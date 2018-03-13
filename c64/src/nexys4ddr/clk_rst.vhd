library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.Vcomponents.all;

-- This file generates clocks and resets for the VGA, CPU, and Ethernet modules.

-- Minimum reset assert time for the Ethernet PHY is 25 ms.
-- At 50 MHz (= 20 ns pr clock cycle) this is approx 10^6 clock cycles.
-- Therefore, for a real implementation, G_RESET_SIZE should be set to 22,
-- corresponding to approx 2*10^6 clock cycles, i.e. 40 ms.

-- The VGA and CPU resets are aaserted for approx 80 ms, to allow
-- the Ethernet PHY to wake up from reset.

entity clk_rst is
   generic (
      G_RESET_SIZE : integer;       -- Number of bits in reset counter.
      G_SIMULATION : boolean        -- Set true to disable MMCM's, to 
                                    -- speed up simulation time.
   );
   port (
      -- Clock. Connected to an external 100 MHz crystal.
      sys_clk100_i : in  std_logic;

      -- Input switches and push buttons
      sys_rstn_i : in  std_logic;   -- Asserted low
      sys_step_i : in  std_logic;
      sys_mode_i : in  std_logic;

      -- Output clocks and resets
      vga_clk_o  : out std_logic;
      vga_rst_o  : out std_logic;
      cpu_clk_o  : out std_logic;
      cpu_rst_o  : out std_logic;
      eth_clk_o  : out std_logic;
      eth_rst_o  : out std_logic
   );
end clk_rst;

architecture Structural of clk_rst is

   -- Debounced input signals (@ sys_clk100_i)
   signal sys_rstn : std_logic := '0';
   signal sys_step : std_logic := '0';
   signal sys_mode : std_logic := '0';
   signal sys_mode_inv : std_logic := '1';

   -- Clocks and Reset
   signal vga_clk   : std_logic := '0';
   signal vga_rst   : std_logic := '1';
   signal cpu_clk   : std_logic := '0';
   signal cpu_rst   : std_logic := '1';
   signal eth_clk   : std_logic := '0';
   signal eth_rst   : std_logic := '1';

   signal cpu_clk_stepped : std_logic := '0';
 
   signal ready : std_logic := '0';
   signal reset : std_logic := '1'; 

   -- Set initially to all-ones, to start the count down.
   signal reset_cnt : std_logic_vector(G_RESET_SIZE-1 downto 0) := (others => '1');

begin

   -------------------------
   -- Debounce input signals
   -------------------------

   inst_reset_debounce : entity work.debounce
   port map (
      clk_i => sys_clk100_i,
      in_i  => sys_rstn_i,
      out_o => sys_rstn
   );

   inst_step_debounce : entity work.debounce
   port map (
      clk_i => sys_clk100_i,
      in_i  => sys_step_i,
      out_o => sys_step
   );

   inst_mode_debounce : entity work.debounce
   port map (
      clk_i => sys_clk100_i,
      in_i  => sys_mode_i,
      out_o => sys_mode
   );


   ------------------------------
   -- Generate clocks
   ------------------------------

   gen_clocks : if G_SIMULATION = false generate
      -- Generate clocks
      inst_clk_wiz_0 : entity work.clk_wiz_0
      port map
      (
         clk_in1 => sys_clk100_i,
         eth_clk => eth_clk,
         vga_clk => vga_clk,
         cpu_clk => cpu_clk
      );

      sys_mode_inv <= not sys_mode;

      -- Note: For some reason, synthesis fails if I0 and I1 are swapped.
      inst_bufgmux : BUFGCTRL
      port map (
         IGNORE0 => '0',
         IGNORE1 => '0',
         S0      => '1',
         S1      => '1',
         I1      => cpu_clk,
         I0      => sys_step,
         CE0     => sys_mode,
         CE1     => sys_mode_inv,
         O       => cpu_clk_stepped
      );
   end generate gen_clocks;

   gen_no_clocks : if G_SIMULATION = true generate
      vga_clk <= sys_clk100_i;
      cpu_clk <= sys_clk100_i;
      eth_clk <= sys_clk100_i;
      cpu_clk_stepped <= cpu_clk when sys_mode = '0' else sys_step;
   end generate gen_no_clocks;
 
 
   ------------------------------
   -- Generate reset
   ------------------------------

   -- Generate the two signals 'reset' and 'ready'.
   -- 'reset' is deasserted after 40 ms.
   -- 'ready' is asserted after 80 ms.
   proc_reset : process (sys_clk100_i)
   begin
      if rising_edge(sys_clk100_i) then
         if reset_cnt /= 0 then
            reset_cnt <= reset_cnt - 1;
            ready <= '0';
         else
            ready <= '1';
         end if;

         reset <= reset_cnt(reset_cnt'left);

         if sys_rstn = '0' then
            reset_cnt <= (others => '1');
            ready     <= '0';
            reset     <= '1';
         end if;
      end if;
   end process proc_reset;


   -- Synchronize resets
   p_eth_rst : process (eth_clk)
   begin
      if rising_edge(eth_clk) then
         eth_rst <= reset;
      end if;
   end process p_eth_rst;
 
   p_cpu_rst : process (cpu_clk)
   begin
      if rising_edge(cpu_clk) then
         cpu_rst <= not ready;
      end if;
   end process p_cpu_rst;
 
   p_vga_rst : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_rst <= not ready;
      end if;
   end process p_vga_rst;
 

   -- Drive output signals
   vga_clk_o <= vga_clk;
   vga_rst_o <= vga_rst;
   cpu_clk_o <= cpu_clk;
   cpu_rst_o <= cpu_rst;
   eth_clk_o <= eth_clk;
   eth_rst_o <= eth_rst;
   
end Structural;

