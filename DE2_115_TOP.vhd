--
-- DE2-115 top-level module (entity declaration)
--
-- William H. Robinson, Vanderbilt University University
--   william.h.robinson@vanderbilt.edu
--
-- Updated from the DE2 top-level module created by 
-- Stephen A. Edwards, Columbia University, sedwards@cs.columbia.edu
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DE2_115_TOP is
  generic (
    TICKS_PER_SECOND : natural := 50_000_000  -- default for 50 MHz CLOCK_50
  );
  port (
    -- Clocks
    
    CLOCK_50 	: in std_logic;                     -- 50 MHz
    CLOCK2_50 	: in std_logic;                     -- 50 MHz
    CLOCK3_50 	: in std_logic;                     -- 50 MHz
    SMA_CLKIN  : in std_logic;                     -- External Clock Input
    SMA_CLKOUT : out std_logic;                    -- External Clock Output

    -- Buttons and switches
    
    KEY : in std_logic_vector(3 downto 0);         -- Push buttons
    SW  : in std_logic_vector(17 downto 0);        -- DPDT switches

    -- LED displays

    HEX0 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    HEX1 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    HEX2 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    HEX3 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    HEX4 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    HEX5 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    HEX6 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    HEX7 : out std_logic_vector(6 downto 0);       -- 7-segment display (active low)
    LEDG : out std_logic_vector(8 downto 0);       -- Green LEDs (active high)
    LEDR : out std_logic_vector(17 downto 0);      -- Red LEDs (active high)

    -- RS-232 interface

    UART_CTS : out std_logic;                      -- UART Clear to Send   
    UART_RTS : in std_logic;                       -- UART Request to Send   
    UART_RXD : in std_logic;                       -- UART Receiver
    UART_TXD : out std_logic;                      -- UART Transmitter   

    -- 16 X 2 LCD Module
    
    LCD_BLON : out std_logic;      							-- Back Light ON/OFF
    LCD_EN   : out std_logic;      							-- Enable
    LCD_ON   : out std_logic;      							-- Power ON/OFF
    LCD_RS   : out std_logic;	   							-- Command/Data Select, 0 = Command, 1 = Data
    LCD_RW   : out std_logic; 	   						-- Read/Write Select, 0 = Write, 1 = Read
    LCD_DATA : inout std_logic_vector(7 downto 0); 	-- Data bus 8 bits

    -- PS/2 ports

    PS2_CLK : inout std_logic;     -- Clock
    PS2_DAT : inout std_logic;     -- Data

    PS2_CLK2 : inout std_logic;    -- Clock
    PS2_DAT2 : inout std_logic;    -- Data

    -- VGA output
    
    VGA_BLANK_N : out std_logic;            -- BLANK
    VGA_CLK 	 : out std_logic;            -- Clock
    VGA_HS 		 : out std_logic;            -- H_SYNC
    VGA_SYNC_N  : out std_logic;            -- SYNC
    VGA_VS 		 : out std_logic;            -- V_SYNC
    VGA_R 		 : out unsigned(7 downto 0); -- Red[9:0]
    VGA_G 		 : out unsigned(7 downto 0); -- Green[9:0]
    VGA_B 		 : out unsigned(7 downto 0); -- Blue[9:0]

    -- SRAM
    
    SRAM_ADDR : out unsigned(19 downto 0);         -- Address bus 20 Bits
    SRAM_DQ   : inout unsigned(15 downto 0);       -- Data bus 16 Bits
    SRAM_CE_N : out std_logic;                     -- Chip Enable
    SRAM_LB_N : out std_logic;                     -- Low-byte Data Mask 
    SRAM_OE_N : out std_logic;                     -- Output Enable
    SRAM_UB_N : out std_logic;                     -- High-byte Data Mask 
    SRAM_WE_N : out std_logic;                     -- Write Enable

    -- Audio CODEC
    
    AUD_ADCDAT 	: in std_logic;               -- ADC Data
    AUD_ADCLRCK 	: inout std_logic;            -- ADC LR Clock
    AUD_BCLK 		: inout std_logic;            -- Bit-Stream Clock
    AUD_DACDAT 	: out std_logic;              -- DAC Data
    AUD_DACLRCK 	: inout std_logic;            -- DAC LR Clock
    AUD_XCK 		: out std_logic               -- Chip Clock
    
    );
  
end DE2_115_TOP;

architecture Lab3 of DE2_115_TOP is
	-- problem 1 --
	signal key_first_stage : std_logic := '1';	-- keys are active low
	signal key_second_stage : std_logic := '1';
	
	signal debounced : std_logic := '1';	-- set to 1 because keys active low
	signal debounce_count : unsigned(19 downto 0):= (others => '0');	-- for 20ms debouncing
	
	signal s1 : std_logic := '1';
	signal sp : std_logic := '0';
	
	constant DEBOUNCE_MAX : unsigned(19 downto 0) := to_unsigned(1_000_000-1, 20);	-- 50 MHz * 20 ms = 1,000,000 counts
	
	-- problem 2 --
	signal Q1 : std_logic_vector(6 downto 0) := (others => '0');
	signal Q2 : std_logic_vector(6 downto 0) := (others => '0');
	signal Q3 : std_logic_vector(6 downto 0) := (others => '0');
	signal Q4 : std_logic_vector(6 downto 0) := (others => '0');
	signal Q5 : std_logic_vector(6 downto 0) := (others => '0');
	signal Q6 : std_logic_vector(6 downto 0) := (others => '0');
	signal Q7 : std_logic_vector(6 downto 0) := (others => '0');
	signal Q8 : std_logic_vector(6 downto 0) := (others => '0');
	
	-- din uses switches 0-6
	-- shift_left control uses button, implementing single-pulse from part 1
	-- reset uses switch 7
	
begin

-- Problem 1 --
	process(CLOCK_50)
	begin
		 if rising_edge(CLOCK_50) then
			-- using a 2FF synchronizer from lecture slides
			key_first_stage <= KEY(0);	
			key_second_stage <= key_first_stage;
			
			-- 20 ms debouncing
			if key_second_stage /= debounced then
				-- check if key has been pressed for >20 ms
				if debounce_count = DEBOUNCE_MAX then
					debounced <= key_second_stage;
					debounce_count <= (others => '0');
				else
					debounce_count <= debounce_count + 1;
				end if;
			else
				debounce_count <= (others => '0');
			end if;
			
			-- using single-pulse circuit from slides
			s1 <= debounced;
			sp <= (not debounced) and s1; -- opposite from slides because of active-low button, sp is active-high
		 end if;
	end process;
		-- outside of process so flip flops aren't created
		 LEDR(0) <= not debounced; -- stable debounced level signal
		 LEDR(1) <= sp; -- one-clock-cycle pulse
	

	-- Part 2 --
	process(CLOCK_50) begin
		if rising_edge(CLOCK_50) then
			if SW(7) = '1' then			-- switch 7 used as reset signal
				Q1 <= (others => '0');
				Q2 <= (others => '0');
				Q3 <= (others => '0');
				Q4 <= (others => '0');
				Q5 <= (others => '0');
				Q6 <= (others => '0');
				Q7 <= (others => '0');
				Q8 <= (others => '0');
			elsif sp = '1' then
				Q1 <= SW(6 downto 0);	-- next data comes from switches 6 (MSB) through 0 (LSB)
				Q2 <= Q1;
				Q3 <= Q2;
				Q4 <= Q3;
            Q5 <= Q4;
            Q6 <= Q5;
            Q7 <= Q6;
            Q8 <= Q7;
			end if;
		end if;
	end process;
	-- vvvv NOTE TO ANDREW LOPEZ-COUTO ==> This is for debugging, you can delete these vvvv --
		-- "data" is showed by which segment within hex0 through hex7 is lit up
		HEX0 <= not Q1;
		HEX1 <= not Q2;
		HEX2 <= not Q3;
		HEX3 <= not Q4;
		HEX4 <= not Q5;
		HEX5 <= not Q6;
		HEX6 <= not Q7;
		HEX7 <= not Q8;
	-- ^^^^ NOTE TO ANDREW LOPEZ-COUTO ==> This is for debugging, you can delete these ^^^^ --	
end Lab3;