library ieee;
use ieee.std_logic_1164.all;

entity CELL_CALC is
    port (
        mine_map   : in  std_logic_vector(99  downto 0);
        adj_counts : out std_logic_vector(399 downto 0)
    );
end CELL_CALC;

architecture skeleton of CELL_CALC is
begin
    adj_counts <= (others => '0'); -- Every cell shows "0" adjacent mines
end skeleton;