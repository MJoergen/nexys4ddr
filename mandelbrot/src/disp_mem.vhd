-- This is the display memory, holding the picture. It has G_NUM_BLOCKS*4096
-- pixels of 9 bits (the iteration count of each pixel), with addresses of
-- G_ADDR_BITS bits, and is implemented in block RAM.
-- It has a write port and a read port, with separate clocks, so it is also the
-- connection between the two clock domains. The address of a pixel is given by
-- its picture column and row, see dispatcher.vhd.
--
-- Each entry of the memory (a word) holds G_PIXELS pixels: consecutive rows of
-- a picture column, with the first row in the lowest 9 bits. So the write port
-- writes G_PIXELS pixels at a time. The write address (wr_addr_i) is that of
-- the first pixel, i.e. its lowest bits (the position in the word) must be
-- zero. The read port reads a single pixel. G_PIXELS must be a power of two.
--
-- The memory is divided into G_NUM_BLOCKS blocks of 2^12 pixels (one BRAM
-- each, used as 4096/G_PIXELS entries of 9*G_PIXELS bits, i.e. with the
-- parity bits), e.g. 128 blocks (2^19 pixels) on the Nexys 4 DDR and 320
-- blocks (1280*1024 pixels) on the MEGA65. The blocks are in groups of 8. The
-- write address and data go to the blocks through a tree of registers: first
-- to a register in each group, and then (if G_BLOCK_REGS is true) to a
-- register for each block. So each register drives one register in each
-- group, or 8 registers, or one BRAM, and the register of a block can be
-- placed next to its BRAM. A single register for the address of all 128
-- BRAMs, which are spread over the whole FPGA, made the routing too slow.
-- Without the registers of the blocks, each register of a group drives the 8
-- BRAMs of the group directly. This saves 47 registers for each block (with
-- four pixels in each word), about 15,000 for 320 blocks, which the MEGA65
-- needs for the job modules. Writes to addresses outside the memory are
-- ignored.
--
-- The write port has three clock cycles of latency, or two without the
-- registers of the blocks. On reset (wr_rst_i), the
-- entire memory is filled with the value 0x055, which takes
-- G_NUM_BLOCKS*4096/G_PIXELS clock cycles. Writes on the write port are
-- ignored while this is in progress.
--
-- The read port has four clock cycles of latency: The read address goes to a
-- register in each group, which drives the 8 BRAMs of the group, then the
-- BRAMs are read, then each group selects the pixel from its blocks, and then
-- the pixel is selected from the groups. Without the registers of the read
-- address, it would drive all the BRAMs, which are spread over the whole
-- FPGA: with 320 blocks this took 8.2 ns of the 9.26 ns at 108 MHz. Selecting
-- the pixel from all the blocks in one clock cycle would be too slow too. The
-- read reset (rd_rst_i) is not used.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity disp_mem is
   generic (
      G_ADDR_BITS  : positive := 19;     -- Bits of the pixel address
      G_NUM_BLOCKS : positive := 128;    -- Blocks (BRAMs) of 4096 pixels
      G_BLOCK_REGS : boolean := true;   -- A write register for each block
      G_PIXELS     : positive := 1       -- Pixels in each word
   );
   port (
      wr_clk_i    : in  std_logic;
      wr_rst_i    : in  std_logic;
      wr_addr_i   : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      wr_data_i   : in  std_logic_vector(9*G_PIXELS-1 downto 0);
      wr_en_i     : in  std_logic;
      --
      rd_clk_i    : in  std_logic;
      rd_rst_i    : in  std_logic;
      rd_addr_i   : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      rd_data_o   : out std_logic_vector( 8 downto 0)
   );
end entity disp_mem;

architecture rtl of disp_mem is

   -- The number of bits needed for the values 0 to n-1
   function log2 (n : natural) return natural is
      variable r : natural := 0;
   begin
      while 2**r < n loop
         r := r + 1;
      end loop;
      return r;
   end function log2;

   -- The addresses below are word addresses, i.e. without the lowest
   -- C_SUB_BITS bits of the pixel address (the position in the word).
   constant C_SUB_BITS    : natural := log2(G_PIXELS);
   constant C_WORD_BITS   : natural := G_ADDR_BITS - C_SUB_BITS;
   constant C_GROUP_SIZE  : positive := 8;   -- Blocks in a group
   constant C_NUM_BLOCKS  : natural := G_NUM_BLOCKS;
   constant C_NUM_GROUPS  : natural := C_NUM_BLOCKS / C_GROUP_SIZE;
   constant C_BLOCK_BITS  : natural := 12 - C_SUB_BITS;  -- Address bits in a block
   constant C_GROUP_BITS  : natural := 15 - C_SUB_BITS;  -- Address bits in a group
   -- The number of words in the memory
   constant C_NUM_WORDS   : natural := C_NUM_BLOCKS * 2**C_BLOCK_BITS;

   subtype word_t is std_logic_vector(9*G_PIXELS-1 downto 0);
   type mem_t is array (0 to 2**C_BLOCK_BITS-1) of word_t;
   type grp_addr_vector is array (natural range <>) of
      std_logic_vector(C_GROUP_BITS-1 downto 0);
   type blk_addr_vector is array (natural range <>) of
      std_logic_vector(C_BLOCK_BITS-1 downto 0);
   type word_vector is array (natural range <>) of word_t;
   type pixel_vector is array (natural range <>) of std_logic_vector(8 downto 0);
   type blk_sel_vector is array (natural range <>) of natural range 0 to C_GROUP_SIZE-1;
   type sub_vector is array (natural range <>) of natural range 0 to G_PIXELS-1;

   signal wr_addr      : std_logic_vector(C_WORD_BITS-1 downto 0);
   signal wr_data      : word_t;
   signal wr_en        : std_logic;
   signal wr_addr_rst  : std_logic_vector(C_WORD_BITS-1 downto 0);
   signal wr_rst       : std_logic := '0';

   -- The write port of each group and of each block (registers, or wires
   -- from the group if G_BLOCK_REGS is false). The address and data
   -- registers are identical, so the attribute keep prevents the synthesis
   -- tool from merging them.
   signal grp_addr_r   : grp_addr_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_data_r   : word_vector(C_NUM_GROUPS-1 downto 0);
   signal grp_en_r     : std_logic_vector(C_NUM_GROUPS-1 downto 0);
   signal blk_addr_r   : blk_addr_vector(C_NUM_BLOCKS-1 downto 0);
   signal blk_data_r   : word_vector(C_NUM_BLOCKS-1 downto 0);
   signal blk_en_r     : std_logic_vector(C_NUM_BLOCKS-1 downto 0);

   attribute keep : string;
   attribute keep of grp_addr_r : signal is "true";
   attribute keep of grp_data_r : signal is "true";
   attribute keep of blk_addr_r : signal is "true";
   attribute keep of blk_data_r : signal is "true";

   -- The read port: The read address, and the address of the word in the
   -- block in each group, the words read from the blocks, the block in its
   -- group and the position of the pixel in the word in each group, the pixel
   -- selected in each group, and the group.
   -- The registers in each group are identical, so the attribute keep
   -- prevents the synthesis tool from merging them.
   signal rd_addr      : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal rd_grp_addr  : blk_addr_vector(C_NUM_GROUPS-1 downto 0);
   signal rd_blk_r     : word_vector(C_NUM_BLOCKS-1 downto 0);
   signal rd_blk_sel_r : blk_sel_vector(C_NUM_GROUPS-1 downto 0) := (others => 0);
   signal rd_sub_r     : sub_vector(C_NUM_GROUPS-1 downto 0) := (others => 0);
   signal rd_grp_d     : pixel_vector(C_NUM_GROUPS-1 downto 0);
   signal rd_grp_sel_r : natural range 0 to C_NUM_GROUPS-1 := 0;
   signal rd_grp_sel_d : natural range 0 to C_NUM_GROUPS-1 := 0;
   signal rd_data_dd   : std_logic_vector(8 downto 0);

   attribute keep of rd_grp_addr  : signal is "true";
   attribute keep of rd_blk_sel_r : signal is "true";
   attribute keep of rd_sub_r     : signal is "true";

begin

   assert G_NUM_BLOCKS mod C_GROUP_SIZE = 0 and
          C_NUM_WORDS <= 2**C_WORD_BITS
      report "The number of blocks must be a multiple of 8, and fit in the address"
      severity failure;

   -------------------------
   -- Write to pixel memory
   -------------------------

   p_write_ctrl : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then

         wr_addr <= wr_addr_i(G_ADDR_BITS-1 downto C_SUB_BITS);
         wr_data <= wr_data_i;
         wr_en   <= wr_en_i;

         if wr_rst = '1' then
            wr_addr <= wr_addr_rst;
            for i in 0 to G_PIXELS-1 loop
               wr_data(9*i+8 downto 9*i) <= "001010101";
            end loop;
            wr_en   <= '1';

            wr_addr_rst <= wr_addr_rst + 1;

            if wr_addr_rst = C_NUM_WORDS-1 then
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
            if wr_en = '1' and to_integer(wr_addr(C_WORD_BITS-1 downto C_GROUP_BITS)) = g then
               grp_en_r(g) <= '1';
            end if;
         end loop;
      end if;
   end process p_write_grp;


   ------------------------------------------
   -- The blocks, and reading from the blocks
   ------------------------------------------

   gen_blk : for b in 0 to C_NUM_BLOCKS-1 generate
      constant C_GROUP : natural := b / C_GROUP_SIZE;
      signal mem : mem_t;
      -- The write enable of the block, from the register of the group
      signal blk_en_s : std_logic;
   begin
      blk_en_s <= '1' when grp_en_r(C_GROUP) = '1' and
                           to_integer(grp_addr_r(C_GROUP)(C_GROUP_BITS-1 downto C_BLOCK_BITS)) = b mod C_GROUP_SIZE
                  else '0';

      gen_blk_regs : if G_BLOCK_REGS generate
         p_write_blk : process (wr_clk_i)
         begin
            if rising_edge(wr_clk_i) then
               blk_addr_r(b) <= grp_addr_r(C_GROUP)(C_BLOCK_BITS-1 downto 0);
               blk_data_r(b) <= grp_data_r(C_GROUP);
               blk_en_r(b)   <= blk_en_s;
            end if;
         end process p_write_blk;
      else generate
         blk_addr_r(b) <= grp_addr_r(C_GROUP)(C_BLOCK_BITS-1 downto 0);
         blk_data_r(b) <= grp_data_r(C_GROUP);
         blk_en_r(b)   <= blk_en_s;
      end generate gen_blk_regs;

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
            rd_blk_r(b) <= mem(to_integer(rd_grp_addr(C_GROUP)));
         end if;
      end process p_read;
   end generate gen_blk;

   -- The read address, and the address of the word in the block for the
   -- blocks of each group
   p_rd_addr : process (rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         rd_addr <= rd_addr_i;
         for g in 0 to C_NUM_GROUPS-1 loop
            rd_grp_addr(g) <= rd_addr_i(C_BLOCK_BITS+C_SUB_BITS-1 downto C_SUB_BITS);
         end loop;
      end if;
   end process p_rd_addr;

   -- The address is split into the group, the block in the group, the word in
   -- the block, and the position of the pixel in the word.
   p_read_sel : process (rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         -- Addresses outside the memory are never read, so they may give any
         -- value.
         rd_grp_sel_r <= 0;
         if to_integer(rd_addr(G_ADDR_BITS-1 downto C_GROUP_BITS+C_SUB_BITS)) < C_NUM_GROUPS then
            rd_grp_sel_r <= to_integer(rd_addr(G_ADDR_BITS-1 downto C_GROUP_BITS+C_SUB_BITS));
         end if;
         for g in 0 to C_NUM_GROUPS-1 loop
            rd_blk_sel_r(g) <= to_integer(rd_addr(C_GROUP_BITS+C_SUB_BITS-1 downto C_BLOCK_BITS+C_SUB_BITS));
            rd_sub_r(g)     <= to_integer(rd_addr) mod G_PIXELS;
         end loop;
         rd_grp_sel_d <= rd_grp_sel_r;
         rd_data_dd   <= rd_grp_d(rd_grp_sel_d);
      end if;
   end process p_read_sel;

   gen_rd_grp : for g in 0 to C_NUM_GROUPS-1 generate
      p_rd_grp : process (rd_clk_i)
         variable word_v : word_t;
      begin
         if rising_edge(rd_clk_i) then
            word_v      := rd_blk_r(g*C_GROUP_SIZE + rd_blk_sel_r(g));
            rd_grp_d(g) <= word_v(9*rd_sub_r(g)+8 downto 9*rd_sub_r(g));
         end if;
      end process p_rd_grp;
   end generate gen_rd_grp;

   rd_data_o <= rd_data_dd;

end architecture rtl;

