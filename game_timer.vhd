library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAME_TIMER is
    generic (
        TICKS_PER_SECOND : natural := 50_000_000
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        game_over : in  std_logic;
        game_won  : in  std_logic;
        hours     : out unsigned(7 downto 0);
        minutes   : out unsigned(7 downto 0);
        seconds   : out unsigned(7 downto 0);
        high_score : out unsigned(16 downto 0)  -- best time in seconds only
    );
end GAME_TIMER;

architecture behavioral of GAME_TIMER is
    signal tick_count : natural range 0 to TICKS_PER_SECOND - 1 := 0;

    signal sec_ones, sec_tens : unsigned(3 downto 0) := (others => '0');
    signal min_ones, min_tens : unsigned(3 downto 0) := (others => '0');
    signal hr_ones,  hr_tens  : unsigned(3 downto 0) := (others => '0');

    -- Convert current time to a flat second count for easy comparison
    signal best_seconds       : unsigned(16 downto 0) := (others => '1'); -- init to max so any time beats it

    signal game_won_prev      : std_logic := '0'; -- edge detector

begin

    seconds <= sec_tens & sec_ones;
    minutes <= min_tens & min_ones;
    hours   <= hr_tens  & hr_ones;

    -- Expose only the low 8 bits of best_seconds for display
    -- (enough to show 0-255 seconds; expand if you want minutes)
    high_score <= best_seconds;

    process(clk)
       variable current_time : unsigned(16 downto 0);
    begin
        if rising_edge(clk) then
            game_won_prev <= game_won;  -- register previous value for edge detect

            if reset = '1' then
                tick_count <= 0;
                sec_ones   <= (others => '0'); sec_tens <= (others => '0');
                min_ones   <= (others => '0'); min_tens <= (others => '0');
                hr_ones    <= (others => '0'); hr_tens  <= (others => '0');

            elsif game_won = '1' and game_won_prev = '0' then
                -- Compute flat second count from current BCD time
                current_time :=
						resize(resize(hr_tens,  17) * to_unsigned(36000, 17), 17) +
						resize(resize(hr_ones,  17) * to_unsigned( 3600, 17), 17) +
						resize(resize(min_tens, 17) * to_unsigned(  600, 17), 17) +
						resize(resize(min_ones, 17) * to_unsigned(   60, 17), 17) +
						resize(resize(sec_tens, 17) * to_unsigned(   10, 17), 17) +
						resize(sec_ones, 17);
						
                if current_time < best_seconds then
                    best_seconds <= current_time;
                end if;
            elsif game_over = '0' and game_won = '0' then
                if tick_count = TICKS_PER_SECOND - 1 then
                    tick_count <= 0;

                    if sec_ones = 9 then
                        sec_ones <= (others => '0');
                        if sec_tens = 5 then
                            sec_tens <= (others => '0');
                            if min_ones = 9 then
                                min_ones <= (others => '0');
                                if min_tens = 5 then
                                    min_tens <= (others => '0');
                                    if hr_tens = 2 and hr_ones = 3 then
                                        hr_ones <= (others => '0');
                                        hr_tens <= (others => '0');
                                    elsif hr_ones = 9 then
                                        hr_ones <= (others => '0');
                                        hr_tens <= hr_tens + 1;
                                    else
                                        hr_ones <= hr_ones + 1;
                                    end if;
                                else
                                    min_tens <= min_tens + 1;
                                end if;
                            else
                                min_ones <= min_ones + 1;
                            end if;
                        else
                            sec_tens <= sec_tens + 1;
                        end if;
                    else
                        sec_ones <= sec_ones + 1;
                    end if;

                else
                    tick_count <= tick_count + 1;
                end if;
            end if;
        end if;
    end process;

end behavioral;