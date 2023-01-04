--------------------------------------------------------------------
-- i2c_clkgen.vhd -- I2C base clock generator
--                   with clock stretching feature
--					 generate 1 pulse every clk_cnt clk cycles, for 1 clk duration
--------------------------------------------------------------------
-- Author  : Cédric Gaudin
-- Version : 0.2 alpha
-- History :
--           20-apr-2002 CG 0.1 Initial alpha release
--           27-apr-2002 CG 0.2 minor cosmetic changes
--------------------------------------------------------------------

library ieee;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

-- Generates a 25MHz clock from a 50MHz source

entity vga_clkgen is
    port(
        signal clk         : in  std_logic; 
        signal rst         : in  std_logic;
        signal clken       : out std_logic
    );

end vga_clkgen;

architecture rtl of vga_clkgen is
    signal r_clk     : std_logic;

begin
    process(clk, rst)
    begin
        if (rst = '1') then
            r_clk <= '0';
        elsif (rising_edge(clk)) then
            r_clk <= not r_clk;
        end if;
    end process;

    clken <= r_clk;
end rtl;
