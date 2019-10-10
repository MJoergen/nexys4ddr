library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the top level module. The ports on this entity
-- are mapped directly to pins on the FPGA.

-- In this version the design can generate a checker board
-- pattern on the VGA output.

entity move is
   generic (
      G_SIZE   : integer;
      G_STARTX : std_logic_vector(G_SIZE-1 downto 0);
      G_STARTY : std_logic_vector(G_SIZE-1 downto 0)
   );
   port (
      clk_i  : in  std_logic;                      -- 100 MHz
      move_i : in  std_logic;
      x_o    : out std_logic_vector(9 downto 0);
      y_o    : out std_logic_vector(9 downto 0)
   );
end move;

architecture structural of move is

   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Position and movement of first Voronoi point
   signal x_r    : std_logic_vector(9 downto 0) := G_STARTX;
   signal y_r    : std_logic_vector(9 downto 0) := G_STARTY;
   signal dirx_r : std_logic_vector(9 downto 0) := to_stdlogicvector(1, 10);
   signal diry_r : std_logic_vector(9 downto 0) := to_stdlogicvector(1, 10);

begin

   p_move : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if move_i = '1' then
            x_r <= x_r + dirx_r;
            y_r <= y_r + diry_r;

            if x_r > H_PIXELS-5 and dirx_r(dirx_r'left) = '0' then
               dirx_r <= (others => '1'); -- -1
            end if;

            if x_r < 5 and dirx_r(dirx_r'left) = '1' then
               dirx_r <= to_stdlogicvector(1, 10);
            end if;

            if y_r > V_PIXELS-5 and diry_r(diry_r'left) = '0' then
               diry_r <= (others => '1'); -- -1
            end if;

            if y_r < 5 and diry_r(diry_r'left) = '1' then
               diry_r <= to_stdlogicvector(1, 10);
            end if;
         end if;
      end if;
   end process p_move;

   x_o <= x_r;
   y_o <= y_r;

end architecture structural;

