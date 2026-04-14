library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAME_TIMER is
    generic (
        TICKS_PER_SECOND : natural := 50_000_000
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;  -- active high, from game_reset
        stop      : in  std_logic;  -- tie to (game_over OR game_won)
        hours     : out unsigned(4 downto 0);  -- 0-23
        minutes   : out unsigned(5 downto 0);  -- 0-59
        seconds   : out unsigned(5 downto 0)   -- 0-59
    );
end GAME_TIMER;

architecture behavioral of GAME_TIMER is
    signal tick_count : natural range 0 to TICKS_PER_SECOND - 1 := 0;
    signal sec_int    : unsigned(5 downto 0) := (others => '0');
    signal min_int    : unsigned(5 downto 0) := (others => '0');
    signal hr_int     : unsigned(4 downto 0) := (others => '0');
begin

    seconds <= sec_int;
    minutes <= min_int;
    hours   <= hr_int;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tick_count <= 0;
                sec_int    <= (others => '0');
                min_int    <= (others => '0');
                hr_int     <= (others => '0');
            elsif stop = '0' then
                if tick_count = TICKS_PER_SECOND - 1 then
                    tick_count <= 0;
                    if sec_int = 59 then
                        sec_int <= (others => '0');
                        if min_int = 59 then
                            min_int <= (others => '0');
                            if hr_int < 23 then
                                hr_int <= hr_int + 1;
                            end if;
                        else
                            min_int <= min_int + 1;
                        end if;
                    else
                        sec_int <= sec_int + 1;
                    end if;
                else
                    tick_count <= tick_count + 1;
                end if;
            end if;
        end if;
    end process;

end behavioral;
