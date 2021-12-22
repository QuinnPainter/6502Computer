    .include viaInfo.asm
    .include biosFunctions.asm
fileLoadAddr = $2000

    .org $0700
    jmp irq
    .org $0703
    jmp osUtilityFunction
    .org $0706
    
    lda #4 ; Wait for approx 1 second
.startWaitLp:
    ldy #$FF
    jsr BIOSUtilityFunc + delay
    dea
    bne .startWaitLp
    
    lda #0
    jsr BIOSUtilityFunc + sendGfxCommand ; clear screen
    
    lda #bootBannerStart & $FF
    sta $00
    lda #bootBannerStart >> 8
    sta $01
    lda #(bootBannerEnd - bootBannerStart) & $FF
    sta $03
    lda #(bootBannerEnd - bootBannerStart) >> 8
    sta $02
    jsr BIOSUtilityFunc + sendGfxCommandArray
    
    lda #4
    jsr BIOSUtilityFunc + sendGfxCommand ; set foreground colour
    lda #7
    jsr BIOSUtilityFunc + sendGfxCommand ; to white
    lda #5
    jsr BIOSUtilityFunc + sendGfxCommand ; set background colour
    lda #0
    jsr BIOSUtilityFunc + sendGfxCommand ; to black
    
    ;lda #'\033' ; enable Insert mode (insert characters instead of overwriting)
    ;jsr BIOSUtilityFunc + printchar ; to disable, repeat the command but replace 'h' with 'l'
    ;lda #'['
    ;jsr BIOSUtilityFunc + printchar
    ;lda #'4'
    ;jsr BIOSUtilityFunc + printchar
    ;lda #'h'
    ;jsr BIOSUtilityFunc + printchar
    
    lda #'\033' ; enable Reverse Wraparound mode (wrap around the screen when going left with arrow or backspace)
    jsr BIOSUtilityFunc + printchar ; to disable, repeat the command but replace 'h' with 'l'
    lda #'[' ; unfortunately, there's no equivalent for right arrow, so you can't arrow off the right side of the screen
    jsr BIOSUtilityFunc + printchar
    lda #'?'
    jsr BIOSUtilityFunc + printchar
    lda #'4'
    jsr BIOSUtilityFunc + printchar
    lda #'5'
    jsr BIOSUtilityFunc + printchar
    lda #'h'
    jsr BIOSUtilityFunc + printchar
    
    jsr BIOSUtilityFunc + printnewline
    
    lda #'>'
    jsr BIOSUtilityFunc + printchar
    
mainlp:
    lda keyboardCurrentKey
    cmp #$FF
    bne .keyPressed
    jmp .noKey
.keyPressed:
    cmp #32
    bcc .controlCode
    ;pha
    ;ldy keyboardCursorPosition
    ;jsr keyboardBufferShiftRight
    ;pla
    lda keyboardCapslockState
    eor keyboardShiftState
    beq .lowercase
    ldy keyboardCurrentKey
    lda keyboardCapsLUT, Y
    bra .uppercase
.lowercase:
    lda keyboardCurrentKey
.uppercase:
    ldy keyboardCursorPosition      ; currently, this has a bug - if you type more than the buffer can handle,
    sta commandBuffer, Y            ; it will overflow back to the beginning, but this won't be visible on screen.
    jsr BIOSUtilityFunc + printchar ; but it should be fine, because no reasonable command is 256 chars long anyway, right?
    inc keyboardCursorPosition
    jmp .keyDone
.controlCode:
    cmp #25
    beq .leftArrow
    cmp #26
    beq .rightArrow
    cmp #11
    beq .enter
    cmp #12
    beq .backspace
    cmp #14
    beq .insert
    ;cmp #13
    ;beq .delete
    jmp .keyDone ; unused control code
.insert:
    ldy keyboardCursorPosition
    jsr keyboardBufferShiftRight
    lda #keyboardInsertSequence & $FF
    sta $00
    lda #keyboardInsertSequence >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    bra .keyDone
.leftArrow:
    lda keyboardCursorPosition
    beq .keyDone
    dec keyboardCursorPosition
    lda #'\033'
    jsr BIOSUtilityFunc + printchar
    lda #'['
    jsr BIOSUtilityFunc + printchar
    lda #'D'
    jsr BIOSUtilityFunc + printchar
    bra .keyDone
.rightArrow:
    ; in most terminals, you can only go as far right as the stuff you've typed
    ; guess that's a thing for later
    inc keyboardCursorPosition
    lda #'\033'
    jsr BIOSUtilityFunc + printchar
    lda #'['
    jsr BIOSUtilityFunc + printchar
    lda #'C'
    jsr BIOSUtilityFunc + printchar
    bra .keyDone
.backspace:
    lda keyboardCursorPosition
    beq .keyDone
    dec keyboardCursorPosition
    ldy keyboardCursorPosition
    lda #' '
    sta commandBuffer, Y
    lda #$8
    jsr BIOSUtilityFunc + printchar
    lda #' '
    jsr BIOSUtilityFunc + printchar
    lda #$8
    jsr BIOSUtilityFunc + printchar
    bra .keyDone
.enter:
    jsr BIOSUtilityFunc + printnewline
    lda #$FF ; if program uses key handling, we don't want it to parse the initial "enter" press
    sta keyboardCurrentKey
    jsr executeCommand
    ldy #0
    lda #$20
.clrCommandBuffer:
    sta commandBuffer, Y
    iny
    bne .clrCommandBuffer
    stz keyboardCursorPosition
    lda #'>'
    jsr BIOSUtilityFunc + printchar
    bra .keyDone
.keyDone:
    lda #$FF
    sta keyboardCurrentKey
.noKey:
    jmp mainlp
    
; Converts a string to all uppercase. Ignores non-letter characters.
; Inputs: ZPG 00, 01 - Address of string.
;         ZPG 02 - Character to break on. Usually 0.
; Outputs: Y, A - Garbage
convertStringUppercase:
    ldy #0
.convCharLp:
    lda ($00), Y
    cmp #97
    bcc .ignoreChar
    cmp #123
    bcs .ignoreChar
    sec
    sbc #32
    sta ($00), Y
    iny
    bra .convCharLp
.ignoreChar:
    cmp $02
    beq .done
    iny
    bra .convCharLp
.done:
    rts
    
; Converts an input 8.3 filename into the format used by the BIOS functions
; Inputs: ZPG 03 - 0E - 8.3 filename (with dot)
; Outputs: ZPG 07 - 11 - Converted 8.3 filename
;          ZPG 12 - 1C - Same converted 8.3 filename
;          A - 0 = success, 1 = invalid input filename
convert83Filename:
    stz $0F
    lda #$03
    sta $00 ; Convert to uppercase
    stz $01
    stz $02
    jsr convertStringUppercase
    lda #' '
    ldy #$B
.clr:sta $11, Y
    dey
    bne .clr
.readNameLp:
    lda $03, Y
    cmp #'.'
    beq .foundDot
    sta $12, Y
    iny
    cpy #$0C
    beq .invalidFilename
    bra .readNameLp
.invalidFilename:
    lda #1
    rts
.foundDot:
    lda $04, Y
    sta $1A
    lda $05, Y
    sta $1B
    lda $06, Y
    sta $1C
    ldy #$B
.copyLp:
    lda $11, Y
    sta $06, Y
    dey
    bne .copyLp
    lda #0
    rts
    
executeCommand:
    lda #commandBuffer & $FF ; Convert the command portion of the buffer to uppercase
    sta $00                  ; Breaks on space so should ignore the arguments
    lda #commandBuffer >> 8
    sta $01
    lda #' '
    sta $02
    jsr convertStringUppercase
    stz $00 ; Index of current command in command string
    ldy #0 ; Index into current command string
    ldx #0 ; Index into command buffer
.testCharLp:
    lda commandStrings, Y
    cmp #0
    beq .reachedEndOfCmdStrings
    cmp commandBuffer, X
    bne .tryNextCommand
    cmp #' '
    beq .foundCorrectCommand
    iny
    inx
    bra .testCharLp
.reachedEndOfCmdStrings:
    lda commandBuffer, X
    cmp #' '
    beq .foundCorrectCommand
    bne .commandDoesntExist
.tryNextCommand:
    lda $00
    clc
    adc #3
    sta $00 ; Each jump is 3 bytes, so the command pointer must be incremented by 3
    ldx #0
.findNextCommandLp:
    lda commandStrings, Y
    cmp #' '
    beq .gotNextCommand
    cmp #0
    beq .commandDoesntExist
    iny
    bra .findNextCommandLp
.gotNextCommand:
    iny
    bra .testCharLp
.foundCorrectCommand:
    lda $00
    sta .jmploc + 1 ; oooh, self modifying code! fancy!
.jmploc:jmp commandJmpTable
.commandDoesntExist:
    lda #invalidCommandString & $FF
    sta $00
    lda #invalidCommandString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    ldy #0
.printInvalidLoop:
    lda commandBuffer, Y
    cmp #' '
    beq .donePrint
    jsr BIOSUtilityFunc + printchar
    iny
    bra .printInvalidLoop
.donePrint:
    jsr BIOSUtilityFunc + printnewline
    rts
    
cls: ; Clear Screen
    lda #0
    jsr BIOSUtilityFunc + sendGfxCommand
    rts

reset:
    jmp ($FFFC)
    
run: ; Execute program from SD card
    ldy #0
.findArgLp:
    lda commandBuffer, Y
    iny
    cmp #' '
    bne .findArgLp
    ldx #0
.copyLp:
    lda commandBuffer, Y
    sta $03, X
    iny
    inx
    cpx #$0C
    bne .copyLp
    jsr convert83Filename
    cmp #1
    beq .invalidFilename
    lda #fileLoadAddr & $FF
    sta $14
    lda #fileLoadAddr >> 8
    sta $15
    jsr BIOSUtilityFunc + sdLoadFile
    cmp #1
    beq .fileNotFound
    jsr fileLoadAddr
    stz programIRQAddress + 1
    rts
.fileNotFound:
    lda #fileNotFoundString & $FF
    sta $00
    lda #fileNotFoundString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    bra .printFilename
.invalidFilename:
    lda #invalidFilenameString & $FF
    sta $00
    lda #invalidFilenameString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
.printFilename:
    ldy #$07
.printlp:
    lda $00, Y
    jsr BIOSUtilityFunc + printchar
    iny
    cpy #$12
    bne .printlp
    jsr BIOSUtilityFunc + printnewline
    rts
    
ramdump:
    ldy #0
.findArgLp:
    lda commandBuffer, Y
    iny
    cmp #' '
    bne .findArgLp
    lda commandBuffer, Y
    ldx commandBuffer + 1, Y
    jsr BIOSUtilityFunc + parseHexString
    cpx #1
    beq .invalidAddress
    stz $FE
    sta $FF
.printLineLp:
    lda $FF
    jsr BIOSUtilityFunc + printbyte
    lda $FE
    jsr BIOSUtilityFunc + printbyte
    lda #' '
    jsr BIOSUtilityFunc + printchar
.printByteLp:
    ldy #0
    lda ($FE), Y
    jsr BIOSUtilityFunc + printbyte
    inc $FE
    lda $FE
    and #$0F
    cmp #$00
    bne .printByteLp
    jsr BIOSUtilityFunc + printnewline
    lda $FE
    bne .printLineLp
    rts
.invalidAddress:
    lda #invalidAddressString & $FF
    sta $00
    lda #invalidAddressString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    lda commandBuffer + 1, Y
    pha
    lda commandBuffer, Y
    jsr BIOSUtilityFunc + printchar
    pla
    jsr BIOSUtilityFunc + printchar
    jsr BIOSUtilityFunc + printnewline
    rts
    
textdump:
    ldy #0
.findArgLp:
    lda commandBuffer, Y
    iny
    cmp #' '
    bne .findArgLp
    ldx #0
.copyLp:
    lda commandBuffer, Y
    sta $03, X
    iny
    inx
    cpx #$0C
    bne .copyLp
    jsr convert83Filename
    cmp #1
    beq .invalidFilename
    lda #fileLoadAddr & $FF
    sta $14
    lda #fileLoadAddr >> 8
    sta $15
    jsr BIOSUtilityFunc + sdLoadFile
    cmp #1
    beq .fileNotFound
    lda #2
    jsr BIOSUtilityFunc + sendGfxCommand
    lda #fileLoadAddr & $FF
    sta $00
    lda #fileLoadAddr >> 8
    sta $01
.printCharLp:
    ldy #0
    lda ($00), Y
    beq .donePrintFile
    jsr BIOSUtilityFunc + sendGfxCommand
    lda $00
    clc
    adc #1
    sta $00
    lda $01
    adc #0
    sta $01
    bra .printCharLp
.donePrintFile:
    lda #0
    jsr BIOSUtilityFunc + sendGfxCommand
    jsr BIOSUtilityFunc + printnewline
    rts
.fileNotFound:
    lda #fileNotFoundString & $FF
    sta $00
    lda #fileNotFoundString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    bra .printFilename
.invalidFilename:
    lda #invalidFilenameString & $FF
    sta $00
    lda #invalidFilenameString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
.printFilename:
    ldy #$07
.printlp:
    lda $00, Y
    jsr BIOSUtilityFunc + printchar
    iny
    cpy #$12
    bne .printlp
    jsr BIOSUtilityFunc + printnewline
    rts
    
; Shift the command buffer left by 1 from a certain position
; Inputs: A - Position to left shift to
; Outputs: X, Y, ZPG 00 - Garbage
;keyboardBufferShiftLeft:
;    sta $00
;    lda #$20
;    ldy #$FF
;.lp:ldx commandBuffer, Y
;    sta commandBuffer, Y
;    txa
;    dey
;    cpy $00
;    bne .lp
;    rts
    
; Shift the command buffer right by 1 from a certain position
; Inputs: Y - Position to right shift to
; Outputs: A, X - Garbage
keyboardBufferShiftRight:
    lda #$20
.lp:ldx commandBuffer, Y
    sta commandBuffer, Y
    txa
    iny
    bne .lp
    rts
    
irq: ; Given an input of A from the BIOS - 0 = Keyboard interrupt, 1 = Other interrupt
    ldx programIRQAddress + 1
    beq .noProgramIRQ
    jmp (programIRQAddress)
.noProgramIRQ:
    and #$FF
    bne .otherInterrupt
    jsr keyboardInterrupt
.otherInterrupt:
    rts
    
keyboardInterrupt:
    lda VIA1_RA
    tax
    and #$7F
    cmp #2
    bcc .shift
    txa
    and #$80    ; ignore break codes (top bit set)
    bne .breakCode
    cpx #8
    beq .capslk
    stx keyboardCurrentKey
.breakCode:
    rts
.shift:
    txa
    and #$80
    bne .shiftReleased
    lda #$FF
    sta keyboardShiftState
    rts
.shiftReleased:
    stz keyboardShiftState
    rts
.capslk:
    lda keyboardCapslockState
    eor #$FF
    sta keyboardCapslockState
    rts
    
osUtilityFunction:
    sty .j + 1
.j: jmp osUtilityFunctionTable
    
getCurrentKey:
    sei
    lda keyboardCurrentKey
    pha
    lda #$FF
    sta keyboardCurrentKey
    pla
    cli
    rts
    
getCapsState:
    lda keyboardCapslockState
    eor keyboardShiftState
    rts
    
; Sets the address that gets jumped to on IRQ
; Inputs : A - Low byte of address
;          X - High byte of address
setIRQAddress:
    sta programIRQAddress
    stx programIRQAddress + 1
    rts
    
bootBannerStart:
    .binary bootbanner.bin
bootBannerEnd:

commandStrings: .string "CLS RESET RUN RAMDUMP TEXTDUMP" ; if this gets greater than 256 chars, there will be problems...
invalidCommandString: .string "Invalid command: "
invalidFilenameString: .string "Invalid filename: "
invalidAddressString: .string "Invalid address: "
fileNotFoundString: .string "File not found: "
keyboardInsertSequence: .string "\033[4h \033[D\033[4l" ; enable Insert mode, put space, cursor left, disable insert mode
keyboardCapsLUT: .include keyboardCapsLUT.asm

keyboardCursorPosition: .byte 0
keyboardCurrentKey: .byte $FF
keyboardShiftState: .byte 0
keyboardCapslockState: .byte 0

programIRQAddress: .word 0

commandBuffer: .blk 256, $20

    .align 8
commandJmpTable:
    jmp cls
    jmp reset
    jmp run
    jmp ramdump
    jmp textdump
    
    .align 8
osUtilityFunctionTable:
    jmp getCurrentKey
    jmp getCapsState
    jmp setIRQAddress