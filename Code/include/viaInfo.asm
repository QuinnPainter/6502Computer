; https://www.mouser.ie/datasheet/2/436/w65c22-1197.pdf
VIA1_RB = $9000 ; VIA used for the graphics and keyboard systems.
VIA1_RA = $9001 ; RB = GFX Data, RA = keyboard data.
VIA1_DDRB = $9002 ; Data Direction Register - 1 = output, 0 = input
VIA1_DDRA = $9003
VIA1_T1CL = $9004
VIA1_T1CH = $9005
VIA1_T1LL = $9006
VIA1_T1LH = $9007
VIA1_T2CL = $9008
VIA1_T2CH = $9009
VIA1_SR = $900A
VIA1_ACR = $900B
VIA1_PCR = $900C
VIA1_IFR = $900D
VIA1_IER = $900E
VIA1_RA2 = $900F
VIA2_RB = $A000 ; VIA used for the SD and sound systems.
VIA2_RA = $A001 ; RA = SD SPI (7 = MISO, 6 = MOSI, 5 = CLK, 4 = CS), RA = Sound (0 = BC1, 1 = BDIR), RB = Sound Data
VIA2_DDRB = $A002
VIA2_DDRA = $A003
VIA2_T1CL = $A004
VIA2_T1CH = $A005
VIA2_T1LL = $A006
VIA2_T1LH = $A007
VIA2_T2CL = $A008
VIA2_T2CH = $A009
VIA2_SR = $A00A
VIA2_ACR = $A00B
VIA2_PCR = $A00C
VIA2_IFR = $A00D
VIA2_IER = $A00E
VIA2_RA2 = $A00F