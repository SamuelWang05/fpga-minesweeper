-- RGB_MUX.vhd
-- Decides the RGB output for every pixel.
-- 
-- Grid layout (1024x768 display):
--   The 10x10 grid is centred on screen.
--   Each cell is 48x48 pixels with a 2-pixel border.
--   Grid starts at pixel (GRID_X0, GRID_Y0).
--
-- Cell visual states
--   HIDDEN   : medium grey   (unrevealed)
--   FLAGGED  : yellow        (player-flagged)
--   REVEALED + count 0       : dark grey  (empty)
--   REVEALED + count 1-8     : dark grey bg + colour digit (simplified: tint by count)
--   REVEALED + mine (0xF)    : red        (game-over explosion cell)
--   CURSOR   : bright white border overlay
--
-- Cell state encoding (2 bits per cell packed in cell_state, 200 bits total)
--   "00" = HIDDEN
--   "01" = FLAGGED
--   "10" = REVEALED
--   "11" = reserved
--
-- adj_counts encoding (4 bits per cell, 400 bits total)
--   "1111" = mine cell
--   others = neighbour mine count 0-8

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity RGB_MUX is
    port (
        pixel_clk  : in  std_logic;
        pixel_col  : in  std_logic_vector(10 downto 0);  -- current pixel X (0-1023)
        pixel_row  : in  std_logic_vector(10 downto 0);  -- current pixel Y (0-767)
        video_on   : in  std_logic;

        -- Game state
        cell_state : in  std_logic_vector(199 downto 0); -- 2 bits per cell, 100 cells
        adj_counts : in  std_logic_vector(399 downto 0); -- 4 bits per cell, 100 cells
        cursor_row : in  unsigned(3 downto 0);           -- 0-9
        cursor_col : in  unsigned(3 downto 0);           -- 0-9
        game_over  : in  std_logic;                       -- '1' = lost
        game_won   : in  std_logic;                       -- '1' = won

        -- Output colour
        red        : out std_logic_vector(7 downto 0);
        green      : out std_logic_vector(7 downto 0);
        blue       : out std_logic_vector(7 downto 0)
    );
end RGB_MUX;

architecture rtl of RGB_MUX is

    -- Grid geometry constants (1024x768 display)
    constant CELL_SIZE  : integer := 48;   -- pixels per cell (including border)
    constant BORDER     : integer := 2;    -- border thickness in pixels
    constant GRID_COLS  : integer := 10;
    constant GRID_ROWS  : integer := 10;
    constant GRID_W     : integer := GRID_COLS * CELL_SIZE;  -- 480
    constant GRID_H     : integer := GRID_ROWS * CELL_SIZE;  -- 480
    constant GRID_X0    : integer := (1024 - GRID_W) / 2;    -- 272
    constant GRID_Y0    : integer := (768  - GRID_H) / 2;    -- 144

    -- Colour palette
    constant COL_BG        : std_logic_vector(23 downto 0) := x"1A1A2E";  -- dark navy background
    constant COL_BORDER    : std_logic_vector(23 downto 0) := x"000000";  -- black border
    constant COL_HIDDEN    : std_logic_vector(23 downto 0) := x"9E9E9E";  -- medium grey
    constant COL_REVEALED  : std_logic_vector(23 downto 0) := x"C8C8C8";  -- light grey
    constant COL_EMPTY     : std_logic_vector(23 downto 0) := x"D0D0D0";  -- slightly lighter
    constant COL_FLAG      : std_logic_vector(23 downto 0) := x"FFD700";  -- gold / yellow
    constant COL_MINE      : std_logic_vector(23 downto 0) := x"FF2222";  -- red
    constant COL_CURSOR    : std_logic_vector(23 downto 0) := x"00E5FF";  -- cyan highlight
    constant COL_WIN       : std_logic_vector(23 downto 0) := x"00FF88";  -- green win flash

    -- Number colours for counts 1-8
    type colour_array is array(0 to 8) of std_logic_vector(23 downto 0);
    constant NUM_COLOUR : colour_array := (
        x"D0D0D0",   -- 0: empty (shouldn't normally render digit)
        x"0000FF",   -- 1: blue
        x"007700",   -- 2: dark green
        x"FF0000",   -- 3: red
        x"00007B",   -- 4: dark blue
        x"7B0000",   -- 5: dark red
        x"007B7B",   -- 6: teal
        x"000000",   -- 7: black
        x"808080"    -- 8: grey
    );

    -- Pixel coordinates as integers
    signal px : integer range 0 to 1023;
    signal py : integer range 0 to 767;

    -- Grid-relative coordinates
    signal in_grid   : std_logic;
    signal cell_x    : integer range 0 to 9;   -- column index
    signal cell_y    : integer range 0 to 9;   -- row index
    signal local_x   : integer range 0 to 47;  -- pixel within cell (X)
    signal local_y   : integer range 0 to 47;  -- pixel within cell (Y)
    signal on_border : std_logic;
    signal on_cursor : std_logic;

    -- Cell index and state
    signal cell_idx  : integer range 0 to 99;
    signal cstate    : std_logic_vector(1 downto 0);
    signal acount    : std_logic_vector(3 downto 0);
    signal is_mine   : std_logic;

    -- Final colour
    signal out_rgb   : std_logic_vector(23 downto 0);

    -- Simple digit renderer: returns '1' if pixel (lx, ly) within a 12x20
    -- digit box (centred in cell interior) is part of the given digit 0-8.
    -- Uses a simplified 5x7 segment pattern stored as a 35-bit constant.
    -- For brevity we implement each digit as a set of filled rectangles.
    function digit_on(digit : integer; lx : integer; ly : integer) return std_logic is
        -- Cell interior is 44x44 (after 2px border).
        -- Digit box occupies central 20x28 pixels within interior.
        -- Origin of digit box: (12, 8) inside interior.
        constant DX0 : integer := 12;
        constant DY0 : integer := 8;
        constant DW  : integer := 20;
        constant DH  : integer := 28;
        variable dx : integer;
        variable dy : integer;
    begin
        -- Interior offset (remove border)
        dx := lx - BORDER - DX0;
        dy := ly - BORDER - DY0;

        -- Out of digit box?
        if dx < 0 or dx >= DW or dy < 0 or dy >= DH then
            return '0';
        end if;

        -- Each digit is defined by simple horizontal/vertical bars
        -- Bars: top(T), mid(M), bot(B), tl(TL), tr(TR), bl(BL), br(BR)
        -- Segment coordinates (within the 20x28 box):
        --   T  : y in [0,3],   x in [2,17]
        --   M  : y in [12,15], x in [2,17]
        --   B  : y in [24,27], x in [2,17]
        --   TL : x in [0,3],   y in [2,13]
        --   TR : x in [16,19], y in [2,13]
        --   BL : x in [0,3],   y in [14,25]
        --   BR : x in [16,19], y in [14,25]

        -- Segment presence table:    T   TL  TR   M   BL  BR   B
        -- 1: only TR, BR
        -- 2: T, TR, M, BL, B
        -- 3: T, TR, M, BR, B
        -- 4: TL, TR, M, BR
        -- 5: T, TL, M, BR, B
        -- 6: T, TL, M, BL, BR, B
        -- 7: T, TR, BR
        -- 8: all segments

        case digit is
            when 1 =>
                if (dx >= 16 and dx <= 19 and dy >= 2  and dy <= 25) then return '1'; end if;
            when 2 =>
                if (dy >= 0  and dy <= 3  and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 16 and dx <= 19 and dy >= 2  and dy <= 13) then return '1'; end if;
                if (dy >= 12 and dy <= 15 and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 0  and dx <= 3  and dy >= 14 and dy <= 25) then return '1'; end if;
                if (dy >= 24 and dy <= 27 and dx >= 2  and dx <= 17) then return '1'; end if;
            when 3 =>
                if (dy >= 0  and dy <= 3  and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 16 and dx <= 19 and dy >= 2  and dy <= 25) then return '1'; end if;
                if (dy >= 12 and dy <= 15 and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dy >= 24 and dy <= 27 and dx >= 2  and dx <= 17) then return '1'; end if;
            when 4 =>
                if (dx >= 0  and dx <= 3  and dy >= 2  and dy <= 13) then return '1'; end if;
                if (dx >= 16 and dx <= 19 and dy >= 2  and dy <= 25) then return '1'; end if;
                if (dy >= 12 and dy <= 15 and dx >= 2  and dx <= 17) then return '1'; end if;
            when 5 =>
                if (dy >= 0  and dy <= 3  and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 0  and dx <= 3  and dy >= 2  and dy <= 13) then return '1'; end if;
                if (dy >= 12 and dy <= 15 and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 16 and dx <= 19 and dy >= 14 and dy <= 25) then return '1'; end if;
                if (dy >= 24 and dy <= 27 and dx >= 2  and dx <= 17) then return '1'; end if;
            when 6 =>
                if (dy >= 0  and dy <= 3  and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 0  and dx <= 3  and dy >= 2  and dy <= 25) then return '1'; end if;
                if (dy >= 12 and dy <= 15 and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 16 and dx <= 19 and dy >= 14 and dy <= 25) then return '1'; end if;
                if (dy >= 24 and dy <= 27 and dx >= 2  and dx <= 17) then return '1'; end if;
            when 7 =>
                if (dy >= 0  and dy <= 3  and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 16 and dx <= 19 and dy >= 2  and dy <= 25) then return '1'; end if;
            when 8 =>
                if (dy >= 0  and dy <= 3  and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dx >= 0  and dx <= 3  and dy >= 2  and dy <= 25) then return '1'; end if;
                if (dx >= 16 and dx <= 19 and dy >= 2  and dy <= 25) then return '1'; end if;
                if (dy >= 12 and dy <= 15 and dx >= 2  and dx <= 17) then return '1'; end if;
                if (dy >= 24 and dy <= 27 and dx >= 2  and dx <= 17) then return '1'; end if;
            when others => null;
        end case;
        return '0';
    end function;

    -- Draw an "F" (flag) glyph in a cell
    function flag_on(lx : integer; ly : integer) return std_logic is
        variable dx, dy : integer;
    begin
        dx := lx - BORDER - 12;
        dy := ly - BORDER - 4;
        if dx < 0 or dx >= 20 or dy < 0 or dy >= 28 then return '0'; end if;
        -- Vertical pole
        if dx >= 8 and dx <= 11 then return '1'; end if;
        -- Flag rectangle (top-left quadrant of pole)
        if dy <= 13 and dx >= 0 and dx <= 11 then return '1'; end if;
        return '0';
    end function;

    -- Draw a simple "X" / burst for mine
    function mine_glyph_on(lx : integer; ly : integer) return std_logic is
        variable dx, dy : integer;
        variable adx, ady : integer;
    begin
        dx  := lx - CELL_SIZE/2;
        dy  := ly - CELL_SIZE/2;
        adx := abs(dx);
        ady := abs(dy);
        -- Thick cross
        if adx <= 3 and ady <= 16 then return '1'; end if;
        if ady <= 3 and adx <= 16 then return '1'; end if;
        -- Diagonals
        if adx = ady and adx <= 12 then return '1'; end if;
        if adx - 1 = ady and adx <= 12 then return '1'; end if;
        if ady - 1 = adx and ady <= 12 then return '1'; end if;
        return '0';
    end function;

begin

    -- Convert std_logic pixel coordinates to integers
    px <= to_integer(unsigned(pixel_col));
    py <= to_integer(unsigned(pixel_row));

    -- Determine if pixel is within the grid area
    in_grid <= '1' when (px >= GRID_X0 and px < GRID_X0 + GRID_W and
                         py >= GRID_Y0 and py < GRID_Y0 + GRID_H) else '0';

    -- Grid-relative cell indices and local pixel offsets
    cell_x  <= (px - GRID_X0) / CELL_SIZE when in_grid = '1' else 0;
    cell_y  <= (py - GRID_Y0) / CELL_SIZE when in_grid = '1' else 0;
    local_x <= (px - GRID_X0) mod CELL_SIZE when in_grid = '1' else 0;
    local_y <= (py - GRID_Y0) mod CELL_SIZE when in_grid = '1' else 0;

    -- Border detection (within cell)
    on_border <= '1' when (local_x < BORDER or local_x >= CELL_SIZE - BORDER or
                           local_y < BORDER or local_y >= CELL_SIZE - BORDER) else '0';

    -- Cursor highlight (outermost 2 pixels of the cursor cell)
    on_cursor <= '1' when (in_grid = '1' and
                           cell_x = to_integer(cursor_col) and
                           cell_y = to_integer(cursor_row) and
                           (local_x < BORDER or local_x >= CELL_SIZE - BORDER or
                            local_y < BORDER or local_y >= CELL_SIZE - BORDER))
                 else '0';

    cell_idx <= cell_y * 10 + cell_x;
    cstate   <= cell_state(cell_idx*2+1 downto cell_idx*2);
    acount   <= adj_counts(cell_idx*4+3 downto cell_idx*4);
    is_mine  <= '1' when acount = "1111" else '0';

    -- -----------------------------------------------------------------------
    -- Colour selection combinational process
    -- -----------------------------------------------------------------------
    process(px, py, in_grid, on_border, on_cursor, cell_x, cell_y,
            local_x, local_y, cell_idx, cstate, acount, is_mine,
            cursor_col, cursor_row, game_over, game_won, video_on)
        variable rgb : std_logic_vector(23 downto 0);
        variable cnt : integer range 0 to 15;
    begin
        rgb := COL_BG;
        cnt := to_integer(unsigned(acount));

        if video_on = '1' then
            if in_grid = '1' then

                if on_cursor = '1' then
                    -- Cursor border overrides everything
                    if game_won = '1' then
                        rgb := COL_WIN;
                    else
                        rgb := COL_CURSOR;
                    end if;

                elsif on_border = '1' then
                    rgb := COL_BORDER;

                else
                    -- Interior of cell
                    case cstate is

                        when "00" =>  -- HIDDEN
                            rgb := COL_HIDDEN;

                        when "01" =>  -- FLAGGED
                            if flag_on(local_x, local_y) = '1' then
                                rgb := x"FF4500";   -- orange-red flag
                            else
                                rgb := COL_HIDDEN;
                            end if;

                        when "10" =>  -- REVEALED
                            if is_mine = '1' then
                                -- Mine cell (game over)
                                if mine_glyph_on(local_x, local_y) = '1' then
                                    rgb := x"000000";
                                else
                                    rgb := COL_MINE;
                                end if;
                            elsif cnt = 0 then
                                rgb := COL_EMPTY;
                            else
                                -- Draw number
                                if digit_on(cnt, local_x, local_y) = '1' then
                                    rgb := NUM_COLOUR(cnt);
                                else
                                    rgb := COL_REVEALED;
                                end if;
                            end if;

                        when others =>
                            rgb := COL_BG;

                    end case;
                end if;

            else
                rgb := COL_BG;
            end if;
        else
            rgb := x"000000";
        end if;

        out_rgb <= rgb;
    end process;

    red   <= out_rgb(23 downto 16);
    green <= out_rgb(15 downto 8);
    blue  <= out_rgb(7  downto 0);

end rtl;