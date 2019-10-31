library ieee;
use ieee.std_logic_1164.all;

-- This block handles all the configuration settings of the VERA,
-- i.e. everything other than the Video RAM and the palette RAM.
--
-- TBD: Currently, only MAP and TILE area base addressess are supported.

entity config is
   port (
      clk_i       : in  std_logic;
      addr_i      : in  std_logic_vector(19 downto 0);
      wr_en_i     : in  std_logic;
      wr_data_i   : in  std_logic_vector( 7 downto 0);
      rd_en_i     : in  std_logic;
      rd_data_o   : out std_logic_vector( 7 downto 0);

      map_base_o  : out std_logic_vector(17 downto 0);
      tile_base_o : out std_logic_vector(17 downto 0)
   );
end config;

architecture structural of config is

begin

   p_config : process (clk_i)
   begin
      if falling_edge(clk_i) then
         map_base_o( 1 downto 0) <= "00";
         tile_base_o(1 downto 0) <= "00";

         if wr_en_i = '1' then
            case addr_i(19 downto 12) is
               when X"F0" => null;                                               -- Display composer
               when X"F2" => null;                                               -- Layer 0
               when X"F3" =>                                                     -- Layer 1
                  case addr_i is  
                     when X"F3002" => map_base_o(  9 downto  2) <= wr_data_i;    -- L1_MAP_BASE_L
                     when X"F3003" => map_base_o( 17 downto 10) <= wr_data_i;    -- L1_MAP_BASE_H
                     when X"F3004" => tile_base_o( 9 downto  2) <= wr_data_i;    -- L1_TILE_BASE_L
                     when X"F3005" => tile_base_o(17 downto 10) <= wr_data_i;    -- L1_TILE_BASE_H
                     when others => null;
                  end case;
               when X"F4" => null;                                               -- Sprite
               when X"F5" => null;                                               -- Sprite attributes
               when X"F6" => null;                                               -- Audio
               when X"F7" => null;                                               -- SPI
               when X"F8" => null;                                               -- UART
               when others => null;
            end case;
         end if; -- if wr_en_i = '1' then

         if rd_en_i = '1' then
            case addr_i(19 downto 12) is
               when X"F3" =>                                                     -- Layer 1
                  case addr_i is                                     
                     when X"F3002" => rd_data_o <= map_base_o(  9 downto  2);
                     when X"F3003" => rd_data_o <= map_base_o( 17 downto 10);
                     when X"F3004" => rd_data_o <= tile_base_o( 9 downto  2);
                     when X"F3005" => rd_data_o <= tile_base_o(17 downto 10);
                     when others => null;
                  end case;
               when others => null;
            end case;
         end if; -- if rd_en_i = '1' then
      end if;
   end process p_config;

end architecture structural;

