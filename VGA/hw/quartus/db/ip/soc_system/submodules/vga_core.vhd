library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_core is
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
end vga_core;

architecture rtl of vga_core is
    -- VGA internal state
    signal r_x : std_logic_vector(31 downto 0);
    signal r_y : std_logic_vector(31 downto 0);

    -- Event signals
    signal w_eol   : std_logic; -- End-of-line
    signal w_eof   : std_logic; -- End-of-frame
    signal w_blank : std_logic;

    signal w_hsync_start : std_logic_vector(15 downto 0);
    signal w_hsync_end   : std_logic_vector(15 downto 0);
    signal w_vsync_start : std_logic_vector(15 downto 0);
    signal w_vsync_end   : std_logic_vector(15 downto 0);

    signal r_debug       : std_logic_vector(31 downto 0);

begin

    -- Logic
    w_eol   <= '1'   when unsigned(r_x) = unsigned(i_vga_hlen) - 1 else '0';
    w_eof   <= w_eol when unsigned(r_y) = unsigned(i_vga_vlen) - 1 else '0';
    w_blank <= '1'   when unsigned(r_x) >= unsigned(i_vga_hdata) or unsigned(r_y) >= unsigned(i_vga_vdata) else '0';

    -- Convenience signals
    w_hsync_start <= std_logic_vector(unsigned(i_vga_hdata) + unsigned(i_vga_hfp));
    w_hsync_end   <= std_logic_vector(unsigned(i_vga_hdata) + unsigned(i_vga_hfp) + unsigned(i_vga_hsync));
    w_vsync_start <= std_logic_vector(unsigned(i_vga_vdata) + unsigned(i_vga_vfp));
    w_vsync_end   <= std_logic_vector(unsigned(i_vga_vdata) + unsigned(i_vga_vfp) + unsigned(i_vga_vsync));
    
    -- FIFO data fetch
    o_req <= not i_clken and not w_blank and not i_reset; -- Fetch data on 25MHz clock falling edge

    -- Counters
    x_counter : process(clk, rst)
    begin
        if rst = '1' then
            r_x <= (others => '0');
        elsif rising_edge(clk) and i_clken = '1' then -- Update counters on 25MHz rising edge
            if w_eol = '1' or i_reset = '1' then
                r_x <= (others => '0');
            else
                r_x <= std_logic_vector(unsigned(r_x) + 1);
            end if;
        end if;
    end process x_counter;

    y_counter : process(clk, rst)
    begin
        if rst = '1' then
            r_y <= (others => '0');
        elsif rising_edge(clk) and i_clken = '1' then -- Update counters on 25MHz rising edge
            if w_eof = '1' or i_reset = '1' then
                r_y <= (others => '0');
            elsif w_eol = '1' then
                r_y <= std_logic_vector(unsigned(r_y) + 1);
            end if;
        end if;
    end process y_counter;

    -- Output signals
    o_eof   <= w_eof;
    o_hsync <= '1' when unsigned(r_x) >= unsigned(w_hsync_start) and unsigned(r_x) < unsigned(w_hsync_end) else '0';
    o_vsync <= '1' when unsigned(r_y) >= unsigned(w_vsync_start) and unsigned(r_y) < unsigned(w_vsync_end) else '0';

    colour_out : process(clk, rst)
    begin
        if rst = '1' then
            o_r      <= (others => '0');
            o_g      <= (others => '0');
            o_b      <= (others => '0');
            o_debug1 <= (others => '0');
        elsif rising_edge(clk) then
            if w_blank = '0' then
                if i_clken = '1' and i_reset = '0' then -- Hold value through cycle
                    o_r      <= i_next(9 downto 2);
                    o_g      <= i_next(19 downto 12);
                    o_b      <= i_next(29 downto 22);
                    o_debug1 <= i_next;
                end if;
            else
                o_r      <= (others => '0');
                o_g      <= (others => '0');
                o_b      <= (others => '0');
                o_debug1 <= (others => '0');
            end if;
        end if;
    end process colour_out;

    -- Maintains a 25MHz counter that is reset when a frame begins
    debug_counter : process(clk, rst, i_clken)
    begin
        if rst = '1' then
            r_debug <= (others => '0');
        elsif rising_edge(clk) and i_clken = '1' then
            if w_eof = '1' or i_reset = '1' then
                r_debug <= (others => '0');
            else
                r_debug <= std_logic_vector(unsigned(r_debug) + 1);
            end if;
        end if;
    end process debug_counter;

    o_debug2 <= r_debug;
end rtl;
