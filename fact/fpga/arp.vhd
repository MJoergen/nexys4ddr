library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module filters for incoming ARP request for our specific IP address
-- and responds with a corresponding ARP reply.

entity arp is
   generic (
      G_MAC       : std_logic_vector(47 downto 0);
      G_IP        : std_logic_vector(31 downto 0)
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;

      -- Receive interface
      rx_valid_i  : in  std_logic;
      rx_sof_i    : in  std_logic;
      rx_eof_i    : in  std_logic;
      rx_data_i   : in  std_logic_vector(7 downto 0);

      -- Transmit interface
      tx_valid_o  : out std_logic;
      tx_sof_o    : out std_logic;
      tx_eof_o    : out std_logic;
      tx_data_o   : out std_logic_vector(7 downto 0)
   );
end arp;

architecture Structural of arp is

   constant C_ARP_SIZE : integer := 14 + 28; -- MAC + ARP

   signal hdr_valid_s : std_logic;
   signal hdr_data_s  : std_logic_vector(C_ARP_SIZE*8-1 downto 0);
   signal hdr_size_s  : std_logic_vector(7 downto 0);

   signal pl_valid_r  : std_logic;
   signal pl_data_r   : std_logic_vector(C_ARP_SIZE*8-1 downto 0);

begin

   i_ser2par : entity work.ser2par
      generic map (
         G_HDR_SIZE => C_ARP_SIZE
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         rx_valid_i  => rx_valid_i,
         rx_sof_i    => rx_sof_i,
         rx_eof_i    => rx_eof_i,
         rx_data_i   => rx_data_i,
         hdr_valid_o => hdr_valid_s,
         hdr_data_o  => hdr_data_s,
         hdr_size_o  => hdr_size_s,
         hdr_more_o  => open,             -- Ignore any extra data bytes
         pl_valid_o  => open, 
         pl_sof_o    => open, 
         pl_eof_o    => open, 
         pl_data_o   => open 
      ); -- ser2par

   p_check : process (clk_i)
      variable sha_v : std_logic_vector(47 downto 0);
      variable spa_v : std_logic_vector(31 downto 0);
   begin
      if rising_edge(clk_i) then
         pl_valid_r <= '0';

         if hdr_valid_s = '1' then
            if hdr_size_s = C_ARP_SIZE then
               if hdr_data_s(29*8+7 downto 20*8) = X"08060001080006040001" then
                  sha_v := hdr_data_s(19*8+7 downto 14*8);
                  spa_v := hdr_data_s(13*8+7 downto 10*8);
                  pl_data_r  <= sha_v & G_MAC & X"0806" &
                                X"0001080006040002" &
                                G_MAC & G_IP & sha_v & spa_v;
                  pl_valid_r <= '1';
               end if;
            end if;
         end if;
      end if;
   end process p_check;

   i_par2ser : entity work.par2ser
      generic map (
         G_PL_SIZE => C_ARP_SIZE
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         pl_valid_i  => pl_valid_r,
         pl_data_i   => pl_data_r,
         tx_valid_o  => tx_valid_o,
         tx_sof_o    => tx_sof_o,
         tx_eof_o    => tx_eof_o,
         tx_data_o   => tx_data_o
      ); -- par2ser

end Structural;

