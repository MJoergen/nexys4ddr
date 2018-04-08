library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This stores the configuration and status information
-- Configuration information is provided in the config_o signal, and includes
-- * 0x00-0x07 X-position (2 bytes pr MOB)
-- * 0x08-0x0B Y-position (1 byte pr MOB)
-- * 0x0C-0x0F Color      (1 byte pr MOB)
-- * 0x10-0x13 Enable     (1 byte pr MOB)
-- * 0x18 Foreground text colour
-- * 0x19 Background text colour
-- * 0x1A Horizontal pixel shift
-- * 0x1B Y-line interrupt
-- * 0x1C IRQ status
-- * 0x1D IRQ mask
-- * 0x1E Keyboard

entity conf_mem is

   generic (
      G_CONF_SIZE : integer           -- Number of bits in CONF address
   );
   port (
      a_clk_i     : in  std_logic;
      a_rst_i     : in  std_logic;
      a_addr_i    : in  std_logic_vector(15 downto 0);
      a_wr_en_i   : in  std_logic;
      a_wr_data_i : in  std_logic_vector(7 downto 0);
      a_rd_en_i   : in  std_logic;
      a_rd_data_o : out std_logic_vector(7 downto 0);
      a_irq_o     : out std_logic;
      a_kb_rden_o : out std_logic;
      a_kb_val_i  : in  std_logic_vector(7 downto 0);
      --
      b_clk_i     : in  std_logic;
      b_rst_i     : in  std_logic;
      b_yline_i   : in  std_logic_vector(7 downto 0);
      b_config_o  : out std_logic_vector(2**(G_CONF_SIZE+3)-1 downto 0);
      b_irq_i     : in  std_logic
  );
end conf_mem;

architecture Structural of conf_mem is

   signal config : std_logic_vector(2**(G_CONF_SIZE+3)-1 downto 0) := (others => '0');

   signal irq : std_logic := '0';

   constant C_YLINE    : integer := 27;
   constant C_IRQ_STAT : integer := 28;
   constant C_IRQ_MASK : integer := 29;
   constant C_KBD      : integer := 30;

   signal a_yline_d : std_logic_vector(7 downto 0);

begin

   --------------
   -- Port A
   --------------

   -- Synchronize
   proc_sync : process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         a_yline_d <= b_yline_i;
      end if;
   end process proc_sync;

   conf_a_proc : process (a_clk_i)
      variable addr_v : integer range 0 to 2**G_CONF_SIZE-1;
   begin
      if rising_edge(a_clk_i) then
         addr_v := conv_integer(a_addr_i(G_CONF_SIZE-1 downto 0));
         if a_wr_en_i = '1' then
            config(addr_v*8+7 downto addr_v*8) <= a_wr_data_i;
         end if;
      end if;
   end process conf_a_proc;

   process (a_addr_i, a_rd_en_i, config, a_kb_val_i)
      variable addr_v : integer range 0 to 2**G_CONF_SIZE-1;
   begin
      addr_v := conv_integer(a_addr_i(G_CONF_SIZE-1 downto 0));
      a_rd_data_o <= (others => '0');  -- Default value to avoid latch.
      a_kb_rden_o <= '0';              -- Default value to avoid latch.
      if a_rd_en_i = '1' then
         case addr_v is
            when C_YLINE =>
               a_rd_data_o <= a_yline_d;
            when C_KBD =>
               a_rd_data_o <= a_kb_val_i;
               a_kb_rden_o <= '1';
            when C_IRQ_STAT =>
               a_rd_data_o(0) <= irq;
            when others =>
               a_rd_data_o <= config(addr_v*8+7 downto addr_v*8);
         end case;
      end if;
   end process;


   --------------
   -- Port B
   --------------

   conf_b_proc : process (b_clk_i)
   begin
      if rising_edge(b_clk_i) then
         b_config_o <= config;
      end if;
   end process conf_b_proc;


   ------------------------------------
   -- Control the IRQ signal to the CPU
   ------------------------------------

   p_status : process (a_clk_i)
   begin
      if falling_edge(a_clk_i) then
         
         -- Special processing when reading from 0x8640
         if conv_integer(a_addr_i(G_CONF_SIZE-1 downto 0)) = C_IRQ_STAT and a_rd_en_i = '1' then
            irq <= '0';
         end if;

         if b_irq_i = '1' and config(C_IRQ_MASK*8) = '1' then  -- IRQ Mask
            irq <= '1';
         end if;

         if a_rst_i = '1' then
            irq <= '0';
         end if;

      end if;
   end process p_status;

   a_irq_o <= irq;

end Structural;

