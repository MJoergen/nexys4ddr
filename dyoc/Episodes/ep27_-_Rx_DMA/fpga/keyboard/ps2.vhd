library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity ps2 is
   port (
      clk_i      : in std_logic;

      -- From keyboard
      ps2_clk_i  : in std_logic;
      ps2_data_i : in std_logic;

      data_o     : out std_logic_vector(7 downto 0);
      valid_o    : out std_logic
   );
end entity ps2;

architecture structural of ps2 is

   -- Registered input from keyboard
   signal ps2_clk_r  : std_logic;
   signal ps2_data_r : std_logic;

   -- Delayed clock signal
   signal ps2_clk_d  : std_logic;

   -- Number of valid bits received
   signal cnt      : integer range 0 to 11 := 0;

   signal shiftreg : std_logic_vector(10 downto 0);

   signal data     : std_logic_vector(7 downto 0);
   signal valid    : std_logic := '0';

begin

   --------------------------------
   -- Register inputs from keyboard
   --------------------------------

   p_ps2_r : process (clk_i)
   begin
      if rising_edge(clk_i) then
         ps2_clk_r  <= ps2_clk_i;
         ps2_data_r <= ps2_data_i;
      end if;
   end process p_ps2_r;


   --------------------------------
   -- Prepare for edge detect
   --------------------------------

   p_ps2_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         ps2_clk_d <= ps2_clk_r;
      end if;
   end process p_ps2_delay;


   --------------------------------
   -- Shift register
   -- This holds 11 bits:
   -- S01234567PT, where
   -- S is Start, P is parity, and T is Stop.
   -- When all 11 bits are received, bit 0
   -- will be the Start bit, and bit 10 will
   -- be the Stop bit.
   --------------------------------

   p_shift : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Wait for falling edge on ps2_clk
         if ps2_clk_d = '1' and ps2_clk_r = '0' then
            shiftreg <= ps2_data_r & shiftreg(10 downto 1);
         end if;
      end if;
   end process p_shift;


   ------------------------------------------------------------
   -- This implements a simple state machine
   -- that waits for 11 bits and then checks
   -- whether there was a valid start bit and a stop bit.
   -- If yes, it marks the byte as valid.
   -- If no, it keeps searching for a valid start and stop bit.
   --
   -- The main reason for having this state machine is
   -- to being able to recover in case the keyboard
   -- and the FPGA come out of sync.
   ------------------------------------------------------------
   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         valid <= '0';

         -- Wait for rising edge on ps2_clk
         if ps2_clk_d = '0' and ps2_clk_r = '1' then
            data <= (others => '0');

            if cnt < 10 then
               cnt <= cnt + 1;
            else
               if shiftreg(10) = '1' and  -- Stop bit
                  shiftreg(0) = '0' then  -- Start bit
                  data <= shiftreg(8 downto 1);
                  valid  <= '1';
                  cnt  <= 0;
               end if;
            end if;
         end if;
      end if;
   end process p_cnt;


   ------------------------------------------------------------
   -- Drive output signals
   ------------------------------------------------------------

   data_o  <= data;
   valid_o <= valid;

end architecture structural;

