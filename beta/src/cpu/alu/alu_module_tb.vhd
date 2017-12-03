library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu_module_tb is
end alu_module_tb;

architecture Structural of alu_module_tb is

   signal a     : std_logic_vector(31 downto 0) := (others => '0');
   signal b     : std_logic_vector(31 downto 0) := (others => '0');
   signal alufn : std_logic_vector( 5 downto 0) := (others => '0');
   signal alu   : std_logic_vector(31 downto 0) := (others => '0');

   signal z : std_logic := '0';
   signal v : std_logic := '0';
   signal n : std_logic := '0';

   signal zvn : std_logic_vector(2 downto 0) := "000";

begin

   -- Instantiate the DUT
   i_dut : entity work.alu_module
   port map (
      alufn_i => alufn,
      a_i     => a,
      b_i     => b,
      alu_o   => alu,
      z_o     => z,
      v_o     => v,
      n_o     => n
   );

   zvn <= z & v & n; -- This is just to simplify test writing.

   -- This is the main test
   p_main : process

      procedure verify(
         alufn_t : in std_logic_vector(5 downto 0);
         a_t     : in std_logic_vector(31 downto 0);
         b_t     : in std_logic_vector(31 downto 0);
         exp_t   : in std_logic_vector(31 downto 0);
         zvn_t   : in std_logic_vector(2 downto 0) := "UUU") is
         variable exp : std_logic_vector(31 downto 0);
      begin
         alufn <= alufn_t;
         a     <= a_t;
         b     <= b_t;
         wait for 10 ns;

         assert alu = exp_t;
         if zvn_t /= "UUU" then
            assert zvn = zvn_t;
         end if;
      end procedure verify;

      procedure verify(
         alufn_t : in std_logic_vector(5 downto 0);
         a_t     : in integer;
         b_t     : in integer;
         exp_t   : in integer;
         zvn_t   : in std_logic_vector(2 downto 0) := "UUU") is
         variable a : std_logic_vector(31 downto 0);
         variable b : std_logic_vector(31 downto 0);
         variable exp : std_logic_vector(31 downto 0);
      begin
         if a_t >= 0 then
            a := std_logic_vector(to_unsigned(a_t, 32));
         else
            a := not std_logic_vector(to_unsigned(-a_t-1, 32));
         end if;

         if b_t >= 0 then
            b := std_logic_vector(to_unsigned(b_t, 32));
         else
            b := not std_logic_vector(to_unsigned(-b_t-1, 32));
         end if;

         if exp_t >= 0 then
            exp := std_logic_vector(to_unsigned(exp_t, 32));
         else
            exp := not std_logic_vector(to_unsigned(-exp_t-1, 32));
         end if;

         verify(alufn_t, a, b, exp, zvn_t);
      end procedure verify;

      constant SMALL : integer := -2**31;
      constant BIG   : integer :=  2**31 - 1;

   begin
      report "Testing add";
      verify ("000000",    44,    33,    77, "000");
      verify ("000000",    44,   -33,    11, "000");
      verify ("000000",   -44,    33,   -11, "001");
      verify ("000000",   -44,   -33,   -77, "001");
      verify ("000000",   BIG,     1, SMALL, "011");
      verify ("000000",   BIG,   BIG,    -2, "011");
      verify ("000000", SMALL, SMALL,     0, "110");
      verify ("000000", SMALL,    -1,   BIG, "010");
      verify ("000000",    44,   -44,     0, "100");

      report "Testing subtract";
      verify ("000001",  44,  33,  11, "000");
      verify ("000001",  44, -33,  77, "000");
      verify ("000001", -44,  33, -77, "001");
      verify ("000001", -44, -33, -11, "001");
      verify ("000001",  33,  44, -11, "001");
      verify ("000001",  33, -44,  77, "000");
      verify ("000001", -33,  44, -77, "001");
      verify ("000001", -33, -44,  11, "000");
      verify ("000001",  44,  44,   0, "100");

      report "Testing compare";
      verify ("110011", 33, 44, 0); -- Equal
      verify ("110011", 44, 44, 1); -- Equal
      verify ("110101", 33, 44, 1); -- Less than
      verify ("110101", 44, 44, 0); -- Less than
      verify ("110101", 44, 33, 0); -- Less than

      verify ("110101", SMALL, SMALL,   0); -- Less than
      verify ("110101", SMALL, SMALL+1, 1); -- Less than
      verify ("110101", SMALL,     0,   1); -- Less than
      verify ("110101", SMALL,   BIG,   1); -- Less than
      verify ("110101",     0, SMALL,   0); -- Less than
      verify ("110101",     0,     0,   0); -- Less than
      verify ("110101",     0,     1,   1); -- Less than
      verify ("110101",     0,   BIG,   1); -- Less than
      verify ("110101",   BIG, SMALL,   0); -- Less than
      verify ("110101",   BIG,     0,   0); -- Less than
      verify ("110101",   BIG-1, BIG,   1); -- Less than
      verify ("110101",   BIG,   BIG,   0); -- Less than

      verify ("110111", 33, 44, 1); -- Less than or equal
      verify ("110111", 44, 44, 1); -- Less than or equal
      verify ("110111", 44, 33, 0); -- Less than or equal

      verify ("110111", SMALL, SMALL,   1); -- Less than or equal
      verify ("110111", SMALL, SMALL+1, 1); -- Less than or equal
      verify ("110111", SMALL,     0,   1); -- Less than or equal
      verify ("110111", SMALL,   BIG,   1); -- Less than or equal
      verify ("110111",     0, SMALL,   0); -- Less than or equal
      verify ("110111",     0,     0,   1); -- Less than or equal
      verify ("110111",     0,     1,   1); -- Less than or equal
      verify ("110111",     0,   BIG,   1); -- Less than or equal
      verify ("110111",   BIG, SMALL,   0); -- Less than or equal
      verify ("110111",   BIG,     0,   0); -- Less than or equal
      verify ("110111",   BIG-1, BIG,   1); -- Less than or equal
      verify ("110111",   BIG,   BIG,   1); -- Less than or equal

      report "Testing boole";
      verify ("011000",  X"05AF05AF", X"0055AAFF",  X"000500AF"); -- And
      verify ("011110",  X"05AF05AF", X"0055AAFF",  X"05FFAFFF"); -- Or
      verify ("010110",  X"05AF05AF", X"0055AAFF",  X"05FAAF50"); -- Xor
      verify ("011010",  X"05AF05AF", X"0055AAFF",  X"05AF05AF"); -- A

      report "Testing shift";
      verify ("100000",  X"05AF05AF", X"00000000",  X"05AF05AF"); -- Shift left
      verify ("100000",  X"05AF05AF", X"00000004",  X"5AF05AF0"); -- Shift left
      verify ("100000",  X"05AF05AF", X"00000008",  X"AF05AF00"); -- Shift left
      verify ("100000",  X"05AF05AF", X"0000000C",  X"F05AF000"); -- Shift left
      verify ("100000",  X"05AF05AF", X"0000001C",  X"F0000000"); -- Shift left
      verify ("100001",  X"05AF05AF", X"00000000",  X"05AF05AF"); -- Shift right
      verify ("100001",  X"05AF05AF", X"00000004",  X"005AF05A"); -- Shift right
      verify ("100001",  X"05AF05AF", X"00000008",  X"0005AF05"); -- Shift right
      verify ("100001",  X"05AF05AF", X"0000000C",  X"00005AF0"); -- Shift right
      verify ("100001",  X"FA50FA50", X"00000000",  X"FA50FA50"); -- Shift right
      verify ("100001",  X"FA50FA50", X"00000004",  X"0FA50FA5"); -- Shift right
      verify ("100001",  X"FA50FA50", X"00000008",  X"00FA50FA"); -- Shift right
      verify ("100001",  X"FA50FA50", X"0000000C",  X"000FA50F"); -- Shift right
      verify ("100011",  X"05AF05AF", X"00000000",  X"05AF05AF"); -- Shift right extend
      verify ("100011",  X"05AF05AF", X"00000004",  X"005AF05A"); -- Shift right extend
      verify ("100011",  X"05AF05AF", X"00000008",  X"0005AF05"); -- Shift right extend
      verify ("100011",  X"05AF05AF", X"0000000C",  X"00005AF0"); -- Shift right extend
      verify ("100011",  X"FA50FA50", X"00000000",  X"FA50FA50"); -- Shift right extend
      verify ("100011",  X"FA50FA50", X"00000004",  X"FFA50FA5"); -- Shift right extend
      verify ("100011",  X"FA50FA50", X"00000008",  X"FFFA50FA"); -- Shift right extend
      verify ("100011",  X"FA50FA50", X"0000000C",  X"FFFFA50F"); -- Shift right extend

      report "Testing multiplication";
      verify ("000010",  1,  1,  1);
      verify ("000010",  1,  0,  0);
      verify ("000010",  1, -1, -1);
      verify ("000010",  0,  1,  0);
      verify ("000010",  0,  0,  0);
      verify ("000010",  0, -1,  0);
      verify ("000010", -1,  1, -1);
      verify ("000010", -1,  0,  0);
      verify ("000010", -1, -1,  1);

      wait;
   end process p_main;

end Structural;

