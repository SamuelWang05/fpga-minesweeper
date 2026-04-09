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

architecture skeleton of PS2_CTRL is
begin
    -- Minimal logic: keep outputs inactive
    move_up <= '0'; move_dn <= '0'; move_lt <= '0'; move_rt <= '0';
    reveal <= '0'; flag <= '0'; game_reset <= '0';
end skeleton;