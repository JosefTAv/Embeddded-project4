library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_vga_core is
    generic(
        INIT_HBP   : integer := 48;
        INIT_HFP   : integer := 16;
        INIT_VBP   : integer := 33;
        INIT_VFP   : integer := 10;
        INIT_HDATA : integer := 640;
        INIT_VDATA : integer := 480;
        INIT_HSYNC : integer := 96;
        INIT_VSYNC : integer := 2;
        INIT_HLEN  : integer := 800;
        INIT_VLEN  : integer := 525
    );
end tb_vga_core;

architecture tb of tb_vga_core is
    component vga_core
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Clock signal
        i_clken     : in  std_logic;

        -- Memory signals
        o_req       : out std_logic;
        i_next      : in  std_logic_vector(31 downto 0);

        -- Event signals
        i_reset     : in std_logic;
        o_eof       : out std_logic;

        -- VGA configuration registers
        i_vga_hbp   : in std_logic_vector(15 downto 0);
        i_vga_hfp   : in std_logic_vector(15 downto 0);
        i_vga_vbp   : in std_logic_vector(15 downto 0);
        i_vga_vfp   : in std_logic_vector(15 downto 0);
        i_vga_hdata : in std_logic_vector(15 downto 0);
        i_vga_vdata : in std_logic_vector(15 downto 0);
        i_vga_hsync : in std_logic_vector(15 downto 0);
        i_vga_vsync : in std_logic_vector(15 downto 0);
        i_vga_hlen  : in std_logic_vector(15 downto 0);
        i_vga_vlen  : in std_logic_vector(15 downto 0);

        -- VGA output signals
        o_r         : out std_logic_vector(7 downto 0);
        o_g         : out std_logic_vector(7 downto 0);
        o_b         : out std_logic_vector(7 downto 0);
        o_hsync     : out std_logic;
        o_vsync     : out std_logic;

        -- Debug signals
        o_debug1    : out std_logic_vector(31 downto 0);
        o_debug2    : out std_logic_vector(31 downto 0)
    );
    end component;

    component vga_clkgen
        port(
            signal clk     : in  std_logic;
            signal rst     : in  std_logic;
            signal clken   : out std_logic
        );
    end component;

    -- 50 MHz -> 20 ns period. Duty cycle = 1/2.
    constant CLK_PERIOD      : time := 20 ns;
    constant CLK_HIGH_PERIOD : time := 10 ns;
    constant CLK_LOW_PERIOD  : time := 10 ns;

    signal clk   : std_logic;
    signal rst   : std_logic;

    signal sim_finished : boolean := false;
 
    signal w_clken : std_logic;
    signal o_reset : std_logic;
    signal i_req   : std_logic;
    signal o_next  : std_logic_vector(31 downto 0);

    signal r_counter : std_logic_vector(31 downto 0);

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

    vga_clkgen_inst : vga_clkgen port map(
        clk     => clk,
        rst     => rst,
        clken   => w_clken
    );

    vga_core_inst : component vga_core
        port map(
            clk         => clk,
            rst         => rst,
    
            -- Clock signal
            i_clken     => w_clken,

            -- Memory signals
            o_req       => i_req,
            i_next      => o_next,

            -- Event signals
            i_reset     => o_reset,

            -- VGA configuration registers
            i_vga_hbp   => std_logic_vector(to_unsigned(INIT_HBP, 16)),
            i_vga_hfp   => std_logic_vector(to_unsigned(INIT_HFP, 16)),
            i_vga_vbp   => std_logic_vector(to_unsigned(INIT_VBP, 16)),
            i_vga_vfp   => std_logic_vector(to_unsigned(INIT_VFP, 16)),
            i_vga_hdata => std_logic_vector(to_unsigned(INIT_HDATA, 16)),
            i_vga_vdata => std_logic_vector(to_unsigned(INIT_VDATA, 16)),
            i_vga_hsync => std_logic_vector(to_unsigned(INIT_HSYNC, 16)),
            i_vga_vsync => std_logic_vector(to_unsigned(INIT_VSYNC, 16)),
            i_vga_hlen  => std_logic_vector(to_unsigned(INIT_HLEN, 16)),
            i_vga_vlen  => std_logic_vector(to_unsigned(INIT_VLEN, 16))
        );

    o_next <= r_counter;

    process(clk, rst) 
    begin
        if rst = '1' then
            r_counter <= (others => '0');
        elsif rising_edge(clk) and i_req = '1' then
            r_counter <= std_logic_vector(unsigned(r_counter) + 1);
        end if;
    end process;

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

        o_reset <= '1';

        wait until falling_edge(clk);
        o_reset <= '0';
        wait until falling_edge(clk);

        wait;
    end process sim;

end architecture tb;
