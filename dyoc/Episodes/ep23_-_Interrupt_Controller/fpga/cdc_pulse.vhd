library ieee;
use ieee.std_logic_1164.all;

-- This module converts a single-clock pulse in the src clock domain to a
-- single-clock pulse in the dst clock domain.
-- Note: The pulse in the src clock domain must only be one clock cycle wide.
-- And there must be several clock cycles between neighbouring pulse.

entity cdc_pulse is
   port (
      src_clk_i   : in  std_logic;
      src_pulse_i : in  std_logic;
      dst_clk_i   : in  std_logic;
      dst_pulse_o : out std_logic
   );
end cdc_pulse;

architecture structural of cdc_pulse is

   signal src_level   : std_logic_vector(0 downto 0) := "0";
   signal dst_level   : std_logic_vector(0 downto 0) := "0";
   signal dst_level_d : std_logic := '0';
   signal dst_pulse   : std_logic := '0';

begin

   ---------------------------------
   -- Convert pulse to level toggle
   ---------------------------------

   src_level_proc : process (src_clk_i)
   begin
      if rising_edge(src_clk_i) then
         if src_pulse_i = '1' then
            src_level(0) <= not src_level(0);
         end if;
      end if;
   end process src_level_proc;


   --------------------------------------
   -- Transfer level to dst clock domain
   --------------------------------------

   cdc_inst : entity work.cdc
   generic map (
      G_WIDTH => 1
   )
   port map (
      src_clk_i  => src_clk_i,
      src_data_i => src_level,
      dst_clk_i  => dst_clk_i,
      dst_data_o => dst_level
   ); -- cdc_inst


   ---------------------------------
   -- Convert level toggle to pulse
   ---------------------------------
   
   dst_pulse_proc : process (dst_clk_i)
   begin
      if rising_edge(dst_clk_i) then
         dst_pulse   <= dst_level(0) xor dst_level_d;
         dst_level_d <= dst_level(0);
      end if;
   end process dst_pulse_proc;


   -----------------------
   -- Drive output signal
   -----------------------

   dst_pulse_o <= dst_pulse;

end architecture structural;

