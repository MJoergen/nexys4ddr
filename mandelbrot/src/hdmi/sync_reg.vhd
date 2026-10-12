--------------------------------------------------------------------------------
-- sync_reg.vhd                                                               --
-- Synchronising register(s) for clock domain crossing.                       --
--------------------------------------------------------------------------------
-- (C) Copyright 2022 Adam Barnes <ambarnes@gmail.com>                        --
-- This file is part of The Tyto Project. The Tyto Project is free software:  --
-- you can redistribute it and/or modify it under the terms of the GNU Lesser --
-- General Public License as published by the Free Software Foundation,       --
-- either version 3 of the License, or (at your option) any later version.    --
-- The Tyto Project is distributed in the hope that it will be useful, but    --
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public     --
-- License for more details. You should have received a copy of the GNU       --
-- Lesser General Public License along with The Tyto Project. If not, see     --
-- https://www.gnu.org/licenses/.                                             --
--------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

package sync_reg_pkg is

  component sync_reg is
    generic (
      width     : integer := 1;
      depth     : integer := 2;
      rst_state : std_logic := '0'
    );
    port (
      rst   : in    std_logic := '0';
      clk   : in    std_logic;
      d     : in    std_logic_vector(width-1 downto 0);
      q     : out   std_logic_vector(width-1 downto 0)
    );
  end component sync_reg;

end package sync_reg_pkg;

-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

entity sync_reg is
  generic (
    width     : integer := 1;
    depth     : integer := 2;
    rst_state : std_logic := '0'
  );
  port (
    rst   : in    std_logic := '0';
    clk   : in    std_logic;                          -- destination clock
    d     : in    std_logic_vector(width-1 downto 0); -- input
    q     : out   std_logic_vector(width-1 downto 0)  -- output
  );
end entity sync_reg;

architecture structural of sync_reg is

  subtype reg_level_t is std_logic_vector(width-1 downto 0);
  type    reg_t is array(0 to depth-1) of reg_level_t;

  signal  reg : reg_t;

  attribute async_reg : string;
  attribute async_reg of reg : signal is "TRUE";

begin

  MAIN: process (rst,clk) is
  begin
    if rst = '1' then
      reg <= (others => (others => rst_state));
    elsif rising_edge(clk) then
      for i in 0 to depth-1 loop
        if i = 0 then
          reg(i) <= d;
        else
          reg(i) <= reg(i-1);
        end if;
      end loop;
    end if;
  end process MAIN;

  q <= reg(depth-1);

end architecture structural;
