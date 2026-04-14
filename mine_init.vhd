library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MINE_INIT is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic; -- Active high reset to start generation
        seed     : in  std_logic_vector(6 downto 0); -- NEW: Seed input
        done     : out std_logic;
        mine_map : out std_logic_vector(99 downto 0)
    );
end MINE_INIT;

architecture behavioral of MINE_INIT is
    signal lfsr_reg : std_logic_vector(6 downto 0);
    signal mines_placed : integer range 0 to 10 := 0;
    signal internal_map : std_logic_vector(99 downto 0);
begin

    process(clk, reset)
        variable next_bit : std_logic;
        variable rand_idx : integer;
    begin
        if reset = '1' then
            internal_map <= (others => '0');
            mines_placed <= 0;
            lfsr_reg <= seed; -- NEW: Initialize LFSR with the random seed
            done <= '0';
        elsif rising_edge(clk) then
            if mines_placed < 10 then
                -- LFSR Taps for 7-bit (x^7 + x^6 + 1)
                next_bit := lfsr_reg(6) xor lfsr_reg(5);
                lfsr_reg <= lfsr_reg(5 downto 0) & next_bit;
                
                -- Convert LFSR value to an index 0-99
                rand_idx := to_integer(unsigned(lfsr_reg));
                
                -- Only place mine if index is valid and cell is currently empty
                if rand_idx < 100 then
                    if internal_map(rand_idx) = '0' then
                        internal_map(rand_idx) <= '1';
                        mines_placed <= mines_placed + 1;
                    end if;
                end if;
            else
                -- Once 10 mines are placed, output the map and signal completion
                mine_map <= internal_map;
                done <= '1';
            end if;
        end if;
    end process;
end behavioral;