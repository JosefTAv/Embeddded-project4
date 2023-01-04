library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity vga_interface is
    port(
        clk        : in    std_logic;
        reset      : in    std_logic;

        -- Avalon master signals
        m_address     : out std_logic_vector(31 downto 0);
        m_byteenable  : out std_logic_vector(3 downto 0);
        m_read        : out std_logic;
        m_readdata    : in  std_logic_vector(31 downto 0);
        m_waitrequest : in  std_logic;

        -- Avalon slave signals
        s_address    : in  std_logic_vector(1 downto 0);
        s_byteenable : in  std_logic_vector(3 downto 0);
        s_chipselect : in  std_logic;
        s_read       : in  std_logic;
        s_readdata   : out std_logic_vector(31 downto 0);
        s_write      : in  std_logic;
        s_writedata  : in  std_logic_vector(31 downto 0)
    );

end vga_interface;

architecture rtl of vga_interface is
    component vga_clkgen
        port(
            signal clk     : in  std_logic;
            signal rst     : in  std_logic;
            signal clken   : out std_logic
        );
    end component;

    -- VGA 25MHz clock
    signal i_vgaclken     : std_logic;

    -- write strobe
    signal i_write_strobe : std_logic;

    -- read strobe
    signal i_read_strobe  : std_logic;

    -- read buffer
    signal o_s_readdata   : std_logic_vector(31 downto 0);

    -- debug register
    signal r_debug        : std_logic_vector(31 downto 0);


begin
    clkgen : vga_clkgen port map(
        clk     => clk,
        rst     => reset,
        clken   => i_vgaclken
    );

    -- R/W strobe
    i_read_strobe <= (s_chipselect and s_read);
    i_write_strobe <= (s_chipselect and s_write);

    -- Output the buffered data when the read strobe is set
    strobe_out : process(clk, reset)
    begin
        if (reset = '1') then
            s_readdata <= (others => '0');
        elsif (rising_edge(clk)) then
            if (i_read_strobe = '1') then
                s_readdata <= o_s_readdata;
            end if;
        end if;
    end process;

    -- Output interface (combinatorial -> synchronism is ensured by the strobe_out process)
    output_interface : process(s_address, r_debug)
    begin
        o_s_readdata <= (others => '0');

        case s_address is
            when "00" => o_s_readdata <= r_debug;
            when others => o_s_readdata <= (others => '0');
        end case;
    end process output_interface;

    -- Input interface (synchronous)
    input_interface : process(clk, reset)
    begin
        if (reset = '1') then
            r_debug      <= (others => '0');
        elsif (rising_edge(clk)) then
            if (i_write_strobe = '1') then
                case s_address is
                    when "00" => r_debug <= s_writedata;
                    when others => null;
                end case;
            end if;
        end if;
    end process input_interface;

end rtl;
