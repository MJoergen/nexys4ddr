--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output, but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity cpu_module is
   port (
      -- Clock
      clk_i     : in  std_logic;

      -- Memory and I/O interface
      addr_o    : out std_logic_vector(15 downto 0);
      data_i    : in  std_logic_vector(7 downto 0);
      wren_o    : out std_logic;
      data_o    : out std_logic_vector(7 downto 0);

      -- Debug (to show on the VGA)
      invalid_o : out std_logic_vector(7 downto 0);
      status_o  : out std_logic_vector(127 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

   signal pc_sel    : std_logic_vector(1 downto 0);
   signal a_sel     : std_logic_vector(1 downto 0);
   signal sr_sel    : std_logic_vector(1 downto 0);
   signal addr_sel  : std_logic_vector(1 downto 0);
   signal data_sel  : std_logic_vector(1 downto 0);
   signal lo_sel    : std_logic;
   signal hi_sel    : std_logic;

   signal pc_reg    : std_logic_vector(15 downto 0);
   signal a_reg     : std_logic_vector(7 downto 0);
   signal sr_reg    : std_logic_vector(7 downto 0);
   signal lo_reg    : std_logic_vector(7 downto 0);
   signal hi_reg    : std_logic_vector(7 downto 0);

   signal addr_s    : std_logic_vector(15 downto 0);
   signal data_s    : std_logic_vector(7 downto 0);

   constant PC_NOP  : std_logic_vector(1 downto 0) := "00";
   constant PC_INC  : std_logic_vector(1 downto 0) := "01";

   constant A_NOP   : std_logic_vector(1 downto 0) := "00";
   constant A_DATA  : std_logic_vector(1 downto 0) := "01";

   constant SR_NOP  : std_logic_vector(1 downto 0) := "00";

   constant LO_NOP  : std_logic := '0';
   constant LO_DATA : std_logic := '1';

   constant HI_NOP  : std_logic := '0';
   constant HI_DATA : std_logic := '1';

   constant ADDR_NOP : std_logic_vector(1 downto 0) := "00";
   constant ADDR_PC  : std_logic_vector(1 downto 0) := "01";
   constant ADDR_HL  : std_logic_vector(1 downto 0) := "10";

   constant DATA_NOP : std_logic_vector(1 downto 0) := "00";
   constant DATA_A   : std_logic_vector(1 downto 0) := "01";


begin

   -- Instantiate the control logic
   inst_ctl : entity work.ctl
   port map (
      clk_i      => clk_i,
      data_i     => data_i,
      pc_sel_o   => pc_sel,
      a_sel_o    => a_sel,
      sr_sel_o   => sr_sel,
      lo_sel_o   => lo_sel,
      hi_sel_o   => hi_sel,
      addr_sel_o => addr_sel,
      data_sel_o => data_sel
   );

   p_pc_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case pc_sel is
            when PC_NOP => null;
            when PC_INC => pc_reg <= pc_reg + 1;
            when others => null;
         end case;
      end if;
   end process p_pc_reg;

   p_a_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case a_sel is
            when A_NOP  => null;
            when A_DATA => a_reg <= data_i;
            when others => null;
         end case;
      end if;
   end process p_a_reg;

   p_sr_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case sr_sel is
            when SR_NOP => null;
            when others => null;
         end case;
      end if;
   end process p_sr_reg;

   p_lo_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case lo_sel is
            when LO_NOP  => null;
            when LO_DATA => lo_reg <= data_i;
            when others  => null;
         end case;
      end if;
   end process p_lo_reg;

   p_hi_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case hi_sel is
            when HI_NOP  => null;
            when HI_DATA => hi_reg <= data_i;
            when others  => null;
         end case;
      end if;
   end process p_hi_reg;

   addr_s <= (others => '0') when addr_sel = ADDR_NOP else
             pc_reg          when addr_sel = ADDR_PC else
             hi_reg & lo_reg when addr_sel = ADDR_HL else
             (others => '0');
   
   data_s <= (others => '0') when data_sel = DATA_NOP else
             a_reg           when data_sel = DATA_A else
             (others => '0');

   -----------------------
   -- Drive output signals
   -----------------------

   addr_o    <= addr_s;
   data_o    <= data_s;
   invalid_o <= (others => '0');
   status_o  <= (others => '0');

end Structural;

