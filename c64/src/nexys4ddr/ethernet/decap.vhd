library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module performs filtering of MAC, IP, and UDP addresses.
-- The clock domain crossing is handled by a fifo on the input.

-- pl_afull_i : Backpressure. May cause fifo overflow.
-- pl_ovf_o   : Input fifo overflow.
-- pl_err_o   : A corrupted packet, e.g. CRC error.
-- pl_drop_o  : Incorrect MAC, IP, UDP address.

entity decap is
   port (
      -- Ctrl interface. Assumed to be constant for now.
      ctrl_mac_dst_i  : in  std_logic_vector(47 downto 0);
      ctrl_ip_dst_i   : in  std_logic_vector(31 downto 0);
      ctrl_udp_dst_i  : in  std_logic_vector(15 downto 0);

      -- Mac interface @ mac_clk_i
      mac_clk_i       : in  std_logic;
      mac_rst_i       : in  std_logic;
      mac_ena_i       : in  std_logic;
      mac_sof_i       : in  std_logic;
      mac_eof_i       : in  std_logic;
      mac_data_i      : in  std_logic_vector(7 downto 0);

      -- Payload interface @ pl_clk_i
      pl_clk_i        : in  std_logic; 
      pl_rst_i        : in  std_logic;
      pl_ena_o        : out std_logic;
      pl_sof_o        : out std_logic;
      pl_eof_o        : out std_logic;
      pl_data_o       : out std_logic_vector(7 downto 0);
      pl_afull_i      : in  std_logic;
      pl_ovf_o        : out std_logic;
      pl_err_o        : out std_logic;
      pl_drop_mac_o   : out std_logic;
      pl_drop_ip_o    : out std_logic;
      pl_drop_udp_o   : out std_logic
   );
end decap;

architecture Structural of decap is

   signal mac_fifo_in   : std_logic_vector(15 downto 0);
   signal mac_error     : std_logic;    -- Fifo overflow. TBD

   signal pl_fifo_empty : std_logic;
   signal pl_fifo_rden  : std_logic := '0';
   signal pl_fifo_out   : std_logic_vector(15 downto 0);
   signal pl_fifo_out_sof  : std_logic;
   signal pl_fifo_out_eof  : std_logic;
   signal pl_fifo_out_data : std_logic_vector(7 downto 0);

   signal pl_bytes  : std_logic_vector(15 downto 0);

   type t_fsm_state is (IDLE_ST, MAC_HDR_ST, IP_HDR_ST, UDP_HDR_ST, FWD_ST, DISC_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

   signal pl_ena  : std_logic := '0';
   signal pl_sof  : std_logic;
   signal pl_eof  : std_logic;
   signal pl_data : std_logic_vector(7 downto 0);
   signal pl_ovf  : std_logic;
   signal pl_err  : std_logic;
   signal pl_drop_mac : std_logic;
   signal pl_drop_ip  : std_logic;
   signal pl_drop_udp : std_logic;

   -- Temporary storage. Instead of using a multiplexor.
   signal ctrl_mac_dst : std_logic_vector(47 downto 0);
   signal ctrl_ip_dst  : std_logic_vector(31 downto 0);
   signal ctrl_udp_dst : std_logic_vector(15 downto 0);

begin

   -------------------------
   -- Clock domain mac_clk_i
   -------------------------

   mac_fifo_in(15 downto 10) <= (others => '0');
   mac_fifo_in(9)            <= mac_eof_i;
   mac_fifo_in(8)            <= mac_sof_i;
   mac_fifo_in(7 downto 0)   <= mac_data_i;

   -- Instantiate the data fifo
   -- The data fifo contains the raw MAC frame.
   inst_data_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16
      )
   port map (
      wr_clk_i    => mac_clk_i,
      wr_rst_i    => mac_rst_i,
      wr_en_i     => mac_ena_i,
      wr_data_i   => mac_fifo_in,
      wr_error_o  => mac_error,
      --
      rd_clk_i    => pl_clk_i,
      rd_rst_i    => pl_rst_i,
      rd_empty_o  => pl_fifo_empty,
      rd_en_i     => pl_fifo_rden,
      rd_data_o   => pl_fifo_out,
      rd_error_o  => open
      );


   ------------------------
   -- Clock domain pl_clk_i
   ------------------------


   -- Extract data from input fifo
   pl_fifo_out_eof       <= pl_fifo_out(9);
   pl_fifo_out_sof       <= pl_fifo_out(8);
   pl_fifo_out_data      <= pl_fifo_out(7 downto 0);

   -- Main state machine
   pl_fsm : process (pl_clk_i)
   begin
      if rising_edge(pl_clk_i) then
         pl_ena  <= '0';
         pl_sof  <= '0';
         pl_eof  <= '0';
         pl_data <= (others => '0');
         pl_ovf  <= '0';
         pl_err  <= '0';
         pl_drop_mac  <= '0';
         pl_drop_ip   <= '0';
         pl_drop_udp  <= '0';

         case fsm_state is
            when IDLE_ST =>
               ctrl_mac_dst <= ctrl_mac_dst_i;
               ctrl_ip_dst  <= ctrl_ip_dst_i;
               ctrl_udp_dst <= ctrl_udp_dst_i;

               if pl_fifo_empty = '0' and pl_fifo_out_sof = '1' then
                  pl_bytes  <= (others => '0');
                  fsm_state <= MAC_HDR_ST;
               end if;

            when MAC_HDR_ST =>
               if pl_fifo_rden = '1' then
                  pl_bytes <= pl_bytes + 1;

                  if pl_bytes < 6 then
                     if pl_fifo_out_data /= ctrl_mac_dst(47 downto 40) then
                        pl_drop_mac <= '1';
                        fsm_state   <= DISC_ST;
                     end if;

                     ctrl_mac_dst <= ctrl_mac_dst(39 downto 0) & X"00";
                  end if;

                  if pl_bytes >= 14 then
                     pl_bytes  <= std_logic_vector(to_unsigned(1, 16));
                     fsm_state <= IP_HDR_ST;
                  end if;
               end if;

            when IP_HDR_ST =>
               if pl_fifo_rden = '1' then
                  pl_bytes <= pl_bytes + 1;

                  if pl_bytes >= 16 and pl_bytes < 20 then
                     if pl_fifo_out_data /= ctrl_ip_dst(31 downto 24) then
                        pl_drop_ip <= '1';
                        fsm_state  <= DISC_ST;
                     end if;

                     ctrl_ip_dst <= ctrl_ip_dst(23 downto 0) & X"00";
                  end if;

                  if pl_bytes >= 20 then
                     pl_bytes  <= std_logic_vector(to_unsigned(1, 16));
                     fsm_state <= UDP_HDR_ST;
                  end if;
               end if;

            when UDP_HDR_ST =>
               if pl_fifo_rden = '1' then
                  pl_bytes <= pl_bytes + 1;

                  if pl_bytes >= 2 and pl_bytes < 4 then
                     if pl_fifo_out_data /= ctrl_udp_dst(15 downto 8) then
                        pl_drop_udp <= '1';
                        fsm_state   <= DISC_ST;
                     end if;

                     ctrl_udp_dst <= ctrl_udp_dst(7 downto 0) & X"00";
                  end if;

                  if pl_bytes >= 8 then
                     pl_bytes  <= std_logic_vector(to_unsigned(1, 16));
                     fsm_state <= FWD_ST;
                     pl_ena    <= '1';
                     pl_sof    <= '1';
                     pl_data   <= pl_fifo_out_data;
                  end if;
               end if;

            when FWD_ST =>
               if pl_fifo_rden = '1' then
                  pl_ena   <= '1';
                  pl_data  <= pl_fifo_out_data;
                  if pl_fifo_out_eof = '1' then
                     fsm_state <= IDLE_ST;
                     pl_eof <= '1';
                  end if;
               end if;

            when DISC_ST =>
               if pl_fifo_rden = '1' then
                  if pl_fifo_out_eof = '1' then
                     fsm_state <= IDLE_ST;
                  end if;
               end if;

         end case;

         if pl_rst_i = '1' then
            fsm_state <= IDLE_ST;
         end if;
      end if;
   end process pl_fsm;

   pl_fifo_rden <= '1' when (fsm_state = MAC_HDR_ST or
                             fsm_state = IP_HDR_ST or
                             fsm_state = UDP_HDR_ST or
                             fsm_state = FWD_ST or
                             fsm_state = DISC_ST)
                         and pl_fifo_empty = '0'
                         and pl_afull_i = '0' else '0';

   -- Drive output signals
   pl_ena_o  <= pl_ena;
   pl_sof_o  <= pl_sof;
   pl_eof_o  <= pl_eof;
   pl_data_o <= pl_data;
   pl_ovf_o  <= pl_ovf;
   pl_err_o  <= pl_err;
   pl_drop_mac_o <= pl_drop_mac;
   pl_drop_ip_o  <= pl_drop_ip;
   pl_drop_udp_o <= pl_drop_udp;

end Structural;

