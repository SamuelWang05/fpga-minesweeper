library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CELL_CALC is
    port (
        mine_map   : in  std_logic_vector(99  downto 0);
        adj_counts : out std_logic_vector(399 downto 0)
    );
end CELL_CALC;

architecture behavioral of CELL_CALC is

    -- Define a 2D array type to make spatial logic much easier to read
    type map_2d_type is array (0 to 9, 0 to 9) of std_logic;
    signal map_2d : map_2d_type;
    
begin

    -- 1. Unpack the 1D input vector into our 2D array
    -- This wires the inputs directly without requiring clock cycles.
    gen_row: for r in 0 to 9 generate
        gen_col: for c in 0 to 9 generate
            map_2d(r, c) <= mine_map(r * 10 + c);
        end generate;
    end generate;

    -- 2. Combinational process to calculate all adjacent counts in parallel
    process(map_2d)
        variable count : unsigned(3 downto 0);
        variable r_min, r_max, c_min, c_max : integer;
        variable cell_idx : integer;
    begin
        -- Loop through every single cell on the board
        for r in 0 to 9 loop
            for c in 0 to 9 loop
                
                -- Calculate the 1D index for the output vector
                cell_idx := r * 10 + c;
                
                if map_2d(r, c) = '1' then
                    -- If the cell is a mine, skip counting and output "1111"
                    -- This matches the encoding expected by your RGB_MUX module.
                    adj_counts((cell_idx * 4) + 3 downto cell_idx * 4) <= "1111";
                else
                    count := (others => '0');
                    
                    -- Determine search boundaries to prevent index out-of-bounds at the edges
                    if r = 0 then r_min := 0; else r_min := r - 1; end if;
                    if r = 9 then r_max := 9; else r_max := r + 1; end if;
                    if c = 0 then c_min := 0; else c_min := c - 1; end if;
                    if c = 9 then c_max := 9; else c_max := c + 1; end if;

                    -- Loop through a 3x3 grid around the target cell
                    for i in r_min to r_max loop
                        for j in c_min to c_max loop
                            
                            -- Only increment if it's a mine AND it's not the center cell itself
                            if (not (i = r and j = c)) and (map_2d(i, j) = '1') then
                                count := count + 1;
                            end if;
                            
                        end loop;
                    end loop;

                    -- Assign the final calculated count to the correct 4-bit output slice
                    adj_counts((cell_idx * 4) + 3 downto cell_idx * 4) <= std_logic_vector(count);
                end if;
                
            end loop;
        end loop;
    end process;
    
end behavioral;