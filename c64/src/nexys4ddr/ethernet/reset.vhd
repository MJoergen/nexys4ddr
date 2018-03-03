library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity reset is

   generic (
      G_RESET_SIZE : integer := 22           -- Number of bits in reset counter.
--      G_RESET_SIZE : integer := 10           -- Number of bits in reset counter.
   );
   port (
      clk50_i      : in    std_logic;        -- Must be 50 MHz
      rst_i        : in    std_logic;

      ready_o       : out   std_logic;

      -- Connected to PHY
      eth_rstn_o   : out   std_logic
   );
end reset;

architecture Structural of reset is

   signal ready    : std_logic := '0';
   signal eth_rstn : std_logic := '0';  -- Assert reset by default.

   -- Minimum reset assert time is 25 ms. At 50 MHz (= 20 ns) this is approx 10^6 clock cycles.
   -- Here we have 21 bits, corresponding to approx 2*10^6 clock cycles, i.e. 40 ms.
   -- Set initially to all-ones, to start the count down.
   signal rst_cnt    : std_logic_vector(G_RESET_SIZE-1 downto 0) := (others => '1');

begin

   -- Generate PHY reset
   proc_eth_rstn : process (clk50_i)
   begin
      if rising_edge(clk50_i) then
         if rst_cnt /= 0 then
            rst_cnt <= rst_cnt - 1;
            ready <= '0';
         else
            ready <= '1';
         end if;

         eth_rstn <= not rst_cnt(rst_cnt'left);

         if rst_i = '1' then
            rst_cnt  <= (others => '1');
            ready    <= '0';
            eth_rstn <= '0';
         end if;
      end if;
   end process proc_eth_rstn;

   ready_o    <= ready;
   eth_rstn_o <= eth_rstn;

end Structural;

