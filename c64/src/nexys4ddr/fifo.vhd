library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity fifo is
   generic (
      G_WIDTH         : natural := 8;
      G_DEPTH         : natural := 4;
      G_AFULL_OFFSET  : natural := 2;
      G_AEMPTY_OFFSET : natural := 2);
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      di_i     : in  std_logic_vector(G_WIDTH-1 downto 0);
      wren_i   : in  std_logic;
      do_o     : out std_logic_vector(G_WIDTH-1 downto 0);
      rden_i   : in  std_logic;
      full_o   : out std_logic;
      afull_o  : out std_logic;
      aempty_o : out std_logic;
      empty_o  : out std_logic;
      fill_o   : out std_logic_vector(G_DEPTH downto 0)  -- filling - +1 wider to support completely full and empty
      );

end entity fifo;

architecture behavioral of fifo is

   type mem_array is array (0 to 2**G_DEPTH-1) of std_logic_vector(G_WIDTH-1 downto 0);
   signal mem     : mem_array := (others => (others => '0'));
   signal wr_ptr  : std_logic_vector(G_DEPTH downto 0) := (others => '0');
   signal rd_ptr  : std_logic_vector(G_DEPTH downto 0) := (others => '0');
   signal fill_r  : std_logic_vector(G_DEPTH downto 0) := (others => '0');
   signal empty_r : std_logic := '1';
   signal wren_d0 : std_logic;

begin  -- architecture behavioral

   empty_o <= empty_r;
   fill_o  <= fill_r;
   do_o    <= mem(conv_integer(rd_ptr(G_DEPTH-1 downto 0)));
   
   fifo_proc : process(clk_i)
   begin
      if rising_edge(clk_i) then

         assert not(rden_i = '1' and empty_r = '1')
            report "reading empty fifo" severity failure;
         assert not(wren_i = '1' and rd_ptr(G_DEPTH-1 downto 0) = wr_ptr(G_DEPTH-1 downto 0) and rd_ptr(depth) /= wr_ptr(depth))
            report "writing full fifo" severity failure;

         if wren_i = '1' then
            -- write data
            mem(conv_integer(wr_ptr(G_DEPTH-1 downto 0))) <= di_i;
         end if;
         
         wren_d0 <= wren_i;
         -- signal empty

         if wren_d0 = '1' and rden_i = '0' then
            fill_r  <= fill_r + 1;
            empty_r <= '0';
         elsif wren_d0 = '0' and rden_i = '1' then
            fill_r <= fill_r - 1;
            if fill_r = 1 then
               empty_r <= '1';
            end if;
         end if;

         -- signal full
         if (rd_ptr = wr_ptr+2**G_DEPTH) or
            (rd_ptr = wr_ptr+2**G_DEPTH+1 and wren = '1' and rden = '0') then
            full_o <= '1';
         else
            full_o <= '0';
         end if;

         -- signal almost full
         if wr_ptr - rd_ptr >= (2**G_DEPTH - (G_AFULL_OFFSET+2)) then
            afull_o <= '1';
         else
            afull_o <= '0';
         end if;

         -- signal almost empty
         if wr_ptr - rd_ptr <= G_AEMPTY_OFFSET then
            aempty_o <= '1';
         else
            aempty_o <= '0';
         end if;
         
         -- update write pointer
         if wren_i = '1' then
            wr_ptr <= wr_ptr + 1;
         end if;

         -- update read pointer
         if rden_i = '1' then
            rd_ptr <= rd_ptr + 1;
         end if;

         if rst_i = '1' then
            wr_ptr  <= (others => '0');
            rd_ptr  <= (others => '0');
            fill_r  <= (others => '0');
            empty_r <= '1';
            full_o  <= '0';
            afull_o <= '0';
            wren_d0 <= '0';
         end if;
      end if;
   end process;

end architecture behavioral;

