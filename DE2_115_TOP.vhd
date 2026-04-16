--
-- DE2-115 top-level module
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DE2_115_TOP is
  generic (
    TICKS_PER_SECOND : natural := 50_000_000
  );
  port (
    CLOCK_50    : in    std_logic;
    CLOCK2_50   : in    std_logic;
    CLOCK3_50   : in    std_logic;
    SMA_CLKIN   : in    std_logic;
    SMA_CLKOUT  : out   std_logic;

    KEY         : in    std_logic_vector(3 downto 0);
    SW          : in    std_logic_vector(17 downto 0);

    HEX0        : out   std_logic_vector(6 downto 0);
    HEX1        : out   std_logic_vector(6 downto 0);
    HEX2        : out   std_logic_vector(6 downto 0);
    HEX3        : out   std_logic_vector(6 downto 0);
    HEX4        : out   std_logic_vector(6 downto 0);
    HEX5        : out   std_logic_vector(6 downto 0);
    HEX6        : out   std_logic_vector(6 downto 0);
    HEX7        : out   std_logic_vector(6 downto 0);
    LEDG        : out   std_logic_vector(8 downto 0);
    LEDR        : out   std_logic_vector(17 downto 0);

    UART_CTS    : out   std_logic;
    UART_RTS    : in    std_logic;
    UART_RXD    : in    std_logic;
    UART_TXD    : out   std_logic;

    LCD_BLON    : out   std_logic;
    LCD_EN      : out   std_logic;
    LCD_ON      : out   std_logic;
    LCD_RS      : out   std_logic;
    LCD_RW      : out   std_logic;
    LCD_DATA    : inout std_logic_vector(7 downto 0);

    PS2_CLK     : inout std_logic;
    PS2_DAT     : inout std_logic;
    PS2_CLK2    : inout std_logic;
    PS2_DAT2    : inout std_logic;

    VGA_BLANK_N : out   std_logic;
    VGA_CLK     : out   std_logic;
    VGA_HS      : out   std_logic;
    VGA_SYNC_N  : out   std_logic;
    VGA_VS      : out   std_logic;
    VGA_R       : out   std_logic_vector(7 downto 0);
    VGA_G       : out   std_logic_vector(7 downto 0);
    VGA_B       : out   std_logic_vector(7 downto 0);

    SRAM_ADDR   : out   unsigned(19 downto 0);
    SRAM_DQ     : inout unsigned(15 downto 0);
    SRAM_CE_N   : out   std_logic;
    SRAM_LB_N   : out   std_logic;
    SRAM_OE_N   : out   std_logic;
    SRAM_UB_N   : out   std_logic;
    SRAM_WE_N   : out   std_logic;

    AUD_ADCDAT  : in    std_logic;
    AUD_ADCLRCK : inout std_logic;
    AUD_BCLK    : inout std_logic;
    AUD_DACDAT  : out   std_logic;
    AUD_DACLRCK : inout std_logic;
    AUD_XCK     : out   std_logic
  );
end DE2_115_TOP;

architecture structural of DE2_115_TOP is

    component VGA_SYNC_module
        port (
            clock_50Mhz                      : in  std_logic;
            red, green, blue                 : in  std_logic_vector(7 downto 0);
            red_out, green_out, blue_out     : out std_logic_vector(7 downto 0);
            horiz_sync_out, vert_sync_out,
            video_on, pixel_clock            : out std_logic;
            pixel_row, pixel_column          : out std_logic_vector(10 downto 0)
        );
    end component;

    component PS2_CTRL
        port (
            clk, reset                         : in  std_logic;
            PS2_CLK                            : in  std_logic;
            PS2_DAT                            : in  std_logic;
            move_up, move_dn, move_lt, move_rt : out std_logic;
            reveal, flag, game_reset           : out std_logic
        );
    end component;

    component MINE_INIT
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            seed     : in  std_logic_vector(6 downto 0); -- NEW: Seed port
            done     : out std_logic;
            mine_map : out std_logic_vector(99 downto 0)
        );
    end component;

    component CELL_CALC
        port (
            mine_map   : in  std_logic_vector(99  downto 0);
            adj_counts : out std_logic_vector(399 downto 0)
        );
    end component;

    component GAME_FSM
        port (
            clk, reset, init_done              : in  std_logic;
            mine_map                           : in  std_logic_vector(99  downto 0);
            adj_counts                         : in  std_logic_vector(399 downto 0);
            move_up, move_dn, move_lt, move_rt : in  std_logic;
            reveal, flag                       : in  std_logic;
            cell_state                         : out std_logic_vector(199 downto 0);
            cursor_row, cursor_col             : out unsigned(3 downto 0);
            game_over, game_won                : out std_logic
        );
    end component;

    component RGB_MUX
        port (
            pixel_clk  : in  std_logic;
            pixel_col  : in  std_logic_vector(10 downto 0);
            pixel_row  : in  std_logic_vector(10 downto 0);
            video_on   : in  std_logic;
            cell_state : in  std_logic_vector(199 downto 0);
            adj_counts : in  std_logic_vector(399 downto 0);
            cursor_row : in  unsigned(3 downto 0);
            cursor_col : in  unsigned(3 downto 0);
            game_over  : in  std_logic;
            game_won   : in  std_logic;
            red        : out std_logic_vector(7 downto 0);
            green      : out std_logic_vector(7 downto 0);
            blue       : out std_logic_vector(7 downto 0)
        );
    end component;

    component GAME_TIMER
        generic (
            TICKS_PER_SECOND : natural := 50_000_000
        );
        port (
            clk           : in  std_logic;
            reset         : in  std_logic;
            game_over     : in  std_logic;
            game_won      : in  std_logic;
            sec_ones      : out unsigned(3 downto 0);
            sec_tens      : out unsigned(3 downto 0);
            sec_hundreds  : out unsigned(3 downto 0);
            best_ones     : out unsigned(3 downto 0);
            best_tens     : out unsigned(3 downto 0);
            best_hundreds : out unsigned(3 downto 0)
        );
    end component;

    component SEG7_DECODER
        port (
            digit : in  unsigned(3 downto 0);
            seg   : out std_logic_vector(6 downto 0)
        );
    end component;

    signal sys_reset  : std_logic;
    signal game_reset : std_logic;

    signal red_int    : std_logic_vector(7 downto 0);
    signal green_int  : std_logic_vector(7 downto 0);
    signal blue_int   : std_logic_vector(7 downto 0);
    signal pixel_clk  : std_logic;
    signal video_on   : std_logic;
    signal pixel_row  : std_logic_vector(10 downto 0);
    signal pixel_col  : std_logic_vector(10 downto 0);

    signal mine_map   : std_logic_vector(99  downto 0);
    signal adj_counts : std_logic_vector(399 downto 0);
    signal cell_state : std_logic_vector(199 downto 0);
    signal cursor_row : unsigned(3 downto 0);
    signal cursor_col : unsigned(3 downto 0);

    signal init_done  : std_logic;
    signal game_over  : std_logic;
    signal game_won   : std_logic;

    signal move_up    : std_logic;
    signal move_dn    : std_logic;
    signal move_lt    : std_logic;
    signal move_rt    : std_logic;
    signal reveal     : std_logic;
    signal flag_key   : std_logic;
    signal kbd_reset  : std_logic;

    -- Timer signals
    signal sec_ones      : unsigned(3 downto 0);
    signal sec_tens      : unsigned(3 downto 0);
    signal sec_hundreds  : unsigned(3 downto 0);
    signal best_ones     : unsigned(3 downto 0);
    signal best_tens     : unsigned(3 downto 0);
    signal best_hundreds : unsigned(3 downto 0);

    -- NEW: Random seed signal
    signal random_seed : std_logic_vector(6 downto 0);

begin

    -- Reset
    sys_reset  <= not KEY(0);
    game_reset <= sys_reset or kbd_reset;

    -- NEW: Free running counter for randomness
    process(CLOCK_50)
        variable counter : unsigned(6 downto 0) := (others => '0');
    begin
        if rising_edge(CLOCK_50) then
            counter := counter + 1;
            -- Ensure seed is never zero (LFSR lockup)
            if counter = 0 then 
                counter := "0000001"; 
            end if;
            random_seed <= std_logic_vector(counter);
        end if;
    end process;



    -- VGA outputs from internal signals
    VGA_CLK     <= pixel_clk;
    VGA_BLANK_N <= video_on;
    VGA_SYNC_N  <= '1';

    -- Tie off unused outputs
    SMA_CLKOUT  <= '0';
    HEX0        <= (others => '1');  -- unused
    HEX1        <= (others => '1');  -- unused
    UART_CTS    <= '0';
    UART_TXD    <= '0';
    LCD_BLON    <= '0';
    LCD_EN      <= '0';
    LCD_ON      <= '0';
    LCD_RS      <= '0';
    LCD_RW      <= '0';
    LCD_DATA    <= (others => 'Z');
    SRAM_ADDR   <= (others => '0');
    SRAM_DQ     <= (others => 'Z');
    SRAM_CE_N   <= '1';
    SRAM_LB_N   <= '1';
    SRAM_OE_N   <= '1';
    SRAM_UB_N   <= '1';
    SRAM_WE_N   <= '1';
    AUD_DACDAT  <= '0';
    AUD_XCK     <= '0';

    -- Status LEDs
    LEDR(0)           <= game_over;
    LEDG(0)           <= game_won;
    LEDG(1)           <= init_done;
    LEDR(17 downto 1) <= (others => '0');
    LEDG(8  downto 2) <= (others => '0');

    U1 : VGA_SYNC_module
        port map (
            clock_50Mhz    => CLOCK_50,
            red            => red_int,
            green          => green_int,
            blue           => blue_int,
            red_out        => VGA_R,
            green_out      => VGA_G,
            blue_out       => VGA_B,
            horiz_sync_out => VGA_HS,
            vert_sync_out  => VGA_VS,
            video_on       => video_on,
            pixel_clock    => pixel_clk,
            pixel_row      => pixel_row,
            pixel_column   => pixel_col
        );

    U2 : PS2_CTRL
        port map (
            clk        => CLOCK_50,
            reset      => sys_reset,
            PS2_CLK    => PS2_CLK,
            PS2_DAT    => PS2_DAT,
            move_up    => move_up,
            move_dn    => move_dn,
            move_lt    => move_lt,
            move_rt    => move_rt,
            reveal     => reveal,
            flag       => flag_key,
            game_reset => kbd_reset
        );

    U3 : MINE_INIT
        port map (
            clk      => CLOCK_50,
            reset    => game_reset,
            seed     => random_seed, -- NEW: Pass the high-speed seed
            done     => init_done,
            mine_map => mine_map
        );

    U4 : CELL_CALC
        port map (
            mine_map   => mine_map,
            adj_counts => adj_counts
        );

    U5 : GAME_FSM
        port map (
            clk        => CLOCK_50,
            reset      => game_reset,
            init_done  => init_done,
            mine_map   => mine_map,
            adj_counts => adj_counts,
            move_up    => move_up,
            move_dn    => move_dn,
            move_lt    => move_lt,
            move_rt    => move_rt,
            reveal     => reveal,
            flag       => flag_key,
            cell_state => cell_state,
            cursor_row => cursor_row,
            cursor_col => cursor_col,
            game_over  => game_over,
            game_won   => game_won
        );

    U6 : RGB_MUX
        port map (
            pixel_clk  => pixel_clk,
            pixel_col  => pixel_col,
            pixel_row  => pixel_row,
            video_on   => video_on,
            cell_state => cell_state,
            adj_counts => adj_counts,
            cursor_row => cursor_row,
            cursor_col => cursor_col,
            game_over  => game_over,
            game_won   => game_won,
            red        => red_int,
            green      => green_int,
            blue       => blue_int
        );

   U7 : GAME_TIMER
    generic map (
        TICKS_PER_SECOND => TICKS_PER_SECOND
    )
    port map (
        clk           => CLOCK_50,
        reset         => game_reset,
        game_over     => game_over,
        game_won      => game_won,
        sec_ones      => sec_ones,
        sec_tens      => sec_tens,
        sec_hundreds  => sec_hundreds,
        best_ones     => best_ones,
        best_tens     => best_tens,
        best_hundreds => best_hundreds
    );

    -- HEX displays: HH:MM:SS across HEX7..HEX2
    U8  : SEG7_DECODER port map (digit => sec_ones,      seg => HEX2);
    U9  : SEG7_DECODER port map (digit => sec_tens,      seg => HEX3);
    U10 : SEG7_DECODER port map (digit => sec_hundreds,  seg => HEX4);
    U11 : SEG7_DECODER port map (digit => best_ones,     seg => HEX5);
    U12 : SEG7_DECODER port map (digit => best_tens,     seg => HEX6);
    U13 : SEG7_DECODER port map (digit => best_hundreds, seg => HEX7);

end structural;