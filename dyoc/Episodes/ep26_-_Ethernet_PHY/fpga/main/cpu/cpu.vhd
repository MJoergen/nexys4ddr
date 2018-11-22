library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity cpu is
   port (
      clk_i         : in  std_logic;

      -- Memory interface
      addr_o        : out std_logic_vector(15 downto 0);
      data_i        : in  std_logic_vector(7 downto 0);
      rden_o        : out std_logic;
      data_o        : out std_logic_vector(7 downto 0);
      wren_o        : out std_logic;
      -- The "wait_i" is '1' when the memory is not ready.
      -- While this is so, the CPU just stands still, waiting.
      wait_i        : in  std_logic;
      memio_cyc_o   : out std_logic_vector( 4*8-1 downto 0);
      memio_latch_i : in  std_logic_vector( 1*8-1 downto 0);

      -- Hardware interrupts
      irq_i         : in  std_logic;
      nmi_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- Debug output
      invalid_o     : out std_logic_vector(7 downto 0);   -- First invalid instruction encountered
      debug_o       : out std_logic_vector(175 downto 0)
   );
end entity cpu;

architecture structural of cpu is

   signal ar_sel    : std_logic;
   signal hi_sel    : std_logic_vector(2 downto 0);
   signal lo_sel    : std_logic_vector(2 downto 0);
   signal pc_sel    : std_logic_vector(5 downto 0);
   signal addr_sel  : std_logic_vector(3 downto 0);
   signal data_sel  : std_logic_vector(2 downto 0);
   signal alu_sel   : std_logic_vector(4 downto 0);
   signal sr_sel    : std_logic_vector(3 downto 0);
   signal sp_sel    : std_logic_vector(1 downto 0);
   signal xr_sel    : std_logic;
   signal yr_sel    : std_logic;
   signal reg_sel   : std_logic_vector(1 downto 0);
   signal zp_sel    : std_logic_vector(1 downto 0);
   signal sri       : std_logic;

begin

   -----------------
   -- Instantiate cycle counter
   -----------------

   inst_cycle : entity work.cycle
   port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      latch_i   => memio_latch_i(0),
      cyc_cnt_o => memio_cyc_o
   );


   -----------------
   -- Instantiate datapath
   -----------------

   inst_datapath : entity work.datapath
   port map (
      clk_i   => clk_i,
      wait_i  => wait_i,

      addr_o  => addr_o,
      data_i  => data_i,
      rden_o  => rden_o,
      data_o  => data_o,
      wren_o  => wren_o,
      sri_o   => sri,

      ar_sel_i   => ar_sel,
      hi_sel_i   => hi_sel,
      lo_sel_i   => lo_sel,
      pc_sel_i   => pc_sel,
      addr_sel_i => addr_sel,
      data_sel_i => data_sel,
      alu_sel_i  => alu_sel,
      sr_sel_i   => sr_sel,
      sp_sel_i   => sp_sel,
      xr_sel_i   => xr_sel,
      yr_sel_i   => yr_sel,
      reg_sel_i  => reg_sel,
      zp_sel_i   => zp_sel,

      debug_o => debug_o(175 downto 64)
   );


   -----------------
   -- Instantiate control logic
   -----------------

   inst_ctl : entity work.ctl
   port map (
      clk_i   => clk_i,
      wait_i  => wait_i,
      irq_i   => irq_i,
      nmi_i   => nmi_i,
      rst_i   => rst_i,
      sri_i   => sri,

      data_i  => data_i,

      ar_sel_o   => ar_sel,
      hi_sel_o   => hi_sel,
      lo_sel_o   => lo_sel,
      pc_sel_o   => pc_sel,
      addr_sel_o => addr_sel,
      data_sel_o => data_sel,
      alu_sel_o  => alu_sel,
      sr_sel_o   => sr_sel,
      sp_sel_o   => sp_sel,
      xr_sel_o   => xr_sel,
      yr_sel_o   => yr_sel,
      reg_sel_o  => reg_sel,
      zp_sel_o   => zp_sel,

      invalid_o => invalid_o,
      debug_o   => debug_o(63 downto 0)
   );

end architecture structural;

