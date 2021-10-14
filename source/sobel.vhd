----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/07/2021 10:46:32 AM
-- Design Name: 
-- Module Name: sobel - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use work.types.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sobel is
  Port ( 
    s11 : in unsigned(8 downto 0);
    s12 : in unsigned(8 downto 0);
    s13 : in unsigned(8 downto 0);
    s21 : in unsigned(8 downto 0);
--    s22 : in unsigned(8 downto 0);
    s23 : in unsigned(8 downto 0);
    s31 : in unsigned(8 downto 0);
    s32 : in unsigned(8 downto 0);
    s33 : in unsigned(8 downto 0);
    pix_out : out unsigned(8 downto 0)
  );
end sobel;

architecture Behavioral of sobel is
    signal Gx_1: unsigned(10 downto 0);
    signal Gx_2: unsigned(10 downto 0);
    signal Gy_1: unsigned(10 downto 0);
    signal Gy_2: unsigned(10 downto 0);
    
    signal Gx: signed(11 downto 0);
    signal Gy: signed(11 downto 0);
    
    signal pix_out_full: signed(11 downto 0); 

begin
    Gx_1 <= ("00" & s11) + ('0' & s21 & '0') + ("00" & s31);
    Gx_2 <= ("00" & s13) + ('0' & s23 & '0') + ("00" & s33);
    Gy_1 <= ("00" & s11) + ('0' & s12 & '0') + ("00" & s13);
    Gy_2 <= ("00" & s31) + ('0' & s32 & '0') + ("00" & s33);
    
    Gx <= -signed('0' & Gx_1) + signed('0' & Gx_2);
    Gy <= signed('0' & Gy_1) - signed('0' & Gy_2);
    
    pix_out_full <= ABS(Gx) + ABS(Gy);
    
    pix_out <= unsigned(pix_out_full(10 downto 2));

end Behavioral;
