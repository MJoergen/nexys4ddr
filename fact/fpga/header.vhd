library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module extracts the first (up to) 60 bytes of an incoming Ethernet frame
-- and forwards them as a separate sideband.
-- The remaining data is forwarded subsequently.

entity header is
   generic
      G_HDR_SIZE  : integer := 60    -- Default corresponding to minimum sized frame
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;

      -- Receive interface
      rx_ena_i    : in  std_logic;
      rx_sof_i    : in  std_logic;
      rx_eof_i    : in  std_logic;
      rx_data_i   : in  std_logic_vector(7 downto 0);

      -- Header output
      hdr_data_o  : out std_logic_vector(G_HDR_SIZE*8-1 downto 0);
      hdr_size_o  : out std_logic_vector(7 downto 0);
      hdr_valid_o : out std_logic;

      -- Payload output
      pl_valid_o  : out std_logic;
      pl_sof_o    : out std_logic;
      pl_eof_o    : out std_logic;
      pl_data_o   : out std_logic_vector(7 downto 0)
   );
end header;

architecture Structural of header is

   type t_state is (IDLE_ST, FRM_ST, END_ST);
   signal state_r : t_fsm_state := IDLE_ST;

   signal hdr_data_r  : std_logic_vector(G_HDR_SIZE*8-1 downto 0);
   signal hdr_size_r  : std_logic_vector(7 downto 0);
   signal hdr_valid_r : std_logic;

   signal pl_valid_r  : std_logic;
   signal pl_sof_r    : std_logic;
   signal pl_eof_r    : std_logic;
   signal pl_data_r   : std_logic_vector(7 downto 0)

begin

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         valid_r <= '0';

         case state_r is
            when IDLE_ST :
               if rx_ena_i = '1' and rx_sof_i = '1' then
                  header_r <= header_r(C_HEADER_SIZE*8-9 downto 0) & rx_data_i;
                  bytes_r  <= (others => '0');
                  state_r  <= FRM_ST;
               end if;

            when FRM_ST :
               if rx_ena_i = '1' then
                  header_r <= header_r(C_HEADER_SIZE*8-9 downto 0) & rx_data_i;
                  if bytes >= C_HEADER_SIZE then
                     state_r <= END_ST;
                  end if;
                  bytes <= bytes + 1;

                  if rx_eof_i = '1' then
                     state_r <= IDLE_ST;
                  end if;
               end if;

            when END_ST :
               if rx_ena_i = '1' and rx_eof_i = '1' then
                  if header_r(29*8+7 downto 20*8) = X"08060001080006040001" then
                     valid_r <= '1';
                  end if;
                  bytes   <= (others => '0');
                  state_r <= IDLE_ST;
               end if;
               
         end case;

         if rst_i = '1' then
            bytes_r <= (others => '0');
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   -- Connnect output signals
   hdr_data_o  <= hdr_data_r;
   hdr_size_o  <= hdr_size_r;
   hdr_valid_o <= hdr_valid_r;

   pl_valid_o  <= pl_valid_r;
   pl_sof_o    <= pl_sof_r;
   pl_eof_o    <= pl_eof_r;
   pl_data_o   <= pl_data_r;

end Structural;

