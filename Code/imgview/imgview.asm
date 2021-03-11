    include viaInfo.asm
    include biosFunctions.asm
    include qsdosFunctions.asm

    ; problem : black pixels in diagonal pattern - why? every 256 bytes maybe?
    ; problem : freaks out when done drawing

    org $2000
    
    lda #'I'
    sta $7
    lda #'M'
    sta $8
    lda #'A'
    sta $9
    lda #'G'
    sta $A
    lda #'E'
    sta $B
    lda #' '
    sta $C
    lda #' '
    sta $D
    lda #' '
    sta $E
    lda #'P'
    sta $F
    lda #'P'
    sta $10
    lda #'M'
    sta $11
    lda #imgPointer & $FF
    sta $14
    lda #imgPointer >> 8
    sta $15
    jsr BIOSUtilityFunc + sdStartStreamFile
    tax
    beq .fileLoaded
    lda #fileNotFoundString & $FF
    sta $00
    lda #fileNotFoundString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    rts
.fileLoaded:
    lda #imgPointer & $FF
    sta $00
    lda #imgPointer >> 8
    sta $01 ; $00-$01 = Current File Pointer
    
    lda ($00)
    cmp #'P'
    bne .invalidFile
    jsr incFilePointer
    lda ($00)
    cmp #'6'
    beq .fileVerified
.invalidFile:
    lda #invalidFileString & $FF
    sta $00
    lda #invalidFileString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    rts
.fileVerified:
    ; currently, all of the width / height / max colour data is skipped
    ; the file is assumed to be 400x300, max colour 255
    ; the pixel colours are some non-linear colour space
    ; but I'm ignoring that, too
    ; currently, bad things will happen if file is not 400x300
    ; could fix this by keeping track how many pixels have been plotted
    ; and filling remaining pixels with blank ones
    jsr incFilePointer ; file pointer should now be on newline (0A)
    jsr incFilePointer ; file pointer should now be after newline
    jsr skipPastComments ; file pointer should now be on 1st char of width
    jsr gotoNextSpace ; file pointer should be on space between width and height
    jsr incFilePointer ; fp should be on 1st char of height
    jsr gotoNextNewline ; fp should be on newline
    jsr incFilePointer ; fp should be on line after width / height
    jsr skipPastComments ; fp should be on 1st char of max colour value
    jsr gotoNextNewline ; fp should be on newline
    jsr incFilePointer ; fp should be on first pixel byte
    ; could improve speed with sendGfxCommandArray
    lda #$07 ; Disable Cursor command
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #$26 ; Draw Bitmap command
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; X coord, low byte
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; X coord, high byte
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; Y coord, low byte
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #0 ; Y coord, high byte
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #$90 ; Width, low byte
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #$01 ; Width, high byte
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #$2C ; Height, low byte
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #$01 ; Height, high byte
    jsr BIOSUtilityFunc + sendGfxCommand
.pixelLoop:
    lda ($00) ; load raw red byte
    and #$C0 ; only keep top 2 bits
    lsr ; shift right twice
    lsr
    sta $02 ; store temporarily
    jsr decrementRemainingBytes
    jsr incFilePointer
    lda ($00) ; load raw green byte
    and #$C0 ; only keep top 2 bits
    lsr ; shift right four times
    lsr
    lsr
    lsr
    ora $02 ; combine with red
    sta $02 ; store temporarily
    jsr decrementRemainingBytes
    jsr incFilePointer
    lda ($00) ; load raw blue byte
    and #$C0 ; only keep top 2 bits
    lsr ; shift right six times
    lsr
    lsr
    lsr
    lsr
    lsr
    ora $02 ; combine with red and blue
    jsr BIOSUtilityFunc + sendGfxCommand ; send finished pixel
    jsr decrementRemainingBytes
    cmp #1
    beq .doneDrawLoop
    jsr incFilePointer
    bra .pixelLoop
.doneDrawLoop: ; remainingBytes ticked down to 0
    ldy #getCurrentKey
    jsr osUtilityFunc
    cmp #10 ; code for Escape
    bne .doneDrawLoop
    lda #0 ; Clear Screen
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #$06 ; Enable Cursor
    jsr BIOSUtilityFunc + sendGfxCommand
    rts
    
; returns 1 in A if we're out of bytes, 0 otherwise
decrementRemainingBytes:
    lda remainingBytes
    beq .return ; remainingBytes is 0
    dea
    sta remainingBytes
    bne .return ; remainingBytes ticked down, and is not 0
    lda #1 ; remainingBytes ticked down, and is 0
    rts
.return:
    lda #0
    rts
    
gotoNextSpace:
    jsr incFilePointer
    lda ($00)
    cmp #' '
    bne gotoNextSpace
    rts
    
gotoNextNewline:
    jsr incFilePointer
    lda ($00)
    cmp #$0A
    bne gotoNextNewline
    rts

skipPastComments:
    lda ($00)
    cmp #'#'
    beq .lineIsComment
    rts
.lineIsComment:
    jsr incFilePointer
    lda ($00)
    cmp #$0A ; newline
    bne .lineIsComment
    jsr incFilePointer ; skip past newline char
    bra skipPastComments ; skip past any further comments
    
incFilePointer:
    lda $00
    clc
    adc #1
    sta $00
    lda $01
    adc #0
    sta $01
    cmp #(imgPointer >> 8) + 2
    beq .streamNextBlock
    rts
.streamNextBlock:
    phy
    phx
    lda #imgPointer & $FF
    sta $05
    lda #imgPointer >> 8
    sta $06
    jsr BIOSUtilityFunc + sdContinueStreamFile
    cmp #1
    bne .notAtEnd
    lda #$FF
    sta remainingBytes
.notAtEnd:
    plx
    ply
    lda #imgPointer >> 8
    sta $01
    stz $00
    rts
    
fileNotFoundString: string "File not found!\r\n"
invalidFileString: string "Not a valid PPM file!\r\n"
remainingBytes: byte 0 ; 0 until last block is hit, then ticks down from 255
    align 8
imgPointer: