--------------------------------------
-- The Control Logic
--
--   rden       <= ctl(0);           -- Read data from memory or I/O
--   wren       <= ctl(1);           -- Write data to memory or I/O
--   alu_func   <= ctl(5 downto 2);  -- ALU function code
--   regs_wren  <= ctl(6);           -- Write to register
--   regs_wrmux <= ctl(8 downto 7);  -- Mux input to register file

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ctl is
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      data_i : in  std_logic_vector( 7 downto 0);
      ctl_o  : out std_logic_vector(10 downto 0)
   );
end ctl;

architecture Structural of ctl is

   signal cnt_r  : std_logic_vector(2 downto 0);
   signal inst_r : std_logic_vector(7 downto 0);

begin

   -- Store the microinstruction counter
   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt_r <= cnt_r + 1;

         if rst_i = '1' then
            cnt_r <= (others => '0');
         end if;
      end if;
   end process p_cnt;

   -- Store the current instruction
   p_inst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cnt_r = 0 then
            inst_r <= data_i;
         end if;
      end if;
   end process p_inst;

   process (cnt_r)
   begin
      ctl_o <= (others => '0');     -- Default value to avoid latch.

      if cnt_r = 0 then
         ctl_o(0) <= '1';              -- rden from memory
         ctl_o(1) <= '0';              -- wren to memory
         ctl_o(5 downto 2) <= "1100";  -- ALU function (NOP)
         ctl_o(6) <= '0';              -- regs_wren
         ctl_o(8 downto 7) <= "00";    -- regs_wrmux
         ctl_o(10 downto 9) <= "00";   -- reg_nr
      end if;

      if cnt_r = 1 then
         ctl_o(0) <= '1';              -- rden from memory
         ctl_o(1) <= '0';              -- wren to memory
         ctl_o(5 downto 2) <= "1100";  -- ALU function (NOP)
         ctl_o(6) <= '1';              -- regs_wren
         ctl_o(8 downto 7) <= "00";    -- regs_wrmux
         ctl_o(10 downto 9) <= "00";   -- reg_nr -> A
      end if;

   end process;

end architecture Structural;

