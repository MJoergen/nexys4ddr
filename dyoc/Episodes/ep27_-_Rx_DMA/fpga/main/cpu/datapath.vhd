library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity datapath is
   port (
      clk_i   : in  std_logic;

      -- Memory interface
      wait_i  : in  std_logic;
      addr_o  : out std_logic_vector(15 downto 0);
      data_i  : in  std_logic_vector(7 downto 0);
      rden_o  : out std_logic;
      data_o  : out std_logic_vector(7 downto 0);
      wren_o  : out std_logic;
      sri_o   : out std_logic;

      -- Control signals
      ar_sel_i   : in  std_logic;
      hi_sel_i   : in  std_logic_vector(2 downto 0);
      lo_sel_i   : in  std_logic_vector(2 downto 0);
      pc_sel_i   : in  std_logic_vector(5 downto 0);
      addr_sel_i : in  std_logic_vector(3 downto 0);
      data_sel_i : in  std_logic_vector(2 downto 0);
      alu_sel_i  : in  std_logic_vector(4 downto 0);
      sr_sel_i   : in  std_logic_vector(3 downto 0);
      sp_sel_i   : in  std_logic_vector(1 downto 0);
      xr_sel_i   : in  std_logic;
      yr_sel_i   : in  std_logic;
      reg_sel_i  : in  std_logic_vector(1 downto 0);
      zp_sel_i   : in  std_logic_vector(1 downto 0);

      -- Debug output containing internal registers
      debug_o : out std_logic_vector(111 downto 0)
   );
end entity datapath;

architecture structural of datapath is

   constant SR_BR : std_logic_vector(7 downto 0) := X"30"; -- Set B and R.

   constant ADDR_NOP    : std_logic_vector(3 downto 0) := B"0000";
   constant ADDR_PC     : std_logic_vector(3 downto 0) := B"0001";
   constant ADDR_HL     : std_logic_vector(3 downto 0) := B"0010";
   constant ADDR_LO     : std_logic_vector(3 downto 0) := B"0011";
   constant ADDR_SP     : std_logic_vector(3 downto 0) := B"0100";
   constant ADDR_ZP     : std_logic_vector(3 downto 0) := B"0101";
   constant ADDR_BRK    : std_logic_vector(3 downto 0) := B"1000";
   constant ADDR_BRK1   : std_logic_vector(3 downto 0) := B"1001";
   constant ADDR_NMI    : std_logic_vector(3 downto 0) := B"1010";
   constant ADDR_NMI1   : std_logic_vector(3 downto 0) := B"1011";
   constant ADDR_RESET  : std_logic_vector(3 downto 0) := B"1100";
   constant ADDR_RESET1 : std_logic_vector(3 downto 0) := B"1101";
   constant ADDR_IRQ    : std_logic_vector(3 downto 0) := B"1110";
   constant ADDR_IRQ1   : std_logic_vector(3 downto 0) := B"1111";
   --
   constant DATA_NOP  : std_logic_vector(2 downto 0) := B"000";
   constant DATA_AR   : std_logic_vector(2 downto 0) := B"001";
   constant DATA_SR   : std_logic_vector(2 downto 0) := B"010";
   constant DATA_ALU  : std_logic_vector(2 downto 0) := B"011";
   constant DATA_PCLO : std_logic_vector(2 downto 0) := B"100";
   constant DATA_PCHI : std_logic_vector(2 downto 0) := B"101";
   constant DATA_SRI  : std_logic_vector(2 downto 0) := B"110";

   constant REG_AR    : std_logic_vector(1 downto 0) := B"00";
   constant REG_XR    : std_logic_vector(1 downto 0) := B"01";
   constant REG_YR    : std_logic_vector(1 downto 0) := B"10";
   constant REG_SP    : std_logic_vector(1 downto 0) := B"11";

   -- Input to ALU
   signal alu_reg : std_logic_vector(7 downto 0);

   -- Output from ALU
   signal alu_ar : std_logic_vector(7 downto 0);
   signal alu_sr : std_logic_vector(7 downto 0);
   
   -- Program Counter
   signal pc : std_logic_vector(15 downto 0);

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0);

   -- 'X' register
   signal xr : std_logic_vector(7 downto 0);

   -- 'Y' register
   signal yr : std_logic_vector(7 downto 0);

   -- Stack Pointer
   signal sp : std_logic_vector(7 downto 0);

   -- Status register
   signal sr : std_logic_vector(7 downto 0);

   -- Address Hi register
   signal hi : std_logic_vector(7 downto 0);
   
   -- Address Lo register
   signal lo : std_logic_vector(7 downto 0);

   -- Zero page register
   signal zp : std_logic_vector(7 downto 0);

   -- Status register written to stack during interrupt.
   signal sr_irq : std_logic_vector(7 downto 0);

   -- Output signals to memory
   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector(7 downto 0);
   signal wren : std_logic;
   signal mem  : std_logic;

begin

   alu_reg <= ar when reg_sel_i = REG_AR else
              xr when reg_sel_i = REG_XR else
              yr when reg_sel_i = REG_YR else
              sp when reg_sel_i = REG_SP else
              (others => '0');


   -------------------
   -- Instantiate ALU
   -------------------

   alu_inst : entity work.alu
   port map (
      a_i    => alu_reg,
      b_i    => data_i,
      sr_i   => sr,
      func_i => alu_sel_i,
      a_o    => alu_ar,
      sr_o   => alu_sr
   ); -- alu_inst


   -------------------------------
   -- Instantiate program Counter
   -------------------------------

   pc_inst : entity work.pc
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      pc_sel_i => pc_sel_i,
      hi_i     => hi,
      lo_i     => lo,
      sr_i     => sr,
      data_i   => data_i,
      pc_o     => pc
   ); -- pc_inst


   ----------------------------
   -- Instantiate 'A' register
   ----------------------------

   ar_inst : entity work.ar
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      ar_sel_i => ar_sel_i,
      alu_ar_i => alu_ar,
      ar_o     => ar
   ); -- ar_inst


   ----------------------------
   -- Instantiate 'X' register
   ----------------------------

   xr_inst : entity work.xr
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      xr_sel_i => xr_sel_i,
      alu_ar_i => alu_ar,
      xr_o     => xr
   ); -- xr_inst


   ----------------------------
   -- Instantiate 'Y' register
   ----------------------------

   yr_inst : entity work.yr
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      yr_sel_i => yr_sel_i,
      alu_ar_i => alu_ar,
      yr_o     => yr
   ); -- yr_inst


   -----------------------------
   -- Instantiate stack pointer
   -----------------------------

   sp_inst : entity work.sp
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      sp_sel_i => sp_sel_i,
      xr_i     => xr,
      sp_o     => sp
   ); -- sp_inst


   -------------------------------
   -- Instantiate status register
   -------------------------------

   sr_inst : entity work.sr
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      sr_sel_i => sr_sel_i,
      alu_sr_i => alu_sr,
      data_i   => data_i,
      sr_o     => sr
   ); -- sr_inst


   -----------------------------
   -- Instantiate 'Hi' register
   -----------------------------

   hi_inst : entity work.hi
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      hi_sel_i => hi_sel_i,
      data_i   => data_i,
      lo_i     => lo,
      xr_i     => xr,
      yr_i     => yr,
      hi_o     => hi
   ); -- hi_inst


   -----------------------------
   -- Instantiate 'Lo' register
   -----------------------------

   lo_inst : entity work.lo
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      lo_sel_i => lo_sel_i,
      data_i   => data_i,
      hi_i     => hi,
      xr_i     => xr,
      yr_i     => yr,
      lo_o     => lo
   ); -- lo_inst


   ----------------------------------
   -- Instantiate zero-page register
   ----------------------------------

   zp_inst : entity work.zp
   port map (
      clk_i    => clk_i,
      wait_i   => wait_i,
      zp_sel_i => zp_sel_i,
      data_i   => data_i,
      xr_i     => xr,
      zp_o     => zp
   ); -- zp_inst


   sr_irq_proc : process (sr)
   begin
      sr_irq <= sr;
      sr_irq(5) <= '1';    -- Reserved
      sr_irq(4) <= '0';    -- Break
   end process sr_irq_proc;


   -- Output multiplexers
   addr <= (others => '0') when addr_sel_i = ADDR_NOP    else
           pc              when addr_sel_i = ADDR_PC     else
           hi & lo         when addr_sel_i = ADDR_HL     else
           X"00" & lo      when addr_sel_i = ADDR_LO     else
           X"01" & sp      when addr_sel_i = ADDR_SP     else
           X"00" & zp      when addr_sel_i = ADDR_ZP     else
           X"FFFA"         when addr_sel_i = ADDR_NMI    else
           X"FFFB"         when addr_sel_i = ADDR_NMI1   else
           X"FFFC"         when addr_sel_i = ADDR_RESET  else
           X"FFFD"         when addr_sel_i = ADDR_RESET1 else
           X"FFFE"         when addr_sel_i = ADDR_IRQ    else
           X"FFFF"         when addr_sel_i = ADDR_IRQ1   else
           X"FFFE"         when addr_sel_i = ADDR_BRK    else
           X"FFFF"         when addr_sel_i = ADDR_BRK1   else
           (others => '0');

   data <= (others => '0') when data_sel_i = DATA_NOP  else
           ar              when data_sel_i = DATA_AR   else
           -- Bits B and R must always be set when pushing onto stack.
           sr or SR_BR     when data_sel_i = DATA_SR   else
           alu_ar          when data_sel_i = DATA_ALU  else
           pc(7 downto 0)  when data_sel_i = DATA_PCLO else
           pc(15 downto 8) when data_sel_i = DATA_PCHI else
           sr_irq          when data_sel_i = DATA_SRI  else
           (others => '0');

   wren <= '1' when data_sel_i = DATA_AR   or
                    data_sel_i = DATA_SR   or
                    data_sel_i = DATA_ALU  or
                    data_sel_i = DATA_PCLO or
                    data_sel_i = DATA_PCHI or
                    data_sel_i = DATA_SRI  else
           '0';

   mem  <= '1' when addr_sel_i = ADDR_PC     or
                    addr_sel_i = ADDR_HL     or
                    addr_sel_i = ADDR_LO     or
                    addr_sel_i = ADDR_SP     or
                    addr_sel_i = ADDR_ZP     or
                    addr_sel_i = ADDR_NMI    or
                    addr_sel_i = ADDR_NMI1   or
                    addr_sel_i = ADDR_RESET  or
                    addr_sel_i = ADDR_RESET1 or
                    addr_sel_i = ADDR_IRQ    or
                    addr_sel_i = ADDR_IRQ1   or
                    addr_sel_i = ADDR_BRK    or
                    addr_sel_i = ADDR_BRK1   else
           '0';

   ------------------------
   -- Drive output signals
   ------------------------

   debug_o( 15 downto   0) <= pc;     -- Two bytes
   debug_o( 23 downto  16) <= ar;     -- One byte
   debug_o( 31 downto  24) <= data_i; -- One byte
   debug_o( 39 downto  32) <= lo;     -- One byte
   debug_o( 47 downto  40) <= hi;     -- One byte
   debug_o( 63 downto  48) <= addr;   -- Two bytes
   debug_o( 71 downto  64) <= data;   -- One byte
   debug_o( 72)            <= wren;   -- One byte
   debug_o( 73)            <= mem and not wren;
   debug_o( 79 downto  74) <= (others => '0');
   debug_o( 87 downto  80) <= sr;     -- One byte
   debug_o( 95 downto  88) <= sp;
   debug_o(103 downto  96) <= yr;
   debug_o(111 downto 104) <= xr;

   addr_o <= addr;
   data_o <= data;
   wren_o <= wren;
   rden_o <= mem and (not wren or alu_sel_i(4));
   sri_o  <= sr(2); -- IRQ mask

end architecture structural;

