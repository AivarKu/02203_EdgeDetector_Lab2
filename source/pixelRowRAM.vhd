
--  Xilinx Simple Dual Port Single Clock RAM
--  This code implements a parameterizable SDP single clock memory.
--  If a reset or enable is not necessary, it may be tied off or removed from the code.

library ieee;
use ieee.std_logic_1164.all;
use work.pixelRowRAM_pkg.all;

library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pixelRowRAM_pkg.all;
USE std.textio.all;

entity pixelRowRam is
generic (
    RAM_WIDTH : integer := 64;                    -- Specify RAM data width
    RAM_DEPTH : integer := 512                    -- Specify RAM depth (number of entries)
    );

port (
        addr  : in std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);     -- Write address bus, width determined from RAM_DEPTH
        dina  : in std_logic_vector(RAM_WIDTH-1 downto 0);		  -- RAM input data
        clka  : in std_logic;                       			  -- Clock
        wea   : in std_logic;                       			  -- Write enable
        enb   : in std_logic;                       			  -- RAM Enable, for additional power savings, disable port when not in use
        rstb  : in std_logic;                       			  -- Output reset (does not affect memory contents)
        doutb : out std_logic_vector(RAM_WIDTH-1 downto 0)   			  -- RAM output data
    );

end pixelRowRam;

architecture rtl of pixelRowRam is

constant C_RAM_WIDTH : integer := RAM_WIDTH;
constant C_RAM_DEPTH : integer := RAM_DEPTH;

signal doutb_reg : std_logic_vector(C_RAM_WIDTH-1 downto 0) := (others => '0');
type ram_type is array (0 to C_RAM_DEPTH-1) of std_logic_vector (C_RAM_WIDTH-1 downto 0);          -- 2D Array Declaration for RAM signal
signal ram_data : std_logic_vector(C_RAM_WIDTH-1 downto 0);

signal ram_name : ram_type := (others => (others => '0'));

begin

    process(clka)
    begin
        if(clka'event and clka = '1') then
            if(wea = '1') then
                ram_name(to_integer(unsigned(addr))) <= dina;
            end if;
            if(enb = '1') then
                ram_data <= ram_name(to_integer(unsigned(addr)));
            end if;
        end if;
    end process;

    doutb <= ram_data;
    
end rtl;
			
						