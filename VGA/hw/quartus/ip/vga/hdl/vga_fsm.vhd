library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_fsm is
    port(
        clk        : in    std_logic;
        rst        : in    std_logic;

        -- Input events
        i_init     : in    std_logic; -- System init event
        i_nf       : in    std_logic; -- New frame event
        i_eof      : in    std_logic; -- End-of-frame event
        i_err      : in    std_logic; -- Error event

        -- Output events
        o_onbusy   : out   std_logic; -- On transition to BUSY event
        o_isbusy   : out   std_logic; -- When the system is in BUSY state

        -- Ouptut state
        o_state    : out   std_logic_vector(1 downto 0)
    );

end vga_fsm;

architecture rtl of vga_fsm is
    type vga_state_type is (
        S_RESET, S_IDLE, S_BUSY, S_ERROR
    );

    signal w_lastinit     : std_logic;
    signal w_init_rising  : std_logic;
    signal w_state        : vga_state_type;

begin

    detect_rising : process(clk, rst)
    begin
        if rst = '1' then
            w_lastinit <= '0';
        elsif rising_edge(clk) then
            if w_lastinit = '0' and i_init = '1' then
                w_init_rising <= '1';
            else
                w_init_rising <= '0';
            end if;

            w_lastinit <= i_init;
        end if;
    end process detect_rising;
   
    update_fsm : process(clk, rst)
    begin
        if rst = '1' then
            w_state <= S_RESET;
            o_onbusy <= '0';
        elsif rising_edge(clk) then
            o_onbusy <= '0';

            if w_state = S_RESET then
                if w_init_rising = '1' then
                    w_state <= S_IDLE;
                end if;
            elsif w_state = S_IDLE then
                if i_err = '1' then
                    w_state <= S_ERROR;
                elsif i_nf = '1' then
                    w_state <= S_BUSY;
                    o_onbusy <= '1';
                end if;
            elsif w_state = S_BUSY then
                if i_err = '1' then
                    w_state <= S_ERROR;
                elsif i_eof = '1' then
                    w_state <= S_IDLE;
                end if;
            elsif w_state = S_ERROR then
                if w_init_rising = '1' then
                    w_state <= S_IDLE;
                end if;
            end if;
        end if;
    end process update_fsm;

    o_isbusy <= '1' when w_state = S_BUSY else '0';
    o_state <= std_logic_vector(to_unsigned(vga_state_type'POS(w_state), 2));

end rtl;
