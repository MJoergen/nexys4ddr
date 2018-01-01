library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ctl is
   port (
      rstn_i   : in  std_logic;
      id_i     : in  std_logic_vector(5 downto 0);
      z_i      : in  std_logic;
      sm_i     : in  std_logic;  -- Supervisor mode
      irq_i    : in  std_logic;
      pcsel_o  : out std_logic_vector(2 downto 0);
      wasel_o  : out std_logic;
      asel_o   : out std_logic;
      ra2sel_o : out std_logic;
      bsel_o   : out std_logic;
      alufn_o  : out std_logic_vector(5 downto 0);
      wdsel_o  : out std_logic_vector(1 downto 0);
      werf_o   : out std_logic;
      moe_o    : out std_logic;
      wr_o     : out std_logic
   );
end ctl;

architecture Structural of ctl is

   -- wasel is only ever set in case of an IRQ.
   type MEM_TYPE is array (0 to 63) of std_logic_vector(17 downto 0);
   signal ctl_mem : MEM_TYPE := (
--        P W A R B      A  W W M W
--        C A S A S      L  D E O R
--        S S E 2 E      U  S R E
--        E E L S L      F  E F
--        L L   E           L
--              L

      -- 000xxx
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved

      -- 001xxx
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved

      -- 010xxx
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved

      -- 011xxx
      B"000_0_0_0_1_000000_10_1_1_0",  -- LD
      B"000_0_0_1_1_000000_00_0_0_1",  -- ST
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"010_0_0_0_0_000000_00_1_0_0",  -- JMP
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"001_0_0_0_0_000000_00_1_0_0",  -- BEQ
      B"001_0_0_0_0_000000_00_1_0_0",  -- BNE
      B"000_0_1_0_0_011010_10_1_1_0",  -- LDR

--        P W A R B      A  W W M W
--        C A S A S      L  D E O R
--        S S E 2 E      U  S R E
--        E E L S L      F  E F
--        L L   E           L
--              L

      -- 100xxx
      B"000_0_0_0_0_000000_01_1_0_0",  -- ADD
      B"000_0_0_0_0_000001_01_1_0_0",  -- SUB
      B"000_0_0_0_0_000010_01_1_0_0",  -- MUL
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"000_0_0_0_0_110011_01_1_0_0",  -- CMPEQ
      B"000_0_0_0_0_110101_01_1_0_0",  -- CMPLT
      B"000_0_0_0_0_110111_01_1_0_0",  -- CMPLE
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved

      -- 101xxx
      B"000_0_0_0_0_011000_01_1_0_0",  -- AND
      B"000_0_0_0_0_011110_01_1_0_0",  -- OR
      B"000_0_0_0_0_010110_01_1_0_0",  -- XOR
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"000_0_0_0_0_100000_01_1_0_0",  -- SHL
      B"000_0_0_0_0_100001_01_1_0_0",  -- SHR
      B"000_0_0_0_0_100011_01_1_0_0",  -- SRA
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved

      -- 110xxx
      B"000_0_0_0_1_000000_01_1_0_0",  -- ADDC
      B"000_0_0_0_1_000001_01_1_0_0",  -- SUBC
      B"000_0_0_0_1_000010_01_1_0_0",  -- MULC
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"000_0_0_0_1_110011_01_1_0_0",  -- CMPEQC
      B"000_0_0_0_1_110101_01_1_0_0",  -- CMPLTC
      B"000_0_0_0_1_110111_01_1_0_0",  -- CMPLEC
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved

      -- 111xxx
      B"000_0_0_0_1_011000_01_1_0_0",  -- ANDC
      B"000_0_0_0_1_011110_01_1_0_0",  -- ORC
      B"000_0_0_0_1_010110_01_1_0_0",  -- XORC
      B"011_1_0_0_0_000000_00_1_0_0",  -- Reserved
      B"000_0_0_0_1_100000_01_1_0_0",  -- SHLC
      B"000_0_0_0_1_100001_01_1_0_0",  -- SHRC
      B"000_0_0_0_1_100011_01_1_0_0",  -- SRAC
      B"011_1_0_0_0_000000_00_1_0_0"); -- Reserved

   signal res : std_logic_vector(17 downto 0);

begin

   p_res : process (id_i, rstn_i)
   begin
      res <= ctl_mem(conv_integer(id_i));
      if rstn_i = '0' then
         res <= (others => '0'); -- Prevent any spurious memory writes during reset.
      end if;
   end process p_res;

   process (res, id_i, z_i, irq_i, sm_i)
   begin
      pcsel_o  <= res(17 downto 15);
      wasel_o  <= res(14);
      asel_o   <= res(13);
      ra2sel_o <= res(12);
      bsel_o   <= res(11);
      alufn_o  <= res(10 downto 5);
      wdsel_o  <= res(4 downto 3);
      werf_o   <= res(2);
      moe_o    <= res(1);
      wr_o     <= res(0);

      if id_i = "011101" and z_i = '0' then -- BEQ branch not taken,
         pcsel_o <= "000";
      end if;

      if id_i = "011110" and z_i = '1' then -- BNE branch not taken,
         pcsel_o <= "000";
      end if;

      if irq_i = '1' and sm_i = '0' then
         -- Set the new Instruction Address to G_XADDR
         pcsel_o <= "100";

         -- Write IA+4 to the XP register
         wasel_o <= '1';
         werf_o  <= '1';
         wdsel_o <= "00";

         -- Prevent any corruption of external memory.
         wr_o    <= '0';
      end if;
   end process;

end Structural;

