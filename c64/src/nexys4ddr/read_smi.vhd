library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This modules continuously reads the SMI from the PHY.
-- Once every millisecond, one of the 32 registers are read.
-- Thus, all registers are read approx 30 times a second.

entity read_smi is

   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      ready_i     : in  std_logic;
      addr_o      : out std_logic_vector(4 downto 0);
      rden_o      : out std_logic;
      data_i      : in  std_logic_vector(15 downto 0);
      registers_o : out std_logic_vector(32*16-1 downto 0)
   );
end read_smi;

architecture Structural of read_smi is

   -- 1 millisecond @ 25 MHz = 25000
   constant CNT_MAX : std_logic_vector(14 downto 0) := std_logic_vector(to_unsigned(25000-1, 15));
   signal counter   : std_logic_vector(14 downto 0) := (others => '0');

   signal addr      : std_logic_vector(4 downto 0);
   signal rden      : std_logic;
   signal registers : std_logic_vector(32*16-1 downto 0);

begin

   proc_counter : process (clk_i)
   begin
      if rising_edge(clk_i) then
         counter <= counter + 1;

         if counter = CNT_MAX then
            counter <= (others => '0');
         end if;

         if rst_i = '1' then
            counter <= (others => '0');
         end if;
      end if;
   end process proc_counter;


   ------------------------------
   -- Read SMI from PHY
   ------------------------------

   proc_smi : process (clk_i)
      variable state_v : std_logic_vector(1 downto 0);
   begin
      if rising_edge(clk_i) then
         state_v := ready_i & rden;
         case state_v is
            when "10" => -- Start new read
               if counter = 0 then
                  -- Store result.
                  registers(conv_integer(addr)*16 + 15 downto conv_integer(addr)*16)
                     <= data_i;

                  -- Start next read.
                  addr <= addr + 1;
                  rden <= '1';
               end if;

            when "11" => -- Wait for acknowledge
               null;
            when "01" => -- Read acknowledged
               rden <= '0';
            when "00" => -- Wait for result
               null;
            when others =>
               null;
         end case;

         if rst_i = '1' then
            rden <= '0';
            addr <= (others => '0');
         end if;
      end if;
   end process proc_smi;

   -- Drive output signals
   addr_o      <= addr;
   rden_o      <= rden;
   registers_o <= registers;

end Structural;

