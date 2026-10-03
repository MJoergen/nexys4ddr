library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the display memory, holding the picture. It has 2^19 entries of 8
-- bits, and is implemented in block RAM. It has a write port and a read port,
-- with separate clocks, so it is also the connection between the two clock
-- domains.
--
-- The memory is divided into 128 blocks of 2^12 entries (one BRAM each). The
-- write address and data go to the blocks through a tree of registers: first
-- to a register in each of 16 groups of 8 blocks, and then to a register for
-- each block. So each register drives at most 16 registers or one BRAM, and
-- the register of a block can be placed next to its BRAM. A single register
-- for the address of all 128 BRAMs, which are spread over the whole FPGA, made
-- the routing too slow.
--
-- The write port has three clock cycles of latency. On reset (wr_rst_i), the
-- entire memory is filled with the value 0x55, which takes 2^19 clock cycles.
-- Writes on the write port are ignored while this is in progress.
--
-- The read port has three clock cycles of latency. The read reset (rd_rst_i)
-- is not used.

entity disp_mem is
   port (
      wr_clk_i    : in  std_logic;
      wr_rst_i    : in  std_logic;
      wr_addr_i   : in  std_logic_vector(18 downto 0);
      wr_data_i   : in  std_logic_vector( 7 downto 0);
      wr_en_i     : in  std_logic;
      --
      rd_clk_i    : in  std_logic;
      rd_rst_i    : in  std_logic;
      rd_addr_i   : in  std_logic_vector(18 downto 0);
      rd_data_o   : out std_logic_vector( 7 downto 0)
   );
end entity disp_mem;

architecture rtl of disp_mem is

   constant C_NUM_GROUPS  : integer := 16;
   constant C_GROUP_SIZE  : integer := 8;   -- Blocks in a group
   constant C_NUM_BLOCKS  : integer := C_NUM_GROUPS*C_GROUP_SIZE;
   constant C_BLOCK_BITS  : integer := 12;  -- Address bits in a block
   constant C_GROUP_BITS  : integer := 15;  -- Address bits in a group

   type mem_t is array (0 to 2**C_BLOCK_BITS-1) of std_logic_vector(7 downto 0);
   type grp_addr_vector is array (natural range <>) of
      std_logic_vector(C_GROUP_BITS-1 downto 0);
   type blk_addr_vector is array (natural range <>) of
      std_logic_vector(C_BLOCK_BITS-1 downto 0);
   type data_vector is array (natural range <>) of
      std_logic_vector(7 downto 0);

   signal wr_addr      : std_logic_vector(18 downto 0);
   signal wr_data      : std_logic_vector( 7 downto 0);
   signal wr_en        : std_logic;
   signal wr_addr_rst  : std_logic_vector(18 downto 0);
   signal wr_rst       : std_logic := '0';

   -- The write port of each group and of each block. The address and data
   -- registers are identical, so the attribute keep prevents the synthesis
   -- tool from merging them.
   signal grp_addr_r   : grp_addr_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_data_r   : data_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_en_r     : std_logic_vector(C_NUM_GROUPS-1 downto 0);
   signal blk_addr_r   : blk_addr_vector(C_NUM_BLOCKS-1 downto 0);
   signal blk_data_r   : data_vector(C_NUM_BLOCKS-1 downto 0);
   signal blk_en_r     : std_logic_vector(C_NUM_BLOCKS-1 downto 0);

   attribute keep : string;
   attribute keep of grp_addr_r : signal is "true";
   attribute keep of grp_data_r : signal is "true";
   attribute keep of blk_addr_r : signal is "true";
   attribute keep of blk_data_r : signal is "true";

   signal rd_blk_r   : data_vector(C_NUM_BLOCKS-1 downto 0);
   signal rd_sel_r   : std_logic_vector(18 downto C_BLOCK_BITS);
   signal rd_data_d  : std_logic_vector(7 downto 0);
   signal rd_data_dd : std_logic_vector(7 downto 0);

begin

   -------------------------
   -- Write to pixel memory
   -------------------------

   p_write_ctrl : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then

         wr_addr <= wr_addr_i;
         wr_data <= wr_data_i;
         wr_en   <= wr_en_i;

         if wr_rst = '1' then
            wr_addr <= wr_addr_rst;
            wr_data <= "01010101";
            wr_en   <= '1';

            wr_addr_rst <= wr_addr_rst + 1;

            if wr_addr_rst + 1 = 0 then
               wr_rst <= '0';
            end if;
         end if;

         if wr_rst_i = '1' then
            wr_addr_rst <= (others => '0');
            wr_rst      <= '1';
         end if;
      end if;
   end process p_write_ctrl;

   p_write_grp : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then
         for g in 0 to C_NUM_GROUPS-1 loop
            grp_addr_r(g) <= wr_addr(C_GROUP_BITS-1 downto 0);
            grp_data_r(g) <= wr_data;
            grp_en_r(g)   <= '0';
            if wr_en = '1' and to_integer(wr_addr(18 downto C_GROUP_BITS)) = g then
               grp_en_r(g) <= '1';
            end if;
         end loop;
      end if;
   end process p_write_grp;


   ------------------------------------------
   -- The blocks, and reading from the blocks
   ------------------------------------------

   gen_blk : for b in 0 to C_NUM_BLOCKS-1 generate
      constant C_GROUP : integer := b / C_GROUP_SIZE;
      signal mem : mem_t;
   begin
      p_write_blk : process (wr_clk_i)
      begin
         if rising_edge(wr_clk_i) then
            blk_addr_r(b) <= grp_addr_r(C_GROUP)(C_BLOCK_BITS-1 downto 0);
            blk_data_r(b) <= grp_data_r(C_GROUP);
            blk_en_r(b)   <= '0';
            if grp_en_r(C_GROUP) = '1' and
               to_integer(grp_addr_r(C_GROUP)(C_GROUP_BITS-1 downto C_BLOCK_BITS)) = b mod C_GROUP_SIZE
            then
               blk_en_r(b) <= '1';
            end if;
         end if;
      end process p_write_blk;

      p_write : process (wr_clk_i)
      begin
         if rising_edge(wr_clk_i) then
            if blk_en_r(b) = '1' then
               mem(to_integer(blk_addr_r(b))) <= blk_data_r(b);
            end if;
         end if;
      end process p_write;

      p_read : process (rd_clk_i)
      begin
         if rising_edge(rd_clk_i) then
            rd_blk_r(b) <= mem(to_integer(rd_addr_i(C_BLOCK_BITS-1 downto 0)));
         end if;
      end process p_read;
   end generate gen_blk;

   p_read_sel : process (rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         rd_sel_r   <= rd_addr_i(18 downto C_BLOCK_BITS);
         rd_data_d  <= rd_blk_r(to_integer(rd_sel_r));
         rd_data_dd <= rd_data_d;
      end if;
   end process p_read_sel;

   rd_data_o <= rd_data_dd;

end architecture rtl;

