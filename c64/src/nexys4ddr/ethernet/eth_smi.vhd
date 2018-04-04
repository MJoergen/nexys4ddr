library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module connects to the SMI port of the LAN8720A Ethernet PHY.
--
-- From the datasheet:
-- At the system level, SMI provides 2 signals: MDIO and MDC. The MDC signal is
-- an aperiodic clock provided by the station management controller (SMC). MDIO
-- is a bi-directional data SMI input/output signal that receives serial data
-- (commands) from the controller SMC and sends serial data (status) to the
-- SMC. The minimum time between edges of the MDC is 160 ns. There is no
-- maximum time between edges. The minimum cycle time (time between two
-- consecutive rising or two consecutive falling edges) is 400 ns. These modest
-- timing requirements allow this interface to be easily driven by the I/O port
-- of a microcontroller.  The data on the MDIO line is latched on the rising
-- edge of the MDC. 
--
-- wren_i and rden_i are sampled only when ready=1.

entity eth_smi is

   port (
      eth_clk_i   : in    std_logic;        -- Must be 50 MHz
      eth_rst_i   : in    std_logic;

      ready_o     : out   std_logic;
      phy_i       : in    std_logic_vector(4 downto 0);
      addr_i      : in    std_logic_vector(4 downto 0);

      rden_i      : in    std_logic;
      data_o      : out   std_logic_vector(15 downto 0);

      wren_i      : in    std_logic;
      data_i      : in    std_logic_vector(15 downto 0);

      -- Connectedto PHY
      eth_mdio_io : inout std_logic;
      eth_mdc_o   : out   std_logic
   );
end eth_smi;

architecture Structural of eth_smi is

   -- Output signals
   signal mdio  : std_logic := '1';
   signal mdc   : std_logic;
   signal data  : std_logic_vector(15 downto 0);
   signal ready : std_logic := '0';

   type t_fsm_state is (IDLE_ST, SETUP_ST, READ_ST, WRITE_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

   -- Current command: 1 = write, 0 = read
   signal wrn : std_logic;

   -- This provides the clock divider, dividing 50 MHz by 32 to get approx 1.6 MHz i.e. a period of 640 ns.
   -- The high bit is connected to SMI clock.
   signal clk_count : std_logic_vector(4 downto 0) := (others => '0');

   signal bit_count : integer range 0 to 47;
   signal data_out1 : std_logic_vector(47 downto 0); -- Preamble, address, etc.
   signal data_out2 : std_logic_vector(15 downto 0);

begin

   proc_fsm : process (eth_clk_i)
   begin
      if rising_edge(eth_clk_i) then

         clk_count <= clk_count + 1;
         if clk_count = 0 then   -- Change state after falling edge of SMI clock
            ready <= '0';        -- Default value for all states

            case fsm_state is
               when IDLE_ST =>
                  ready <= '1';
                  mdio  <= '1';

                  if wren_i = '1' then
                     data_out1 <= X"FFFFFFFF" & "0101" & phy_i & addr_i & "00";
                     data_out2 <= data_i;
                     wrn       <= '1';
                     bit_count <= 47;
                     ready     <= '0';
                     fsm_state <= SETUP_ST;
                  end if;

                  if rden_i = '1' then
                     data_out1 <= X"FFFFFFFF" & "0110" & phy_i & addr_i & "11";
                     wrn       <= '0';
                     bit_count <= 47;
                     ready     <= '0';
                     fsm_state <= SETUP_ST;
                  end if;

               when SETUP_ST =>
                  mdio      <= data_out1(47);
                  data_out1 <= data_out1(46 downto 0) & '0';

                  -- During read, prepare to change direction of bus.
                  if bit_count < 2 and wrn = '0' then
                     mdio      <= 'Z';
                  end if;

                  if bit_count = 0 then
                     bit_count <= 15;
                     if wrn = '1' then
                        fsm_state <= WRITE_ST;
                     else
                        fsm_state <= READ_ST;
                        mdio      <= 'Z';
                     end if;
                  else
                     bit_count <= bit_count-1;
                  end if;

               when READ_ST =>
                  data      <= data(14 downto 0) & mdio;

                  if bit_count = 0 then
                     ready     <= '1';
                     fsm_state <= IDLE_ST;
                  else
                     bit_count <= bit_count-1;
                  end if;

               when WRITE_ST   =>
                  mdio      <= data_out2(15);
                  data_out2 <= data_out2(14 downto 0) & '0';

                  if bit_count = 0 then
                     ready     <= '1';
                     fsm_state <= IDLE_ST;
                  else
                     bit_count <= bit_count-1;
                  end if;

            end case;
         end if;

         if eth_rst_i = '1' then
            fsm_state <= IDLE_ST;
            clk_count <= (others => '0');
         end if;
      end if;
   end process proc_fsm;


   -- Drive output signals
   eth_mdio_io <= mdio;
   eth_mdc_o   <= clk_count(4);

   data_o  <= data;
   ready_o <= ready;

end Structural;

