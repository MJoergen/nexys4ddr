library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module controls the movement of a single Voronoi point.
-- The generics control the initial position and the velocity.
--
-- To achieve smooth motion, the module operates internally
-- with fixed-point 10.3 arithmetic, i.e. 10 integer bits
-- and 3 fractional bits.
-- The velocity is given in 1.3 fixed point two's complement arithmetic.
-- This means in particular the following example values:
-- "0000" -> 0.0
-- "0100" -> 0.5
-- "1000" -> -1.0
-- "1100" -> -0.5


entity move is
   generic (
      G_SIZE   : integer
   );
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      startx_i : in  std_logic_vector(G_SIZE-1 downto 0);
      starty_i : in  std_logic_vector(G_SIZE-1 downto 0);
      velx_i   : in  std_logic_vector(3 downto 0);
      vely_i   : in  std_logic_vector(3 downto 0);
      move_i   : in  std_logic;
      x_o      : out std_logic_vector(9 downto 0);
      y_o      : out std_logic_vector(9 downto 0)
   );
end move;

architecture structural of move is

   -- This function performs a sign extension from 1.3 to 10.3 fixed point
   -- two's complement values.
   function sign_extend(arg : std_logic_vector(3 downto 0)) return std_logic_vector is
      variable res : std_logic_vector(G_SIZE+2 downto 0);
   begin
      res := (others => arg(3));
      res(3 downto 0) := arg;
      return res;
   end function sign_extend;

   constant C_HPIXELS : integer := 640;
   constant C_VPIXELS : integer := 480;

   -- Position and movement of first Voronoi point
   signal x_r      : std_logic_vector(G_SIZE+2 downto 0);
   signal y_r      : std_logic_vector(G_SIZE+2 downto 0);
   signal velx_r   : std_logic_vector(G_SIZE+2 downto 0);
   signal vely_r   : std_logic_vector(G_SIZE+2 downto 0);
   constant C_ZERO : std_logic_vector(G_SIZE+2 downto 0) := (others => '0');

begin

   p_move : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if move_i = '1' then
            x_r <= x_r + velx_r;
            y_r <= y_r + vely_r;

            if x_r(G_SIZE+2 downto 3) > C_HPIXELS-5 and velx_r(velx_r'left) = '0' then
               velx_r <= C_ZERO-velx_r;
            end if;

            if x_r(G_SIZE+2 downto 3) < 5 and velx_r(velx_r'left) = '1' then
               velx_r <= C_ZERO-velx_r;
            end if;

            if y_r(G_SIZE+2 downto 3) > C_VPIXELS-5 and vely_r(vely_r'left) = '0' then
               vely_r <= C_ZERO-vely_r;
            end if;

            if y_r(G_SIZE+2 downto 3) < 5 and vely_r(vely_r'left) = '1' then
               vely_r <= C_ZERO-vely_r;
            end if;
         end if;

         if rst_i = '1' then
            x_r    <= startx_i & "000";
            y_r    <= starty_i & "000";
            velx_r <= sign_extend(velx_i);
            vely_r <= sign_extend(vely_i);
         end if;
      end if;
   end process p_move;

   -- Remove the three LSB.
   x_o <= x_r(G_SIZE+2 downto 3);
   y_o <= y_r(G_SIZE+2 downto 3);

end architecture structural;

