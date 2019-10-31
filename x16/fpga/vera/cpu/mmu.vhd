library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block translates between the CPU memory map and the internal memory map.
--
-- External memory map (8 bytes visible to the CPU):
-- 0 : VERA_ADDR_LO
-- 1 : VERA_ADDR_MID
-- 2 : VERA_ADDR_HI
-- 3 : VERA_DATA0
-- 4 : VERA_DATA1
-- 5 : VERA_CTRL
-- 6 : VERA_IEN
-- 7 : VERA_ISR
-- 
-- Internal memory map:
-- 0x00000 - 0x1FFFF : Video RAM
-- 0x20000 - 0xEFFFF : Reserved
-- 0xF0000 - 0xF001F : Display composer
-- 0xF1000 - 0xF11FF : Palette
-- 0xF2000 - 0xF200F : Layer 1
-- 0xF3000 - 0xF300F : Layer 2
-- 0xF4000 - 0xF400F : Sprite registers
-- 0xF5000 - 0xF53FF : Sprite attributes
-- 0xF6000 - 0xF6FFF : Reserved for audio
-- 0xF7000 - 0xF7001 : SPI
-- 0xF8000 - 0xFFFFF : Reserved

entity mmu is
   port (
      clk_i          : in  std_logic;
      -- External memory map
      cpu_addr_i     : in  std_logic_vector( 2 downto 0);
      cpu_wr_en_i    : in  std_logic;
      cpu_wr_data_i  : in  std_logic_vector( 7 downto 0);
      cpu_rd_en_i    : in  std_logic;
      cpu_rd_data_o  : out std_logic_vector( 7 downto 0);
      -- Internal memory map
      vera_addr_o    : out std_logic_vector(19 downto 0);
      vera_wr_en_o   : out std_logic;
      vera_wr_data_o : out std_logic_vector( 7 downto 0);
      vera_rd_en_o   : out std_logic;
      vera_rd_data_i : in  std_logic_vector( 7 downto 0)
   );
end mmu;

architecture structural of mmu is

   signal address0_r    : std_logic_vector(23 downto 0); -- Port 0 (address and increment)
   signal address1_r    : std_logic_vector(23 downto 0); -- Port 1 (address and increment)
   signal addr_sel_r    : std_logic := '0';              -- Default port 0
   signal vera_rd_en_d  : std_logic;
   signal mmu_rd_data_r : std_logic_vector( 7 downto 0);

   -- Convert the 4-bit increment setting to a 20-bit increment value.
   function get_increment(arg : std_logic_vector) return std_logic_vector is
      variable idx : integer range 0 to 15;
      variable res : std_logic_vector(19 downto 0) := (others => '0');
   begin
      idx := to_integer(arg);
      if idx > 0 then
         res(idx-1) := '1';
      end if;
      return res;
   end function get_increment;

begin

   --------------------------
   -- Read and write process
   --------------------------

   p_read_write : process (clk_i)
   begin
      if falling_edge(clk_i) then
         mmu_rd_data_r <= (others => '0');
         if cpu_wr_en_i = '1' then
            case cpu_addr_i is
               when "000" => if addr_sel_r = '0' then                               -- VERA_ADDR_LO
                                address0_r( 7 downto  0) <= cpu_wr_data_i;
                             else
                                address1_r( 7 downto  0) <= cpu_wr_data_i;
                             end if;

               when "001" => if addr_sel_r = '0' then                               -- VERA_ADDR_MID
                                address0_r(15 downto  8) <= cpu_wr_data_i;
                             else
                                address1_r(15 downto  8) <= cpu_wr_data_i;
                             end if;

               when "010" => if addr_sel_r = '0' then                               -- VERA_ADDR_HI
                                address0_r(23 downto 16) <= cpu_wr_data_i;
                             else
                                address1_r(23 downto 16) <= cpu_wr_data_i;
                             end if;

               when "011" => address0_r(19 downto 0) <= address0_r(19 downto  0) +  -- VERA_ADDR_DATA0
                                          get_increment(address0_r(23 downto 20));

               when "100" => address1_r(19 downto 0) <= address1_r(19 downto  0) +  -- VERA_ADDR_DATA1
                                          get_increment(address1_r(23 downto 20));

               when "101" => addr_sel_r <= cpu_wr_data_i(0);                        -- VERA_ADDR_CTRL
               
               when "110" => null;                                                  -- VERA_IEN

               when "111" => null;                                                  -- VERA_ISR

               when others => null;
            end case;
         end if; -- if cpu_wr_en_i = '1' then

         if cpu_rd_en_i = '1' then
            case cpu_addr_i is
               when "000" => if addr_sel_r = '0' then                               -- VERA_ADDR_LO
                                mmu_rd_data_r <= address0_r( 7 downto  0);
                             else
                                mmu_rd_data_r <= address1_r( 7 downto  0);
                             end if;

               when "001" => if addr_sel_r = '0' then                               -- VERA_ADDR_MID
                                mmu_rd_data_r <= address0_r(15 downto  8);
                             else
                                mmu_rd_data_r <= address1_r(15 downto  8);
                             end if;

               when "010" => if addr_sel_r = '0' then                               -- VERA_ADDR_HI
                                mmu_rd_data_r <= address0_r(23 downto 16);
                             else
                                mmu_rd_data_r <= address1_r(23 downto 16);
                             end if;

               when "011" => address0_r(19 downto 0) <= address0_r(19 downto  0) +  -- VERA_ADDR_DATA0
                                          get_increment(address0_r(23 downto 20));

               when "100" => address1_r(19 downto 0) <= address1_r(19 downto  0) +  -- VERA_ADDR_DATA1
                                          get_increment(address1_r(23 downto 20));

               when "101" => mmu_rd_data_r <= "0000000" & addr_sel_r;               -- VERA_ADDR_CTRL
               
               when "110" => null;                                                  -- VERA_IEN

               when "111" => null;                                                  -- VERA_ISR

               when others => null;
            end case;
         end if; -- if cpu_rd_en_i = '1' then

         vera_rd_en_d <= vera_rd_en_o;
      end if;
   end process p_read_write;


   vera_addr_o    <= address0_r(19 downto 0) when cpu_addr_i = "011" else
                     address1_r(19 downto 0) when cpu_addr_i = "100" else
                     (others => '0');
   vera_wr_data_o <= cpu_wr_data_i;
   vera_wr_en_o   <= cpu_wr_en_i when cpu_addr_i = "011" or cpu_addr_i = "100" else
                     '0';
   vera_rd_en_o   <= cpu_rd_en_i when cpu_addr_i = "011" or cpu_addr_i = "100" else
                     '0';

   cpu_rd_data_o  <= vera_rd_data_i when vera_rd_en_d = '1' else
                     mmu_rd_data_r;
                   
end architecture structural;

