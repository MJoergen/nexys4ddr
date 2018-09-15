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
      -- Connected to SMI
      smi_ready_i : in  std_logic;
      smi_addr_o  : out std_logic_vector(4 downto 0);
      smi_rden_o  : out std_logic;
      smi_data_i  : in  std_logic_vector(15 downto 0);
      -- Connected to user
      user_data_o : out std_logic_vector(32*16-1 downto 0)
   );
end read_smi;

architecture Structural of read_smi is

   -- 1 millisecond @ 25 MHz = 25000
   constant CNT_MAX : std_logic_vector(14 downto 0) := std_logic_vector(to_unsigned(25000-1, 15));
   signal counter   : std_logic_vector(14 downto 0) := (others => '0');

   signal smi_addr  : std_logic_vector(4 downto 0) := (others => '0');
   signal smi_rden  : std_logic := '0';
   signal user_data : std_logic_vector(32*16-1 downto 0);

begin

   proc_counter : process (clk_i)
   begin
      if rising_edge(clk_i) then
         counter <= counter + 1;

         if counter = CNT_MAX then
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
         if smi_ready_i = '1' and counter = CNT_MAX then
            -- Store result from previous read.
            user_data(conv_integer(smi_addr)*16 + 15 downto conv_integer(smi_addr)*16) <= smi_data_i;

            -- Start next read.
            smi_addr <= smi_addr + 1;
            smi_rden <= '1';
         end if;

         -- Deassert read request when it has been acknowledged.
         if smi_ready_i = '0' then
            smi_rden <= '0';
         end if;
      end if;
   end process proc_smi;

   -- Drive output signals
   smi_addr_o  <= smi_addr;
   smi_rden_o  <= smi_rden;
   user_data_o <= user_data;

end Structural;

