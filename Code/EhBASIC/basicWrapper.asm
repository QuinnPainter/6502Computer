    .include biosFunctions.asm
    .include qsdosFunctions.asm
ccflag		= $0200	; BASIC CTRL-C flag, 00 = enabled, 01 = dis
ccbyte		= ccflag+1	; BASIC CTRL-C byte
ccnull		= ccbyte+1	; BASIC CTRL-C byte timeout
VEC_CC		= ccnull+1	; ctrl c check vector
VEC_IN		= VEC_CC+2	; input vector
VEC_OUT		= VEC_IN+2	; output vector
VEC_LD		= VEC_OUT+2	; load vector
VEC_SV		= VEC_LD+2	; save vector
    
    .org $2000
    lda #inputHandler & $FF
    sta VEC_IN
    lda #inputHandler >> 8
    sta VEC_IN + 1
    lda #outputHandler & $FF
    sta VEC_OUT
    lda #outputHandler >> 8
    sta VEC_OUT + 1
    lda #loadHandler & $FF
    sta VEC_LD
    lda #loadHandler >> 8
    sta VEC_LD + 1
    lda #saveHandler & $FF
    sta VEC_SV
    lda #saveHandler >> 8
    sta VEC_SV + 1
    jmp	$2100
    
; This is a non halting scan of the input device.
; If a character is ready it should be placed in A and the carry flag set,
; if there is no character then A, and the carry flag, should be cleared.
inputHandler:
    phy
    ldy #getCurrentKey
    jsr osUtilityFunc
    cmp #$FF
    beq .noKey
    cmp #32
    bcc .controlCode
    pha
    ldy #getCapsState
    jsr osUtilityFunc
    beq .lowercase
    ply
    lda keyboardCapsLUT, Y
    bra .return
.lowercase:
    pla
.return:
    ply
    sec
    rts
.controlCode:
    cmp #11
    beq .enter
    cmp #12
    beq .backspace
    cmp #17
    beq .pausebrk
    bra .noKey
.enter:
    lda #$D ; carriage return
    bra .return
.backspace:
    lda #$8
    bra .return
.pausebrk:
    lda #$3 ; CTRL-C signal (C char minus 64)
    bra .return
.noKey:
    ply
    lda #$0
    clc
    rts
   
; The character to be sent is in A and should not be changed by the routine.
; Also on return, the N and Z flags should reflect the character in A.   
outputHandler:
    pha
    phx
    jsr BIOSUtilityFunc + printchar
    plx
    pla
    rts

loadHandler:
    rts
    
saveHandler:
    rts
    
keyboardCapsLUT: .include keyboardCapsLUT.asm
    
    .org $2100
    .binary basicbinary.bin