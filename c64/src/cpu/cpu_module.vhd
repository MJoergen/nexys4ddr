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
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      step_i : in  std_logic;

      -- Memory and I/O interface
      addr_o : out std_logic_vector(15 downto 0);
      --
      rden_o : out std_logic;
      data_i : in  std_logic_vector(7 downto 0);
      wait_i : in  std_logic;
      --
      wren_o : out std_logic;
      data_o : out std_logic_vector(7 downto 0);

      -- Interrupt
      irq_i  : in  std_logic;

      invalid_o : out std_logic_vector(7 downto 0);

      -- Debug (to show on the VGA)
      status_o : out std_logic_vector(127 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

   -- Signals connected to ALU
   signal alu_a_in : std_logic_vector(7 downto 0);
   signal alu_out  : std_logic_vector(7 downto 0);
   signal alu_c    : std_logic;
   signal alu_s    : std_logic;
   signal alu_v    : std_logic;
   signal alu_z    : std_logic;

   -- Program Registers
   signal reg_sp : std_logic_vector( 7 downto 0) := (others => '0');
   signal reg_pc : std_logic_vector(15 downto 0) := (others => '0');
   signal reg_sr : std_logic_vector( 7 downto 0) := (others => '0');

   -- Signals connected to the register file
   signal regs_rd_data : std_logic_vector(7 downto 0);
   signal regs_debug   : std_logic_vector(23 downto 0);

   -- Additional Registers
   signal mem_addr_reg  : std_logic_vector(15 downto 0) := (others => '0');
   signal mem_addr2_reg : std_logic_vector(15 downto 0) := (others => '0');

   signal irq_masked : std_logic;

   -- This file contains the following registers:
   -- Register File (A, X, Y). Input is always from ALU. Requires ALU function
   --    code (4 bits).
   -- Program Counter. Input is either (PC + 4) or (mem_addr_reg) (1 bit).
   -- Stack Pointer. Input is either (SP + 1) or (SP - 1) (1 bit).
   -- Memory Address. Input is always data_i. 1 bit for each of hi and lo. (2 bits).
   -- Status Register, NZCV. Input is always from ALU. 1 bit for each (4 bits).
   -- Status Register, BID. 2 bits for each (6 bits).
   -- Status Register, All. Input is either register or memory (1 bit).

   -- Signals driven by the Control Logic
   signal ctl_wr_reg        : std_logic_vector(5 downto 0);
   signal ctl_wr_pc         : std_logic_vector(5 downto 0);
   signal ctl_wr_sp         : std_logic_vector(1 downto 0);
   signal ctl_wr_hold_addr  : std_logic_vector(1 downto 0);
   signal ctl_wr_hold_addr2 : std_logic_vector(1 downto 0);
   signal ctl_wr_szcv       : std_logic_vector(3 downto 0);
   signal ctl_wr_b          : std_logic_vector(1 downto 0);
   signal ctl_wr_i          : std_logic_vector(1 downto 0);
   signal ctl_wr_d          : std_logic_vector(1 downto 0);
   signal ctl_wr_sr         : std_logic_vector(1 downto 0);

   -- Additionally, some MUX's:
   signal ctl_mem_addr     : std_logic_vector(3 downto 0);
   signal ctl_mem_rden     : std_logic;
   signal ctl_reg_nr_wr    : std_logic_vector(1 downto 0);
   signal ctl_reg_nr_rd    : std_logic_vector(1 downto 0);

   -- Memory write data. Input is Register, PC, or SR (2 bits).
   signal ctl_mem_wrdata   : std_logic_vector(2 downto 0);
   signal ctl_wr_c         : std_logic_vector(1 downto 0);

   signal ctl_debug : std_logic_vector(10 downto 0);

   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector( 7 downto 0);

   signal wr_mask : std_logic_vector(7 downto 0);
   signal wr_data : std_logic_vector(7 downto 0);

   signal status : std_logic_vector(127 downto 0);

begin

   irq_masked <= irq_i and not reg_sr(2);

   -- Instantiate the control logic
   inst_ctl : entity work.ctl
   port map (
               clk_i           => clk_i,
               rst_i           => rst_i,
               step_i          => step_i,
               wait_i          => wait_i,
               irq_i           => irq_masked,
               data_i          => data_i,
               wr_reg_o        => ctl_wr_reg,
               wr_pc_o         => ctl_wr_pc,
               wr_sp_o         => ctl_wr_sp,
               wr_hold_addr_o  => ctl_wr_hold_addr,
               wr_szcv_o       => ctl_wr_szcv,
               wr_b_o          => ctl_wr_b,
               wr_i_o          => ctl_wr_i,
               wr_d_o          => ctl_wr_d,
               wr_sr_o         => ctl_wr_sr,
               mem_addr_o      => ctl_mem_addr,
               mem_rden_o      => ctl_mem_rden,
               reg_nr_wr_o     => ctl_reg_nr_wr,
               reg_nr_rd_o     => ctl_reg_nr_rd,
               mem_wrdata_o    => ctl_mem_wrdata,
               wr_c_o          => ctl_wr_c,
               wr_hold_addr2_o => ctl_wr_hold_addr2,
               invalid_o       => invalid_o,
               debug_o         => ctl_debug
            );

   -- Instantiate register file
   inst_regs : entity work.regs
   port map ( 
               clk_i       => clk_i,
               rst_i       => rst_i,
               reg_nr_wr_i => ctl_reg_nr_wr,
               reg_nr_rd_i => ctl_reg_nr_rd,
               data_o      => regs_rd_data,
               wren_i      => ctl_wr_reg(4),
               data_i      => alu_out,
               debug_o     => regs_debug
            );

   -- Instantiate the ALU (combinatorial)
   inst_alu : entity work.alu
   port map (
               a_i    => alu_a_in,
               b_i    => data_i,
               c_i    => reg_sr(0),  -- Carry
               func_i => ctl_wr_reg(3 downto 0),
               res_o  => alu_out,
               c_o    => alu_c,
               s_o    => alu_s,
               v_o    => alu_v,
               z_o    => alu_z
            );

   alu_a_in <= regs_rd_data when ctl_wr_reg(5) = '0' else reg_sp;


   -- Program Counter register
   inst_pc : entity work.pc
   port map (
      -- Clock
      clk_i   => clk_i,
      rst_i   => rst_i,
      wr_pc_i => ctl_wr_pc,
      sr_i    => reg_sr,
      data_i  => data_i,
      addr_i  => mem_addr_reg,
      pc_o    => reg_pc
   );

   -- Stack pointer
   inst_sp : entity work.sp
   port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      wr_i   => ctl_wr_sp,
      regs_i => regs_rd_data,
      sp_o   => reg_sp
   );

   -- Memory address hold register
   inst_addr : entity work.addr
   port map (
      -- Clock
      clk_i   => clk_i,
      rst_i   => rst_i,
      wr_i    => ctl_wr_hold_addr,
      data_i  => data_i,
      regs_i  => regs_rd_data,
      addr_o  => mem_addr_reg
   );

   -- Second memory address hold register
   inst_addr2 : entity work.addr2
   port map (
      -- Clock
      clk_i   => clk_i,
      rst_i   => rst_i,
      wr_i    => ctl_wr_hold_addr2,
      data_i  => data_i,
      regs_i  => regs_rd_data,
      addr_o  => mem_addr2_reg
   );


   wr_mask(7) <= ctl_wr_szcv(3);
   wr_mask(6) <= ctl_wr_szcv(0);
   wr_mask(5) <= '0';
   wr_mask(4) <= ctl_wr_b(1);
   wr_mask(3) <= ctl_wr_d(1);
   wr_mask(2) <= ctl_wr_i(1);
   wr_mask(1) <= ctl_wr_szcv(2);
   wr_mask(0) <= ctl_wr_szcv(1) or ctl_wr_c(1);

   wr_data(7) <= alu_s;
   wr_data(6) <= alu_v;
   wr_data(5) <= '0';
   wr_data(4) <= ctl_wr_b(0);
   wr_data(3) <= ctl_wr_d(0);
   wr_data(2) <= ctl_wr_i(0);
   wr_data(1) <= alu_z;
   wr_data(0) <= (alu_c and ctl_wr_szcv(1)) or (ctl_wr_c(0) and ctl_wr_c(1));

   -- Status register
   inst_sr : entity work.sr
   port map (
      -- Clock
      clk_i      => clk_i,
      rst_i      => rst_i,

      wr_mask_i  => wr_mask,
      wr_data_i  => wr_data,

      wr_sr_i    => ctl_wr_sr,
      data_i     => data_i,
      reg_i      => regs_rd_data,

      sr_o       => reg_sr
   );
 
   -- Select memory address
   addr <= reg_pc                           when ctl_mem_addr = "0000" else    -- Used during instruction fetch
           mem_addr_reg                     when ctl_mem_addr = "0001" else    -- Used during zero-page and absolute addressing
           X"01" & reg_sp                   when ctl_mem_addr = "0010" else    -- Used during stack push and pull
           mem_addr2_reg                    when ctl_mem_addr = "0011" else    -- Used during other addressing modes
           X"FFFE"                          when ctl_mem_addr = "1000" else    -- BRK
           X"FFFF"                          when ctl_mem_addr = "1001" else    -- BRK
           X"FFFA"                          when ctl_mem_addr = "1010" else    -- NMI
           X"FFFB"                          when ctl_mem_addr = "1011" else    -- NMI
           X"FFFC"                          when ctl_mem_addr = "1100" else    -- RESET
           X"FFFD"                          when ctl_mem_addr = "1101" else    -- RESET
           X"FFFE"                          when ctl_mem_addr = "1110" else    -- IRQ
           X"FFFF"                          when ctl_mem_addr = "1111" else    -- IRQ
           (others => 'X');

   -- Select memory data
   data <= regs_rd_data        when ctl_mem_wrdata(1 downto 0) = "00" else     -- Used during register store to memory
           reg_pc(15 downto 8) when ctl_mem_wrdata(1 downto 0) = "01" else     -- Used during IRQ
           reg_pc(7 downto 0)  when ctl_mem_wrdata(1 downto 0) = "10" else     -- Used during IRQ
           reg_sr              when ctl_mem_wrdata(1 downto 0) = "11" else     -- Used during IRQ
           (others => '0');

   -- Debug output
   p_status : process (clk_i)
   begin
      if rising_edge(clk_i) then
         status( 15 downto   0) <= addr;                                     -- "ADDR"
         status( 31 downto  16) <= "0000000" & ctl_mem_wrdata(2) & data;     -- "WR_DATA"
         status( 47 downto  32) <= "0000000" & ctl_mem_rden & data_i;        -- "RD_DATA"
         status( 63 downto  48) <= reg_pc;                                   -- "PC"
         status( 79 downto  64) <= "00000" & ctl_debug;                      -- "INST"
         status( 95 downto  80) <= reg_sr & regs_debug(7 downto 0);          -- "SR_A"
         status(111 downto  96) <= regs_debug(23 downto 8);                  -- "X_Y"
         status(127 downto 112) <= X"01" & reg_sp;                           -- "SP"
      end if;
   end process p_status;


   -----------------------
   -- Drive output signals
   -----------------------

   addr_o   <= addr;
   data_o   <= data;
   rden_o   <= ctl_mem_rden;
   wren_o   <= ctl_mem_wrdata(2);
   status_o <= status;

end Structural;

