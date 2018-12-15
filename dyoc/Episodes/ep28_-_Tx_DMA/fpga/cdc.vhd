library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library unimacro;

-- This module handles clock crossing using a Xilinx FIFO.
-- The FIFO is written to whenever it is empty,
-- and read from whenever it is not empty.

entity cdc is
   generic (
      G_WIDTH : integer
   );
   port (
      src_clk_i  : in  std_logic;
      src_data_i : in  std_logic_vector(G_WIDTH-1 downto 0);
      dst_clk_i  : in  std_logic;
      dst_data_o : out std_logic_vector(G_WIDTH-1 downto 0)
   );
end cdc;

architecture structural of cdc is

   constant C_NUM_FIFOS : integer := (G_WIDTH+35) / 36;

   signal src_data : std_logic_vector(C_NUM_FIFOS*36-1 downto 0);
   signal dst_data : std_logic_vector(C_NUM_FIFOS*36-1 downto 0);

   signal rst             : std_logic := '1';
   signal rst_shr         : std_logic_vector(7 downto 0) := X"FF";

   signal dst_empty       : std_logic_vector(C_NUM_FIFOS-1 downto 0);
   signal dst_rd_en       : std_logic;

   signal src_prog_full   : std_logic_vector(C_NUM_FIFOS-1 downto 0);
   signal src_wr_en       : std_logic;
   signal src_wr_rst_busy : std_logic;

begin

   src_data(G_WIDTH-1 downto 0) <= src_data_i;
   dst_data_o <= dst_data(G_WIDTH-1 downto 0);

   rst_proc : process (src_clk_i)
   begin
      if rising_edge(src_clk_i) then
         -- Hold reset asserted for a number of clock cycles.
         rst     <= rst_shr(0);
         rst_shr <= "0" & rst_shr(rst_shr'left downto 1);
      end if;
   end process rst_proc;

   -- Write when empty
   src_wr_en <= not src_prog_full(0) and not src_wr_rst_busy;

   -- Read when not empty
   dst_rd_en <= not dst_empty(0);


   ---------------------------------
   -- Instantiate asynchronous FIFO
   ---------------------------------

   gen_fifos : for i in 0 to C_NUM_FIFOS-1 generate
      i_fifo_dualclock_macro : entity unimacro.fifo_dualclock_macro
         generic map (
            DEVICE                  => "7SERIES",  -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"
            ALMOST_FULL_OFFSET      => X"0005",    -- Sets almost full threshold
            ALMOST_EMPTY_OFFSET     => X"0080",    -- Sets the almost empty threshold
            DATA_WIDTH              => 36,         -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
            FIFO_SIZE               => "18Kb",     -- Target BRAM, "18Kb" or "36Kb"
            FIRST_WORD_FALL_THROUGH => true
         )
         port map (
            ALMOSTEMPTY => open,             -- 1-bit output almost empty
            ALMOSTFULL  => src_prog_full(i), -- 1-bit output almost full
            DO          => dst_data(36*i+35 downto 36*i),       -- Output data, width defined by DATA_WIDTH parameter
            EMPTY       => dst_empty(i),     -- 1-bit output empty
            FULL        => open,             -- 1-bit output full
            RDCOUNT     => open,             -- Output read count, width determined by FIFO depth
            RDERR       => open,             -- 1-bit output read error
            WRCOUNT     => open,             -- Output write count, width determined by FIFO depth
            WRERR       => open,             -- 1-bit output write error
            DI          => src_data(36*i+35 downto 36*i),       -- Input data, width defined by DATA_WIDTH parameter
            RDCLK       => dst_clk_i,        -- 1-bit input read clock
            RDEN        => dst_rd_en,        -- 1-bit input read enable
            RST         => rst,              -- 1-bit input reset
            WRCLK       => src_clk_i,        -- 1-bit input write clock
            WREN        => src_wr_en         -- 1-bit input write enable
         ); -- i_fifo_dualclock_macro
   end generate gen_fifos;

end architecture structural;

