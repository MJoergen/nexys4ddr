library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ctl is
   port (
      rstn_i  : in  std_logic;
      id_i    : in  std_logic_vector(5 downto 0);
      rasel_o : out std_logic;
      bsel_o  : out std_logic;
      alufn_o : out std_logic_vector(5 downto 0);
      wdsel_o : out std_logic_vector(1 downto 0);
      werf_o  : out std_logic;
      moe_o   : out std_logic;
      wr_o    : out std_logic
   );
end ctl;

architecture Structural of ctl is

   type MEM_TYPE is array (0 to 63) of std_logic_vector(12 downto 0);
   signal ctl_mem : MEM_TYPE := (
      -- 000xxx
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved

      -- 001xxx
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved

      -- 010xxx
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved
      "0000000000000",  -- Reserved

      -- 011xxx
      "0000000000000",  -- LD
      "0000000000000",  -- ST
      "0000000000000",  -- Reserved
      "0000000000000",  -- JMP
      "0000000000000",  -- Reserved
      "0000000000000",  -- BEQ
      "0000000000000",  -- BNE
      "0000000000000",  -- LDR

      -- 100xxx
      "0000000000000",  -- ADD
      "0000000000000",  -- SUB
      "0000000000000",  -- MUL
      "0000000000000",  -- Reserved
      "0000000000000",  -- CMPEQ
      "0000000000000",  -- CMPLT
      "0000000000000",  -- CMPLE
      "0000000000000",  -- Reserved

      -- 101xxx
      "0000000000000",  -- AND
      "0000000000000",  -- OR
      "0000000000000",  -- XOR
      "0000000000000",  -- Reserved
      "0000000000000",  -- SHL
      "0000000000000",  -- SHR
      "0000000000000",  -- SRA
      "0000000000000",  -- Reserved

      -- 110xxx
      "0000000000000",  -- ADDC
      "0000000000000",  -- SUBC
      "0000000000000",  -- MULC
      "0000000000000",  -- Reserved
      "0000000000000",  -- CMPEQC
      "0000000000000",  -- CMPLTC
      "0000000000000",  -- CMPLEC
      "0000000000000",  -- Reserved

      -- 111xxx
      "0000000000000",  -- ANDC
      "0000000000000",  -- ORC
      "0000000000000",  -- XORC
      "0000000000000",  -- Reserved
      "0000000000000",  -- SHLC
      "0000000000000",  -- SHRC
      "0000000000000",  -- SRAC
      "0000000000000"); -- Reserved

   signal res : std_logic_vector(12 downto 0);

begin

   p_res : process (id_i, rstn_i)
   begin
      res <= ctl_mem(conv_integer(id_i));
      if rstn_i = '0' then
         res <= (others => '0');
      end if;
   end process p_res;

   rasel_o <= res(12);
   bsel_o  <= res(11);
   alufn_o <= res(10 downto 5);
   wdsel_o <= res(4 downto 3);
   werf_o  <= res(2);
   moe_o   <= res(1);
   wr_o    <= res(0);

end Structural;

