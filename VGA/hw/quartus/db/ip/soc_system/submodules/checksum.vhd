library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity checksum is
    port(
        decoded       : in    std_logic_vector(31 downto 0);
        encoded       : out   std_logic_vector(31 downto 0);
        valid         : out   std_logic
    );

end checksum;

architecture rtl of checksum is
    signal w_decoded : std_logic_vector(31 downto 0);
    signal w_encoded : std_logic_vector(31 downto 0);
begin

    compute_checksum: process(w_decoded)
        variable count : unsigned(1 downto 0) := "00";
    begin
        count := "00";
        for i in 0 to 29 loop
            count := count + ("0" & w_decoded(i));
        end loop;

        w_encoded(29 downto 0) <= w_decoded(29 downto 0);
        w_encoded(31 downto 30) <= std_logic_vector(count);
    end process compute_checksum;

    w_decoded <= decoded(7 downto 0) & decoded(15 downto 8) & decoded(23 downto 16) & decoded(31 downto 24);
    encoded <= w_encoded(7 downto 0) & w_encoded(15 downto 8) & w_encoded(23 downto 16) & w_encoded(31 downto 24);
    --w_decoded <= decoded;
    --encoded <= w_encoded;

    valid <= '1' when w_encoded = w_decoded else '0';

end rtl;
