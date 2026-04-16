library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAME_TIMER is
    generic (
        TICKS_PER_SECOND : natural := 50_000_000
    );
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        game_over     : in  std_logic;
        game_won      : in  std_logic;
        -- Current time digits (outputs to HEX display)
        sec_ones      : out unsigned(3 downto 0);
        sec_tens      : out unsigned(3 downto 0);
        sec_hundreds  : out unsigned(3 downto 0);
        -- Best time digits (outputs to HEX display)
        best_ones     : out unsigned(3 downto 0);
        best_tens     : out unsigned(3 downto 0);
        best_hundreds : out unsigned(3 downto 0)
    );
end GAME_TIMER;

architecture behavioral of GAME_TIMER is

    signal tick_count    : natural range 0 to TICKS_PER_SECOND - 1 := 0;

    -- Current time BCD digits
    signal sec_ones_r     : unsigned(3 downto 0) := (others => '0');
    signal sec_tens_r     : unsigned(3 downto 0) := (others => '0');
    signal sec_hundreds_r : unsigned(3 downto 0) := (others => '0');

    -- Best time BCD digits (init to 9 so any real time beats it)
    signal best_ones_r     : unsigned(3 downto 0) := (others => '1');
    signal best_tens_r     : unsigned(3 downto 0) := (others => '1');
    signal best_hundreds_r : unsigned(3 downto 0) := (others => '1');

    signal game_won_prev : std_logic := '0';

begin

    -- Wire internal registers to outputs
    sec_ones      <= sec_ones_r;
    sec_tens      <= sec_tens_r;
    sec_hundreds  <= sec_hundreds_r;
    best_ones     <= best_ones_r;
    best_tens     <= best_tens_r;
    best_hundreds <= best_hundreds_r;

    process(clk)
    begin
        if rising_edge(clk) then
            game_won_prev <= game_won;

            if reset = '1' then
                tick_count      <= 0;
                sec_ones_r      <= (others => '0');
                sec_tens_r      <= (others => '0');
                sec_hundreds_r  <= (others => '0');
                -- best_*_r intentionally NOT reset so high score persists

            elsif game_won = '1' and game_won_prev = '0' then
                -- Compare BCD digits directly, no multiplication needed
                -- Check hundreds first, then tens, then ones
                if sec_hundreds_r < best_hundreds_r then
                    best_hundreds_r <= sec_hundreds_r;
                    best_tens_r     <= sec_tens_r;
                    best_ones_r     <= sec_ones_r;

                elsif sec_hundreds_r = best_hundreds_r then
                    if sec_tens_r < best_tens_r then
                        best_hundreds_r <= sec_hundreds_r;
                        best_tens_r     <= sec_tens_r;
                        best_ones_r     <= sec_ones_r;

                    elsif sec_tens_r = best_tens_r then
                        if sec_ones_r < best_ones_r then
                            best_hundreds_r <= sec_hundreds_r;
                            best_tens_r     <= sec_tens_r;
                            best_ones_r     <= sec_ones_r;
                        end if;
                    end if;
                end if;

            elsif game_over = '0' and game_won = '0' then
                -- Timer counting
                if tick_count = TICKS_PER_SECOND - 1 then
                    tick_count <= 0;

                    if sec_ones_r = 9 then
                        sec_ones_r <= (others => '0');

                        if sec_tens_r = 9 then
                            sec_tens_r <= (others => '0');

                            if sec_hundreds_r = 9 then
                                sec_hundreds_r <= "1001"; -- stay at 9
                            else
                                sec_hundreds_r <= sec_hundreds_r + 1;
                            end if;

                        else
                            sec_tens_r <= sec_tens_r + 1;
                        end if;

                    else
                        sec_ones_r <= sec_ones_r + 1;
                    end if;

                else
                    tick_count <= tick_count + 1;
                end if;
            end if;
        end if;
    end process;

end behavioral;