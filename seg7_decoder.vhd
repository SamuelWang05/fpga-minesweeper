library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SEG7_DECODER is
    port (
        digit : in  unsigned(3 downto 0);  -- 0-9
        seg   : out std_logic_vector(6 downto 0)  -- active low, segments a-g
    );
end SEG7_DECODER;

architecture behavioral of SEG7_DECODER is
begin
    process(digit)
    begin
        case to_integer(digit) is
            when 0 => seg <= "1000000";
            when 1 => seg <= "1111001";
            when 2 => seg <= "0100100";
            when 3 => seg <= "0110000";
            when 4 => seg <= "0011001";
            when 5 => seg <= "0010010";
            when 6 => seg <= "0000010";
            when 7 => seg <= "1111000";
            when 8 => seg <= "0000000";
            when 9 => seg <= "0010000";
            when others => seg <= "1111111";  -- blank
        end case;
    end process;
end behavioral;
