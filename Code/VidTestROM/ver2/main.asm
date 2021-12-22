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

    .org $C000
reset:
    ldx #$FF ; Initialize stack pointer
    txs
    
    sei ; disable IRQ
    cld ; disable decimal mode
    
    lda #%11111111
    sta VIA1_DDRB ; DDRB (graphics bus) all outputs
    lda #%10001100
    sta VIA1_PCR ; setup graphics handshake
    lda #%01111111
    sta VIA1_IER ; disable all via interrupts
    ;lda #%10010000
    ;sta VIA1_IER ; Enable graphics ready interrupt
    
    ldy #$FF ; wait for graphics card to start up
    jsr delay
    
    ;cli ; now that the VIA IRQs are set up, we can enable IRQ
    
    lda #0
    sta VIA1_RB ; clear the screen (multiple times in case there's a gfx command in progress)
    sta VIA1_RB ; clear the screen (multiple times in case there's a gfx command in progress)
    sta VIA1_RB ; clear the screen (multiple times in case there's a gfx command in progress)
    sta VIA1_RB ; clear the screen (multiple times in case there's a gfx command in progress)
    
    lda #'F'
    sta $500

infloop:
    lda #1
    sta VIA1_RB
    
    ldy #$FF
    jsr delay
;.lp2:
;    ldx #$FF
;.lp1:
;    lda $00     ; 3 cycles (doesn't do anything, just needed a 3 cycle instruction
;    dex         ; 2 cycles
;    bne .lp1    ; 3 or 4 cycles if on page boundary
;    dey         ; So, if it's 8 cycles, at 2MHz this loop will take 1020 microseconds
;    bne .lp2

    lda $500
    ina
    bne .n
    lda #32
.n:
    sta VIA1_RB
    sta $500
    
    ldy #$FF
    jsr delay
;.blp2:
;    ldx #$FF
;.blp1:
;    lda $00     ; 3 cycles (doesn't do anything, just needed a 3 cycle instruction
;    dex         ; 2 cycles
;    bne .blp1    ; 3 or 4 cycles if on page boundary
;    dey         ; So, if it's 8 cycles, at 2MHz this loop will take 1020 microseconds
;    bne .blp2

    bra infloop
    
; Delay for a while
; Inputs: Y - Number of times to wait approx 1 millisecond (1020 microseconds)
; Outputs: X - Garbage
delay:
    pha
.lp2:
    ldx #$FF
.lp1:
    lda $00     ; 3 cycles (doesn't do anything, just needed a 3 cycle instruction
    dex         ; 2 cycles
    bne .lp1    ; 3 or 4 cycles if on page boundary
    dey         ; So, if it's 8 cycles, at 2MHz this loop will take 1020 microseconds
    bne .lp2
    pla
    rts
    
nmi:
    rti
    
irq:
    rti
    
    .org $FFFA
    .word nmi ; NMI vector
    .word reset ; Reset vector
    .word irq ; IRQ vector