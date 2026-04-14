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
        
        -- Changed to 8-bit to hold two 4-bit BCD digits (Tens and Ones)
        hours     : out unsigned(7 downto 0);  
        minutes   : out unsigned(7 downto 0);  
        seconds   : out unsigned(7 downto 0)   
    );
end GAME_TIMER;

architecture behavioral of GAME_TIMER is
    signal tick_count : natural range 0 to TICKS_PER_SECOND - 1 := 0;

    -- Separate signals for ones (0-9) and tens (0-5 or 0-2)
    signal sec_ones, sec_tens : unsigned(3 downto 0) := (others => '0');
    signal min_ones, min_tens : unsigned(3 downto 0) := (others => '0');
    signal hr_ones,  hr_tens  : unsigned(3 downto 0) := (others => '0');

begin

    -- Concatenate tens and ones into the 8-bit outputs
    seconds <= sec_tens & sec_ones;
    minutes <= min_tens & min_ones;
    hours   <= hr_tens  & hr_ones;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tick_count <= 0;
                sec_ones <= (others => '0'); sec_tens <= (others => '0');
                min_ones <= (others => '0'); min_tens <= (others => '0');
                hr_ones  <= (others => '0'); hr_tens  <= (others => '0');
                
            elsif stop = '0' then
                if tick_count = TICKS_PER_SECOND - 1 then
                    tick_count <= 0;

                    -- BCD Seconds Logic
                    if sec_ones = 9 then
                        sec_ones <= (others => '0');
                        
                        if sec_tens = 5 then
                            sec_tens <= (others => '0');

                            -- BCD Minutes Logic
                            if min_ones = 9 then
                                min_ones <= (others => '0');
                                
                                if min_tens = 5 then
                                    min_tens <= (others => '0');

                                    -- BCD Hours Logic (Wraps at 23)
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