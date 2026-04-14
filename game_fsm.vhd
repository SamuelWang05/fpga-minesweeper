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

architecture skeleton of GAME_FSM is
    signal row, col       : unsigned(3 downto 0) := (others => '0');
    signal cell_state_int : std_logic_vector(199 downto 0) := (others => '0');
begin

    cell_state <= cell_state_int;
    cursor_row <= row;
    cursor_col <= col;
    game_over  <= '0';
    game_won   <= '0';

    main_proc : process(clk)
        variable cell_idx : integer range 0 to 99;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                row           <= "0000";
                col           <= "0000";
                cell_state_int <= (others => '0');  -- All HIDDEN

            elsif init_done = '1' then

                -- Cursor movement
                if move_up = '1' then
                    if row > 0 then row <= row - 1; end if;
                elsif move_dn = '1' then
                    if row < 9 then row <= row + 1; end if;
                elsif move_lt = '1' then
                    if col > 0 then col <= col - 1; end if;
                elsif move_rt = '1' then
                    if col < 9 then col <= col + 1; end if;

                -- Flag toggle
                elsif flag = '1' then
                    cell_idx := to_integer(row) * 10 + to_integer(col);
                    if cell_state_int(cell_idx*2+1 downto cell_idx*2) = "00" then
                        cell_state_int(cell_idx*2+1 downto cell_idx*2) <= "01";  -- HIDDEN -> FLAGGED
                    elsif cell_state_int(cell_idx*2+1 downto cell_idx*2) = "01" then
                        cell_state_int(cell_idx*2+1 downto cell_idx*2) <= "00";  -- FLAGGED -> HIDDEN
                    end if;
                    -- Do nothing if REVEALED ("10")

                end if;
            end if;
        end if;
    end process;

end skeleton;
