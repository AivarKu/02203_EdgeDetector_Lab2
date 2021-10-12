-- -----------------------------------------------------------------------------
--
--  Title      :  Edge-Detection design project - task 2.
--             :
--  Developers :  YOUR NAME HERE - s??????@student.dtu.dk
--             :  YOUR NAME HERE - s??????@student.dtu.dk
--             :
--  Purpose    :  This design contains an entity for the accelerator that must be build
--             :  in task two of the Edge Detection design project. It contains an
--             :  architecture skeleton for the entity as well.
--             :
--  Revision   :  1.0   ??-??-??     Final version
--             :
--
-- -----------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- The entity for task two. Notice the additional signals for the memory.
-- reset is active high.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity acc_real is
    port(
        clk    : in  bit_t;             -- The clock.
        reset  : in  bit_t;             -- The reset signal. Active high.
        addr   : out halfword_t;        -- Address bus for data.
        dataR  : in  word_t;            -- The data bus.
        dataW  : out word_t;            -- The data bus.
        en     : out bit_t;             -- Request signal for data.
        we     : out bit_t;             -- Read/Write signal for data.
        start  : in  bit_t;
        finish : out bit_t
    );
end acc_real;

-- Image is 288*352 pixels

architecture rtl of acc_real is

    constant ram_wr_offset              : integer := 25344;
    constant WORD_7_0_PIXEL_LOAD_POS    : integer := 352;
    constant WORD_15_8_PIXEL_LOAD_POS   : integer := 351;
    constant WORD_23_16_PIXEL_LOAD_POS  : integer := 350;
    constant WORD_31_24_PIXEL_LOAD_POS  : integer := 349;

    type state_type is (WAIT_START, SHIFT_ROWS, FETCH_DATA, READ_ROW, WRITE, WRITE_LAST_ROW, STOP); -- Input your own state names
    signal state, next_state : state_type;

    signal addr_cnt_ena     : std_logic;
    signal addr_cnt         : unsigned(15 downto 0);
    signal addr_read_cnt    : unsigned(15 downto 0);
    signal addr_write_cnt   : unsigned(15 downto 0);
    signal addr_cnt_done    : std_logic;
    signal read_row_cnt     : integer range 0 to 287;
    
    signal loadDataToRow0   : std_logic;
    signal shiftAllRowsUp   : std_logic;
    signal shiftAllRowsLeft : std_logic;
    
    type pixel_row_type is array (0 to 353) of unsigned(7 downto 0); -- Row is two pixels wider than image to enable edge handling
    signal pixel_row_0 : pixel_row_type;
    signal pixel_row_1 : pixel_row_type;
    signal pixel_row_2 : pixel_row_type;
    
    signal pixel0 : std_logic_vector(7 downto 0);
    signal pixel1 : std_logic_vector(7 downto 0);
    signal pixel2 : std_logic_vector(7 downto 0);
    signal pixel3 : std_logic_vector(7 downto 0);


begin


    address_cnt : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                addr_cnt <= (others => '0');
                addr_read_cnt <= (others => '0');
                addr_write_cnt <= (others => '0');
                read_row_cnt <= 0;
                addr_cnt_done <= '0';
            else
                addr_cnt_done <= '0';
                if addr_cnt_ena = '1' then
                    if we = '0' then  -- Read address counter
                        if addr_cnt = 88-1 then
                            addr_cnt_done <= '1';
                            addr_cnt <= (others => '0');
                            addr_read_cnt <= addr_read_cnt + to_unsigned(88, addr_read_cnt'length);
                            read_row_cnt <= read_row_cnt + 1;
                        elsif addr_cnt_done = '0' then
                            addr_cnt <= addr_cnt + 1;
                        end if;
                         
                     else -- Write address counter
                        if addr_cnt = 88-2 then
                            addr_cnt_done <= '1';
                        end if;
                        
                        if addr_cnt = 88-1 then
                            addr_cnt <= (others => '0');
                            addr_write_cnt <= addr_write_cnt + to_unsigned(88, addr_write_cnt'length);
                        else
                            addr_cnt <= addr_cnt + 1;
                        end if;
                     end if;
                 end if;
            end if;
        end if;
    end process;
    
    addr <= std_logic_vector(addr_read_cnt + addr_cnt) when we = '0' else
            std_logic_vector(addr_write_cnt + addr_cnt + ram_wr_offset);
            
    pixel0 <= std_logic_vector(pixel_row_1(4));
    pixel1 <= std_logic_vector(pixel_row_1(3));
    pixel2 <= std_logic_vector(pixel_row_1(2));
    pixel3 <= std_logic_vector(pixel_row_1(1));
            
         
    -- Pixel ring shift registers
    ring_shft: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pixel_row_0 <= (others => (others => '0'));
                pixel_row_1 <= (others => (others => '0'));
                pixel_row_2 <= (others => (others => '0'));
            else
                if loadDataToRow0 = '1' then
                    -- Load in new word
                    pixel_row_0(WORD_7_0_PIXEL_LOAD_POS) <= unsigned(dataR(7 downto 0));
                    pixel_row_0(WORD_15_8_PIXEL_LOAD_POS) <= unsigned(dataR(15 downto 8));
                    pixel_row_0(WORD_23_16_PIXEL_LOAD_POS) <= unsigned(dataR(23 downto 16));
                    pixel_row_0(WORD_31_24_PIXEL_LOAD_POS) <= unsigned(dataR(31 downto 24));
                    
                    -- Shift other data
                    for i in 352 downto 5 loop
                        pixel_row_0(i-4) <= pixel_row_0(i);
                    end loop;
                    
                elsif shiftAllRowsUp = '1' then
                    for i in 352 downto 1 loop
                        pixel_row_2(i) <= pixel_row_1(i);
                        pixel_row_1(i) <= pixel_row_0(i);
                    end loop;
                    pixel_row_0 <= (others => (others => '0'));
                    
                elsif shiftAllRowsLeft = '1' then -- Ringbuffer shift
                    for i in 352 downto 5 loop
                        pixel_row_2(i-4) <= pixel_row_2(i);
                        pixel_row_1(i-4) <= pixel_row_1(i);
                        pixel_row_0(i-4) <= pixel_row_0(i);
                    end loop;
                    pixel_row_2(352-0) <= pixel_row_2(4-0);
                    pixel_row_2(352-1) <= pixel_row_2(4-1);
                    pixel_row_2(352-2) <= pixel_row_2(4-2);
                    pixel_row_2(352-3) <= pixel_row_2(4-3);
                    pixel_row_1(352-0) <= pixel_row_1(4-0);
                    pixel_row_1(352-1) <= pixel_row_1(4-1);
                    pixel_row_1(352-2) <= pixel_row_1(4-2);
                    pixel_row_1(352-3) <= pixel_row_1(4-3);
                    pixel_row_0(352-0) <= pixel_row_0(4-0);
                    pixel_row_0(352-1) <= pixel_row_0(4-1);
                    pixel_row_0(352-2) <= pixel_row_0(4-2);
                    pixel_row_0(352-3) <= pixel_row_0(4-3);
                    
                end if;
            end if;
        end if;
    end process;

    
    -- FSM Combinatoriel logic
    fsm_cl : process (all)
    begin
        next_state  <= WAIT_START;
        en <= '1';
        we <= '0';
        finish <= '0';
        addr_cnt_ena <= '0';
        dataW <= (others => '0');
        loadDataToRow0 <= '0';
        shiftAllRowsUp <= '0';
        shiftAllRowsLeft <= '0';
    
        case (state) is    
            when WAIT_START =>
                en <= '0';
                if start = '1' then
                    next_state  <= SHIFT_ROWS;
                end if;  
                
            when SHIFT_ROWS =>
                shiftAllRowsUp <= '1';
                if read_row_cnt >= 288 then
                    next_state  <= WRITE_LAST_ROW;
                else 
                    next_state  <= FETCH_DATA;
                end if;
                
            when FETCH_DATA =>
                addr_cnt_ena <= '1';
                if start = '1' then
                    next_state  <= READ_ROW;
                end if;  
                     
            when READ_ROW =>
                loadDataToRow0 <= '1';
                addr_cnt_ena <= '1';
                if addr_cnt_done = '1' then
                    if read_row_cnt >= 3-1 then
                        next_state  <= WRITE;
                    else
                        next_state  <= SHIFT_ROWS;
                    end if;
                else
                    next_state  <= READ_ROW;
                end if; 
      
            when WRITE =>
                we <= '1';
                addr_cnt_ena <= '1';
                shiftAllRowsLeft <= '1';
                dataW <= pixel3 & pixel2 & pixel1 & pixel0;
                
                if addr_cnt_done = '1' then
                    next_state  <= SHIFT_ROWS;
                else
                    next_state  <= WRITE;
                end if;   
                
            when WRITE_LAST_ROW =>
                we <= '1';
                addr_cnt_ena <= '1';
                shiftAllRowsLeft <= '1';
                dataW <= pixel3 & pixel2 & pixel1 & pixel0;
                
                if addr_cnt_done = '1' then
                    next_state  <= STOP;
                else
                    next_state  <= WRITE_LAST_ROW;
                end if;    
                
            when STOP =>
                finish <= '1';
                next_state  <= WAIT_START;
            
            when others =>
                next_state <= WAIT_START;
        
        end case;
    end process;
    
    -- FSM Registers
    fsm_seq : process (clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= WAIT_START;
            else
                state <= next_state;
            end if;
        end if;
    end process;


end rtl;
