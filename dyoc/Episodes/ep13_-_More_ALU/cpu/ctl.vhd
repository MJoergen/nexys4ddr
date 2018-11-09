library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ctl is
   port (
      clk_i      : in  std_logic;
      wait_i     : in  std_logic;

      data_i     : in  std_logic_vector(7 downto 0);

      ar_sel_o   : out std_logic;
      hi_sel_o   : out std_logic;
      lo_sel_o   : out std_logic;
      pc_sel_o   : out std_logic_vector(5 downto 0);
      addr_sel_o : out std_logic_vector(2 downto 0);
      data_sel_o : out std_logic_vector(2 downto 0);
      alu_sel_o  : out std_logic_vector(4 downto 0);
      sr_sel_o   : out std_logic_vector(3 downto 0);
      sp_sel_o   : out std_logic_vector(1 downto 0);

      invalid_o  : out std_logic_vector(7 downto 0);
      debug_o    : out std_logic_vector(47 downto 0)
   );
end entity ctl;

architecture structural of ctl is

   subtype t_ctl is std_logic_vector(27 downto 0);
   type t_rom is array(0 to 8*256-1) of t_ctl;

   constant NOP       : t_ctl := B"00_0000_00000_0_0_000_000_000000_0_0_0";
   --
   constant AR_ALU    : t_ctl := B"00_0000_00000_0_0_000_000_000000_0_0_1";
   --
   constant HI_DATA   : t_ctl := B"00_0000_00000_0_0_000_000_000000_0_1_0";
   --
   constant LO_DATA   : t_ctl := B"00_0000_00000_0_0_000_000_000000_1_0_0";
   --
   constant PC_INC    : t_ctl := B"00_0000_00000_0_0_000_000_000001_0_0_0";
   constant PC_HL     : t_ctl := B"00_0000_00000_0_0_000_000_000010_0_0_0";
   constant PC_HL1    : t_ctl := B"00_0000_00000_0_0_000_000_000011_0_0_0";
   constant PC_BPL    : t_ctl := B"00_0000_00000_0_0_000_000_000100_0_0_0";
   constant PC_BMI    : t_ctl := B"00_0000_00000_0_0_000_000_001100_0_0_0";
   constant PC_BVC    : t_ctl := B"00_0000_00000_0_0_000_000_010100_0_0_0";
   constant PC_BVS    : t_ctl := B"00_0000_00000_0_0_000_000_011100_0_0_0";
   constant PC_BCC    : t_ctl := B"00_0000_00000_0_0_000_000_100100_0_0_0";
   constant PC_BCS    : t_ctl := B"00_0000_00000_0_0_000_000_101100_0_0_0";
   constant PC_BNE    : t_ctl := B"00_0000_00000_0_0_000_000_110100_0_0_0";
   constant PC_BEQ    : t_ctl := B"00_0000_00000_0_0_000_000_111100_0_0_0";
   --
   constant ADDR_PC   : t_ctl := B"00_0000_00000_0_0_000_001_000000_0_0_0";
   constant ADDR_HL   : t_ctl := B"00_0000_00000_0_0_000_010_000000_0_0_0";
   constant ADDR_ZP   : t_ctl := B"00_0000_00000_0_0_000_011_000000_0_0_0";
   constant ADDR_SP   : t_ctl := B"00_0000_00000_0_0_000_100_000000_0_0_0";
   --
   constant DATA_AR   : t_ctl := B"00_0000_00000_0_0_001_000_000000_0_0_0";
   constant DATA_SR   : t_ctl := B"00_0000_00000_0_0_010_000_000000_0_0_0";
   constant DATA_ALU  : t_ctl := B"00_0000_00000_0_0_011_000_000000_0_0_0";
   constant DATA_PCLO : t_ctl := B"00_0000_00000_0_0_100_000_000000_0_0_0";
   constant DATA_PCHI : t_ctl := B"00_0000_00000_0_0_101_000_000000_0_0_0";
   --
   constant LAST      : t_ctl := B"00_0000_00000_0_1_000_000_000000_0_0_0";
   --
   constant INVALID   : t_ctl := B"00_0000_00000_1_0_000_000_000000_0_0_0";
   --
   constant ALU_ORA   : t_ctl := B"00_0000_00000_0_0_000_000_000000_0_0_0";
   constant ALU_AND   : t_ctl := B"00_0000_00001_0_0_000_000_000000_0_0_0";
   constant ALU_EOR   : t_ctl := B"00_0000_00010_0_0_000_000_000000_0_0_0";
   constant ALU_ADC   : t_ctl := B"00_0000_00011_0_0_000_000_000000_0_0_0";
   constant ALU_STA   : t_ctl := B"00_0000_00100_0_0_000_000_000000_0_0_0";
   constant ALU_LDA   : t_ctl := B"00_0000_00101_0_0_000_000_000000_0_0_0";
   constant ALU_CMP   : t_ctl := B"00_0000_00110_0_0_000_000_000000_0_0_0";
   constant ALU_SBC   : t_ctl := B"00_0000_00111_0_0_000_000_000000_0_0_0";
   constant ALU_ASL_A : t_ctl := B"00_0000_01000_0_0_000_000_000000_0_0_0";
   constant ALU_ROL_A : t_ctl := B"00_0000_01001_0_0_000_000_000000_0_0_0";
   constant ALU_LSR_A : t_ctl := B"00_0000_01010_0_0_000_000_000000_0_0_0";
   constant ALU_ROR_A : t_ctl := B"00_0000_01011_0_0_000_000_000000_0_0_0";
   constant ALU_BIT_A : t_ctl := B"00_0000_01100_0_0_000_000_000000_0_0_0";
   constant ALU_DEC_A : t_ctl := B"00_0000_01110_0_0_000_000_000000_0_0_0";
   constant ALU_INC_A : t_ctl := B"00_0000_01111_0_0_000_000_000000_0_0_0";
   constant ALU_ASL_B : t_ctl := B"00_0000_10000_0_0_000_000_000000_0_0_0";
   constant ALU_ROL_B : t_ctl := B"00_0000_10001_0_0_000_000_000000_0_0_0";
   constant ALU_LSR_B : t_ctl := B"00_0000_10010_0_0_000_000_000000_0_0_0";
   constant ALU_ROR_B : t_ctl := B"00_0000_10011_0_0_000_000_000000_0_0_0";
   constant ALU_BIT_B : t_ctl := B"00_0000_10100_0_0_000_000_000000_0_0_0";
   constant ALU_DEC_B : t_ctl := B"00_0000_10110_0_0_000_000_000000_0_0_0";
   constant ALU_INC_B : t_ctl := B"00_0000_10111_0_0_000_000_000000_0_0_0";
   --
   constant SR_ALU    : t_ctl := B"00_0001_00000_0_0_000_000_000000_0_0_0";
   constant SR_DATA   : t_ctl := B"00_0010_00000_0_0_000_000_000000_0_0_0";
   constant SR_CLC    : t_ctl := B"00_1000_00000_0_0_000_000_000000_0_0_0";
   constant SR_SEC    : t_ctl := B"00_1001_00000_0_0_000_000_000000_0_0_0";
   constant SR_CLI    : t_ctl := B"00_1010_00000_0_0_000_000_000000_0_0_0";
   constant SR_SEI    : t_ctl := B"00_1011_00000_0_0_000_000_000000_0_0_0";
   constant SR_CLV    : t_ctl := B"00_1100_00000_0_0_000_000_000000_0_0_0";
   constant SR_CLD    : t_ctl := B"00_1110_00000_0_0_000_000_000000_0_0_0";
   constant SR_SED    : t_ctl := B"00_1111_00000_0_0_000_000_000000_0_0_0";
   --
   constant SP_INC    : t_ctl := B"01_0000_00000_0_0_000_000_000000_0_0_0";
   constant SP_DEC    : t_ctl := B"10_0000_00000_0_0_000_000_000000_0_0_0";

   -- Decode control signals
   signal ctl      : t_ctl;
   alias ar_sel    : std_logic                    is ctl(0);
   alias hi_sel    : std_logic                    is ctl(1);
   alias lo_sel    : std_logic                    is ctl(2);
   alias pc_sel    : std_logic_vector(5 downto 0) is ctl(8 downto 3);
   alias addr_sel  : std_logic_vector(2 downto 0) is ctl(11 downto 9);
   alias data_sel  : std_logic_vector(2 downto 0) is ctl(14 downto 12);
   alias last_s    : std_logic                    is ctl(15);
   alias invalid_s : std_logic                    is ctl(16);
   alias alu_sel   : std_logic_vector(4 downto 0) is ctl(21 downto 17);
   alias sr_sel    : std_logic_vector(3 downto 0) is ctl(25 downto 22);
   alias sp_sel    : std_logic_vector(1 downto 0) is ctl(27 downto 26);

   signal rom : t_rom := (

-- 00 BRK b (also RESET, NMI, and IRQ).
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 01 ORA (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 02
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 03
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 04
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 05 ORA d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_ORA + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 06 ASL d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_ASL_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 07
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 08 PHP
      ADDR_PC + PC_INC,
      ADDR_SP + DATA_SR + SP_DEC + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 09 ORA #
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + ALU_ORA + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 0A ASL A
      ADDR_PC + PC_INC,
      ALU_ASL_A + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 0B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 0C
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 0D ORA a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_ORA + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 0E ASL a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_ASL_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 0F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 10 BPL r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BPL + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 11 ORA (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 12
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 13
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 14
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 15 ORA d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 16 ASL d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 17
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 18 CLC
      ADDR_PC + PC_INC,
      SR_CLC + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 19 ORA a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 1A
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 1B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 1C
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 1D ORA a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 1E ASL a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 1F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 20 JSR a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + HI_DATA,
      ADDR_SP + DATA_PCHI + SP_DEC,
      ADDR_SP + DATA_PCLO + SP_DEC,
      PC_HL + LAST,
      INVALID,
      INVALID,

-- 21 AND (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 22
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 23
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 24 BIT d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_BIT_B + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 25 AND d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_AND + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 26 ROL d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_ROL_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 27
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 28 PLP
      ADDR_PC + PC_INC,
      SP_INC,
      ADDR_SP + SR_DATA + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 29 AND #
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + ALU_AND + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 2A ROL A
      ADDR_PC + PC_INC,
      ALU_ROL_A + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 2B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 2C BIT a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_BIT_B + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 2D AND a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_AND + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 2E ROL a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_ROL_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 2F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 30 BMI r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BMI + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 31 AND (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 32
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 33
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 34
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 35 AND d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 36 ROL d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 37
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 38 SEC
      ADDR_PC + PC_INC,
      SR_SEC + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 39 AND a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 3A
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 3B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 3C
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 3D AND a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 3E ROL a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 3F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 40 RTI
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 41 EOR (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 42
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 43
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 44
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 45 EOR d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_EOR + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 46 LSR d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_LSR_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 47
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 48 PHA
      ADDR_PC + PC_INC,
      ADDR_SP + DATA_AR + SP_DEC + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 49 EOR #
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + ALU_EOR + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 4A LSR A
      ADDR_PC + PC_INC,
      ALU_LSR_A + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 4B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 4C JMP a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      PC_HL + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 4D EOR a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_EOR + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 4E LSR a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_LSR_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 4F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 50 BVC r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BVC + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 51 EOR (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 52
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 53
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 54
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 55 EOR d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 56 LSR d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 57
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 58 CLI
      ADDR_PC + PC_INC,
      SR_CLI + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 59 EOR a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 5A
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 5B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 5C
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 5D EOR a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 5E LSR a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 5F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 60 RTS
      ADDR_PC + PC_INC,
      SP_INC,
      ADDR_SP + SP_INC + LO_DATA,
      ADDR_SP + HI_DATA,
      PC_HL1 + LAST,
      INVALID,
      INVALID,
      INVALID,

-- 61 ADC (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 62
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 63
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 64
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 65 ADC d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_ADC + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 66 ROR d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_ROR_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 67
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 68 PLA
      ADDR_PC + PC_INC,
      SP_INC,
      ADDR_SP + ALU_LDA + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 69 ADC #
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + ALU_ADC + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 6A ROR A
      ADDR_PC + PC_INC,
      ALU_ROR_A + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 6B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 6C JMP (a)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 6D ADC a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_ADC + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 6E ROR a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_ROR_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 6F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 70 BVS r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BVS + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 71 ADC (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 72
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 73
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 74
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 75 ADC d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 76 ROR d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 77
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 78 SEI
      ADDR_PC + PC_INC,
      SR_SEI + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 79 ADC a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 7A
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 7B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 7C
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 7D ADC a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 7E ROR a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 7F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 80
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 81 STA (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 82
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 83
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 84 STY d
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 85 STA d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + DATA_AR + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 86 STX d
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 87
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 88 DEY
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 89
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 8A TXA
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 8B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 8C STY a
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 8D STA a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + DATA_AR + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 8E STX a
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 8F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 90 BCC r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BCC + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 91 STA (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 92
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 93
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 94 STY d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 95 STA d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 96 STX d,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 97
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 98 TYA
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 99 STA a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 9A TXS
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 9B
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 9C
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 9D STA a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 9E
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- 9F
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A0 LDY #
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A1 LDA (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A2 LDX #
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A3
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A4 LDY d
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A5 LDA d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_LDA + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A6 LDX d
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A7
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A8 TAY
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- A9 LDA #
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + ALU_LDA + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- AA TAX
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- AB
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- AC LDY a
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- AD LDA a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_LDA + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- AE LDX a
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- AF
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B0 BCS r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BCS + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B1 LDA (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B2
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B3
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B4 LDY d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B5 LDA d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B6 LDX d,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B7
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B8 CLV
      ADDR_PC + PC_INC,
      SR_CLV + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- B9 LDA a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- BA TSX
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- BB
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- BC LDY a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- BD LDA a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- BE LDX a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- BF
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C0 CPY #
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C1 CMP (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C2
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C3
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C4 CPY d
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C5 CMP d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_CMP + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C6 DEC d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_DEC_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C7
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C8 INY
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- C9 CMP #
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + ALU_CMP + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- CA DEX
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- CB
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- CC CPY a
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- CD CMP a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_CMP + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- CE DEC a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_DEC_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- CF
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D0 BNE r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BNE + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D1 CMP (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D2
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D3
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D4
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D5 CMP d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D6 DEC d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D7
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D8 CLD
      ADDR_PC + PC_INC,
      SR_CLD + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- D9 CMP a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- DA
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- DB
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- DC
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- DD CMP a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- DE DEC a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- DF
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E0 CPX #
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E1 SBC (d,X)
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E2
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E3
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E4 CPX d
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E5 SBC d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_SBC + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E6 INC d
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_ZP + ALU_INC_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E7
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E8 INX
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- E9 SBC #
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + ALU_SBC + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- EA NOP
      ADDR_PC + PC_INC,
      LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- EB
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- EC CPX a
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- ED SBC a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_SBC + AR_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- EE INC a
      ADDR_PC + PC_INC,
      ADDR_PC + PC_INC + LO_DATA,
      ADDR_PC + PC_INC + HI_DATA,
      ADDR_HL + ALU_INC_B + DATA_ALU + SR_ALU + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- EF
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F0 BEQ r
      ADDR_PC + PC_INC,
      ADDR_PC + PC_BEQ + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F1 SBC (d),Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F2
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F3
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F4
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F5 SBC d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F6 INC d,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F7
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F8 SED
      ADDR_PC + PC_INC,
      SR_SED + LAST,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- F9 SBC a,Y
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- FA
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- FB
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- FC
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- FD SBC a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- FE INC a,X
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,

-- FF
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID,
      INVALID);

   signal ir  : std_logic_vector(7 downto 0) := (others => '0');
   signal cnt : std_logic_vector(2 downto 0) := (others => '0');

   signal invalid_inst : std_logic_vector(7 downto 0) := (others => '0');

begin

   cnt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            cnt <= cnt + 1;
            if last_s = '1' then
               cnt <= (others => '0');
            end if;
         end if;
      end if;
   end process cnt_proc;

   ir_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if cnt = 0 then
               ir <= data_i;     -- Only load instruction register at beginning of instruction.
            end if;
         end if;
      end if;
   end process ir_proc;

   invalid_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if invalid_s = '1' then
               if invalid_inst = X"00" then
                  invalid_inst <= ir;
               end if;
            end if;
         end if;
      end if;
   end process invalid_proc;

   -- Combinatorial lookup in ROM
   ctl <= ADDR_PC + PC_INC when cnt = 0 else
          rom(conv_integer(ir)*8 + conv_integer(cnt));

   -- Drive output signals
   ar_sel_o   <= ar_sel;
   hi_sel_o   <= hi_sel;
   lo_sel_o   <= lo_sel;
   pc_sel_o   <= pc_sel;
   addr_sel_o <= addr_sel;
   data_sel_o <= data_sel;
   alu_sel_o  <= alu_sel;
   sr_sel_o   <= sr_sel;
   sp_sel_o   <= sp_sel;

   -- Debug Output
   invalid_o  <= invalid_inst;
   debug_o(27 downto  0) <= ctl;    -- Four bytes
   debug_o(31 downto 28) <= (others => '0');
   debug_o(34 downto 32) <= cnt;    -- One byte
   debug_o(39 downto 35) <= (others => '0');
   debug_o(47 downto 40) <= ir;     -- One byte

end architecture structural;

