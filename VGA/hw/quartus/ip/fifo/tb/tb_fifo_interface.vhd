library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fifo_interface is
    generic(
        FB_SIZE   : integer := 307200
    );
end tb_fifo_interface;

architecture tb of tb_fifo_interface is
    component fifo_interface
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
    end component;

    -- 50 MHz -> 20 ns period. Duty cycle = 1/2.
    constant CLK_PERIOD      : time := 20 ns;
    constant CLK_HIGH_PERIOD : time := 10 ns;
    constant CLK_LOW_PERIOD  : time := 10 ns;

    signal clk   : std_logic;
    signal rst   : std_logic;

    signal sim_finished : boolean := false;
 
     -- Avalon master signals
     signal m_address       : std_logic_vector(31 downto 0);
     signal m_byteenable    : std_logic_vector(3 downto 0);
     signal m_read          : std_logic;
     signal m_readdata      : std_logic_vector(31 downto 0);
     signal m_waitrequest   : std_logic;
     signal m_burstcount    : std_logic_vector(4 downto 0);
     signal m_readdatavalid : std_logic;

     -- FIFO control signals
     signal o_baseaddr      : std_logic_vector(31 downto 0);
     signal o_length        : std_logic_vector(31 downto 0);
     signal o_reset         : std_logic;
     signal o_req           : std_logic;
     signal i_wait          : std_logic;
     signal i_next          : std_logic_vector(31 downto 0);

     -- Debug signals
     signal i_debug         : std_logic_vector(31 downto 0);

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

    fifo_interface_inst : component fifo_interface
        port map(
            clk             => clk,
            rst             => rst,
    
            -- Avalon master signals
            m_address       => m_address,
            m_byteenable    => m_byteenable,
            m_read          => m_read,
            m_readdata      => m_readdata,
            m_waitrequest   => m_waitrequest,
            m_burstcount    => m_burstcount,
            m_readdatavalid => m_readdatavalid,
    
            -- FIFO control signals
            i_baseaddr      => o_baseaddr,
            i_length        => o_length,
            i_reset         => o_reset,
            i_req           => o_req,
            o_wait          => i_wait,
            o_next          => i_next,
    
            -- Debug signals
            o_debug         => i_debug
        );

    data_generation : process(clk, rst)
    begin
        if rst = '1' then
            m_readdata <= (others => '0');
        elsif rising_edge(clk) then
            if m_read = '1' then
                m_readdata <= "00" & m_address(31 downto 2);
            else
                m_readdata <= std_logic_vector(unsigned(m_readdata) + 1);
            end if;
        end if;
    end process data_generation;

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

        m_waitrequest <= '0';
        m_readdatavalid <= '1';

        o_baseaddr <= (others => '0');
        o_length <= std_logic_vector(to_unsigned(FB_SIZE, 30)) & "00";
        o_reset <= '1';

        wait until falling_edge(clk);
        o_reset <= '0';
        wait until falling_edge(clk);
        wait until falling_edge(clk);

        for i in 0 to 2*FB_SIZE loop
            wait until falling_edge(clk);
            o_req <= '1';

            wait until falling_edge(clk);
            o_req <= '0';

            assert i mod FB_SIZE = unsigned(i_next);
        end loop;

        sim_finished <= true;

        wait;
    end process sim;

end architecture tb;
