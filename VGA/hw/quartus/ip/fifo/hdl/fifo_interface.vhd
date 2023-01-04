library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_interface is
    generic(
        BURSTCOUNT   : integer := 16
    );

    port(
        clk        : in    std_logic;
        rst        : in    std_logic;

        -- Avalon master signals
        m_address       : out std_logic_vector(31 downto 0);
        m_byteenable    : out std_logic_vector(3 downto 0);
        m_read          : out std_logic;
        m_readdata      : in  std_logic_vector(31 downto 0);
        m_waitrequest   : in  std_logic;
        m_burstcount    : out std_logic_vector(4 downto 0);
        m_readdatavalid : in  std_logic;

        -- FIFO control signals
        i_baseaddr      : in  std_logic_vector(31 downto 0);
        i_length        : in  std_logic_vector(31 downto 0);
        i_reset         : in  std_logic;
        i_req           : in  std_logic;
        o_wait          : out std_logic;
        o_next          : out std_logic_vector(31 downto 0);

        -- Debug signals
        o_debug         : out std_logic_vector(31 downto 0)
    );

end fifo_interface;

architecture rtl of fifo_interface is
    component fifo_core
	port(
		clock		: in  std_logic;
		data		: in  std_logic_vector(31 downto 0);
		rdreq		: in  std_logic;
		wrreq		: in  std_logic;
		almost_full	: out std_logic;
        empty       : out std_logic;
		q		    : out std_logic_vector(31 downto 0)
	);
    end component;

    component fifo_fsm
    port(
        clk          : in    std_logic;
        rst          : in    std_logic;
        i_req_wait   : in    std_logic; -- Bus busy event
        i_fetch_wait : in    std_logic; -- Back pressure event
        i_ack        : in    std_logic; -- Burst acknowledged event
        o_request    : out   std_logic;
        o_fetch      : out   std_logic;
        o_state      : out   std_logic_vector(1 downto 0)
    );
    end component;

    -- FIFO signals
    signal w_fifo_in    : std_logic_vector(31 downto 0);
    signal w_fifo_out   : std_logic_vector(31 downto 0);
    signal w_push       : std_logic;
    signal w_pop        : std_logic;
    signal w_in_wait    : std_logic;
    signal w_out_wait   : std_logic;
    signal w_req_wait   : std_logic;
    signal w_fetch_wait : std_logic;

    -- Internal state
    signal r_address    : std_logic_vector(31 downto 0);
    signal r_burst      : std_logic_vector(5 downto 0);
    signal o_ack        : std_logic;
    signal i_request    : std_logic;
    signal i_fetch      : std_logic;

begin
    fifo_core_inst : fifo_core port map(
		clock	    => clk,
		data	    => w_fifo_in,
		rdreq	    => w_pop,
		wrreq	    => w_push,
		almost_full	=> w_in_wait,
        empty	    => w_out_wait,
		q	        => w_fifo_out
	);

    fifo_fsm_inst : fifo_fsm port map(
        clk          => clk,
        rst          => rst,
        i_req_wait   => w_req_wait,
        i_fetch_wait => w_fetch_wait,
        i_ack        => o_ack,
        o_request    => i_request,
        o_fetch      => i_fetch,
        o_state      => o_debug(1 downto 0)
    );

    -- Debug signals
    o_debug(31 downto 13) <= r_address(18 downto 0);
    o_debug(12 downto 7) <= r_burst;
    o_debug(6) <= w_in_wait;       -- FIFO full
    o_debug(5) <= w_out_wait;      -- FIFO empty
    o_debug(4) <= i_reset;         -- Do not read
    o_debug(3) <= m_waitrequest;   -- Bus busy
    o_debug(2) <= m_readdatavalid; -- Bus data valid

    -- Requests 32-bits tranfers
    m_byteenable <= "1111";

    -- Manage FIFO input
    w_push     <= m_readdatavalid and i_fetch;
    w_fifo_in  <= m_readdata;

    -- Manage FIFO output
    w_pop      <= i_req;
    o_wait     <= w_out_wait;
    o_next     <= w_fifo_out;

    -- Manage FIFO FSM
    w_req_wait   <= w_in_wait or i_reset;
    w_fetch_wait <= m_waitrequest;

    -- When the system is in the "request" state
    request : process(i_request, r_address)
    begin
        if i_request = '1' then
            m_address    <= r_address;
            m_burstcount <= std_logic_vector(to_unsigned(BURSTCOUNT, 5));
            m_read       <= '1';
        else
            m_address    <= x"DEADBEEF";
            m_burstcount <= (others => '0');
            m_read       <= '0';
        end if;
    end process request;

    -- Update the address and burst counters
    update_counters : process(clk, rst)
    begin
        if rst = '1' then
            r_address <= (others => '0');
            r_burst   <= (others => '0');
        elsif rising_edge(clk) then
            if i_reset = '1' or unsigned(r_address) >= unsigned(i_baseaddr) + unsigned(i_length) - 1 then
                r_address <= i_baseaddr;
            elsif m_readdatavalid = '1' and i_fetch = '1' then
                r_address <= std_logic_vector(unsigned(r_address) + 4);
            end if;

            if unsigned(r_burst) >= BURSTCOUNT - 1 then
                r_burst <= (others => '0');
            elsif m_readdatavalid = '1' and i_fetch = '1' then
                r_burst <= std_logic_vector(unsigned(r_burst) + 1);
            end if;
        end if;
    end process update_counters;

    -- Acknowledges the completion of a burst
    o_ack <= '1' when unsigned(r_burst) = BURSTCOUNT - 1 else '0';

end rtl;
