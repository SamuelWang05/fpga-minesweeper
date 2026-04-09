library ieee;
use ieee.std_logic_1164.all;

entity MINE_INIT is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        done     : out std_logic;
        mine_map : out std_logic_vector(99 downto 0)
    );
end MINE_INIT;

architecture skeleton of MINE_INIT is
begin
    done <= '1'; -- Pretend initialization is finished immediately
    mine_map <= (others => '0'); -- No mines for now
end skeleton;