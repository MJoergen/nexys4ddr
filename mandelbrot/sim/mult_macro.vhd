library ieee;
use ieee.std_logic_1164.all;

-- This is a simulation model of the Xilinx unimacro MULT_MACRO. The Xilinx
-- source for it does not compile in GHDL, because it instantiates primitives
-- that have been removed from the unisim library.
--
-- This model is compiled into the library "unimacro", so the design can use it
-- in the same way as the Xilinx version:
--
--   library unimacro;
--   use unimacro.vcomponents.all;
--
-- Only a signed multiplier with LATENCY = 1 is modelled, i.e. the product is
-- registered once. This corresponds to DEVICE = "7SERIES".

package vcomponents is

   component mult_macro
      generic (
         DEVICE  : string  := "VIRTEX5";
         LATENCY : integer := 3;
         WIDTH_A : integer := 18;
         WIDTH_B : integer := 18
      );
      port (
         P   : out std_logic_vector(WIDTH_A+WIDTH_B-1 downto 0);
         A   : in  std_logic_vector(WIDTH_A-1 downto 0);
         B   : in  std_logic_vector(WIDTH_B-1 downto 0);
         CE  : in  std_logic;
         CLK : in  std_logic;
         RST : in  std_logic
      );
   end component mult_macro;

end package vcomponents;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult_macro is
   generic (
      DEVICE  : string  := "VIRTEX5";
      LATENCY : integer := 3;
      WIDTH_A : integer := 18;
      WIDTH_B : integer := 18
   );
   port (
      P   : out std_logic_vector(WIDTH_A+WIDTH_B-1 downto 0);
      A   : in  std_logic_vector(WIDTH_A-1 downto 0);
      B   : in  std_logic_vector(WIDTH_B-1 downto 0);
      CE  : in  std_logic;
      CLK : in  std_logic;
      RST : in  std_logic
   );
end entity mult_macro;

architecture sim of mult_macro is

begin

   assert LATENCY = 1
      report "This model of mult_macro only supports LATENCY = 1"
      severity failure;

   p_mult : process (CLK)
   begin
      if rising_edge(CLK) then
         if CE = '1' then
            P <= std_logic_vector(signed(A) * signed(B));
         end if;

         if RST = '1' then
            P <= (others => '0');
         end if;
      end if;
   end process p_mult;

end architecture sim;
