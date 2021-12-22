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
    
; $0000 - page 0 (used for temp variables)
; $0100 - stack page
; $0200 - leaving open (needed for EhBASIC)
gfxCmdBufferPage = $0300 ; 0300 - 03FF (must be page-aligned)
gfxCmdBufferTop = $0400
gfxCmdBufferBottom = $0401

    .org $C000
reset:
    ldx #$FF ; Initialize stack pointer
    txs
    
    sei ; disable IRQ
    cld ; disable decimal mode
    
    ;stz VIA1_DDRA ; keyboard input bus all inputs
    ;lda #%00001000
    ;sta VIA1_PCR ; setup keyboard handshake
    ;lda #%01111111
    ;sta VIA1_IER ; disable VIA2 interrupts
    ;lda #%10000010
    ;sta VIA1_IER ; enable keyboard interrupt
    
    lda #%11111111
    sta VIA1_DDRB ; DDRB (graphics bus) all outputs
    lda #%10001100
    sta VIA1_PCR ; setup graphics handshake
    lda #%01111111
    sta VIA1_IER ; disable all via interrupts
    lda #%10010000
    sta VIA1_IER ; Enable graphics ready interrupt
    
    ldy #$FF ; wait for graphics card to start up
    jsr delay
    
    stz gfxCmdBufferTop
    stz gfxCmdBufferBottom
    
    cli ; now that the VIA IRQs are set up, we can enable IRQ
    
    lda #0
    jsr sendGfxCommand ; clear the screen (multiple times in case there's a gfx command in progress)
    
    lda #$FF ; Initialize graphics interrupt
    sta VIA1_RB
    
    lda #0
    jsr sendGfxCommand ; clear the screen (multiple times in case there's a gfx command in progress)
    lda #0
    jsr sendGfxCommand ; clear the screen (multiple times in case there's a gfx command in progress)
    lda #0
    jsr sendGfxCommand ; clear the screen (multiple times in case there's a gfx command in progress)
    lda #$2B
    jsr sendGfxCommand ; clear sprites
    lda #4
    jsr sendGfxCommand ; set foreground colour
    lda #7
    jsr sendGfxCommand ; to white
    lda #5
    jsr sendGfxCommand ; set background colour
    lda #0
    jsr sendGfxCommand ; to black
    lda #6
    jsr sendGfxCommand ; enable cursor

    lda #startString & $FF
    sta $00
    lda #startString >> 8
    sta $01
    jsr printstring
infloop:
    jsr printstring
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
    
; Add a string to the graphics buffer (can't be more than 256 chars including terminator)
; Inputs: ZPG $00, $01 - Address of string (with terminating 0)
; Outputs: A, X, Y - Garbage
printstring:
    lda #$02 ; Print String
    jsr sendGfxCommand
    ldy #0
.printloop:
    lda ($00), Y
    beq .done   ; if char is 0, we've reached the end of the string
    jsr sendGfxCommand
    iny
    bra .printloop
.done:
    lda #0
    jsr sendGfxCommand ; terminate string
    rts
    
; Add a character to the graphics buffer
; Inputs: A - Character to print
; Outputs: X - Garbage
printchar:
    pha
    lda #1
    jsr sendGfxCommand
    pla
    jsr sendGfxCommand
    rts
    
; Send a block of commands to the graphics buffer
; Inputs: ZPG 00, 01 = Start address of array
;         ZPG 02, 03 = Size of array
;         (02 - num pages, 03 - num bytes after pages)
sendGfxCommandArray:
    lda $02
    beq .noPages
    ldy #0
.sendPageByteLoop:
    lda ($00), Y
    jsr sendGfxCommand
    iny
    bne .sendPageByteLoop
    inc $01
    dec $02
    bne .sendPageByteLoop
.noPages:
    lda $03
    beq .done
.sendByteLoop:
    lda ($00), Y
    jsr sendGfxCommand
    iny
    cpy $03
    bne .sendByteLoop
.done:
    rts

; Add a command to the graphics buffer
; Inputs: A - Command to add
; Outputs: X - Garbage
sendGfxCommand:
    ;phy
    ;ldy #$FF
    ;jsr delay
    ;ply
    ldx gfxCmdBufferTop
    sta gfxCmdBufferPage,X
    inx
.1: cpx gfxCmdBufferBottom
    beq .1          ; If buffer is full, wait for it to clear out
    stx gfxCmdBufferTop
    lda #%10010000 ; Enable graphics ready interrupt
    sta VIA1_IER
    rts
    
nmi:
    rti
    
irq:
    pha
    phx
    phy
    lda VIA1_IFR
    and #%00010000
    beq .notGfxInterrupt
    jsr GfxInterrupt
.notGfxInterrupt:
    lda VIA1_IFR
    and #%00000010
    beq .notKeyboardInterrupt
    lda VIA1_RA ; Acknowledge interrupt
.notKeyboardInterrupt:
    ;cpx #$FF
    ;beq .notOtherInterrupt
    ;lda sdosLoaded ; Some other interrupt happened (via timers probably)
    ;beq .notOtherInterrupt
    ;lda #1
    ;jsr $0700
;.notOtherInterrupt:
    ply
    plx
    pla
    rti
    
GfxInterrupt:
    ldx gfxCmdBufferBottom
    cpx gfxCmdBufferTop
    beq .bufferEmpty
    
    lda gfxCmdBufferPage,X
    sta VIA1_RB
    ;inc gfxCmdBufferBottom  ; using this should be the same, but it causes the computer to crap out after 256 gfx commands. why???
    inx
    stx gfxCmdBufferBottom
    rts
.bufferEmpty:
    lda #%00010000 ; Disable graphics ready interrupt
    sta VIA1_IER
    rts

startString: string "Hello World"
    
    .org $FFFA
    .word nmi ; NMI vector
    .word reset ; Reset vector
    .word irq ; IRQ vector