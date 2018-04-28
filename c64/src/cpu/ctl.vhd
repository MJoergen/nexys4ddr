--------------------------------------
-- The Control Logic
--
-- This uses a ROM containing up to eight microcodes for each instruction.
--
-- The specification of the individual instructions is primarily taken
-- from this link: http://nesdev.com/6502.txt

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity ctl is
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      step_i : in  std_logic;
      wait_i : in  std_logic;
      irq_i  : in  std_logic;
      data_i : in  std_logic_vector( 7 downto 0);

      wr_reg_o        : out std_logic_vector(5 downto 0);
      wr_pc_o         : out std_logic_vector(5 downto 0);
      wr_sp_o         : out std_logic_vector(1 downto 0);
      wr_hold_addr_o  : out std_logic_vector(1 downto 0);
      wr_szcv_o       : out std_logic_vector(3 downto 0);
      wr_b_o          : out std_logic_vector(1 downto 0);
      wr_i_o          : out std_logic_vector(1 downto 0);
      wr_d_o          : out std_logic_vector(1 downto 0);
      wr_sr_o         : out std_logic_vector(1 downto 0);
      mem_addr_o      : out std_logic_vector(3 downto 0);
      mem_rden_o      : out std_logic;
      reg_nr_wr_o     : out std_logic_vector(1 downto 0);
      reg_nr_rd_o     : out std_logic_vector(1 downto 0);
      mem_wrdata_o    : out std_logic_vector(2 downto 0);
      wr_c_o          : out std_logic_vector(1 downto 0);
      wr_hold_addr2_o : out std_logic_vector(1 downto 0);

      invalid_o       : out std_logic_vector(7 downto 0);
      debug_o         : out std_logic_vector(10 downto 0)
   );
end ctl;

architecture Structural of ctl is

   signal cnt_s     : std_logic_vector(2 downto 0) := (others => '0');
   signal cnt_r     : std_logic_vector(2 downto 0) := (others => '0');
   signal inst_s    : std_logic_vector(7 downto 0) := (others => '0');
   signal inst_r    : std_logic_vector(7 downto 0) := (others => '0');
   signal last      : std_logic;
   signal invalid   : std_logic;
   signal invalid_r : std_logic_vector(7 downto 0) := (others => '0');

   signal ctl       : std_logic_vector(45 downto 0);
   signal irq_l     : std_logic := '0';
   signal rst_l     : std_logic := '0';

   subtype micro_op_type is std_logic_vector(45 downto 0);
   type micro_op_rom_type is array(0 to 8*256-1) of micro_op_type;

   constant C_WR_REG_OR     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010000";
   constant C_WR_REG_AND    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010001";
   constant C_WR_REG_EOR    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010010";
   constant C_WR_REG_ADC    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010011";
   constant C_WR_REG_A      : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010100";
   constant C_WR_REG_B      : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010101";
   constant C_WR_REG_CMP    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010110";
   constant C_WR_REG_SBC    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_010111";
   constant C_WR_REG_ASL    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_011000";
   constant C_WR_REG_ROL    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_011001";
   constant C_WR_REG_LSR    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_011010";
   constant C_WR_REG_ROR    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_011011";
   constant C_WR_REG_DEC    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_011110";
   constant C_WR_REG_INC    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_011111";
   constant C_WR_REG_SP     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_110100";

   constant C_ALU_OR        : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_ALU_AND       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000001";
   constant C_ALU_EOR       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000010";
   constant C_ALU_ADC       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000011";
   constant C_ALU_B         : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000101";
   constant C_ALU_CMP       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000110";
   constant C_ALU_SBC       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000111";
   constant C_ALU_ASL       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_001000";
   constant C_ALU_ROL       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_001001";
   constant C_ALU_LSR       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_001010";
   constant C_ALU_ROR       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_001011";
   constant C_ALU_DEC       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_001110";
   constant C_ALU_INC       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_001111";

   constant C_WR_PC_HOLD    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000011_000000";
   constant C_WR_PC_LOAD    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000101_000000";
   constant C_WR_PC_INC     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000001_000000";
   constant C_WR_PC_BPL     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000111_000000";
   constant C_WR_PC_BMI     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_001111_000000";
   constant C_WR_PC_BVC     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_010111_000000";
   constant C_WR_PC_BVS     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_011111_000000";
   constant C_WR_PC_BCC     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_100111_000000";
   constant C_WR_PC_BCS     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_101111_000000";
   constant C_WR_PC_BNE     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_110111_000000";
   constant C_WR_PC_BEQ     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_111111_000000";

   constant C_WR_SP_LOAD    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_01_000000_000000";
   constant C_WR_SP_DEC     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_10_000000_000000";
   constant C_WR_SP_INC     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_11_000000_000000";

   constant C_WR_HOLD_LO    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_01_00_000000_000000";
   constant C_WR_HOLD_HI    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_10_00_000000_000000";
   constant C_WR_HOLD_ADD   : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_11_00_000000_000000";

   constant C_WR_SR_V       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0001_00_00_000000_000000";
   constant C_WR_SR_C       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0010_00_00_000000_000000";
   constant C_WR_SR_Z       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0100_00_00_000000_000000";
   constant C_WR_SR_S       : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_1000_00_00_000000_000000";

   constant C_WR_SR_B_0     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_10_0000_00_00_000000_000000";
   constant C_WR_SR_B_1     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_11_0000_00_00_000000_000000";
   constant C_WR_SR_I_0     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_10_00_0000_00_00_000000_000000";
   constant C_WR_SR_I_1     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_11_00_0000_00_00_000000_000000";
   constant C_WR_SR_D_0     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_10_00_00_0000_00_00_000000_000000";
   constant C_WR_SR_D_1     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_11_00_00_0000_00_00_000000_000000";
   constant C_WR_SR_REG     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_10_00_00_00_0000_00_00_000000_000000";
   constant C_WR_SR_MEM     : micro_op_type := B"00_0_0_00_000_00_00_0_0000_11_00_00_00_0000_00_00_000000_000000";

   constant C_WR_ADDR_PC    : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_HOLD  : micro_op_type := B"00_0_0_00_000_00_00_0_0001_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_SP    : micro_op_type := B"00_0_0_00_000_00_00_0_0010_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_HOLD2 : micro_op_type := B"00_0_0_00_000_00_00_0_0011_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_FFFA  : micro_op_type := B"00_0_0_00_000_00_00_0_1010_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_FFFB  : micro_op_type := B"00_0_0_00_000_00_00_0_1011_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_FFFC  : micro_op_type := B"00_0_0_00_000_00_00_0_1100_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_FFFD  : micro_op_type := B"00_0_0_00_000_00_00_0_1101_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_FFFE  : micro_op_type := B"00_0_0_00_000_00_00_0_1110_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_ADDR_FFFF  : micro_op_type := B"00_0_0_00_000_00_00_0_1111_00_00_00_00_0000_00_00_000000_000000";

   constant C_MEM_RD        : micro_op_type := B"00_0_0_00_000_00_00_1_0000_00_00_00_00_0000_00_00_000000_000000";

   constant C_REG_WR_A      : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_REG_WR_X      : micro_op_type := B"00_0_0_00_000_00_01_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_REG_WR_Y      : micro_op_type := B"00_0_0_00_000_00_10_0_0000_00_00_00_00_0000_00_00_000000_000000";

   constant C_REG_RD_A      : micro_op_type := B"00_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_REG_RD_X      : micro_op_type := B"00_0_0_00_000_01_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_REG_RD_Y      : micro_op_type := B"00_0_0_00_000_10_00_0_0000_00_00_00_00_0000_00_00_000000_000000";

   constant C_MEM_WR_REG    : micro_op_type := B"00_0_0_00_100_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_MEM_WR_PC_HI  : micro_op_type := B"00_0_0_00_101_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_MEM_WR_PC_LO  : micro_op_type := B"00_0_0_00_110_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_MEM_WR_SR     : micro_op_type := B"00_0_0_00_111_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";

   constant C_WR_SR_C_0     : micro_op_type := B"00_0_0_10_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_SR_C_1     : micro_op_type := B"00_0_0_11_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";

   constant C_LAST          : micro_op_type := B"00_0_1_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_INVALID       : micro_op_type := B"00_1_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";

   constant C_WR_HOLD2_LOAD : micro_op_type := B"01_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_HOLD2_ADD  : micro_op_type := B"10_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";
   constant C_WR_HOLD2_INC  : micro_op_type := B"11_0_0_00_000_00_00_0_0000_00_00_00_00_0000_00_00_000000_000000";

   constant C_READ_NEXT_BYTE : micro_op_type := C_WR_PC_INC + C_MEM_RD;


   constant micro_op_rom : micro_op_rom_type := (
   -- 00 BRK b (also RESET, NMI, and IRQ).
            C_READ_NEXT_BYTE,
            C_WR_ADDR_SP   + C_MEM_WR_PC_HI + C_WR_SP_DEC,
            C_WR_ADDR_SP   + C_MEM_WR_PC_LO + C_WR_SP_DEC,
            C_WR_ADDR_SP   + C_MEM_WR_SR    + C_WR_SP_DEC + C_WR_SR_I_1,
            C_WR_ADDR_FFFC + C_MEM_RD       + C_WR_HOLD_LO,
            C_WR_ADDR_FFFD + C_MEM_RD       + C_WR_PC_LOAD + C_LAST,
            C_INVALID,
            C_INVALID,
   -- 01 ORA (d,X)
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 02
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 03
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 04
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 05 ORA d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 06 ASL d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 07
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 08 PHP
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 09 ORA #
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 0A ASL A
            C_READ_NEXT_BYTE,
            C_WR_REG_ASL + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 0B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 0C
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 0D ORA a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 0E ASL a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 0F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 10 BPL r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BPL + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 11 ORA (d),Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 12
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 13
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 14
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 15 ORA d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 16 ASL d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 17
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 18 CLC
            C_READ_NEXT_BYTE,
            C_WR_SR_C_0 + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 19 ORA a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 1A
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 1B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 1C
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 1D ORA a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 1E ASL a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 1F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 20 JSR a
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD       + C_WR_HOLD_LO + C_WR_PC_INC,
            C_WR_ADDR_PC + C_MEM_RD       + C_WR_HOLD_HI,
            C_WR_ADDR_SP + C_MEM_WR_PC_HI + C_WR_SP_DEC,
            C_WR_ADDR_SP + C_MEM_WR_PC_LO + C_WR_SP_DEC + C_WR_PC_HOLD + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 21 AND (d,X)
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 22
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 23
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 24 BIT d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 25 AND d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 26 ROL d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 27
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 28 PLP
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 29 AND #
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_INC + C_WR_REG_AND + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 2A ROL A
            C_READ_NEXT_BYTE,
            C_WR_REG_ROL + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 2B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 2C BIT a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 2D AND a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 2E ROL a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 2F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 30 BMI r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BMI + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 31 AND (d),Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 32
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 33
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 34
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 35 AND d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 36 ROL d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 37
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 38 SEC
            C_READ_NEXT_BYTE,
            C_WR_SR_C_1 + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 39 AND a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 3A
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 3B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 3C
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 3D AND a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 3E ROL a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 3F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 40 RTI
            C_READ_NEXT_BYTE,
            C_WR_SP_INC,
            C_WR_ADDR_SP + C_WR_SP_INC + C_MEM_RD + C_WR_SR_MEM,
            C_WR_ADDR_SP + C_WR_SP_INC + C_MEM_RD + C_WR_HOLD_LO,
            C_WR_ADDR_SP + C_MEM_RD + C_WR_PC_LOAD + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 41 EOR (d,X)
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 42
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 43
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 44
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 45 EOR d
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_EOR + C_WR_SR_Z + C_WR_SR_S + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 46 LSR d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 47
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 48 PHA
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 49 EOR #
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_INC + C_WR_REG_EOR + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 4A LSR A
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 4B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 4C JMP a
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_INC + C_WR_HOLD_LO,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_LOAD + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 4D EOR a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 4E LSR a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 4F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 50 BVC r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BVC + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 51 EOR (d),Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 52
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 53
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 54
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 55 EOR d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 56 LSR d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 57
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 58 CLI
            C_READ_NEXT_BYTE,
            C_WR_SR_I_0 + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 59 EOR a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 5A
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 5B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 5C
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 5D EOR a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 5E LSR a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 5F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 60 RTS
            C_READ_NEXT_BYTE,
            C_WR_SP_INC,
            C_WR_ADDR_SP + C_WR_SP_INC + C_MEM_RD + C_WR_HOLD_LO,
            C_WR_ADDR_SP + C_MEM_RD + C_WR_PC_LOAD,
            C_WR_PC_INC + C_LAST,      -- Can be optimized by combining the last two micro-ops.
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 61 ADC (d,X)
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 62
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 63
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 64
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 65 ADC d
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_ADC + C_WR_SR_V + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 66 ROR d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 67
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 68 PLA
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 69 ADC #
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_INC + C_WR_REG_ADC + C_WR_SR_V + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 6A ROR A
            C_READ_NEXT_BYTE,
            C_WR_REG_ROR + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 6B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 6C JMP (a)
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 6D ADC a
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_ADC + C_WR_SR_V + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 6E ROR a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 6F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 70 BVS r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BVS + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 71 ADC (d),Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 72
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 73
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 74
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 75 ADC d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 76 ROR d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 77
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 78 SEI
            C_READ_NEXT_BYTE,
            C_WR_SR_I_1 + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 79 ADC a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 7A
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 7B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 7C
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 7D ADC a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 7E ROR a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 7F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 80
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 81 STA (d,X)
            C_READ_NEXT_BYTE,
            C_WR_HOLD2_ADD + C_REG_RD_X + C_MEM_RD + C_WR_PC_INC,    -- compute d+X
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_LO + C_WR_HOLD2_INC, -- read from d+X
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_HI,                  -- read from d+X+1
            C_WR_ADDR_HOLD + C_MEM_WR_REG + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 82
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 83
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 84 STY d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 85 STA d
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_HOLD_LO + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_WR_REG + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 86 STX d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 87
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 88 DEY
            C_READ_NEXT_BYTE,
            C_REG_WR_Y + C_REG_RD_Y + C_WR_REG_DEC + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 89
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 8A TXA
            C_READ_NEXT_BYTE,
            C_REG_WR_A + C_REG_RD_X + C_WR_REG_A + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 8B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 8C STY a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 8D STA a
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_WR_REG + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 8E STX a
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_REG_RD_X + C_MEM_WR_REG + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 8F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- 90 BCC r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BCC + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 91 STA (d),Y
            C_READ_NEXT_BYTE,
            C_WR_HOLD2_LOAD + C_MEM_RD + C_WR_PC_INC,                   -- read value of d
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_LO + C_WR_HOLD2_INC, -- read from d
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_HI,                  -- read from d+1
            C_WR_HOLD_ADD + C_REG_RD_Y,                                 -- calculate (d)+Y         TBD: Could perhaps be absorbed into previous or next micro-instruction.
            C_WR_ADDR_HOLD + C_MEM_WR_REG + C_LAST,                     -- write to (d)+Y
            C_INVALID,
            C_INVALID,
   -- 92
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 93
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 94 STY d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 95 STA d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 96 STX d,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 97
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 98 TYA
            C_READ_NEXT_BYTE,
            C_REG_WR_A + C_REG_RD_Y + C_WR_REG_A + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 99 STA a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 9A TXS
            C_READ_NEXT_BYTE,
            C_REG_RD_X + C_WR_SP_LOAD + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 9B
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 9C
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 9D STA a,X
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_ADD + C_REG_RD_X,
            C_WR_ADDR_HOLD + C_MEM_WR_REG + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 9E
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- 9F
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- A0 LDY #
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A1 LDA (d,X)
            C_READ_NEXT_BYTE,
            C_WR_HOLD2_ADD + C_REG_RD_X + C_MEM_RD + C_WR_PC_INC,    -- compute d+X
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_LO + C_WR_HOLD2_INC, -- read from d+X
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_HI,                  -- read from d+X+1
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_B + C_WR_SR_S + C_WR_SR_Z + C_LAST,   -- read from (d+X)
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A2 LDX #
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_REG_B + C_REG_WR_X + C_WR_PC_INC + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A3
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A4 LDY d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A5 LDA d
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_B + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A6 LDX d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A7
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A8 TAY
            C_READ_NEXT_BYTE,
            C_REG_WR_Y + C_REG_RD_A + C_WR_REG_A + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- A9 LDA #
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_REG_B + C_WR_PC_INC + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- AA TAX
            C_READ_NEXT_BYTE,
            C_REG_WR_X + C_REG_RD_A + C_WR_REG_A + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- AB
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- AC LDY a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- AD LDA a
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_B + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- AE LDX a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- AF
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- B0 BCS r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BCS + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B1 LDA (d),Y
            C_READ_NEXT_BYTE,
            C_WR_HOLD2_LOAD + C_MEM_RD + C_WR_PC_INC,                   -- read value of d
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_LO + C_WR_HOLD2_INC, -- read from d
            C_WR_ADDR_HOLD2 + C_MEM_RD + C_WR_HOLD_HI,                  -- read from d+1
            C_WR_HOLD_ADD + C_REG_RD_Y,                                 -- calculate (d)+Y         TBD: Could perhaps be absorbed into previous or next micro-instruction.
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_B + C_WR_SR_S + C_WR_SR_Z + C_LAST,   -- read from (d)+Y
            C_INVALID,
            C_INVALID,
   -- B2
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B3
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B4 LDY d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B5 LDA d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B6 LDX d,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B7
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B8 CLV
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- B9 LDA a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- BA TSX
            C_READ_NEXT_BYTE,
            C_REG_WR_X + C_WR_REG_SP + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- BB
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- BC LDY a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- BD LDA a,X
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_ADD + C_REG_RD_X,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_B + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- BE LDX a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- BF
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- C0 CPY #
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C1 CMP (d,X)
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C2
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C3
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C4 CPY d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C5 CMP d
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_ALU_CMP + C_WR_SR_C + C_WR_SR_Z + C_WR_SR_S + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C6 DEC d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C7
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C8 INY
            C_READ_NEXT_BYTE,
            C_REG_WR_Y + C_REG_RD_Y + C_WR_REG_INC + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- C9 CMP #
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_INC + C_ALU_CMP + C_WR_SR_C + C_WR_SR_Z + C_WR_SR_S + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- CA DEX
            C_READ_NEXT_BYTE,
            C_REG_WR_X + C_REG_RD_X + C_WR_REG_DEC + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- CB
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- CC CPY a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- CD CMP a
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_ALU_CMP + C_WR_SR_C + C_WR_SR_Z + C_WR_SR_S + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- CE DEC a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- CF
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- D0 BNE r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BNE + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D1 CMP (d),Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D2
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D3
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D4
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D5 CMP d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D6 DEC d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D7
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D8 CLD
            C_READ_NEXT_BYTE,
            C_WR_SR_D_0 + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- D9 CMP a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- DA
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- DB
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- DC
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- DD CMP a,X
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_ADD + C_REG_RD_X,
            C_WR_ADDR_HOLD + C_MEM_RD + C_ALU_CMP + C_WR_SR_C + C_WR_SR_Z + C_WR_SR_S + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- DE DEC a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- DF
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- E0 CPX #
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E1 SBC (d,X)
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E2
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E3
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E4 CPX d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E5 SBC d
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_SBC + C_WR_SR_V + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E6 INC d
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E7
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E8 INX
            C_READ_NEXT_BYTE,
            C_REG_WR_X + C_REG_RD_X + C_WR_REG_INC + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- E9 SBC #
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_INC + C_WR_REG_SBC + C_WR_SR_V + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- EA NOP
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- EB
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- EC CPX a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- ED SBC a
            C_READ_NEXT_BYTE,
            C_WR_HOLD_LO + C_MEM_RD + C_WR_PC_INC,
            C_WR_HOLD_HI + C_MEM_RD + C_WR_PC_INC,
            C_WR_ADDR_HOLD + C_MEM_RD + C_WR_REG_SBC + C_WR_SR_V + C_WR_SR_C + C_WR_SR_S + C_WR_SR_Z + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- EE INC a
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- EF
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   --
   -- F0 BEQ r
            C_READ_NEXT_BYTE,
            C_WR_ADDR_PC + C_MEM_RD + C_WR_PC_BEQ + C_LAST,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F1 SBC (d),Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F2
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F3
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F4
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F5 SBC d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F6 INC d,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F7
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F8 SED
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- F9 SBC a,Y
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- FA
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- FB
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- FC
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- FD SBC a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- FE INC a,X
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
   -- FF
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID,
            C_INVALID
         );

begin

   invalid_o <= invalid_r;

   -- Check for illegal or unimplemented instructions.
   p_assert : process (clk_i)
   begin 
      if rising_edge(clk_i) then
         if rst_i = '0' then
            if invalid = '1' then
               invalid_r <= inst_r;
            end if;
            assert invalid = '0' report "Invalid opcode" severity failure;
         end if;

         if rst_i = '1' then
            invalid_r <= (others => '0');
         end if;
      end if;
   end process p_assert;

   -- Calculate new values of 'cnt' and 'inst'
   cnt_s <= "100"     when rst_i = '1' else
            "001"     when wait_i = '0' and step_i = '1' and last = '1' and irq_i = '1' else
            "000"     when wait_i = '0' and step_i = '1' and last = '1' else
            cnt_r + 1 when wait_i = '0' and step_i = '1' else
            cnt_r;

   inst_s <= X"00"  when rst_i = '1' else
             X"00"  when wait_i = '0' and last = '1' and irq_i = '1' else
             data_i when wait_i = '0' and cnt_r = 0 else
             inst_r;

   -- Store the new values of 'cnt' and 'inst'
   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt_r  <= cnt_s;
         inst_r <= inst_s;
      end if;
   end process p_fsm;

   -- Combinatorial process
   process (cnt_r, inst_r, wait_i, step_i)
   begin
      ctl <= micro_op_rom(conv_integer(inst_r & cnt_r));
      if wait_i = '1' or step_i = '0' then
         ctl(27 downto  0) <= (others => '0');
         ctl(45 downto 44) <= (others => '0');
         ctl(41 downto 40) <= (others => '0');
      end if;
   end process;


   -- Latch reset and interrupt
   p_irq_reset : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if last = '1' and step_i = '1' then
            irq_l <= irq_i;
            rst_l <= irq_i;
         end if;

         if rst_i = '1' then
            irq_l <= '0';
            rst_l <= rst_i;
         end if;
      end if;
   end process p_irq_reset;

   -- Drive output signals
   debug_o( 7 downto 0) <= data_i when cnt_r = 0 else inst_r;
   debug_o(10 downto 8) <= cnt_r;

   wr_reg_o        <= ctl( 5 downto  0);
   wr_pc_o         <= ctl(11 downto  6);
   wr_sp_o         <= ctl(13 downto 12);
   wr_hold_addr_o  <= ctl(15 downto 14);
   wr_szcv_o       <= ctl(19 downto 16);
   wr_b_o          <= ctl(21 downto 20);
   wr_i_o          <= ctl(23 downto 22);
   wr_d_o          <= ctl(25 downto 24);
   wr_sr_o         <= ctl(27 downto 26);
   mem_addr_o      <= ctl(31 downto 28) when ctl(31) = '0'
                      else '1' & rst_l & irq_l & ctl(28);
   mem_rden_o      <= ctl(32);
   reg_nr_wr_o     <= ctl(34 downto 33);
   reg_nr_rd_o     <= ctl(36 downto 35);
   mem_wrdata_o    <= ctl(39 downto 37);
   wr_c_o          <= ctl(41 downto 40);
   last            <= ctl(42);
   invalid         <= ctl(43);
   wr_hold_addr2_o <= ctl(45 downto 44);

end architecture Structural;

