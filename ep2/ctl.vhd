library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ctl is
   port (
      -- Clock
      clk_i      : in  std_logic;
      data_i     : in  std_logic_vector(7 downto 0);
      pc_sel_o   : out std_logic_vector(1 downto 0);
      a_sel_o    : out std_logic_vector(1 downto 0);
      sr_sel_o   : out std_logic_vector(1 downto 0);
      lo_sel_o   : out std_logic;
      hi_sel_o   : out std_logic;
      addr_sel_o : out std_logic_vector(1 downto 0);
      data_sel_o : out std_logic_vector(1 downto 0)
   );
end ctl;

architecture Structural of ctl is

   constant PC_NOP   : std_logic_vector(1 downto 0) := "00";
   constant PC_INC   : std_logic_vector(1 downto 0) := "01";

   constant A_NOP    : std_logic_vector(1 downto 0) := "00";
   constant A_DATA   : std_logic_vector(1 downto 0) := "01";

   constant SR_NOP   : std_logic_vector(1 downto 0) := "00";

   constant LO_NOP   : std_logic := '0';
   constant LO_DATA  : std_logic := '1';

   constant HI_NOP   : std_logic := '0';
   constant HI_DATA  : std_logic := '1';

   constant ADDR_NOP : std_logic_vector(1 downto 0) := "00";
   constant ADDR_PC  : std_logic_vector(1 downto 0) := "01";
   constant ADDR_HL  : std_logic_vector(1 downto 0) := "10";

   constant DATA_NOP : std_logic_vector(1 downto 0) := "00";
   constant DATA_A   : std_logic_vector(1 downto 0) := "01";

   signal inst_r : std_logic_vector(7 downto 0);
   signal cnt_r  : std_logic_vector(2 downto 0);

   type t_ctl is record
      pc_sel   : std_logic_vector(1 downto 0);
      a_sel    : std_logic_vector(1 downto 0);
      sr_sel   : std_logic_vector(1 downto 0);
      lo_sel   : std_logic;
      hi_sel   : std_logic;
      addr_sel : std_logic_vector(1 downto 0);
      data_sel : std_logic_vector(1 downto 0);
   end record t_ctl;

   constant NOP : t_ctl := 
      (PC_NOP, A_NOP, SR_NOP, LO_NOP, HI_NOP, ADDR_NOP, DATA_NOP);

   signal ctl : t_ctl;

   type t_inst is array(0 to 7) of t_ctl;

   type t_rom is array(0 to 255) of t_inst;

   signal rom : t_rom := (
      others => (others => NOP));

begin

   -- A9 LDA #
   rom(0)(0).pc_sel   <= PC_INC;
   rom(0)(0).addr_sel <= ADDR_PC;
   --
   rom(0)(1).pc_sel   <= PC_INC;
   rom(0)(1).addr_sel <= ADDR_PC;
   rom(0)(1).a_sel    <= A_DATA;

   -- AD LDA a
   rom(1)(0).pc_sel   <= PC_INC;
   rom(1)(0).addr_sel <= ADDR_PC;
   --
   rom(1)(1).pc_sel   <= PC_INC;
   rom(1)(1).addr_sel <= ADDR_PC;
   rom(1)(1).lo_sel   <= LO_DATA;
   --
   rom(1)(2).pc_sel   <= PC_INC;
   rom(1)(2).addr_sel <= ADDR_PC;
   rom(1)(2).hi_sel   <= HI_DATA;
   --
   rom(1)(3).addr_sel <= ADDR_HL;
   rom(1)(3).a_sel    <= A_DATA;

   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt_r <= cnt_r + 1;
      end if;
   end process p_cnt;

   p_inst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cnt_r = 0 then
            inst_r <= data_i;
         end if;
      end if;
   end process p_inst;

   ctl <= rom(conv_integer(inst_r))(conv_integer(cnt_r));

   -- Drive output signals
   pc_sel_o   <= ctl.pc_sel;
   a_sel_o    <= ctl.a_sel;
   sr_sel_o   <= ctl.sr_sel;
   lo_sel_o   <= ctl.lo_sel;
   hi_sel_o   <= ctl.hi_sel;
   addr_sel_o <= ctl.addr_sel;
   data_sel_o <= ctl.data_sel;

end Structural;

