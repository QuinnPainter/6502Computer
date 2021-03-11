    .include viaInfo.asm
    .include biosFunctions.asm

    .org $2000
    lda #helloString & $FF
    sta $00
    lda #helloString >> 8
    sta $01
    jsr BIOSUtilityFunc + printstring
    rts
    
helloString: .string "Hello, world!\r\n"