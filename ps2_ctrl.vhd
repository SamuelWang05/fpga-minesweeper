library ieee;
use ieee.std_logic_1164.all;

entity PS2_CTRL is
    port (
        clk, reset                         : in  std_logic;
        PS2_CLK                            : in  std_logic;
        PS2_DAT                            : in  std_logic;
        move_up, move_dn, move_lt, move_rt : out std_logic := '0';
        reveal, flag, game_reset           : out std_logic := '0'
    );
end PS2_CTRL;

architecture  rtl of ps2_ctrl is
    -- PS/2 Scan Codes
    constant SC_W : STD_LOGIC_VECTOR(7 downto 0) := x"1D";
    constant SC_A         : std_logic_vector(7 downto 0) := x"1C";
    constant SC_S         : std_logic_vector(7 downto 0) := x"1B";
    constant SC_D         : std_logic_vector(7 downto 0) := x"23";
    constant SC_F         : std_logic_vector(7 downto 0) := x"2B"; -- flag
    constant SC_R         : std_logic_vector(7 downto 0) := x"2D"; -- reveal
    constant SC_ESC       : std_logic_vector(7 downto 0) := x"76"; -- game reset
    constant SC_BREAK_PRE : std_logic_vector(7 downto 0) := x"F0"; -- break code prefix

    -- PS/2 Reciever Signals
    signal ps2_clk_sync : std_logic_vector(2 downto 0) := (others => '0');
    signal ps2_dat_sync : std_logic_vector(1 downto 0) := (others => '1');
    signal ps2_clk_s    : std_logic;
    signal ps2_dat_s    : std_logic;
    signal ps2_clk_fall : std_logic;

    signal shift_reg : std_logic_vector(10 downto 0) := (others => '0');
    signal bit_count : integer range 0 to 10 := 0;
    signal parity_ok : std_logic;

    signal scan_code  : std_logic_vector(7 downto 0) := (others => '0');
    signal byte_ready  : std_logic := '0';

    -- Scan Deocde State (Need to track whether the last byte recieved was 0xF0
    -- so we can ignore key-release events)
    signal break_pending : std_logic := '0';

begin
    sync_proc : process(clk)
    begin
        if rising_edge(clk) then
            ps2_clk_sync <= ps2_clk_sync(1 downto 0) & PS2_CLK;
            ps2_dat_sync <= ps2_dat_sync(0) & PS2_DAT;
        end if;
    end process;

    ps2_clk_s <= ps2_clk_sync(2);
    ps2_dat_s <= ps2_dat_sync(1);
    ps2_clk_fall <= '1' when ps2_clk_sync(2) = '0' and ps2_clk_sync(1) = '1'
                    else '0';
    
  -- -------------------------------------------------------
    -- Receive one PS/2 byte
    -- -------------------------------------------------------
    receive_proc : process(clk)
    begin
        if rising_edge(clk) then
            byte_ready <= '0';

            if reset = '1' then
                bit_count <= 0;
                shift_reg <= (others => '0');

            elsif ps2_clk_fall = '1' then
                if bit_count = 0 then
                    if ps2_dat_s = '0' then     -- valid start bit
                        shift_reg <= (others => '0');
                        bit_count <= 1;
                    end if;

                elsif bit_count < 10 then
                    shift_reg <= ps2_dat_s & shift_reg(10 downto 1);
                    bit_count <= bit_count + 1;

                else                            -- stop bit
                    shift_reg <= ps2_dat_s & shift_reg(10 downto 1);
                    bit_count <= 0;

                    if ps2_dat_s = '1' and parity_ok = '1' then
                        scan_code  <= shift_reg(8 downto 1);
                        byte_ready <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    parity_ok <= shift_reg(1) xor shift_reg(2) xor shift_reg(3) xor
                 shift_reg(4) xor shift_reg(5) xor shift_reg(6) xor
                 shift_reg(7) xor shift_reg(8) xor shift_reg(9);

    -- -------------------------------------------------------
    -- Decode scan codes ? game outputs
    -- -------------------------------------------------------
    -- PS/2 protocol:
    --   Key press   ? <scan_code>
    --   Key release ? 0xF0 <scan_code>
    --
    -- We only pulse outputs on MAKE events (not break).
    -- break_pending is set when 0xF0 is seen, then cleared
    -- after the following byte is consumed.
    -- -------------------------------------------------------
    decode_proc : process(clk)
    begin
        if rising_edge(clk) then
            -- Default: deassert all outputs every cycle
            move_up    <= '0';
            move_dn    <= '0';
            move_lt    <= '0';
            move_rt    <= '0';
            reveal     <= '0';
            flag       <= '0';
            game_reset <= '0';

            if reset = '1' then
                break_pending <= '0';

            elsif byte_ready = '1' then
                if scan_code = SC_BREAK_PRE then
                    -- Next byte will be a break code ? suppress it
                    break_pending <= '1';

                elsif break_pending = '1' then
                    -- This is a key-release byte; discard it
                    break_pending <= '0';

                else
                    -- Make event: pulse the appropriate output
                    break_pending <= '0';
                    case scan_code is
                        when SC_W     => move_up    <= '1';
                        when SC_S     => move_dn    <= '1';
                        when SC_A     => move_lt    <= '1';
                        when SC_D     => move_rt    <= '1';
                        when SC_R     => reveal     <= '1';
                        when SC_F     => flag       <= '1';
                        when SC_ESC     => game_reset <= '1';
                        when others   => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;