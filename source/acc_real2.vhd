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
use work.pixelRowRAM_pkg.all;

entity acc_real2 is
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
end acc_real2;

-- Image is 288*352 pixels

architecture rtl of acc_real2 is
    
    constant ram_wr_offset              : integer := 25344;

    -- State machine signals
    type state_type is (WAIT_START, READ_0, READ_1, READ_2, WRITE_0, WRITE_1, WRITE_2, WRITE_3, WRITE_4, WRITE_5, WRITE_6, LAST_WRITE, STOP);
    signal state, next_state : state_type;
    signal state_counter : unsigned(6 downto 0);
    signal timer         : integer range 0 to 127;

    -- FSM control signals
    signal read_row         : std_logic; 
    signal write_row        : std_logic;
    
    -- Address counter signals
    signal row_done         : std_logic;
    signal addr_cnt         : unsigned(8 downto 0);
    signal read_addr_offset : unsigned(15 downto 0);
    signal write_addr_offset: unsigned(15 downto 0);
    signal read_row_cnt     : integer range 0 to 288;
    signal ram_input_sel : integer range 0 to 2;
    
    -- Pixel row multiplexer shufler
    type pixel_row_type is array (0 to 8) of unsigned(7 downto 0); -- Row is two pixels wider than image to enable edge handling
    signal pixel_row_0 : pixel_row_type;
    signal pixel_row_1 : pixel_row_type;
    signal pixel_row_2 : pixel_row_type;
    
    
    component sobel is -- For one pixel, we generate 4 of this
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
    
    -- Sobel output signals
    type pixelOut_type is array (0 to 3) of unsigned(7 downto 0);
    signal pixelsOut : pixelOut_type;
    signal pixelOut0 : std_logic_vector(7 downto 0);
    signal pixelOut1 : std_logic_vector(7 downto 0);
    signal pixelOut2 : std_logic_vector(7 downto 0);
    signal pixelOut3 : std_logic_vector(7 downto 0);
    
    component pixelRowRam is
    generic 
    (
        RAM_WIDTH : integer := 32;                    -- Specify RAM data width
        RAM_DEPTH : integer := 128                    -- Specify RAM depth (number of entries),     MORE EFFICENT POSSIBLE
    );
    port 
    (
        addr  : in std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);    -- Write address bus, width determined from RAM_DEPTH
        dina  : in std_logic_vector(RAM_WIDTH-1 downto 0);		        -- RAM input data
        clka  : in std_logic;                       			        -- Clock
        wea   : in std_logic;                       			        -- Write enable
        enb   : in std_logic;                       			        -- RAM Enable, for additional power savings, disable port when not in use
        rstb  : in std_logic;                       			        -- Output reset (does not affect memory contents)
        doutb : out std_logic_vector(RAM_WIDTH-1 downto 0)   			-- RAM output data
    );
    end component;
    
    signal ram_addr  : std_logic_vector(6 downto 0);
    signal ram0_dout : std_logic_vector(31 downto 0);
    signal ram1_dout : std_logic_vector(31 downto 0);
    signal ram2_dout : std_logic_vector(31 downto 0);
    signal ram0_we   : std_logic;
    signal ram1_we   : std_logic;
    signal ram2_we   : std_logic;
    signal ram_ena   : std_logic;
    
    
    signal ram_pix_row_0 : pixelOut_type;
    signal ram_pix_row_1 : pixelOut_type;
    signal ram_pix_row_2 : pixelOut_type;
    
begin

    address_cnt : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or state = WAIT_START then
                addr_cnt <= (others => '0');
                read_addr_offset <= (others => '0');
                write_addr_offset <= (others => '0');
                read_row_cnt <= 0;
                row_done <= '0';
                ram_input_sel <= 0;
            else
                row_done <= '0';
                
                if read_row = '1' then
                        if addr_cnt = 87 then
                            row_done <= '1';
                        end if;
                        if addr_cnt = 88 then
                            read_row_cnt <= read_row_cnt + 1;
                            addr_cnt <= (others => '0');
                            read_addr_offset <= read_addr_offset + to_unsigned(88, read_addr_offset'length);
                            if ram_input_sel = 2 then
                                ram_input_sel <= 0;
                            else
                                ram_input_sel <= ram_input_sel + 1;
                            end if;
                        else
                           addr_cnt <= addr_cnt + 1;
                        end if;
                 end if;
                 
                 if write_row = '1' then
                        if addr_cnt = 90 then
                            row_done <= '1';
                        end if;
                        if row_done = '1' and read_row_cnt = 288 then
                                read_row_cnt <= read_row_cnt + 1;
                                ram_input_sel <= ram_input_sel + 1;
                            end if;
                        if addr_cnt = 90 then
                            write_addr_offset <= write_addr_offset + to_unsigned(88, write_addr_offset'length);
                            addr_cnt <= (others => '0');
                        else
                            addr_cnt <= addr_cnt + 1;
                        end if;
                 end if;

            end if;
        end if;
    end process;
    
    -- Pixel shift registers and edge correction
    ring_shft: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or state = WAIT_START then   
                pixel_row_0 <= (others => (others => '0'));
                pixel_row_1 <= (others => (others => '0'));
                pixel_row_2 <= (others => (others => '0'));
            else
                pixel_row_0 <= (others => (others => '0'));
                pixel_row_1 <= (others => (others => '0'));
                pixel_row_2 <= (others => (others => '0'));           
                                
                if write_row = '1' then
                    pixel_row_0(0 to 3) <= pixel_row_0(4 to 7);
                    pixel_row_1(0 to 3) <= pixel_row_1(4 to 7);
                    pixel_row_2(0 to 3) <= pixel_row_2(4 to 7);
                                       
                    
                    if read_row_cnt = 2 then

                        if state = WRITE_1 then
                            pixel_row_0(4) <= ram_pix_row_1(0);
                            pixel_row_1(4) <= ram_pix_row_1(0);
                            pixel_row_2(4) <= ram_pix_row_2(0);
                            for k in 0 to 3 loop
                                pixel_row_0(5 + k) <= ram_pix_row_1(k);
                                pixel_row_1(5 + k) <= ram_pix_row_1(k);
                                pixel_row_2(5 + k) <= ram_pix_row_2(k);
                            end loop;
                            
                        elsif state = WRITE_2 or state = WRITE_3 or state = WRITE_4 then
                            pixel_row_0(4) <= pixel_row_0(8);
                            pixel_row_1(4) <= pixel_row_1(8);
                            pixel_row_2(4) <= pixel_row_2(8);
                            for k in 0 to 3 loop
                                pixel_row_0(5 + k) <= ram_pix_row_1(k);
                                pixel_row_1(5 + k) <= ram_pix_row_1(k);
                                pixel_row_2(5 + k) <= ram_pix_row_2(k);
                            end loop;
                            
                        elsif state = WRITE_5 then
                            pixel_row_0(4) <= pixel_row_0(8);
                            pixel_row_1(4) <= pixel_row_1(8);
                            pixel_row_2(4) <= pixel_row_2(8);
                            pixel_row_0(5) <= pixel_row_1(8);
                            pixel_row_1(5) <= pixel_row_1(8);
                            pixel_row_2(5) <= pixel_row_2(8);
                        end if;
                            
                        
                    elsif read_row_cnt = 289 then
                        if state = WRITE_1 then
                            pixel_row_0(4) <= ram_pix_row_0(0);
                            pixel_row_1(4) <= ram_pix_row_1(0);
                            pixel_row_2(4) <= ram_pix_row_1(0);
                            for k in 0 to 3 loop
                                pixel_row_0(5 + k) <= ram_pix_row_0(k);
                                pixel_row_1(5 + k) <= ram_pix_row_1(k);
                                pixel_row_2(5 + k) <= ram_pix_row_1(k);
                            end loop;
                            
                        elsif state = WRITE_2 or state = WRITE_3 or state = WRITE_4 then
                            pixel_row_0(4) <= pixel_row_0(8);
                            pixel_row_1(4) <= pixel_row_1(8);
                            pixel_row_2(4) <= pixel_row_2(8);
                            for k in 0 to 3 loop
                                pixel_row_0(5 + k) <= ram_pix_row_0(k);
                                pixel_row_1(5 + k) <= ram_pix_row_1(k);
                                pixel_row_2(5 + k) <= ram_pix_row_1(k);
                            end loop;
                            
                        elsif state = WRITE_5 then
                            pixel_row_0(4) <= pixel_row_0(8);
                            pixel_row_1(4) <= pixel_row_1(8);
                            pixel_row_2(4) <= pixel_row_2(8);
                            pixel_row_0(5) <= pixel_row_0(8);
                            pixel_row_1(5) <= pixel_row_1(8);
                            pixel_row_2(5) <= pixel_row_1(8);
                        end if;
                    
                    else 
                        if state = WRITE_1 then
                            pixel_row_0(4) <= ram_pix_row_0(0);
                            pixel_row_1(4) <= ram_pix_row_1(0);
                            pixel_row_2(4) <= ram_pix_row_2(0);
                            for k in 0 to 3 loop
                                pixel_row_0(5 + k) <= ram_pix_row_0(k);
                                pixel_row_1(5 + k) <= ram_pix_row_1(k);
                                pixel_row_2(5 + k) <= ram_pix_row_2(k);
                            end loop;
                            
                        elsif state = WRITE_2 or state = WRITE_3 or state = WRITE_4 then
                            pixel_row_0(4) <= pixel_row_0(8);
                            pixel_row_1(4) <= pixel_row_1(8);
                            pixel_row_2(4) <= pixel_row_2(8);
                            for k in 0 to 3 loop
                                pixel_row_0(5 + k) <= ram_pix_row_0(k);
                                pixel_row_1(5 + k) <= ram_pix_row_1(k);
                                pixel_row_2(5 + k) <= ram_pix_row_2(k);
                            end loop;
                            
                        elsif state = WRITE_5 then
                            pixel_row_0(4) <= pixel_row_0(8);
                            pixel_row_1(4) <= pixel_row_1(8);
                            pixel_row_2(4) <= pixel_row_2(8);
                            pixel_row_0(5) <= pixel_row_0(8);
                            pixel_row_1(5) <= pixel_row_1(8);
                            pixel_row_2(5) <= pixel_row_2(8);
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Ram control signals
    addr <= std_logic_vector(addr_cnt(6 downto 0) + read_addr_offset) when read_row = '1' else
            std_logic_vector(addr_cnt(6 downto 0)-3 + write_addr_offset + ram_wr_offset);
            
    ram_addr <= std_logic_vector(addr_cnt(6 downto 0)-1) when read_row = '1' else
                std_logic_vector(addr_cnt(6 downto 0)) ;  
                
            
   -- 3 row pixel RAMs
    ram0: pixelRowRam
    generic map
    (
        RAM_WIDTH => 32,
        RAM_DEPTH => 128
    )
    port map 
    (
        addr  => ram_addr,
        dina  => dataR,
        clka  => clk,
        wea   => ram0_we,
        enb   => ram_ena,
        rstb  => reset,
        doutb => ram0_dout
    );
    
    ram1: pixelRowRam
    generic map
    (
        RAM_WIDTH => 32,
        RAM_DEPTH => 128
    )
    port map 
    (
        addr  => ram_addr,
        dina  => dataR,
        clka  => clk,
        wea   => ram1_we,
        enb   => ram_ena,
        rstb  => reset,
        doutb => ram1_dout
    );
    
    ram2: pixelRowRam
    generic map
    (
        RAM_WIDTH => 32,
        RAM_DEPTH => 128
    )
    port map 
    (
        addr  => ram_addr,
        dina  => dataR,
        clka  => clk,
        wea   => ram2_we,
        enb   => ram_ena,
        rstb  => reset,
        doutb => ram2_dout
    );
        
    process (all)
    begin
        case ram_input_sel is
            when 2 =>
                ram_pix_row_0(3) <= unsigned(ram2_dout(31 downto 24));
                ram_pix_row_0(2) <= unsigned(ram2_dout(23 downto 16));
                ram_pix_row_0(1) <= unsigned(ram2_dout(15 downto 8));
                ram_pix_row_0(0) <= unsigned(ram2_dout(7 downto 0));
                ram_pix_row_1(3) <= unsigned(ram0_dout(31 downto 24));
                ram_pix_row_1(2) <= unsigned(ram0_dout(23 downto 16));
                ram_pix_row_1(1) <= unsigned(ram0_dout(15 downto 8));
                ram_pix_row_1(0) <= unsigned(ram0_dout(7 downto 0));
                ram_pix_row_2(3) <= unsigned(ram1_dout(31 downto 24));
                ram_pix_row_2(2) <= unsigned(ram1_dout(23 downto 16));
                ram_pix_row_2(1) <= unsigned(ram1_dout(15 downto 8));
                ram_pix_row_2(0) <= unsigned(ram1_dout(7 downto 0));
             when 1 =>
                ram_pix_row_0(3) <= unsigned(ram1_dout(31 downto 24));
                ram_pix_row_0(2) <= unsigned(ram1_dout(23 downto 16));
                ram_pix_row_0(1) <= unsigned(ram1_dout(15 downto 8));
                ram_pix_row_0(0) <= unsigned(ram1_dout(7 downto 0));
                ram_pix_row_1(3) <= unsigned(ram2_dout(31 downto 24));
                ram_pix_row_1(2) <= unsigned(ram2_dout(23 downto 16));
                ram_pix_row_1(1) <= unsigned(ram2_dout(15 downto 8));
                ram_pix_row_1(0) <= unsigned(ram2_dout(7 downto 0));
                ram_pix_row_2(3) <= unsigned(ram0_dout(31 downto 24));
                ram_pix_row_2(2) <= unsigned(ram0_dout(23 downto 16));
                ram_pix_row_2(1) <= unsigned(ram0_dout(15 downto 8));
                ram_pix_row_2(0) <= unsigned(ram0_dout(7 downto 0));
             when others =>
                ram_pix_row_0(3) <= unsigned(ram0_dout(31 downto 24));
                ram_pix_row_0(2) <= unsigned(ram0_dout(23 downto 16));
                ram_pix_row_0(1) <= unsigned(ram0_dout(15 downto 8));
                ram_pix_row_0(0) <= unsigned(ram0_dout(7 downto 0));
                ram_pix_row_1(3) <= unsigned(ram1_dout(31 downto 24));
                ram_pix_row_1(2) <= unsigned(ram1_dout(23 downto 16));
                ram_pix_row_1(1) <= unsigned(ram1_dout(15 downto 8));
                ram_pix_row_1(0) <= unsigned(ram1_dout(7 downto 0));
                ram_pix_row_2(3) <= unsigned(ram2_dout(31 downto 24));
                ram_pix_row_2(2) <= unsigned(ram2_dout(23 downto 16));
                ram_pix_row_2(1) <= unsigned(ram2_dout(15 downto 8));
                ram_pix_row_2(0) <= unsigned(ram2_dout(7 downto 0));              
        end case;
        
    end process;

    

    -- 4 Sobel operators
    sob_gen: for i in 0 to 3 generate
        sob: sobel port map
        ( 
            s11 => pixel_row_0(0 + i),
            s12 => pixel_row_0(1 + i),
            s13 => pixel_row_0(2 + i),
            s21 => pixel_row_1(0 + i),
            --    s22 : in unsigned(8 downto 0);
            s23 => pixel_row_1(2 + i),
            s31 => pixel_row_2(0 + i),
            s32 => pixel_row_2(1 + i),
            s33 => pixel_row_2(2 + i),
            pix_out => pixelsOut(i)
        );
    end generate;

    pixelOut0 <= std_logic_vector(pixelsOut(0));
    pixelOut1 <= std_logic_vector(pixelsOut(1));
    pixelOut2 <= std_logic_vector(pixelsOut(2));
    pixelOut3 <= std_logic_vector(pixelsOut(3));
    dataW <= pixelOut3 & pixelOut2 & pixelOut1 & pixelOut0;
    
--    pixelOut0 <= std_logic_vector(pixel_row_1(1));
--    pixelOut1 <= std_logic_vector(pixel_row_1(2));
--    pixelOut2 <= std_logic_vector(pixel_row_1(3));
--    pixelOut3 <= std_logic_vector(pixel_row_1(4));
            

    
    --read_row_cnt <= 0;

    
    -- FSM Combinatoriel logic
    fsm_cl : process (all)
    begin
        next_state  <= WAIT_START;
        finish <= '0';
        read_row <= '0';
        write_row <= '0';
        timer <= 1;
        en <= '0';
        we <= '0';
        ram_ena <= '0';
        ram0_we <= '0';
        ram1_we <= '0';
        ram2_we <= '0';
    
        case (state) is    
            when WAIT_START =>
                if start = '1' then
                    next_state  <= READ_0;
                end if;  
                
            when READ_0 =>
                en <= '1';
                read_row <= '1';
                next_state  <= READ_1;
 
            when READ_1 =>
                en <= '1';
                read_row <= '1';
                case ram_input_sel is
                    when 0 =>
                        ram0_we <= '1';
                    when 1 =>
                        ram1_we <= '1';
                    when 2 =>
                        ram2_we <= '1';     
                end case;
                timer <= 87;
                next_state  <= READ_2;
                
            when READ_2 =>
                read_row <= '1';
                case ram_input_sel is
                    when 0 =>
                        ram0_we <= '1';
                    when 1 =>
                        ram1_we <= '1';
                    when 2 =>
                        ram2_we <= '1';     
                end case;
                if read_row_cnt = 0 then
                    next_state  <= READ_0;
                else
                    next_state  <= WRITE_0;
                end if;
                
            when WRITE_0 =>
                write_row <= '1';
                ram_ena <= '1';
                next_state  <= WRITE_1;
                
            when WRITE_1 =>
                write_row <= '1';
                ram_ena <= '1';
                next_state  <= WRITE_2;
                
            when WRITE_2 =>
                write_row <= '1';
                ram_ena <= '1';
                next_state  <= WRITE_3;
                
            when WRITE_3 =>
                write_row <= '1';
                ram_ena <= '1';
                we <= '1';
                en <= '1';
                timer <= 85;
                next_state  <= WRITE_4;
                
            when WRITE_4 =>
                write_row <= '1';
                we <= '1';
                en <= '1';
                next_state  <= WRITE_5;
                
            when WRITE_5 =>
                write_row <= '1';
                we <= '1';
                en <= '1';
                next_state  <= WRITE_6;
 
             when WRITE_6 =>
                write_row <= '1';
                we <= '1';
                en <= '1';
                if read_row_cnt = 288 then
                    next_state  <= WRITE_0;
                elsif read_row_cnt = 289 then
                    next_state  <= STOP;
                else
                    next_state  <= READ_0;
                end if;  
                
            when STOP =>
                finish <= '1';
                if start = '0' then
                    next_state  <= WAIT_START;
                else
                    next_state  <= STOP;
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
                state_counter <= to_unsigned(1, state_counter'length);
            else
                if (state_counter >= timer) then
                    state_counter <= to_unsigned(1, state_counter'length);
                    state <= next_state;  
                else
                    state_counter <= state_counter + 1;
                end if;
            end if;
        end if;
    end process;


end rtl;
