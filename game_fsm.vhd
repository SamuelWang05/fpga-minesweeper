library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAME_FSM is
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
end GAME_FSM;

architecture behavioral of GAME_FSM is

    -- 2D Array types for spatial logic
    type state_2d_type is array (0 to 9, 0 to 9) of std_logic_vector(1 downto 0);
    signal state_2d, next_state_2d : state_2d_type;

    type count_2d_type is array (0 to 9, 0 to 9) of unsigned(3 downto 0);
    signal count_2d : count_2d_type;

    signal row, col : unsigned(3 downto 0) := (others => '0');

    signal game_over_int : std_logic := '0';
    signal game_won_int  : std_logic := '0';

begin

    -- 1. Unpack/Pack 1D vectors into 2D arrays 
    gen_pack: for r in 0 to 9 generate
        gen_pack_c: for c in 0 to 9 generate
            -- Assign to output
            cell_state((r*10+c)*2+1 downto (r*10+c)*2) <= state_2d(r, c);
            -- Read from input
            count_2d(r, c) <= unsigned(adj_counts((r*10+c)*4+3 downto (r*10+c)*4));
        end generate;
    end generate;

    -- Route internal signals to outputs
    cursor_row <= row;
    cursor_col <= col;
    game_over  <= game_over_int;
    game_won   <= game_won_int;

    -- 2. Win/Loss detection (Combinational)
    process(state_2d, count_2d)
        variable unrevealed_count : integer;
        variable hit_mine : std_logic;
    begin
        unrevealed_count := 0;
        hit_mine := '0';

        for r in 0 to 9 loop
            for c in 0 to 9 loop
                -- Game Over: If a cell is revealed and it's a mine (15 = "1111")
                if state_2d(r, c) = "10" and count_2d(r, c) = 15 then
                    hit_mine := '1';
                end if;
                -- Count cells that are NOT revealed to check for win
                if state_2d(r, c) /= "10" then
                    unrevealed_count := unrevealed_count + 1;
                end if;
            end loop;
        end loop;

        game_over_int <= hit_mine;

        -- Win condition: exactly 10 cells remain unrevealed, and no mines hit
        if hit_mine = '0' and unrevealed_count = 10 then
            game_won_int <= '1';
        else
            game_won_int <= '0';
        end if;
    end process;

    -- 3. Next State Logic (Flood fill & User Input)
    process(state_2d, count_2d, reveal, flag, row, col, game_over_int, game_won_int)
        variable r_min, r_max, c_min, c_max : integer;
        variable should_reveal : boolean;
        variable r_int, c_int : integer;
    begin
        next_state_2d <= state_2d; -- Default: hold current state

        r_int := to_integer(row);
        c_int := to_integer(col);

        -- Only process actions if the game is active
        if game_over_int = '0' and game_won_int = '0' then

            -- A. Handle Direct User Input (Flag/Reveal)
            if flag = '1' then
                if state_2d(r_int, c_int) = "00" then
                    next_state_2d(r_int, c_int) <= "01"; -- FLAGGED
                elsif state_2d(r_int, c_int) = "01" then
                    next_state_2d(r_int, c_int) <= "00"; -- HIDDEN
                end if;
            elsif reveal = '1' then
                if state_2d(r_int, c_int) = "00" then
                    next_state_2d(r_int, c_int) <= "10"; -- REVEALED
                end if;
            end if;

            -- B. Hardware "Flood Fill" (Cellular Automata)
            -- This combinationally checks all cells to see if they should reveal next cycle
            for r in 0 to 9 loop
                for c in 0 to 9 loop
                    if state_2d(r, c) = "00" then -- Only auto-reveal HIDDEN cells
                        should_reveal := false;

                        -- Define 3x3 search boundaries (prevents edge wrap-around)
                        if r = 0 then r_min := 0; else r_min := r - 1; end if;
                        if r = 9 then r_max := 9; else r_max := r + 1; end if;
                        if c = 0 then c_min := 0; else c_min := c - 1; end if;
                        if c = 9 then c_max := 9; else c_max := c + 1; end if;

                        for i in r_min to r_max loop
                            for j in c_min to c_max loop
                                -- RULE: If a neighbor is revealed AND has 0 adjacent mines
                                if state_2d(i, j) = "10" and count_2d(i, j) = 0 then
                                    should_reveal := true;
                                end if;
                            end loop;
                        end loop;

                        -- Apply the reveal to the next state
                        if should_reveal then
                            next_state_2d(r, c) <= "10";
                        end if;
                    end if;
                end loop;
            end loop;

        end if;
    end process;

    -- 4. Synchronous State Update & Cursor Control
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_2d <= (others => (others => "00"));
                row <= (others => '0');
                col <= (others => '0');
            elsif init_done = '1' then

                -- Handle Cursor Movement (Frozen if game over/won)
                if game_over_int = '0' and game_won_int = '0' then
                    if move_up = '1' and row > 0 then
                        row <= row - 1;
                    elsif move_dn = '1' and row < 9 then
                        row <= row + 1;
                    elsif move_lt = '1' and col > 0 then
                        col <= col - 1;
                    elsif move_rt = '1' and col < 9 then
                        col <= col + 1;
                    end if;
                end if;

                -- Apply calculated state combinations 
                state_2d <= next_state_2d;

            end if;
        end if;
    end process;

end behavioral;