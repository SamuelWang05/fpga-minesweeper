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
    mine_map(17 downto 0) <= (others => '0'); -- First 18 tiles are empty
    mine_map(99 downto 18) <= (others => '1'); -- All other tiles have mines
end skeleton;