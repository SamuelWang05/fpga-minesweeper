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
begin
    cell_state <= (others => '0'); -- All cells hidden ("00")
    cursor_row <= "0000";
    cursor_col <= "0000";
    game_over  <= '0';
    game_won   <= '0';
end skeleton;