library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_checksum is
end tb_checksum;

architecture tb of tb_checksum is
    component checksum
    port(
        decoded       : in    std_logic_vector(31 downto 0);
        encoded       : out   std_logic_vector(31 downto 0);
        valid         : out   std_logic
    );
    end component;

    -- 50 MHz -> 20 ns period. Duty cycle = 1/2.
    constant CLK_PERIOD      : time := 20 ns;
    constant CLK_HIGH_PERIOD : time := 10 ns;
    constant CLK_LOW_PERIOD  : time := 10 ns;

    signal clk   : std_logic;
    signal rst   : std_logic;

    signal sim_finished : boolean := false;
 
    signal w_in    : std_logic_vector(31 downto 0);
    signal w_out   : std_logic_vector(31 downto 0);
    signal w_valid : std_logic;

begin
    clk_generation : process
    begin
        if not sim_finished then
            clk <= '1';
            wait for CLK_HIGH_PERIOD;
            clk <= '0';
            wait for CLK_LOW_PERIOD;
        else
            wait;
        end if;
    end process clk_generation;

    checksum_inst : component checksum
        port map(
            decoded => w_in,
            encoded => w_out,
            valid   => w_valid
        );

    sim : process
        procedure async_reset is
        begin
            wait until rising_edge(clk);
            wait for CLK_PERIOD / 4;
            rst <= '1';

            wait for CLK_PERIOD / 2;
            rst <= '0';
        end procedure async_reset;

    begin
        async_reset;

        --w_in <= x"FCF3CF3F";
        w_in <= x"40010594";

        wait for CLK_PERIOD / 2;

        assert w_valid = '1';

        sim_finished <= true;

        wait;
    end process sim;

end architecture tb;
