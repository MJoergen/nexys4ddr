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

   -- The Status Register contains: SV-BDIZC
   constant SR_C : integer := 0;
   constant SR_Z : integer := 1;
   constant SR_I : integer := 2;
   constant SR_D : integer := 3;
   constant SR_B : integer := 4;
   constant SR_R : integer := 5;    -- Bit 5 is reserved.
   constant SR_V : integer := 6;
   constant SR_S : integer := 7;
   constant SR_BR : std_logic_vector(7 downto 0) := (SR_B => '1', SR_R => '1', others => '0');

   constant PC_NOP  : std_logic_vector(2 downto 0) := B"000";
   constant PC_INC  : std_logic_vector(2 downto 0) := B"001";
   constant PC_HL   : std_logic_vector(2 downto 0) := B"010";
   constant PC_HL1  : std_logic_vector(2 downto 0) := B"011";
   constant PC_SR   : std_logic_vector(2 downto 0) := B"100";
   constant PC_D_HI : std_logic_vector(2 downto 0) := B"101";
   constant PC_D_LO : std_logic_vector(2 downto 0) := B"110";
   --
   constant PC_BPL : std_logic_vector(2 downto 0) := B"000";
   constant PC_BMI : std_logic_vector(2 downto 0) := B"001";
   constant PC_BVC : std_logic_vector(2 downto 0) := B"010";
   constant PC_BVS : std_logic_vector(2 downto 0) := B"011";
   constant PC_BCC : std_logic_vector(2 downto 0) := B"100";
   constant PC_BCS : std_logic_vector(2 downto 0) := B"101";
   constant PC_BNE : std_logic_vector(2 downto 0) := B"110";
   constant PC_BEQ : std_logic_vector(2 downto 0) := B"111";
   --
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
   --
   constant SR_NOP    : std_logic_vector(3 downto 0) := B"0000";
   constant SR_ALU    : std_logic_vector(3 downto 0) := B"0001";
   constant SR_DATA   : std_logic_vector(3 downto 0) := B"0010";
   constant SR_CLC    : std_logic_vector(3 downto 0) := B"1000";
   constant SR_SEC    : std_logic_vector(3 downto 0) := B"1001";
   constant SR_CLI    : std_logic_vector(3 downto 0) := B"1010";
   constant SR_SEI    : std_logic_vector(3 downto 0) := B"1011";
   constant SR_CLV    : std_logic_vector(3 downto 0) := B"1100";
   constant SR_CLD    : std_logic_vector(3 downto 0) := B"1110";
   constant SR_SED    : std_logic_vector(3 downto 0) := B"1111";
   --
   constant SP_NOP    : std_logic_vector(1 downto 0) := B"00";
   constant SP_INC    : std_logic_vector(1 downto 0) := B"01";
   constant SP_DEC    : std_logic_vector(1 downto 0) := B"10";
   constant SP_XR     : std_logic_vector(1 downto 0) := B"11";
   --
   constant HI_NOP    : std_logic_vector(2 downto 0) := B"000";
   constant HI_DATA   : std_logic_vector(2 downto 0) := B"001";
   constant HI_ADDX   : std_logic_vector(2 downto 0) := B"010";
   constant HI_ADDY   : std_logic_vector(2 downto 0) := B"011";
   constant HI_INC    : std_logic_vector(2 downto 0) := B"100";
   --
   constant LO_NOP    : std_logic_vector(2 downto 0) := B"000";
   constant LO_DATA   : std_logic_vector(2 downto 0) := B"001";
   constant LO_ADDX   : std_logic_vector(2 downto 0) := B"010";
   constant LO_ADDY   : std_logic_vector(2 downto 0) := B"011";
   constant LO_INC    : std_logic_vector(2 downto 0) := B"100";
   --
   constant ZP_NOP    : std_logic_vector(1 downto 0) := B"00";
   constant ZP_DATA   : std_logic_vector(1 downto 0) := B"01";
   constant ZP_ADDX   : std_logic_vector(1 downto 0) := B"10";
   constant ZP_INC    : std_logic_vector(1 downto 0) := B"11";
   --
   constant REG_AR    : std_logic_vector(1 downto 0) := B"00";
   constant REG_XR    : std_logic_vector(1 downto 0) := B"01";
   constant REG_YR    : std_logic_vector(1 downto 0) := B"10";
   constant REG_SP    : std_logic_vector(1 downto 0) := B"11";

   -- Convert signed 8-bit number to signed 16-bit number
   function sign_extend(arg : std_logic_vector(7 downto 0))
   return std_logic_vector is
      variable res : std_logic_vector(15 downto 0);
   begin
      res := (others => arg(7)); -- Copy sign bit to all bits.
      res(7 downto 0) := arg;
      return res;
   end function sign_extend;

   -- Input to ALU
   signal alu_reg : std_logic_vector(7 downto 0);

   -- Output from ALU
   signal alu_ar : std_logic_vector(7 downto 0);
   signal alu_sr : std_logic_vector(7 downto 0);
   
   -- Program Counter
   signal pc : std_logic_vector(15 downto 0);

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0) := (others => '0');

   -- 'X' register
   signal xr : std_logic_vector(7 downto 0) := (others => '0');

   -- 'Y' register
   signal yr : std_logic_vector(7 downto 0) := (others => '0');

   -- Stack Pointer
   signal sp : std_logic_vector(7 downto 0) := X"FF";

   -- Status register
   signal sr : std_logic_vector(7 downto 0) := (others => '0');

   -- Address Hi register
   signal hi : std_logic_vector(7 downto 0) := (others => '0');
   
   -- Address Lo register
   signal lo : std_logic_vector(7 downto 0) := (others => '0');

   -- Zero-page register
   signal zp : std_logic_vector(7 downto 0);

   -- Indirect addressing
   signal hilo_addx_s : std_logic_vector(15 downto 0);
   signal hilo_addy_s : std_logic_vector(15 downto 0);
   signal hilo_inc_s  : std_logic_vector(15 downto 0);

   -- Output signals to memory
   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector(7 downto 0);
   signal wren : std_logic;

   -- Status register written to stack during interrupt.
   signal sr_irq : std_logic_vector(7 downto 0);

begin

   alu_reg <= ar when reg_sel_i = REG_AR else
              xr when reg_sel_i = REG_XR else
              yr when reg_sel_i = REG_YR else
              sp when reg_sel_i = REG_SP else
              (others => '0');

   -- Instantiate ALU
   i_alu : entity work.alu
   port map (
      a_i    => alu_reg,
      b_i    => data_i,
      sr_i   => sr,
      func_i => alu_sel_i,
      a_o    => alu_ar,
      sr_o   => alu_sr
   );

   -- Program Counter
   p_pc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case pc_sel_i(2 downto 0) is
               when PC_NOP => null;
               when PC_INC => pc <= pc + 1;
               when PC_HL  => pc <= hi & lo;
               when PC_HL1 => pc <= (hi & lo) + 1;
               when PC_SR  =>
                  if (pc_sel_i(5 downto 3) = PC_BPL and sr(SR_S) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BMI and sr(SR_S) = '1') or
                     (pc_sel_i(5 downto 3) = PC_BVC and sr(SR_V) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BVS and sr(SR_V) = '1') or
                     (pc_sel_i(5 downto 3) = PC_BCC and sr(SR_C) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BCS and sr(SR_C) = '1') or
                     (pc_sel_i(5 downto 3) = PC_BNE and sr(SR_Z) = '0') or
                     (pc_sel_i(5 downto 3) = PC_BEQ and sr(SR_Z) = '1') then
                     pc <= pc + 1 + sign_extend(data_i);
                  else
                     pc <= pc + 1;  -- If branch is not taken, just go to the next instruction.
                  end if;
               when PC_D_HI => pc(15 downto 8) <= data_i;
               when PC_D_LO => pc( 7 downto 0) <= data_i;
               when others => null;
            end case;
         end if;
      end if;
   end process p_pc;

   -- 'A' register
   p_ar : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if ar_sel_i = '1' then
               ar <= alu_ar;
            end if;
         end if;
      end if;
   end process p_ar;

   -- 'X' register
   p_xr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if xr_sel_i = '1' then
               xr <= alu_ar;
            end if;
         end if;
      end if;
   end process p_xr;

   -- 'Y' register
   p_yr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if yr_sel_i = '1' then
               yr <= alu_ar;
            end if;
         end if;
      end if;
   end process p_yr;

   -- Stack Pointer
   p_sp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case sp_sel_i is
               when SP_NOP => null;
               when SP_INC => sp <= sp + 1;
               when SP_DEC => sp <= sp - 1;
               when SP_XR  => sp <= xr;
               when others => null;
            end case;
         end if;
      end if;
   end process p_sp;

   -- Status register
   p_sr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case sr_sel_i is
               when SR_NOP  => null;
               when SR_ALU  => sr <= alu_sr;
               when SR_DATA => sr <= data_i;
               when SR_CLC  => sr(SR_C) <= '0';
               when SR_SEC  => sr(SR_C) <= '1';
               when SR_CLI  => sr(SR_I) <= '0';
               when SR_SEI  => sr(SR_I) <= '1';
               when SR_CLV  => sr(SR_V) <= '0';
               when SR_CLD  => sr(SR_D) <= '0';
               when SR_SED  => sr(SR_D) <= '1';
               when others => null;
            end case;
         end if;
      end if;
   end process p_sr;

   hilo_addx_s <= (hi & lo) + xr;
   hilo_addy_s <= (hi & lo) + yr;
   hilo_inc_s  <= (hi & lo) + 1;

   -- 'Hi' register
   p_hi : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case hi_sel_i is
               when HI_NOP  => null;
               when HI_DATA => hi <= data_i;
               when HI_ADDX => hi <= hilo_addx_s(15 downto 8);
               when HI_ADDY => hi <= hilo_addy_s(15 downto 8);
               when HI_INC  => hi <= hilo_inc_s (15 downto 8);
               when others  => null;
            end case;
         end if;
      end if;
   end process p_hi;

   -- 'Lo' register
   p_lo : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case lo_sel_i is
               when LO_NOP  => null;
               when LO_DATA => lo <= data_i;
               when LO_ADDX => lo <= hilo_addx_s(7 downto 0);
               when LO_ADDY => lo <= hilo_addy_s(7 downto 0);
               when LO_INC  => lo <= hilo_inc_s (7 downto 0);
               when others  => null;
            end case;
         end if;
      end if;
   end process p_lo;

   -- 'Zp' register
   p_zp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case zp_sel_i is
               when ZP_NOP  => null;
               when ZP_DATA => zp <= data_i;
               when ZP_ADDX => zp <= zp + xr;
               when ZP_INC  => zp <= zp + 1;
               when others  => null;
            end case;
         end if;
      end if;
   end process p_zp;

   p_sr_irq : process (sr)
   begin
      sr_irq <= sr;
      sr_irq(SR_R) <= '1';
      sr_irq(SR_B) <= '0';
   end process p_sr_irq;

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


   -----------------
   -- Drive output signals
   -----------------

   debug_o( 15 downto   0) <= pc;     -- Two bytes
   debug_o( 23 downto  16) <= ar;     -- One byte
   debug_o( 31 downto  24) <= data_i; -- One byte
   debug_o( 39 downto  32) <= lo;     -- One byte
   debug_o( 47 downto  40) <= hi;     -- One byte
   debug_o( 63 downto  48) <= addr;   -- Two bytes
   debug_o( 71 downto  64) <= data;   -- One byte
   debug_o( 72)            <= wren;   -- One byte
   debug_o( 79 downto  73) <= (others => '0');
   debug_o( 87 downto  80) <= sr;     -- One byte
   debug_o( 95 downto  88) <= sp;
   debug_o(103 downto  96) <= yr;
   debug_o(111 downto 104) <= xr;


   addr_o <= addr;
   data_o <= data;
   wren_o <= wren and not wait_i;
   sri_o  <= sr(SR_I);

end architecture structural;

