    include viaInfo.asm
    include biosFunctions.asm
    include qsdosFunctions.asm

    org $2000
    
    lda #'S'
    sta $7
    lda #'O'
    sta $8
    lda #'N'
    sta $9
    lda #'G'
    sta $A
    lda #' '
    sta $B
    lda #' '
    sta $C
    lda #' '
    sta $D
    lda #' '
    sta $E
    lda #'V'
    sta $F
    lda #'G'
    sta $10
    lda #'M'
    sta $11
    lda #songPointer & $FF
    sta $14
    lda #songPointer >> 8
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
    lda #playingString & $FF
    sta $00
    lda #playingString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring

    lda #songPointer & $FF
    sta $00
    lda #songPointer >> 8
    sta $01 ; $00-$01 = Current Command Pointer
    
    lda $00
    clc
    adc #$80
    sta $00 ; Get past VGM file header

    ldy #$FF
    jsr BIOSUtilityFunc + delay ; Wait for the start string to print so there aren't any interrupts while the song plays
    
mainlp:
    lda ($00)
    cmp #$A0
    beq .setRegister
    tax
    and #$F0
    cmp #$70
    beq .shortWait
    txa
    cmp #$61
    beq .longWait
    cmp #$62
    beq .frameWait60
    cmp #$63
    beq .frameWait50
    cmp #$66
    bne .notEndOfSong
    jmp .endOfSong
.notEndOfSong:
    jmp unknownCommand
.setRegister:
    jsr incCommandPointer
    lda ($00)
    tax
    jsr incCommandPointer
    lda ($00)
    jsr BIOSUtilityFunc + writeSoundRegister
    jsr incCommandPointer
    bra mainlp
.shortWait:
    txa
    and #$0F
    ina ; Wait isn't 0-15, it's 1-16
.swlp:
    jsr waitOneSample
    dea
    bne .swlp
    jsr incCommandPointer
    bra mainlp
.frameWait60:
    jsr wait735Samples
    jsr incCommandPointer
    bra mainlp
.frameWait50:
    jsr wait882Samples
    jsr incCommandPointer
    bra mainlp
.longWait:
    jsr incCommandPointer
    lda ($00)
.lowerLoop: ; Wait the amount of samples specified by lower byte
    beq .doneLowerLoop
    jsr waitOneSample
    dea
    bra .lowerLoop
.doneLowerLoop:
    jsr incCommandPointer
    lda ($00)
.upperLoop: ; Wait the amount of samples specified by upper byte
    beq .doneUpperLoop
    jsr waitFFSamples
    dea
    bra .upperLoop
.doneUpperLoop:
    jsr incCommandPointer
    jmp mainlp
.endOfSong:
    lda #0 ; Mute all sound channels
    ldx #$8
    jsr BIOSUtilityFunc + writeSoundRegister
    lda #0
    ldx #$9
    jsr BIOSUtilityFunc + writeSoundRegister
    lda #0
    ldx #$A
    jsr BIOSUtilityFunc + writeSoundRegister
    lda #finishedPlayingString & $FF
    sta $00
    lda #finishedPlayingString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    rts
    
; Made for 2MHz. Waits exactly 45 cycles, including the function call + return.
waitOneSample: ; JSR - 6 cycles.
    rept 15 ; 15 * 2 = 30
    nop ; 2
    endr
    cpy $00 ; 3
    rts ; 6
    
; Waits 11564 cycles (could be off by 1 or 2)
waitFFSamples: ; JSR - 6 cycles
    ldy #222 ; 2
.l: jsr waitOneSample ; 45      ]
    dey ; 2                     ]   loop: 52 per iteration, 222 * 52 = 11544
    beq .d ; 2 (3 if succeed)   ]
    jmp .l ; 3                  ]
.d: nop ; 2
    cpy $00 ; 3
    rts ; 6
    
; Waits 735 samples (could be off by 1 or 2) (equivalent to 1 frame at 60fps)
wait735Samples: ; JSR - 6 cycles
    ldy #13 ; 2
.l: jsr waitOneSample ; 45      ]
    dey ; 2                     ]   loop: 52 per iteration, 13 * 52 = 676
    beq .d ; 2 (3 if succeed)   ]
    jmp .l ; 3                  ]
.d: jsr waitOneSample ; 45
    rts ; 6
   
; Waits 882 samples (could be off by 1 or 2) (equivalent to 1 frame at 50fps)   
wait882Samples: ; JSR - 6 cycles
    ldy #15 ; 2
.l: jsr waitOneSample ; 45      ]
    dey ; 2                     ]   loop: 52 per iteration, 15 * 52 = 780
    beq .d ; 2 (3 if succeed)   ]
    jmp .l ; 3                  ]
.d: jsr waitOneSample ; 45
    jsr waitOneSample ; 45
    rts ; 6

incCommandPointer:
    lda $00
    clc
    adc #1
    sta $00
    lda $01
    adc #0
    sta $01
    cmp #(songPointer >> 8) + 2
    beq .streamNextBlock
    rts
.streamNextBlock:
    phy
    phx
    lda #songPointer & $FF
    sta $05
    lda #songPointer >> 8
    sta $06
    jsr BIOSUtilityFunc + sdContinueStreamFile
    plx
    ply
    lda #songPointer >> 8
    sta $01
    stz $00
    rts

unknownCommand:
    phx
    lda #badCommandString & $FF
    sta $00
    lda #badCommandString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    pla
    jsr BIOSUtilityFunc + printbyte
    jsr BIOSUtilityFunc + printnewline
    rts
    
;irq: ; Given an input of A from the BIOS - 0 = Keyboard interrupt, 1 = Other interrupt
;    tax
;    beq .keyboardInterrupt
;    lda VIA2_T1CL ; Acknowledge timer interrupt
;    ldy #$0
;    lda $00
;    jsr writeSoundRegister
;    inc $00
;    
;    lda #'1'
;    jsr BIOSUtilityFunc + printchar
;    rts
;.keyboardInterrupt:
;    lda VIA2_RA
;    rts

playingString: string "Playing song.vgm...\r\n"
finishedPlayingString: string "Done!\r\n"
fileNotFoundString: string "File not found!\r\n"
badCommandString: string "Unimplemented VGM command: "
    align 8
songPointer: