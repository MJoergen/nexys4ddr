library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simple test bench for the compression module

entity compress_tb is
end compress_tb;

architecture Structural of compress_tb is

   signal clk       : std_logic;
   signal rst       : std_logic;
   signal in_ena    : std_logic;
   signal in_sof    : std_logic;
   signal in_eof    : std_logic;
   signal in_data   : std_logic_vector(7 downto 0);
   signal out_ena   : std_logic;
   signal out_sof   : std_logic;
   signal out_eof   : std_logic;
   signal out_data  : std_logic_vector(7 downto 0);

   signal test_running : boolean := true;

   type t_dat is array (natural range <>) of std_logic_vector(11 downto 0);
   -- Bit 8 is SOF, bit 9 is EOF.
   constant dat_in : t_dat := (
      X"187", X"087", X"287",
      X"187", X"087", X"078", X"278",
      X"387",
      X"187", X"287",
      X"187", X"278",
      X"187", X"087", X"278",
      X"187", X"078", X"278");

   constant dat_out : t_dat := (
      X"187", X"202",
      X"187", X"001", X"078", X"201",
      X"187", X"200",
      X"187", X"201",
      X"187", X"000", X"078", X"200",
      X"187", X"001", X"078", X"200",
      X"187", X"000", X"078", X"201");

   signal idx_in   : integer := 0;
   signal idx_out  : integer := 0;
   signal rst_done : std_logic;
   signal idle     : std_logic;

begin

   -- Generate clock
   proc_clk : process
   begin
     if not test_running then
       wait;
     end if;

     clk <= '1', '0' after 5 ns; -- 100 MHz
     wait for 10 ns;
   end process proc_clk;


   -- Generate reset
   rst      <= '1', '0' after 100 ns;
   rst_done <= '0', '1' after 200 ns;


   -- Generate input data
   proc_in : process (clk)
   begin
      if rising_edge(clk) then
         if idle = '1' then
            in_ena <= '0';
            in_sof <= '0';
            in_eof <= '0';

            if idx_in <= dat_in'right then
               idle <= '0';
            end if;
         else
            if dat_in(idx_in)(9) = '1' then
               idle <= '1';
            end if;

            in_ena  <= '1';
            in_sof  <= dat_in(idx_in)(8);
            in_eof  <= dat_in(idx_in)(9);
            in_data <= dat_in(idx_in)(7 downto 0);
            idx_in     <= idx_in + 1;
         end if;

         if rst_done = '0' then
            in_ena <= '0';
            in_sof <= '0';
            in_eof <= '0';
            idx_in    <= 0;
            idle   <= '0';
         end if;
      end if;
   end process proc_in;


   -- Verify output data
   proc_out : process (clk)
   begin
      if rising_edge(clk) then
         if out_ena = '1' then
            assert out_sof  = dat_out(idx_out)(8);
            assert out_eof  = dat_out(idx_out)(9);
            assert out_data = dat_out(idx_out)(7 downto 0);
            idx_out <= idx_out + 1;
         end if;
      end if;
   end process proc_out;


   -- Instantiate DUT
   inst_compress : entity work.compress
   port map (
      clk_i       => clk,
      rst_i       => rst,
      in_ena_i    => in_ena,
      in_sof_i    => in_sof,
      in_eof_i    => in_eof,
      in_data_i   => in_data,
      out_ena_o   => out_ena,
      out_sof_o   => out_sof,
      out_eof_o   => out_eof,
      out_data_o  => out_data  
   );

end Structural;

