library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_interface is
    generic(
        INIT_HBP   : integer := 48;
        INIT_HFP   : integer := 16;
        INIT_VBP   : integer := 33;
        INIT_VFP   : integer := 10;
        INIT_HDATA : integer := 640;
        INIT_VDATA : integer := 480;
        INIT_HSYNC : integer := 96;
        INIT_VSYNC : integer := 2
    );

    port(
        clk        : in    std_logic;
        rst        : in    std_logic;

        -- Avalon slave signals
        s_address    : in  std_logic_vector(3 downto 0);
        s_byteenable : in  std_logic_vector(3 downto 0);
        s_chipselect : in  std_logic;
        s_read       : in  std_logic;
        s_readdata   : out std_logic_vector(31 downto 0);
        s_write      : in  std_logic;
        s_writedata  : in  std_logic_vector(31 downto 0);

        -- FIFO interface signals
        o_fifo_baseaddr : out std_logic_vector(31 downto 0);
        o_fifo_length   : out std_logic_vector(31 downto 0);
        o_fifo_reset    : out std_logic;
        o_fifo_req      : out std_logic;
        i_fifo_wait     : in  std_logic;
        i_fifo_next     : in  std_logic_vector(31 downto 0);
        i_fifo_debug    : in  std_logic_vector(31 downto 0);

        -- Data integrity validation signals
        o_data_test     : out std_logic_vector(31 downto 0);
        i_data_valid    : in  std_logic
    );

end vga_interface;

architecture rtl of vga_interface is
    component vga_fsm
        port(
            signal clk      : in  std_logic;
            signal rst      : in  std_logic;
            signal i_init   : in  std_logic;
            signal i_nf     : in  std_logic;
            signal i_eof    : in  std_logic;
            signal i_err    : in  std_logic;
            signal o_onbusy : out std_logic;
            signal o_isbusy : out std_logic;
            signal o_state  : out std_logic_vector(1 downto 0)
        );
    end component;

    component vga_clkgen
        port(
            signal clk     : in  std_logic;
            signal rst     : in  std_logic;
            signal clken   : out std_logic
        );
    end component;

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

    -------------------------------
    --------- VGA signals ---------
    -------------------------------

    -- VGA 25MHz clock
    signal w_vgaclken     : std_logic;
    
    -- Signals deduced from configuration
    signal w_fb_size      : std_logic_vector(27 downto 0);
    signal w_vga_hlen     : std_logic_vector(15 downto 0);
    signal w_vga_vlen     : std_logic_vector(15 downto 0);
    signal w_addroffset   : std_logic_vector(31 downto 0);

    -- VGA logic signals
    signal i_vga_state    : std_logic_vector(1 downto 0);

    signal i_isbusy       : std_logic;
    signal i_onbusy       : std_logic;

    signal w_data_req     : std_logic;
    signal w_data_err     : std_logic;
    signal w_data_ready   : std_logic;
    signal w_data_next    : std_logic_vector(31 downto 0);

    signal w_reset        : std_logic;
    signal w_eof          : std_logic;

    -------------------------------
    -------- Avalon signals--------
    -------------------------------

    -- Write strobe
    signal i_write_strobe : std_logic;

    -- Read strobe
    signal i_read_strobe  : std_logic;

    -- Read buffer
    signal o_s_readdata   : std_logic_vector(31 downto 0);

    -------------------------------
    ---------- Registers ----------
    -------------------------------

    -- Runtime registers
    signal r_init         : std_logic_vector(31 downto 0);
    signal r_nf           : std_logic_vector(31 downto 0);
    signal r_baseaddr     : std_logic_vector(31 downto 0);
    signal r_fbid         : std_logic_vector(3 downto 0);
    signal r_state        : std_logic_vector(31 downto 0);

    -- Configuration registers
    signal r_vga_hbp      : std_logic_vector(15 downto 0);
    signal r_vga_hfp      : std_logic_vector(15 downto 0);
    signal r_vga_vbp      : std_logic_vector(15 downto 0);
    signal r_vga_vfp      : std_logic_vector(15 downto 0);
    signal r_vga_hdata    : std_logic_vector(15 downto 0);
    signal r_vga_vdata    : std_logic_vector(15 downto 0);
    signal r_vga_hsync    : std_logic_vector(15 downto 0);
    signal r_vga_vsync    : std_logic_vector(15 downto 0);

    -- Debug registers
    signal r_debug1       : std_logic_vector(31 downto 0);
    signal r_debug2       : std_logic_vector(31 downto 0);
    signal r_debug3       : std_logic_vector(31 downto 0);

begin
    vga_fsm_inst : vga_fsm port map(
        clk      => clk,
        rst      => rst,
        i_init   => r_init(0),
        i_nf     => r_nf(0),
        i_eof    => w_eof,
        i_err    => w_data_err,
        o_onbusy => i_onbusy,
        o_isbusy => i_isbusy,
        o_state  => i_vga_state
    );

    vga_clkgen_inst : vga_clkgen port map(
        clk     => clk,
        rst     => rst,
        clken   => w_vgaclken
    );

    vga_core_inst : vga_core port map(
        clk         => clk,
        rst         => rst,
        i_clken     => w_vgaclken,
        o_req       => w_data_req,
        i_next      => w_data_next,
        i_reset     => w_reset,
        o_eof       => w_eof,
        i_vga_hbp   => r_vga_hbp,
        i_vga_hfp   => r_vga_hfp,
        i_vga_vbp   => r_vga_vbp,
        i_vga_vfp   => r_vga_vfp,
        i_vga_hdata => r_vga_hdata,
        i_vga_vdata => r_vga_vdata,
        i_vga_hsync => r_vga_hsync,
        i_vga_vsync => r_vga_vsync,
        i_vga_hlen  => w_vga_hlen,
        i_vga_vlen  => w_vga_vlen,
        o_debug1    => r_debug1,
        o_debug2    => r_debug2
    );

    -------------------------------
    ---------- VGA logic ----------
    -------------------------------

    -- Compute lengths from configuration
    w_fb_size <= std_logic_vector(unsigned(r_vga_hdata(13 downto 0)) * unsigned(r_vga_vdata(13 downto 0)));
    w_vga_hlen <= std_logic_vector(unsigned(r_vga_hdata) + unsigned(r_vga_hbp) + unsigned(r_vga_hfp) + unsigned(r_vga_hsync));
    w_vga_vlen <= std_logic_vector(unsigned(r_vga_vdata) + unsigned(r_vga_vbp) + unsigned(r_vga_vfp) + unsigned(r_vga_vsync));
    w_addroffset <= std_logic_vector(unsigned(r_baseaddr) + unsigned(w_fb_size) * unsigned(r_fbid));

    -- FSM logic
    r_state    <= (31 downto 2 => '0') & i_vga_state;
    w_data_err <= not i_data_valid and w_data_ready and i_isbusy and not w_data_req;
    w_reset    <= not i_isbusy;

    -- Setup FIFO framebuffer
    o_fifo_baseaddr <= w_addroffset;
    o_fifo_length   <= "00" & w_fb_size & "00"; -- Pad and multiply by 4
    o_fifo_reset    <= w_reset;

    -- Request data from FIFO
    o_fifo_req   <= w_data_req and not i_fifo_wait;
    w_data_next  <= i_fifo_next when w_data_ready = '1' else x"DEADBEEF";
    o_data_test  <= i_fifo_next when w_data_ready = '1' else (others => '0'); -- Verify checksum of FIFO data

    process(clk, rst)
    begin
        if rst = '1' then
            r_debug3 <= (others => '0');
        elsif rising_edge(clk) then
            if w_data_err = '1' then
                r_debug3     <= i_fifo_next; -- Take note of the failing SDRAM content
            end if;
        end if;
    end process;

    process(clk, rst)
    begin
        if rst = '1' then
            w_data_ready <= '0';
        elsif rising_edge(clk) then
            w_data_ready <= w_data_req and not i_fifo_wait;
        end if;
    end process;

    --------------------------------
    ------- Avalon interface -------
    --------------------------------

    -- R/W strobe
    i_read_strobe <= (s_chipselect and s_read);
    i_write_strobe <= (s_chipselect and s_write);

    -- Output the buffered data when the read strobe is set
    strobe_out : process(clk, rst)
    begin
        if rst = '1' then
            s_readdata <= (others => '0');
        elsif rising_edge(clk) then
            if i_read_strobe = '1' then
                s_readdata <= o_s_readdata;
            end if;
        end if;
    end process;

    -- Output interface (combinatorial -> synchronism is ensured by the strobe_out process)
    output_interface : process(s_address, r_init, r_nf, r_baseaddr, r_fbid, 
                               r_state, r_vga_hbp, r_vga_hfp, r_vga_vbp, r_vga_vfp, 
                               r_vga_hdata, r_vga_vdata ,r_vga_hsync, r_vga_vsync,
                               r_debug1, r_debug2, r_debug3)
    begin
        o_s_readdata <= (others => '0');

        case s_address is
            when "0000" => o_s_readdata              <= r_init;
            when "0001" => o_s_readdata              <= r_nf;
            when "0010" => o_s_readdata              <= r_baseaddr;
            when "0011" => o_s_readdata(3 downto 0)  <= r_fbid;
            when "0100" => o_s_readdata              <= r_state;
            when "0101" => o_s_readdata(15 downto 0) <= r_vga_hbp;
            when "0110" => o_s_readdata(15 downto 0) <= r_vga_hfp;
            when "0111" => o_s_readdata(15 downto 0) <= r_vga_vbp;
            when "1000" => o_s_readdata(15 downto 0) <= r_vga_vfp;
            when "1001" => o_s_readdata(15 downto 0) <= r_vga_hdata;
            when "1010" => o_s_readdata(15 downto 0) <= r_vga_vdata;
            when "1011" => o_s_readdata(15 downto 0) <= r_vga_hsync;
            when "1100" => o_s_readdata(15 downto 0) <= r_vga_vsync;
            when "1101" => o_s_readdata              <= r_debug1;
            when "1110" => o_s_readdata              <= r_debug2;
            when "1111" => o_s_readdata              <= r_debug3;
            when others => o_s_readdata <= (others => '0');
        end case;
    end process output_interface;

    -- Input interface (synchronous)
    input_interface : process(clk, rst)
    begin
        if rst = '1' then
            r_init        <= (others => '0');
            r_nf          <= (others => '0');
            r_baseaddr    <= (others => '0');
            r_fbid        <= (others => '0');
            r_vga_hbp     <= std_logic_vector(to_unsigned(INIT_HBP, 16));
            r_vga_hfp     <= std_logic_vector(to_unsigned(INIT_HFP, 16));
            r_vga_vbp     <= std_logic_vector(to_unsigned(INIT_VBP, 16));
            r_vga_vfp     <= std_logic_vector(to_unsigned(INIT_VFP, 16));
            r_vga_hdata   <= std_logic_vector(to_unsigned(INIT_HDATA, 16));
            r_vga_vdata   <= std_logic_vector(to_unsigned(INIT_VDATA, 16));
            r_vga_hsync   <= std_logic_vector(to_unsigned(INIT_HSYNC, 16));
            r_vga_vsync   <= std_logic_vector(to_unsigned(INIT_VSYNC, 16));
        elsif rising_edge(clk) then
            if i_write_strobe = '1' then
                case s_address is
                    when "0000" => r_init <= s_writedata;
                    when "0001" => r_nf <= s_writedata;
                    when "0010" => r_baseaddr <= s_writedata;
                    when "0011" => r_fbid <= s_writedata(3 downto 0);
                    when "0100" => null; -- Overwriting the system state is not allowed
                    when "0101" => r_vga_hbp <= s_writedata(15 downto 0);
                    when "0110" => r_vga_hfp <= s_writedata(15 downto 0);
                    when "0111" => r_vga_vbp <= s_writedata(15 downto 0);
                    when "1000" => r_vga_vfp <= s_writedata(15 downto 0);
                    when "1001" => r_vga_hdata <= s_writedata(15 downto 0);
                    when "1010" => r_vga_vdata <= s_writedata(15 downto 0);
                    when "1011" => r_vga_hsync <= s_writedata(15 downto 0);
                    when "1100" => r_vga_vsync <= s_writedata(15 downto 0);
                    when "1101" => null;
                    when "1110" => null;
                    when "1111" => null;
                    when others => null;
                end case;
            end if;
        end if;
    end process input_interface;

end rtl;
