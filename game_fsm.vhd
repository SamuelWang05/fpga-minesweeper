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
            -- Assign to output packed vector
            cell_state((r*10+c)*2+1 downto (r*10+c)*2) <= state_2d(r, c);
            -- Read from adjacent counts input
            count_2d(r, c) <= unsigned(adj_counts((r*10+c)*4+3 downto (r*10+c)*4));
        end generate;
    end generate;

    -- Route internal signals to output ports
    cursor_row <= row;
    cursor_col <= col;
    game_over  <= game_over_int;
    game_won   <= game_won_int;

    -- 2. Win/Loss Detection (Combinational)
    process(state_2d, count_2d)
        variable unrevealed_count : integer;
        variable hit_mine : std_logic;
    begin
        unrevealed_count := 0;
        hit_mine := '0';

        for r in 0 to 9 loop
            for c in 0 to 9 loop
                -- Game Over: If any cell is revealed AND it contains a mine (15 = "1111")
                if state_2d(r, c) = "10" and count_2d(r, c) = 15 then
                    hit_mine := '1';
                end if;
                -- Count cells that are NOT revealed to check for victory
                if state_2d(r, c) /= "10" then
                    unrevealed_count := unrevealed_count + 1;
                end if;
            end loop;
        end loop;

        game_over_int <= hit_mine;

        -- Win condition: exactly 10 cells (mines) remain unrevealed, and no mines hit
        if hit_mine = '0' and unrevealed_count = 10 then
            game_won_int <= '1';
        else
            game_won_int <= '0';
        end if;
    end process;

    -- 3. Next State Logic (Flood Fill & User Input)
    process(state_2d, count_2d, reveal, flag, row, col, game_over_int, game_won_int)
        variable r_min, r_max, c_min, c_max : integer;
        variable should_reveal : boolean;
        variable r_int, c_int : integer;
    begin
        next_state_2d <= state_2d; -- Default: hold current state

        r_int := to_integer(row);
        c_int := to_integer(col);

        -- Only process new actions if the game is currently active
        if game_over_int = '0' and game_won_int = '0' then

            -- A. Handle Direct User Input (Flag/Reveal)
            if flag = '1' then
                if state_2d(r_int, c_int) = "00" then
                    next_state_2d(r_int, c_int) <= "01"; -- Set to FLAGGED
                elsif state_2d(r_int, c_int) = "01" then
                    next_state_2d(r_int, c_int) <= "00"; -- Return to HIDDEN
                end if;
            elsif reveal = '1' then
                if state_2d(r_int, c_int) = "00" then
                    next_state_2d(r_int, c_int) <= "10"; -- Set to REVEALED
                end if;
            end if;

            -- B. Hardware Flood Fill (Parallel logic)
            for r in 0 to 9 loop
                for c in 0 to 9 loop
                    if state_2d(r, c) = "00" then -- Only auto-reveal cells currently HIDDEN
                        should_reveal := false;

                        -- Define boundaries for 3x3 search
                        if r = 0 then r_min := 0; else r_min := r - 1; end if;
                        if r = 9 then r_max := 9; else r_max := r + 1; end if;
                        if c = 0 then c_min := 0; else c_min := c - 1; end if;
                        if c = 9 then c_max := 9; else c_max := c + 1; end if;

                        for i in r_min to r_max loop
                            for j in c_min to c_max loop
                                -- RULE: Reveal if neighbor is REVEALED and has 0 adjacent mines
                                if state_2d(i, j) = "10" and count_2d(i, j) = 0 then
                                    should_reveal := true;
                                end if;
                            end loop;
                        end loop;

                        if should_reveal then
                            next_state_2d(r, c) <= "10";
                        end if;
                    end if;
                end loop;
            end loop;
        end if;
    end process;

    -- 4. Synchronous Update (Cursor & State Commit)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_2d <= (others => (others => "00"));
                row <= (others => '0');
                col <= (others => '0');
            elsif init_done = '1' then

                -- A. Cursor Movement (Enabled only during active play)
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

                -- B. State Update & "Reveal All Mines" Logic
                if game_over_int = '1' then
                    -- If game is lost, iterate through all cells and reveal mines
                    for r in 0 to 9 loop
                        for c in 0 to 9 loop
                            if count_2d(r, c) = 15 then
                                state_2d(r, c) <= "10"; -- Force state to REVEALED
                            end if;
                        end loop;
                    end loop;
                else
                    -- Normal operation: Commit the next state calculated in Process 3
                    state_2d <= next_state_2d;
                end if;

            end if;
        end if;
    end process;

end behavioral;