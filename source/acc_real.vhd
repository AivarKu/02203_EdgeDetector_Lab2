-- -----------------------------------------------------------------------------
--
--  Title      :  Edge-Detection design project - task 2.
--             :
--  Developers :  Pawel Tomasz Pieta - s202606@student.dtu.dk
--             :  Aivar Külle - s202963@student.dtu.dk
--             :
--  Purpose    :  This design contains an entity for the accelerator that must be build
--             :  in task two of the Edge Detection design project. It contains an
--             :  architecture skeleton for the entity as well.
--             :
--  Revision   :  1.0   04-11-2021    Final version
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
    constant WORD_7_0_PIXEL_LOAD_POS    : integer := 349;
    constant WORD_15_8_PIXEL_LOAD_POS   : integer := 350;
    constant WORD_23_16_PIXEL_LOAD_POS  : integer := 351;
    constant WORD_31_24_PIXEL_LOAD_POS  : integer := 352;

    type state_type is (WAIT_START, FIRST_FETCH, FIRST_READ, FIRST_SHIFT, SECOND_FETCH, SECOND_READ, FIRST_DO_EDGES,
    SHIFT_ROWS, FETCH_DATA, READ_ROW, WRITE, DO_EDGES, LAST_DO_EDGES, WRITE_LAST_ROW, STOP);
    signal state, next_state : state_type;

    signal addr_cnt         : unsigned(15 downto 0);
    signal addr_read_offset : unsigned(15 downto 0);
    signal addr_write_offset: unsigned(15 downto 0);
    signal addr_cnt_done    : std_logic;
    signal read_row_cnt     : integer range 0 to 288;
    
    signal addr_cnt_ena     : std_logic;
    signal loadDataToRow0   : std_logic;
    signal shiftAllRowsUp   : std_logic;
    signal shiftAllRowsLeft : std_logic;
    signal shiftAllRowsLeftHalf : std_logic;
    signal first_fill_edges : std_logic;
    signal fill_edges       : std_logic;
    signal last_fill_edges  : std_logic;
    
    type pixel_row_type is array (0 to 353) of unsigned(7 downto 0); -- Row is two pixels wider than image to enable edge handling
    signal pixel_row_0 : pixel_row_type;
    signal pixel_row_1 : pixel_row_type;
    signal pixel_row_2 : pixel_row_type;
    
    type pixelOut_type is array (0 to 3) of unsigned(7 downto 0);
    signal pixelsOut : pixelOut_type;
    
    signal pixelOut0 : std_logic_vector(7 downto 0);
    signal pixelOut1 : std_logic_vector(7 downto 0);
    signal pixelOut2 : std_logic_vector(7 downto 0);
    signal pixelOut3 : std_logic_vector(7 downto 0);
    
    component sobel is
    Port 
    ( 
        s11 : in unsigned(7 downto 0);
        s12 : in unsigned(7 downto 0);
        s13 : in unsigned(7 downto 0);
        s21 : in unsigned(7 downto 0);
        --    s22 : in unsigned(8 downto 0);
        s23 : in unsigned(7 downto 0);
        s31 : in unsigned(7 downto 0);
        s32 : in unsigned(7 downto 0);
        s33 : in unsigned(7 downto 0);
        pix_out : out unsigned(7 downto 0)
    );
    end component;
    
begin


    address_cnt : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or state = WAIT_START then
                addr_cnt <= (others => '0');
                addr_read_offset <= (others => '0');
                addr_write_offset <= (others => '0');
                read_row_cnt <= 0;
                addr_cnt_done <= '0';
            else
                addr_cnt_done <= '0';

                
                if addr_cnt_ena = '1' then
                    if we = '0' then  -- Read address counter
                        if addr_cnt = 88-1 then
                            addr_cnt_done <= '1';
                            addr_cnt <= (others => '0');
                            addr_read_offset <= addr_read_offset + to_unsigned(88, addr_read_offset'length);
                            read_row_cnt <= read_row_cnt + 1;
                        elsif addr_cnt_done = '0' then
                            addr_cnt <= addr_cnt + 1;
                        end if;
                         
                     else -- Write address counter
                        if addr_cnt = 88-1 then
                            addr_cnt_done <= '1';
                        end if;
                        
                        if addr_cnt = 88 then
                            addr_cnt <= (others => '0');
                            addr_write_offset <= addr_write_offset + to_unsigned(88, addr_write_offset'length);
                        else
                            addr_cnt <= addr_cnt + 1;
                        end if;
                     end if;
                 end if;
            end if;
        end if;
    end process;
    
    addr <= std_logic_vector(addr_cnt + addr_read_offset) when we = '0' else
            std_logic_vector(addr_cnt + addr_write_offset + ram_wr_offset);
            
    
    -- 4 Sobel operators
    sob_gen: for i in 0 to 3 generate
        sob: sobel port map
        ( 
            s11 => pixel_row_2(0 + i),
            s12 => pixel_row_2(1 + i),
            s13 => pixel_row_2(2 + i),
            s21 => pixel_row_1(0 + i),
            --    s22 : in unsigned(8 downto 0);
            s23 => pixel_row_1(2 + i),
            s31 => pixel_row_0(0 + i),
            s32 => pixel_row_0(1 + i),
            s33 => pixel_row_0(2 + i),
            pix_out => pixelsOut(i)
        );
    end generate;
    
    pixelOut0 <= std_logic_vector(pixelsOut(0));
    pixelOut1 <= std_logic_vector(pixelsOut(1));
    pixelOut2 <= std_logic_vector(pixelsOut(2));
    pixelOut3 <= std_logic_vector(pixelsOut(3));
            
         
    -- Pixel ring shift registers
    ring_shft: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or state = WAIT_START then
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
                    for i in 353 downto 4 loop
                        pixel_row_2(i-4) <= pixel_row_2(i);
                        pixel_row_1(i-4) <= pixel_row_1(i);
                        pixel_row_0(i-4) <= pixel_row_0(i);
                    end loop;
                    pixel_row_2(353-0) <= pixel_row_2(3-0);
                    pixel_row_2(353-1) <= pixel_row_2(3-1);
                    pixel_row_2(353-2) <= pixel_row_2(3-2);
                    pixel_row_2(353-3) <= pixel_row_2(3-3);
                    pixel_row_1(353-0) <= pixel_row_1(3-0);
                    pixel_row_1(353-1) <= pixel_row_1(3-1);
                    pixel_row_1(353-2) <= pixel_row_1(3-2);
                    pixel_row_1(353-3) <= pixel_row_1(3-3);
                    pixel_row_0(353-0) <= pixel_row_0(3-0);
                    pixel_row_0(353-1) <= pixel_row_0(3-1);
                    pixel_row_0(353-2) <= pixel_row_0(3-2);
                    pixel_row_0(353-3) <= pixel_row_0(3-3);
                    
                elsif shiftAllRowsLeftHalf = '1' then -- Ringbuffer shift
                    for i in 353 downto 2 loop
                        pixel_row_2(i-2) <= pixel_row_2(i);
                        pixel_row_1(i-2) <= pixel_row_1(i);
                        pixel_row_0(i-2) <= pixel_row_0(i);
                    end loop;
                    pixel_row_2(353-0) <= pixel_row_2(1-0);
                    pixel_row_2(353-1) <= pixel_row_2(1-1);
                    pixel_row_1(353-0) <= pixel_row_1(1-0);
                    pixel_row_1(353-1) <= pixel_row_1(1-1);
                    pixel_row_0(353-0) <= pixel_row_0(1-0);
                    pixel_row_0(353-1) <= pixel_row_0(1-1);
                    
                elsif first_fill_edges = '1' then
                    pixel_row_2(0)              <= pixel_row_1(1);
                    for i in 1 to 353 loop
                        pixel_row_2(i) <= pixel_row_1(i);
                    end loop;
                    pixel_row_2(353)            <= pixel_row_1(352);
                    pixel_row_1(0)              <= pixel_row_1(1);
                    pixel_row_1(353)            <= pixel_row_1(352);
                    pixel_row_0(0)              <= pixel_row_0(1);
                    pixel_row_0(353)            <= pixel_row_0(352);
                    
                elsif fill_edges = '1' then -- All other rows
                    pixel_row_2(0)              <= pixel_row_2(1);      
                    pixel_row_2(353)            <= pixel_row_2(352);
                    pixel_row_1(0)              <= pixel_row_1(1);
                    pixel_row_1(353)            <= pixel_row_1(352);
                    pixel_row_0(0)              <= pixel_row_0(1);
                    pixel_row_0(353)            <= pixel_row_0(352);

                elsif last_fill_edges = '1' then
                    pixel_row_2(0)              <= pixel_row_2(1);      
                    pixel_row_2(353)            <= pixel_row_2(352);
                    pixel_row_1(0)              <= pixel_row_1(1);
                    pixel_row_1(353)            <= pixel_row_1(352);
                    pixel_row_0(0)              <= pixel_row_1(1);
                    for i in 1 to 353 loop
                        pixel_row_0(i) <= pixel_row_1(i);
                    end loop;
                    pixel_row_0(353)            <= pixel_row_1(352);
                    
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
        dataW <= (others => '0');
        addr_cnt_ena <= '0';
        loadDataToRow0 <= '0';
        shiftAllRowsUp <= '0';
        shiftAllRowsLeft <= '0';
        shiftAllRowsLeftHalf <= '0';
        first_fill_edges <= '0';
        fill_edges <= '0';
        last_fill_edges <= '0';
    
        case (state) is    
            when WAIT_START =>
                en <= '0';
                if start = '1' then
                    next_state  <= FIRST_FETCH;
                end if;  
                
            when FIRST_FETCH =>
                addr_cnt_ena <= '1';
                next_state  <= FIRST_READ;
                
            when FIRST_READ =>
                loadDataToRow0 <= '1';
                addr_cnt_ena <= '1';
                if addr_cnt_done = '1' then
                    next_state  <= FIRST_SHIFT;
                else
                    next_state  <= FIRST_READ;
                end if; 
                
            when FIRST_SHIFT =>
                shiftAllRowsUp <= '1';
                next_state  <= SECOND_FETCH;
                
            when SECOND_FETCH =>
                addr_cnt_ena <= '1';
                next_state  <= SECOND_READ;
                
            when SECOND_READ =>
                loadDataToRow0 <= '1';
                addr_cnt_ena <= '1';
                if addr_cnt_done = '1' then
                    next_state  <= FIRST_DO_EDGES;
                else
                    next_state  <= SECOND_READ;
                end if; 
                
            when FIRST_DO_EDGES =>
                 first_fill_edges <= '1';
                 next_state  <= WRITE;
                
            when SHIFT_ROWS =>
                shiftAllRowsUp <= '1';
                if read_row_cnt >= 288 then
                    next_state  <= LAST_DO_EDGES;
                else 
                    next_state  <= FETCH_DATA;
                end if;
                
            when FETCH_DATA =>
                addr_cnt_ena <= '1';
                next_state  <= READ_ROW;
                     
            when READ_ROW =>
                loadDataToRow0 <= '1';
                addr_cnt_ena <= '1';
                if addr_cnt_done = '1' then
                    if read_row_cnt >= 2 then
                        next_state  <= DO_EDGES;
                    else
                        next_state  <= SHIFT_ROWS;
                    end if;
                else
                    next_state  <= READ_ROW;
                end if; 
                
            when DO_EDGES =>
                 fill_edges <= '1';
                 next_state  <= WRITE;
      
            when WRITE =>
                we <= '1';
                addr_cnt_ena <= '1';
                if addr_cnt_done = '0' then
                    shiftAllRowsLeft <= '1';
                else
                    shiftAllRowsLeftHalf <= '1';
                end if;  
                    
                dataW <= pixelOut3 & pixelOut2 & pixelOut1 & pixelOut0;
                
                if addr_cnt_done = '1' then
                    next_state  <= SHIFT_ROWS;
                else
                    next_state  <= WRITE;
                end if;  
                
            when LAST_DO_EDGES =>
                 last_fill_edges <= '1';
                 next_state  <= WRITE_LAST_ROW;
                
            when WRITE_LAST_ROW =>
                we <= '1';
                addr_cnt_ena <= '1';
                if addr_cnt_done = '0' then
                    shiftAllRowsLeft <= '1';
                else
                    shiftAllRowsLeftHalf <= '1';
                end if;  
                
                dataW <= pixelOut3 & pixelOut2 & pixelOut1 & pixelOut0;
                
                if addr_cnt_done = '1' then
                    next_state  <= STOP;
                else
                    next_state  <= WRITE_LAST_ROW;
                end if;    
                
            when STOP =>
                finish <= '1';
                if start = '1' then
                    next_state  <= STOP;
                else
                    next_state  <= WAIT_START;
                end if; 
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
