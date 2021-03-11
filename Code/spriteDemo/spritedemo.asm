    .include viaInfo.asm
    .include biosFunctions.asm
    .include qsdosFunctions.asm

    .org $2000
    lda #$27 ; Update Sprite Graphic
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; Sprite index 0
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #12 ; Width 12
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #16 ; Height 16
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0
    jsr BIOSUtilityFunc + sendGfxCommand
    ldy #0
.sendlp:
    lda mario, Y
    jsr BIOSUtilityFunc + sendGfxCommand
    iny
    cpy #192
    bne .sendlp
    lda #$29 ; Make Sprite Visible
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; Sprite index 0
    jsr BIOSUtilityFunc + sendGfxCommand
.mainlp:
    ldy #getCurrentKey
    jsr osUtilityFunc
    cmp #17
    bne .noBreak
    lda #$2A ; Make Sprite Invisible
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; Sprite index 0
    jsr BIOSUtilityFunc + sendGfxCommand
    rts
.noBreak:
    clc ; increment x position
    lda spriteX
    adc #1
    sta spriteX
    lda spriteX + 1
    adc #0
    sta spriteX + 1
    
    lda spriteX ; reset X position if it gets to far right of the screen
    cmp #$90
    bne .notEqualX
    lda spriteX + 1
    cmp #$1
    bne .notEqualX
    stz spriteX
    stz spriteX + 1
.notEqualX:

    clc ; apply gravity of 1 to y velocity
    lda spriteYVelocity
    adc #1
    sta spriteYVelocity
    lda spriteYVelocity + 1
    adc #0
    sta spriteYVelocity + 1
    
    clc ; apply y velocity to y position
    lda spriteY
    adc spriteYVelocity
    sta spriteY
    lda spriteY + 1
    adc spriteYVelocity + 1
    sta spriteY + 1
    
    lda spriteY + 1
    cmp #1
    beq .checkYLow
    bcs .yGreater
    bra .yFine
.checkYLow:
    lda spriteY
    cmp #$2C
    bcc .yFine
.yGreater:
    lda #1 ; reset y pos to bottom of screen
    sta spriteY + 1
    lda #$2C
    sta spriteY
    
    lda spriteYVelocity ; negate y velocity by NOT-ing and adding 1
    eor #$FF
    sta spriteYVelocity
    lda spriteYVelocity + 1
    eor #$FF
    sta spriteYVelocity + 1
    clc
    lda spriteYVelocity
    adc #1
    sta spriteYVelocity
    lda spriteYVelocity + 1
    adc #0
    sta spriteYVelocity + 1

.yFine:
    lda #$28 ; Move Sprite
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; Sprite index 0
    jsr BIOSUtilityFunc + sendGfxCommand
    lda spriteX
    jsr BIOSUtilityFunc + sendGfxCommand
    lda spriteX + 1
    jsr BIOSUtilityFunc + sendGfxCommand
    lda spriteY
    jsr BIOSUtilityFunc + sendGfxCommand
    lda spriteY + 1
    jsr BIOSUtilityFunc + sendGfxCommand
    jmp .mainlp

spriteX: .word 0
spriteY: .word 0
spriteYVelocity: .word 0

mario:
    .byte $FF, $FF, $FF, $30, $30, $30, $30, $30, $FF, $FF, $FF, $FF
    .byte $FF, $FF, $30, $30, $30, $30, $30, $30, $30, $30, $30, $FF
    .byte $FF, $FF, $14, $14, $14, $39, $39, $14, $39, $FF, $FF, $FF
    .byte $FF, $14, $39, $14, $39, $39, $39, $14, $39, $39, $39, $FF
    .byte $FF, $14, $39, $14, $14, $39, $39, $39, $14, $39, $39, $39
    .byte $FF, $14, $14, $39, $39, $39, $39, $14, $14, $14, $14, $FF
    .byte $FF, $FF, $FF, $39, $39, $39, $39, $39, $39, $39, $FF, $FF
    .byte $FF, $FF, $14, $14, $30, $14, $14, $14, $FF, $FF, $FF, $FF
    .byte $FF, $14, $14, $14, $30, $14, $14, $30, $14, $14, $14, $FF
    .byte $14, $14, $14, $14, $30, $30, $30, $30, $14, $14, $14, $14
    .byte $39, $39, $14, $30, $39, $30, $30, $39, $30, $14, $39, $39
    .byte $39, $39, $39, $30, $30, $30, $30, $30, $30, $39, $39, $39
    .byte $39, $39, $30, $30, $30, $30, $30, $30, $30, $30, $39, $39
    .byte $FF, $FF, $30, $30, $30, $FF, $FF, $30, $30, $30, $FF, $FF
    .byte $FF, $14, $14, $14, $FF, $FF, $FF, $FF, $14, $14, $14, $FF
    .byte $14, $14, $14, $14, $FF, $FF, $FF, $FF, $14, $14, $14, $14