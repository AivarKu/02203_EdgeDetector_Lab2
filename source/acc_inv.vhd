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

entity acc_inv is
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
end acc_inv;

    

architecture rtl of acc_inv is

    type state_type is (WAIT_START, READ, WRITE, STOP); -- Input your own state names
    signal state, next_state : state_type;

    signal addr_cnt_ena : std_logic;
    signal addr_cnt : unsigned(15 downto 0);
    signal addr_cnt_done : std_logic;
    
    constant ram_wr_offset : integer := 25344;
    
    signal pixel0 : unsigned(7 downto 0);
    signal pixel1 : unsigned(7 downto 0);
    signal pixel2 : unsigned(7 downto 0);
    signal pixel3 : unsigned(7 downto 0);

begin


    myprocess : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                addr_cnt <= (others => '0');
                addr_cnt_done <= '0';
            else
                if addr_cnt_ena = '1'  then
                    if addr_cnt = 25343 then
                        addr_cnt_done <= '1';
                        addr_cnt <= (others => '0');
                    else
                        addr_cnt <= addr_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process myprocess;
    
    addr <= std_logic_vector(addr_cnt) when we = '0' else
            std_logic_vector(addr_cnt + ram_wr_offset);
            
    pixel0 <= 255-unsigned(dataR(7 downto 0));
    pixel1 <= 255-unsigned(dataR(15 downto 8));
    pixel2 <= 255-unsigned(dataR(23 downto 16));
    pixel3 <= 255-unsigned(dataR(31 downto 24));
    
    
    -- Combinatoriel logic
    cl : process (all)
    begin
        next_state  <= WAIT_START;
        en <= '0';
        we <= '0';
        finish <= '0';
        addr_cnt_ena <= '0';
        dataW <= (others => '0');
    
        case (state) is       
            when WAIT_START =>
                if start = '1' then
                    next_state  <= READ;
                end if;   
             
            when READ =>
                en <= '1';
                next_state  <= WRITE;
      
            when WRITE =>
                en <= '1';
                we <= '1';
                addr_cnt_ena <= '1';
                dataW <= std_logic_vector( pixel3 & pixel2 & pixel1 & pixel0);
                if addr_cnt_done = '1' then
                    next_state  <= STOP;
                else
                    next_state  <= READ;
                end if;        
                
             when STOP =>
                en <= '0';
                finish <= '1';
                next_state  <= WAIT_START;
            
            when others =>
                next_state <= WAIT_START;
        
        end case;
    end process cl;
    
    -- Registers
    seq : process (clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= WAIT_START;
            else
                state <= next_state;
            end if;
        end if;
    end process seq;


end rtl;
