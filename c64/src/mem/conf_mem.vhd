library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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
-- * 0x1F Collision

entity conf_mem is

   generic (
      G_NEXYS4DDR : boolean;          -- True, when using the Nexys4DDR board.
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
      b_clk_i       : in  std_logic;
      b_rst_i       : in  std_logic;
      b_vcount_i    : in  std_logic_vector(10 downto 0);
      b_hcount_i    : in  std_logic_vector(10 downto 0);
      b_collision_i : in  std_logic_vector(3 downto 0);
      b_config_o    : out std_logic_vector(2**(G_CONF_SIZE+3)-1 downto 0)
  );
end conf_mem;

architecture Structural of conf_mem is

   constant C_FGCOL     : integer := 24;
   constant C_BGCOL     : integer := 25;
   constant C_YLINE     : integer := 27;
   constant C_IRQ_STAT  : integer := 28;
   constant C_IRQ_MASK  : integer := 29;
   constant C_KBD       : integer := 30;
   constant C_COLLISION : integer := 31;

   signal a_vcount    : std_logic_vector(10 downto 0);
   signal a_hcount    : std_logic_vector(10 downto 0);
   signal a_collision : std_logic_vector( 3 downto 0);
   signal a_config    : std_logic_vector(2**(G_CONF_SIZE+3)-1 downto 0) := (
      C_FGCOL*8+7 downto C_FGCOL*8 => '1',
      C_BGCOL*8+7 downto C_BGCOL*8 => '0',
      others => '0');
   signal a_rd_data   : std_logic_vector(7 downto 0);

   signal a_irq_s      : std_logic_vector(1 downto 0);
   signal a_irq_latch  : std_logic_vector(1 downto 0) := (others => '0');
   signal a_coll_latch : std_logic_vector(3 downto 0) := (others => '0');

   signal b_config    : std_logic_vector(2**(G_CONF_SIZE+3)-1 downto 0);

begin

   ----------------------------------
   -- Clock synchronizers
   ----------------------------------

   -- From @b_clk_i to @a_clk_i
   inst_cdc_vcount : entity work.cdcvector
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_SIZE      => 11
   )
   port map (
      rx_clk_i => b_clk_i,
      rx_in_i  => b_vcount_i,
      tx_clk_i => a_clk_i,
      tx_out_o => a_vcount
   );

   inst_cdc_hcount : entity work.cdcvector
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_SIZE      => 11
   )
   port map (
      rx_clk_i => b_clk_i,
      rx_in_i  => b_hcount_i,
      tx_clk_i => a_clk_i,
      tx_out_o => a_hcount
   );

   inst_cdc_collision : entity work.cdcvector
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_SIZE      => 4
   )
   port map (
      rx_clk_i => b_clk_i,
      rx_in_i  => b_collision_i,
      tx_clk_i => a_clk_i,
      tx_out_o => a_collision
   );

   -- From @a_clk_i to @b_clk_i
   inst_cdcvector_config : entity work.cdcvector
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_SIZE      => 2**(G_CONF_SIZE+3)
   )
   port map (
      rx_clk_i => a_clk_i,
      rx_in_i  => a_config,
      tx_clk_i => b_clk_i,
      tx_out_o => b_config
   );


   --------------
   -- Port A
   --------------

   -- Generate interrupt
   a_irq_s(0) <= '1' when a_vcount(8 downto 0) = (a_config(C_YLINE*8+7 downto C_YLINE*8) & '1')
                      and a_hcount = std_logic_vector(to_unsigned(656, 11)) else '0';
   a_irq_s(1) <= '1' when a_collision /= "0000" else '0';


   proc_write : process (a_clk_i)
      variable addr_v : integer range 0 to 2**G_CONF_SIZE-1;
      variable a_irq_latch_v  : std_logic_vector(1 downto 0);
      variable a_coll_latch_v : std_logic_vector(3 downto 0);
   begin
      if rising_edge(a_clk_i) then
         addr_v := conv_integer(a_addr_i(G_CONF_SIZE-1 downto 0));

         a_irq_latch_v  := a_irq_latch;
         a_coll_latch_v := a_coll_latch;

         if a_wr_en_i = '1' then
            a_config(addr_v*8+7 downto addr_v*8) <= a_wr_data_i;

            if addr_v = C_IRQ_STAT then
               a_irq_latch_v := a_irq_latch_v and not a_wr_data_i(1 downto 0);
            end if;
            if addr_v = C_COLLISION then
               a_coll_latch_v := a_coll_latch_v and not a_wr_data_i(3 downto 0);
            end if;
         end if;

         a_irq_latch_v  := a_irq_latch_v or (a_irq_s and a_config(C_IRQ_MASK*8+1 downto C_IRQ_MASK*8));
         a_coll_latch_v := a_coll_latch_v or a_collision;

         a_irq_latch  <= a_irq_latch_v;
         a_coll_latch <= a_coll_latch_v;

         a_config(C_IRQ_STAT*8+1  downto C_IRQ_STAT*8)  <= a_irq_latch_v;
         a_config(C_COLLISION*8+3 downto C_COLLISION*8) <= a_coll_latch_v;

         if a_rst_i = '1' then
            a_irq_latch  <= (others => '0');
            a_coll_latch <= (others => '0');
         end if;
      end if;
   end process proc_write;

   proc_read : process (a_clk_i)
      variable addr_v : integer range 0 to 2**G_CONF_SIZE-1;
   begin
      if rising_edge(a_clk_i) then
         addr_v := conv_integer(a_addr_i(G_CONF_SIZE-1 downto 0));

         a_rd_data <= (others => '0');

         if a_rd_en_i = '1' then
            case addr_v is
               when C_YLINE     =>
                  a_rd_data <= a_vcount(8 downto 1);
               when C_KBD       =>
                  a_rd_data <= a_kb_val_i;
               when C_IRQ_STAT  =>
                  a_rd_data(1 downto 0) <= a_irq_latch;
               when C_COLLISION =>
                  a_rd_data(3 downto 0) <= a_coll_latch;
               when others =>
                  a_rd_data <= a_config(addr_v*8+7 downto addr_v*8);
            end case;
         end if;
      end if;
   end process proc_read;

   -- Drive output signals.
   a_irq_o     <= '1' when a_irq_latch /= 0 else '0';
   a_rd_data_o <= a_rd_data;
   a_kb_rden_o <= '1' when a_rd_en_i = '1' and a_addr_i(G_CONF_SIZE-1 downto 0) = C_KBD
                  else '0';      -- Has to be combinatorial.


   --------------
   -- Port B
   --------------

   -- Drive output signals.
   b_config_o <= b_config;

end Structural;

