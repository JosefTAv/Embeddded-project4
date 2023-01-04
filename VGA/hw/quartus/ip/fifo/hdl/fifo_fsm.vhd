library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_fsm is
    port(
        clk          : in    std_logic;
        rst          : in    std_logic;

        -- Input events
        i_req_wait   : in    std_logic; -- Back pressure event
        i_fetch_wait : in    std_logic; -- Bus busy event
        i_ack        : in    std_logic; -- Burst acknowledged event

        -- Ouptut events
        o_request    : out   std_logic;
        o_fetch      : out   std_logic;

        -- Output state
        o_state      : out   std_logic_vector(1 downto 0)
    );

end fifo_fsm;

architecture rtl of fifo_fsm is
    type fifo_state_type is (
        S_WAIT, S_REQUEST, S_FETCH
    );

    signal w_state : fifo_state_type;

begin
   
    update_fsm : process(clk, rst)
    begin
        if rst = '1' then
            w_state <= S_WAIT;
        elsif rising_edge(clk) then
            if w_state = S_WAIT then
                if i_req_wait = '0' then
                    w_state <= S_REQUEST;
                end if;
            elsif w_state = S_REQUEST then
                if i_fetch_wait = '0' then
                    w_state <= S_FETCH;
                end if;
            elsif w_state = S_FETCH then
                if i_ack = '1' then
                    if i_req_wait = '0' then
                        w_state <= S_REQUEST;
                    else
                        w_state <= S_WAIT;
                    end if;
                end if;
            end if;
        end if;
    end process update_fsm;

    o_request <= '1' when w_state = S_REQUEST else '0';
    o_fetch   <= '1' when w_state = S_FETCH   else '0';
    o_state   <= std_logic_vector(to_unsigned(fifo_state_type'POS(w_state), 2));

end rtl;
