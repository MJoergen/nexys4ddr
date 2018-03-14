library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module performs the MAC/IP/UDP encapsulation of payload data.
-- It calculates all headers, including checksum.
-- Clock domain crossing is handled by FIFOs on the input.
-- The module operates in store-n-forward mode, because it needs the total
-- length of the payload. This limits the maximum frame size to the size of the
-- input fifo. Overflow of this input fifo is signalled in the pl_error_o signal.

entity encap is
   port (
      -- Payload clock
      pl_clk_i      : in  std_logic; 
      pl_rst_i      : in  std_logic;

      -- Mac clock
      mac_clk_i    : in  std_logic;
      mac_rst_i    : in  std_logic;

      -- Ctrl interface. Assumed to be constant for now.
      ctrl_mac_dst_i : in std_logic_vector(47 downto 0);
      ctrl_mac_src_i : in std_logic_vector(47 downto 0);
      ctrl_ip_dst_i  : in std_logic_vector(31 downto 0);
      ctrl_ip_src_i  : in std_logic_vector(31 downto 0);
      ctrl_udp_dst_i : in std_logic_vector(15 downto 0);
      ctrl_udp_src_i : in std_logic_vector(15 downto 0);

      -- Payload interface @ pl_clk_i
      pl_ena_i   : in  std_logic;
      pl_sof_i   : in  std_logic;
      pl_eof_i   : in  std_logic;
      pl_data_i  : in  std_logic_vector(7 downto 0);
      pl_error_o : out std_logic;

      -- Mac interface @ mac_clk_i
      mac_data_o  : out std_logic_vector(7 downto 0);
      mac_sof_o   : out std_logic;
      mac_eof_o   : out std_logic;
      mac_empty_o : out std_logic;
      mac_rden_i  : in  std_logic
   );
end encap;

architecture Structural of encap is

   -- Ctrl fifo input @ pl_clk_i
   signal pl_ctrl_in     : std_logic_vector(15 downto 0);
   signal pl_ctrl_wren   : std_logic := '0';

   -- Ctrl fifo output @ mac_clk_i
   signal mac_ctrl_out   : std_logic_vector(15 downto 0);
   signal mac_ctrl_rden  : std_logic := '0';
   signal mac_ctrl_empty : std_logic;

   -- Payload fifo output @ mac_clk_i
   signal mac_data_out   : std_logic_vector(7 downto 0);
   signal mac_data_rden  : std_logic := '0';
   signal mac_data_empty : std_logic;

   type t_fsm_state is (IDLE_ST, CHKSUM_ST, HDR_ST, PL_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

   signal byte_cnt    : std_logic_vector(15 downto 0) := (others => '0');

   signal frm_len     : std_logic_vector(15 downto 0);

   -- Headers
   signal hdr_data : std_logic_vector(42*8-1 downto 0);
   signal hdr_len  : std_logic_vector(15 downto 0);

   signal mac_empty : std_logic := '1';
   signal mac_sof   : std_logic := '0';
   signal mac_eof   : std_logic := '0';

begin

   ------------------------
   -- Clock domain pl_clk_i
   ------------------------

   -- Instantiate the data fifo
   -- The data fifo contains the raw payload data.
   -- This fifo must be large enough to contain an entire frame.
   -- This fifo stores the entire frame, until the length has been calculated.
   inst_data_fifo : entity work.fifo
   generic map (
      G_WIDTH => 8
      )
   port map (
      wr_clk_i    => pl_clk_i,
      wr_rst_i    => pl_rst_i,
      wr_en_i     => pl_ena_i,
      wr_data_i   => pl_data_i,
      wr_error_o  => pl_error_o,    -- Write to full fifo
      --
      rd_clk_i    => mac_clk_i,
      rd_rst_i    => mac_rst_i,
      rd_en_i     => mac_data_rden,
      rd_data_o   => mac_data_out,
      rd_empty_o  => mac_data_empty,
      rd_error_o  => open           -- Read from empty fifo
      );

   -- Count the number of bytes 
   -- The ctrl fifo contains the number of payload bytes in each frame.
   pl_ctrl : process (pl_clk_i)
   begin
      if rising_edge(pl_clk_i) then
         pl_ctrl_wren <= '0';

         if pl_ena_i = '1' then
            byte_cnt <= byte_cnt + 1;

            if pl_sof_i = '1' then
               byte_cnt <= X"0001";
            end if;

            if pl_eof_i = '1' then
               pl_ctrl_wren <= '1';
               pl_ctrl_in   <= byte_cnt + 1;
            end if;
         end if;
      end if;
   end process pl_ctrl;

   -- Instantiate the ctrl fifo
   -- This fifo contains the calculated number of bytes in each frame.
   -- Ignore overflow, because this fifo contains much less data than
   -- the daat fifo.
   inst_ctrl_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16)
   port map (
      wr_clk_i   => pl_clk_i,
      wr_rst_i   => pl_rst_i,
      wr_en_i    => pl_ctrl_wren,
      wr_data_i  => pl_ctrl_in,
      wr_error_o => open,
      --
      rd_clk_i   => mac_clk_i,
      rd_rst_i   => mac_rst_i,
      rd_en_i    => mac_ctrl_rden,
      rd_data_o  => mac_ctrl_out,
      rd_empty_o => mac_ctrl_empty,
      rd_error_o => open
      );


   -------------------------
   -- Clock domain mac_clk_i
   -------------------------


   -- Generate MAC frame
   proc_mac : process (mac_clk_i)
      -- Calculate the one-complement sum.
      -- Used to calculate the checksum of the IP header.
      function chksum(arg : std_logic_vector) 
         return std_logic_vector is
         variable temp_v : std_logic_vector(31 downto 0) := (others => '0');
         variable len_v  : integer;
         variable val_v  : std_logic_vector(15 downto 0);
      begin
         len_v := arg'length;
         for i in 0 to len_v/16-1 loop
            val_v := arg(i*16+15+arg'right downto i*16+arg'right);
            temp_v := temp_v + (X"0000" & val_v);
         end loop;
         temp_v := (X"0000" & temp_v(15 downto 0)) + (X"0000" & temp_v(31 downto 16));
         return not temp_v(15 downto 0);
      end function chksum;

   begin
      if falling_edge(mac_clk_i) then
         mac_ctrl_rden <= '0';

         case fsm_state is
            when IDLE_ST =>
               mac_empty <= '1'; -- Disable transmission
               mac_sof   <= '0';
               mac_eof   <= '0';
               if mac_ctrl_empty = '0' then   -- We now have a complete frame, so lets build the header
                  frm_len   <= mac_ctrl_out;
                  mac_ctrl_rden <= '1';

                  -- Build UDP header
                  hdr_data( 8*8-1 downto  6*8) <= ctrl_udp_src_i;
                  hdr_data( 6*8-1 downto  4*8) <= ctrl_udp_dst_i;
                  hdr_data( 4*8-1 downto  2*8) <= X"0008" + mac_ctrl_out;  -- Total length including UDP header and UDP payload.
                  hdr_data( 2*8-1 downto  0*8) <= X"0000";  -- UDP header checksum (unused).

                  -- Build IP header
                  hdr_data(28*8-1 downto 27*8) <= X"45";
                  hdr_data(27*8-1 downto 26*8) <= X"00";
                  hdr_data(26*8-1 downto 24*8) <= X"0014" + X"0008" + mac_ctrl_out; -- Total length including IP header and IP payload.
                  hdr_data(24*8-1 downto 22*8) <= X"0000"; -- ID. Could be used as sequence number.
                  hdr_data(22*8-1 downto 20*8) <= X"0000"; -- Fragmentation.
                  hdr_data(20*8-1 downto 19*8) <= X"FF";   -- TTL.
                  hdr_data(19*8-1 downto 18*8) <= X"11";   -- Protocol UDP.
                  hdr_data(18*8-1 downto 16*8) <= X"0000"; -- IP header checksum. Must be set to zero here, before calculation.
                  hdr_data(16*8-1 downto 12*8) <= ctrl_ip_src_i;
                  hdr_data(12*8-1 downto  8*8) <= ctrl_ip_dst_i;

                  -- Build MAC header
                  hdr_data(42*8-1 downto 36*8) <= ctrl_mac_dst_i;
                  hdr_data(36*8-1 downto 30*8) <= ctrl_mac_src_i;
                  hdr_data(30*8-1 downto 28*8) <= X"0800";

                  hdr_len <= std_logic_vector(to_unsigned(hdr_data'length/8, 16));
                  fsm_state <= CHKSUM_ST;
               end if;

            when CHKSUM_ST  =>
               hdr_data(18*8-1 downto 16*8) <= chksum(hdr_data(28*8-1 downto 8*8));
               mac_empty <= '0';  -- Start transmission
               mac_sof   <= '1';
               mac_eof   <= '0';
               fsm_state <= HDR_ST;

            when HDR_ST  =>
               if mac_rden_i = '1' then
                  hdr_data(42*8-1 downto 0) <= hdr_data(41*8-1 downto 0) & X"00";
                  hdr_len <= hdr_len - 1;
                  mac_sof <= '0';

                  if hdr_len = 1 then
                     fsm_state <= PL_ST;
                  end if;
               end if;

            when PL_ST  =>
               if mac_rden_i = '1' then
                  frm_len <= frm_len - 1;
                  if frm_len <= 2 then
                     mac_eof <= '1';
                  end if;
                  if frm_len = 1 then
                     fsm_state <= IDLE_ST;
                  end if;
               end if;

         end case;

         if mac_rst_i = '1' then
            fsm_state <= IDLE_ST;
         end if;
      end if;
   end process proc_mac;

   -- Drive output signals
   mac_data_rden <= '1' when mac_rden_i = '1' and fsm_state = PL_ST else '0';

   mac_empty_o <= mac_empty;
   mac_sof_o   <= mac_sof;
   mac_eof_o   <= mac_eof;
   mac_data_o  <= hdr_data(42*8-1 downto 41*8) when fsm_state = HDR_ST else mac_data_out;

end Structural;

