; https://www.mouser.ie/datasheet/2/436/w65c22-1197.pdf
VIA1_RB = $A000 ; VIA used for the graphics and sound systems,
VIA1_RA = $A001 ; RB = GFX Data, RA = AY-3-8910 data.
VIA1_DDRB = $A002 ; Data Direction Register - 1 = output, 0 = input
VIA1_DDRA = $A003
VIA1_T1CL = $A004
VIA1_T1CH = $A005
VIA1_T1LL = $A006
VIA1_T1LH = $A007
VIA1_T2CL = $A008
VIA1_T2CH = $A009
VIA1_SR = $A00A
VIA1_ACR = $A00B
VIA1_PCR = $A00C
VIA1_IFR = $A00D
VIA1_IER = $A00E
VIA1_RA2 = $A00F
VIA2_RB = $B000 ; VIA used for the keyboard, SD and sound systems.
VIA2_RA = $B001 ; RA = Keyboard Data, RB = SD SPI (7 = MISO, 6 = MOSI, 5 = CLK, 4 = CS), RB = Sound (0 = BC1, 1 = BDIR)
VIA2_DDRB = $B002
VIA2_DDRA = $B003
VIA2_T1CL = $B004
VIA2_T1CH = $B005
VIA2_T1LL = $B006
VIA2_T1LH = $B007
VIA2_T2CL = $B008
VIA2_T2CH = $B009
VIA2_SR = $B00A
VIA2_ACR = $B00B
VIA2_PCR = $B00C
VIA2_IFR = $B00D
VIA2_IER = $B00E
VIA2_RA2 = $B00F