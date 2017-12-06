library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cpu_module is
   port (
      -- Clock
      clk_i   : in  std_logic;                        -- 10 MHz
      clken_i : in  std_logic;                        -- Clock enable
      rstn_i  : in  std_logic;                        -- Active low
      ia_o    : out std_logic_vector(  31 downto 0);  -- Instruction Address
      id_i    : in  std_logic_vector(  31 downto 0);  -- Instruction Data
      ma_o    : out std_logic_vector(  31 downto 0);  -- Memory Address
      moe_o   : out std_logic;                        -- Memory Output Enable
      mrd_i   : in  std_logic_vector(  31 downto 0);  -- Memory Read Data
      wr_o    : out std_logic;                        -- Write
      mwd_o   : out std_logic_vector(  31 downto 0);  -- Memory Write Data

      val_o   : out std_logic_vector(1023 downto 0)   -- Debug output (to VGA)
   );
end cpu_module;

architecture Structural of cpu_module is

   -- Signals driven by the Program Counter
   signal pc_ia : std_logic_vector(31 downto 0) := (others => '0');

   -- Signals driven by the ALU
   signal alu_out : std_logic_vector(31 downto 0);

   -- Signals driven by the Register File
   signal regfile_radata : std_logic_vector(31 downto 0);
   signal regfile_rbdata : std_logic_vector(31 downto 0);

   -- Signals driven by the Control Logic
   signal ctl_pcsel  : std_logic_vector(2 downto 0);
   signal ctl_wasel  : std_logic;
   signal ctl_asel   : std_logic;
   signal ctl_ra2sel : std_logic;
   signal ctl_bsel   : std_logic;
   signal ctl_alufn  : std_logic_vector(5 downto 0);
   signal ctl_wdsel  : std_logic_vector(1 downto 0);
   signal ctl_werf   : std_logic;
   signal ctl_moe    : std_logic;
   signal ctl_wr     : std_logic;

   -- Instruction decoding.
   alias id_opcode  : std_logic_vector( 5 downto 0) is id_i(31 downto 26);
   alias id_rc      : std_logic_vector( 4 downto 0) is id_i(25 downto 21);
   alias id_ra      : std_logic_vector( 4 downto 0) is id_i(20 downto 16);
   alias id_rb      : std_logic_vector( 4 downto 0) is id_i(15 downto 11);
   alias id_literal : std_logic_vector(15 downto 0) is id_i(15 downto  0);

   signal mux_b   : std_logic_vector(31 downto 0);
   signal mux_c   : std_logic_vector(31 downto 0);
   signal mux_ra2 : std_logic_vector( 4 downto 0);

   function sign_extend(arg : std_logic_vector(15 downto 0))
      return std_logic_vector is
      variable res : std_logic_vector(31 downto 0);
   begin
      res := (others => arg(15)); -- Copy sign bit to all bits.
      res(15 downto 0) := arg;
      return res;
   end function sign_extend;

begin

   -- Program counter
   i_pc : entity work.pc
   port map (
      cpu_clk_i   => clk_i,
      cpu_clken_i => clken_i,
      rstn_i      => rstn_i,
      ia_o        => pc_ia
   );

   -- Instruction Address
   ia_o <= pc_ia;

   -- Register File
   i_regfile : entity work.regfile
   port map (
      cpu_clk_i   => clk_i,
      cpu_clken_i => clken_i,
      werf_i      => ctl_werf,
      ra2sel_i    => ctl_ra2sel,
      ra_i        => id_ra,
      rb_i        => id_rb,
      rc_i        => id_rc,
      wdata_i     => mux_c,
      radata_o    => regfile_radata,
      rbdata_o    => regfile_rbdata,
      regs_o      => val_o            -- Debug output
   );

   -- Arithmetic & Logic Unit
   i_alu : entity work.alu_module
   port map (
      alufn_i => ctl_alufn,
      a_i     => regfile_radata,
      b_i     => mux_b,
      alu_o   => alu_out,
      z_o     => open,   -- Not used
      v_o     => open,   -- Not used
      n_o     => open    -- Not used
   );

   mux_b <= regfile_rbdata when ctl_bsel = '0' 
            else sign_extend(id_literal);

   ma_o  <= alu_out; -- Data Address
   wr_o  <= ctl_wr;
   moe_o <= ctl_moe;
   mwd_o <= regfile_rbdata;

   mux_c <= alu_out when ctl_wdsel = "01"
            else mrd_i when ctl_wdsel = "10"
            else (others => '0');

   mux_ra2 <= id_rb when ctl_ra2sel = '0'
              else id_rc;

   -- Control Logic
   i_ctl : entity work.ctl
   port map (
      rstn_i   => rstn_i,
      id_i     => id_opcode,
      pcsel_o  => ctl_pcsel,
      wasel_o  => ctl_wasel,
      asel_o   => ctl_asel,
      ra2sel_o => ctl_ra2sel,
      bsel_o   => ctl_bsel,
      alufn_o  => ctl_alufn,
      wdsel_o  => ctl_wdsel,
      werf_o   => ctl_werf,
      moe_o    => ctl_moe,
      wr_o     => ctl_wr
   );
 
end Structural;

