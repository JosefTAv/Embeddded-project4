library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
        if rst = '1' then
            r_clk <= '0';
        elsif rising_edge(clk) then
            r_clk <= not r_clk;
        end if;
    end process;

    clken <= r_clk;
end rtl;
