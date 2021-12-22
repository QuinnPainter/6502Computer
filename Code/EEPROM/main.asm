    .include viaInfo.asm

SD_MISO = %10000000
SD_MOSI = %01000000
SD_CLK = %00100000
SD_CS = %00010000

SOUND_BUSCTRL = VIA2_RA
SOUND_DATABUS = VIA2_RB
SOUND_BC1 = %00000001
SOUND_BDIR = %00000010
SOUND_BUSMODE_DATA = SOUND_BDIR
SOUND_BUSMODE_ADDR = SOUND_BDIR | SOUND_BC1
SOUND_BUSMODE_READ = SOUND_BC1

; $0000 - page 0 (used for temp variables)
; $0100 - stack page
; $0200 - leaving open (needed for EhBASIC)
gfxCmdBufferPage = $0300 ; 0300 - 03FF (must be page-aligned)
sdBufferAddr = $0400 ; 0400 - 05FF (must be page-aligned)
fat32SectorsPerCluster = $0600
fat32RootDirClusterNum = $0601 ; 0601 - 0604 (l.e. 32 bit number)
fat32SectorOffset = $0605 ; 0605 - 0608 (l.e. 32 bit number) Offset between the beginning of the drive and the start of the partition
fat32NumReservedSectors = $0609 ; 0609 - 060A (l.e. 16 bit number)
fat32FATBeginAddr = $060B ; 060B - 060E (l.e. 32 bit number) Absolute sector addr of the first FAT
fat32NumFATs = $060F
fat32SectorsPerFAT = $0610 ; 0610 - 0613 (l.e. 32 bit number)
fat32ClusterBeginAddr = $0614 ; 0614 - 0617 (l.e. 32 bit number) Absolute addr of the beginning of the cluster area
fat32RootDirBeginAddr = $0618 ; 0618 - 061B (l.e. 32 bit number) Absolute addr of the root directory
sdCurrentClusterNum = $061C ; 061C - 061F (l.e. 32 bit)
sdCurrentSectorNum = $0620 ; 0620 - 0623 (l.e. 32 bit)
sdCurrentSectorInCluster = $0624 ; (8 bit) Index of the current sector relative to the current cluster (so it's 0 to 7)
gfxCmdBufferTop = $0625
gfxCmdBufferBottom = $0626
sdosLoaded = $0627

    .org $C000
    ; Jump table used for accessing BIOS utilities from programs in RAM
    ; Each JMP is 3 bytes, sooo:
    jmp binhex ; 0
    jmp sendGfxCommand ; 3
    jmp printchar ; 6
    jmp printstring ; 9
    jmp printbyte ; 12
    jmp sendGfxCommandArray ; 15
    jmp printnewline ; 18
    jmp fastmemfill ; 21
    jmp delay ; 24
    jmp div8x8 ; 27
    jmp sdLoadFile ; 30
    jmp parseHexString ; 33
    jmp writeSoundRegister ; 36
    jmp sdStartStreamFile ; 39
    jmp sdContinueStreamFile ; 42
reset:
    ldx #$FF ; Initialize stack pointer
    txs
    
    sei ; disable IRQ
    cld ; disable decimal mode
    
    stz VIA1_DDRA ; keyboard input bus all inputs
    ;lda #%00001000
    ;sta VIA2_PCR ; setup keyboard handshake
    ;lda #%01111111
    ;sta VIA2_IER ; disable VIA2 interrupts
    ;lda #%10000010
    ;sta VIA2_IER ; enable keyboard interrupt
    
    lda #%11111111
    sta VIA1_DDRB ; DDRB (graphics bus) all outputs
    lda #%10001000
    sta VIA1_PCR ; setup graphics and keyboard handshake
    lda #%01111111
    sta VIA1_IER ; disable VIA1 interrupts
    lda #%10010010
    sta VIA1_IER ; Enable graphics ready and keyboard interrupts
    
    lda #%11111111
    sta VIA2_DDRB ; Sound bus all outputs
    
    lda #%01110011
    sta VIA2_DDRA ; SD + sound inputs / outputs
    
    ldy #$FF ; wait for graphics card to start up
    jsr delay
    
    stz gfxCmdBufferTop
    stz gfxCmdBufferBottom
    stz sdosLoaded
    
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
    
    ; Memory test
    lda #'\033' ; Escape code to move the cursor left 6 spaces
    jsr printchar
    lda #'['
    jsr printchar
    lda #'6'
    jsr printchar
    lda #'D'
    jsr printchar
    
    ldy #0
    stz $00
    lda #$07 ; Can only test from $0700 on (below is used for zero page, stack, and graphics)
    sta $01
    stz $02 ; holds the 6-digit BCD value of the number of bytes tested
    lda #$17
    sta $03
    lda #$92
    sta $04
.memtestLoop:
    sed
    clc ; Increment number of bytes tested (4 bytes are tested at a time)
    lda $04
    adc #4
    sta $04
    lda $03
    adc #0
    sta $03
    lda $02
    adc #0
    sta $02
    cld
    lda #2
    jsr sendGfxCommand
    lda #'\033' ; Escape code to move the cursor left 5 spaces
    jsr sendGfxCommand
    lda #'['
    jsr sendGfxCommand
    lda #'5'
    jsr sendGfxCommand
    lda #'D'
    jsr sendGfxCommand
    lda $02
    jsr binhex
    txa
    jsr sendGfxCommand
    lda $03
    jsr binhex
    phx
    jsr sendGfxCommand
    pla
    jsr sendGfxCommand
    lda $04
    jsr binhex
    phx
    jsr sendGfxCommand
    pla
    jsr sendGfxCommand
    lda #0
    jsr sendGfxCommand
    
    ldx #4
.memtestCheckByteLoop:
    lda #$FF
    sta ($00), Y
    lda ($00), Y
    cmp #$FF
    bne .memtestFail
    iny
    beq .memtestNextPage
.memtestNextPageRet:
    dex
    bne .memtestCheckByteLoop

    bra .memtestLoop
.memtestNextPage:
    inc $01
    lda $01
    cmp #$80
    beq .memtestPass
    bra .memtestNextPageRet
.memtestFail:
    lda #memtestFailString & $FF
    sta $00
    lda #memtestFailString >> 8
    sta $01
    jsr printstring
    bra .memtestDone
.memtestPass:
    lda #memtestPassString & $FF
    sta $00
    lda #memtestPassString >> 8
    sta $01
    jsr printstring
.memtestDone:
    
    ; Initialise SD card
    lda #initsdString & $FF
    sta $00
    lda #initsdString >> 8
    sta $01
    jsr printstring
    
    lda #SD_CS
    sta VIA2_RA ; Set CS high, CLK low
    ldx #10 ; Send dummy byte (0xFF) 10 times
.dummyByteLoop:
    lda #$FF
    jsr sdSendByte
    dex
    bne .dummyByteLoop
    
    stz VIA2_RA     ; Set CS low
    lda #$40        ; Send CMD0 (0x40, 4 blank argument bytes, 0x95 CRC)
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$95
    jsr sdSendByte
    
    jsr sdWaitResponse
    ldx #0              ; Error code 0
    cmp #$01            ; Response should be 01
    beq .nosderr0
    jmp sdError
.nosderr0:
    
    jsr sdSendDummies
    
    stz VIA2_RA     ; Set CS low
    lda #$48        ; Send CMD8 (0x48, 0x000001AA argument, 0x87 CRC)
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$01
    jsr sdSendByte
    lda #$AA
    jsr sdSendByte
    lda #$87
    jsr sdSendByte
    
    jsr sdWaitResponse
    ldx #1              ; Error code 1
    cmp #$01            ; Response should be 01
    beq .nosderr1
    jmp sdError
.nosderr1:
    
    jsr sdGetByte       ; Accept and discard the 4 byte response
    jsr sdGetByte
    jsr sdGetByte
    jsr sdGetByte
    
    jsr sdSendDummies
    
.sdInitLoop:
    jsr sdSendDummies
    
    stz VIA2_RA     ; CRC should be disabled by this point so we can just use 0xFF (not 0!)
    lda #$77        ; Send CMD55 (0x77, 0x00000000 argument, 0x65 CRC)
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$65
    jsr sdSendByte
    
    jsr sdWaitResponse
    ldx #2              ; Error code 2
    cmp #$01            ; Response should be 01
    beq .nosderr2
    jmp sdError
.nosderr2:

    jsr sdSendDummies
    
    stz VIA2_RA
    lda #$69        ; Send ACMD41 (0x69, 0x40000000 argument, 0x77 CRC)
    jsr sdSendByte
    lda #$40
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$77
    jsr sdSendByte
    
    jsr sdWaitResponse  ; keep sending CMD55 and ACMD41 until response is 0
    cmp #$00
    beq .sdInitDone
    jmp .sdInitLoop
.sdInitDone:

    jsr sdSendDummies
    
    stz VIA2_RA
    lda #$7A        ; Send CMD58 (0x7A, 0x00000000 argument, 0xFF CRC)
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$FF
    jsr sdSendByte

    jsr sdWaitResponse ; ignore status response
    
    jsr sdGetByte       ; 32 bit response
    pha
    jsr sdGetByte
    jsr sdGetByte
    jsr sdGetByte
    
    pla
    and #%11000000      ; Check top 2 bits are set (top = card busy, second = card capacity status)
    cmp #%11000000
    beq .sdStatusCorrect
    ldx #$3             ; Error code 3
    jmp sdError
.sdStatusCorrect:

    jsr sdSendDummies

    stz VIA2_RA
    lda #$50        ; Send CMD16 (0x50, 0x00000200 argument, 0xFF CRC)
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$02
    jsr sdSendByte
    lda #$00
    jsr sdSendByte
    lda #$FF
    jsr sdSendByte
    
    jsr sdWaitResponse
    cmp #0
    beq .nosderr3
    ldx #4
    jmp sdError
.nosderr3:

    jsr sdSendDummies
    
    lda #successString & $FF ; Successfully initialised SD
    sta $00
    lda #successString >> 8
    sta $01
    jsr printstring
    
    lda #fsStartString & $FF
    sta $00
    lda #fsStartString >> 8
    sta $01
    jsr printstring
    
    stz $01 ; Address to read (0)
    stz $02
    stz $03
    stz $04
    lda #sdBufferAddr >> 8 ; Address to save to
    sta $06
    lda #sdBufferAddr & $FF
    sta $05
    jsr sdReadBlock
    
    lda sdBufferAddr + $52
    cmp #"F"
    bne .nofat32
    lda sdBufferAddr + $53
    cmp #"A"
    bne .nofat32
    lda sdBufferAddr + $54
    cmp #"T"
    bne .nofat32
    lda sdBufferAddr + $55
    cmp #"3"
    bne .nofat32
    lda sdBufferAddr + $56
    cmp #"2"
    bne .nofat32
    ; FAT32 partition is present without MBR
    lda #fat32nombrString & $FF
    sta $00
    lda #fat32nombrString >> 8
    sta $01
    jsr printstring
    stz $01
    stz $02
    stz $03
    stz $04
    jmp .partitionFound
.nofat32:
    lda sdBufferAddr + $36
    cmp #"F"
    bne .nofat16
    lda sdBufferAddr + $37
    cmp #"A"
    bne .nofat16
    lda sdBufferAddr + $38
    cmp #"T"
    bne .nofat16
    ; FAT12 or FAT16 partition present without MBR
    ldx #5
    jmp sdError
.nofat16: ; https://en.wikipedia.org/wiki/Master_boot_record#PTE
    ; Haven't found FAT32/16/12 partition, so assume block 1 is MBR
    lda sdBufferAddr + $1BE + $4
    cmp #$0C ; Partition Type = FAT32 with Logical Block Addressing
    beq .validPartitionType
    ldx #6
    jmp sdError
.validPartitionType:
    lda #fat32mbrString & $FF
    sta $00
    lda #fat32mbrString >> 8
    sta $01
    jsr printstring
    lda sdBufferAddr + $1BE + $8
    sta $01
    lda sdBufferAddr + $1BE + $9
    sta $02
    lda sdBufferAddr + $1BE + $A
    sta $03
    lda sdBufferAddr + $1BE + $B
    sta $04
.partitionFound: ; At this point, address of start of fat32 should be in $01 - $04
    lda $01
    sta fat32SectorOffset + 0
    lda $02
    sta fat32SectorOffset + 1
    lda $03
    sta fat32SectorOffset + 2
    lda $04
    sta fat32SectorOffset + 3
    ; Read in the FAT32 boot sector
    lda #sdBufferAddr >> 8 ; Address to save to
    sta $06
    lda #sdBufferAddr & $FF
    sta $05
    jsr sdReadBlock
    lda sdBufferAddr + $0D ; Number of sectors per cluster
    sta fat32SectorsPerCluster
    lda sdBufferAddr + $0E ; Number of reserved sectors
    sta fat32NumReservedSectors
    lda sdBufferAddr + $0E + 1
    sta fat32NumReservedSectors + 1
    lda sdBufferAddr + $10 ; Number of FATs
    sta fat32NumFATs
    lda sdBufferAddr + $24 + 0 ; Sectors per FAT
    sta fat32SectorsPerFAT + 0
    lda sdBufferAddr + $24 + 1
    sta fat32SectorsPerFAT + 1
    lda sdBufferAddr + $24 + 2
    sta fat32SectorsPerFAT + 2
    lda sdBufferAddr + $24 + 3
    sta fat32SectorsPerFAT + 3
    lda sdBufferAddr + $2C + 0 ; 32 bit root directory cluster number
    sta fat32RootDirClusterNum + 0
    lda sdBufferAddr + $2C + 1
    sta fat32RootDirClusterNum + 1
    lda sdBufferAddr + $2C + 2
    sta fat32RootDirClusterNum + 2
    lda sdBufferAddr + $2C + 3
    sta fat32RootDirClusterNum + 3
    
    lda fat32SectorOffset + 0 ; FAT Begin Addr = start of partition + reserved sectors
    sta $00
    lda fat32SectorOffset + 1
    sta $01
    lda fat32SectorOffset + 2
    sta $02
    lda fat32SectorOffset + 3
    sta $03
    lda fat32NumReservedSectors + 0
    sta $04
    lda fat32NumReservedSectors + 1
    sta $05
    stz $06
    stz $07
    jsr add32
    lda $08
    sta fat32FATBeginAddr + 0
    lda $09
    sta fat32FATBeginAddr + 1
    lda $0A
    sta fat32FATBeginAddr + 2
    lda $0B
    sta fat32FATBeginAddr + 3
    
    lda fat32SectorsPerFAT + 0 ; Cluster Begin Addr = start of partition + reserved sectors + (num FATS * sectors per FAT)
    sta $00
    lda fat32SectorsPerFAT + 1
    sta $01
    lda fat32SectorsPerFAT + 2
    sta $02
    lda fat32SectorsPerFAT + 3
    sta $03
    ldx fat32NumFATs
    jsr mul32x8 ; get (numFATS * sectorsPerFAT)
    lda fat32FATBeginAddr + 0
    sta $04
    lda fat32FATBeginAddr + 1
    sta $05
    lda fat32FATBeginAddr + 2
    sta $06
    lda fat32FATBeginAddr + 3
    sta $07
    jsr add32 ; add start of partition + reserved sectors (which is equal to FAT Begin Addr)
    lda $08
    sta fat32ClusterBeginAddr + 0
    lda $09
    sta fat32ClusterBeginAddr + 1
    lda $0A
    sta fat32ClusterBeginAddr + 2
    lda $0B
    sta fat32ClusterBeginAddr + 3
    
    lda fat32RootDirClusterNum ; Calculate the root directory addr from the cluster num
    sta $00
    lda fat32RootDirClusterNum + 1
    sta $01
    lda fat32RootDirClusterNum + 2
    sta $02
    lda fat32RootDirClusterNum + 3
    sta $03
    jsr fat32ClusterToSector
    lda $08
    sta fat32RootDirBeginAddr + 0
    lda $09
    sta fat32RootDirBeginAddr + 1
    lda $0A
    sta fat32RootDirBeginAddr + 2
    lda $0B
    sta fat32RootDirBeginAddr + 3
    
    lda #loadingsdosString & $FF
    sta $00
    lda #loadingsdosString >> 8
    sta $01
    jsr printstring
    
    lda #'S'
    sta $7
    lda #'D'
    sta $8
    lda #'O'
    sta $9
    lda #'S'
    sta $A
    lda #'B'
    sta $B
    lda #'O'
    sta $C
    lda #'O'
    sta $D
    lda #'T'
    sta $E
    lda #'P'
    sta $F
    lda #'R'
    sta $10
    lda #'G'
    sta $11
    lda #$00 ; Address to save to - $0700
    sta $14
    lda #$07
    sta $15
    jsr sdLoadFile
    
    tax
    bne .fileNotFound
    
    lda #sdossuccessString & $FF
    sta $00
    lda #sdossuccessString >> 8
    sta $01
    jsr printstring
    
    lda #$FF
    sta sdosLoaded
    
    jmp $0706
    
.fileNotFound:
    lda #sdoserrorString & $FF ; If sdLoadFile returns 1, the file wasn't found
    sta $00
    lda #sdoserrorString >> 8
    sta $01
    jsr printstring
.stucklp:
    bra .stucklp

; Encountered an error with the SD card
; This locks up the computer, so no need for outputs or subroutine stuff.
; Inputs: X - Error code
sdError:
    phx
    lda #failString & $FF
    sta $00
    lda #failString >> 8
    sta $01
    jsr printstring
    pla
    jsr printbyte
.sdErrorLoop:       ; Computer won't work without SD, so just be stuck forever
    bra .sdErrorLoop
    
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

; Load a file from the SD card into ram
; Currently only works in the root directory
; Inputs - ZPG $07 - $11 - 8.3 filename of file to load
;          ZPG $14 - $15 - Address to save the file to (page aligned)
; Outputs - A - Status (0 = success, 1 = fail)
sdLoadFile:
    stz $00 ; used for detecting if we need to go to next sector
    stz sdCurrentSectorInCluster

    lda fat32RootDirClusterNum + 0
    sta sdCurrentClusterNum + 0
    lda fat32RootDirClusterNum + 1
    sta sdCurrentClusterNum + 1
    lda fat32RootDirClusterNum + 2
    sta sdCurrentClusterNum + 2
    lda fat32RootDirClusterNum + 3
    sta sdCurrentClusterNum + 3
    
    lda fat32RootDirBeginAddr + 0
    sta sdCurrentSectorNum + 0
    sta $01
    lda fat32RootDirBeginAddr + 1
    sta sdCurrentSectorNum + 1
    sta $02
    lda fat32RootDirBeginAddr + 2
    sta sdCurrentSectorNum + 2
    sta $03
    lda fat32RootDirBeginAddr + 3
    sta sdCurrentSectorNum + 3
    sta $04
    lda #sdBufferAddr >> 8 ; Address to save to
    sta $06
    lda #sdBufferAddr & $FF
    sta $05
    jsr sdReadBlock
    ; $12, $13 is used as the RAM addr of the current file entry we're looking at
    lda #sdBufferAddr & $FF
    sta $12
    lda #sdBufferAddr >> 8
    sta $13
.checkLoop: ; Loop to check if the current file is the one we want
    ldy #0
    lda ($12), Y ; Load the first byte of the file entry
    beq .fileNotFound ; If it's 0, we've reached the end of the directory
    cmp #$E5
    beq .skip ; If it's E5, this file is "unused" (deleted)
    ldy #$0B
    lda ($12), Y ; Load the attribute byte
    tax
    and #%00001111 ; If last 4 bits are set, this file is a LFN entry (should be ignored)
    cmp #%00001111
    beq .skip
    txa
    and #%00011000 ; Bit 4 = Entry is directory, Bit 3 = Entry is Volume ID
    bne .skip ; Check that both bits are 0
    ; Check filename
    ldy #$0
.filenameCheckLoop:
    lda ($12), Y
    cmp $07, Y
    bne .skip
    iny
    cpy #11
    bne .filenameCheckLoop
    bra .correctFile
.fileNotFound:
    lda #1
    rts
.skip: ; Go to next file
    lda $12
    clc
    adc #32
    sta $12
    bcc .noInc
    lda $00
    beq .nextChunk
    
    ldy #0
.pushFilenameLp: ; fat32FindNextSector overwrites the filename area $07-$11 so we need to save it
    lda $07, Y
    pha
    iny
    cpy #11
    bne .pushFilenameLp
    
    jsr fat32FindNextSector
    tax
    
    ldy #10
.pullFilenameLp:
    pla
    sta $07, Y
    dey
    cpy #$FF
    bne .pullFilenameLp
    
    txa
    bne .fileNotFound
    lda sdCurrentSectorNum + 0
    sta $01
    lda sdCurrentSectorNum + 1
    sta $02
    lda sdCurrentSectorNum + 2
    sta $03
    lda sdCurrentSectorNum + 3
    sta $04
    lda #sdBufferAddr >> 8 ; Address to save to
    sta $06
    lda #sdBufferAddr & $FF
    sta $05
    jsr sdReadBlock
    lda #sdBufferAddr & $FF ; Reset buffer addr
    sta $12
    lda #sdBufferAddr >> 8
    sta $13
    stz $00 ; Get the next sector
    jmp .checkLoop
.nextChunk: ; Go to the next 256 bytes of the current sector
    lda #$FF
    sta $00
    inc $13
.noInc:
    jmp .checkLoop
.correctFile: ; Load the file that was found
    stz sdCurrentSectorInCluster

    ldy #$1A ; Cluster Low, byte 1
    lda ($12), Y
    sta $00
    sta sdCurrentClusterNum + 0
    ldy #$1B ; Cluster Low, byte 2
    lda ($12), Y
    sta $01
    sta sdCurrentClusterNum + 1
    ldy #$14 ; Cluster High, byte 1
    lda ($12), Y
    sta $02
    sta sdCurrentClusterNum + 2
    ldy #$15 ; Cluster High, byte 2
    lda ($12), Y
    sta $03
    sta sdCurrentClusterNum + 3
    jsr fat32ClusterToSector
    
    lda $08
    sta sdCurrentSectorNum + 0
    lda $09
    sta sdCurrentSectorNum + 1
    lda $0A
    sta sdCurrentSectorNum + 2
    lda $0B
    sta sdCurrentSectorNum + 3
    
    lda $14 ; Where to put the block
    sta $05
    lda $15
    sta $06
.readFileLoop:
    lda sdCurrentSectorNum + 0
    sta $01
    lda sdCurrentSectorNum + 1
    sta $02
    lda sdCurrentSectorNum + 2
    sta $03
    lda sdCurrentSectorNum + 3
    sta $04
    
    lda $06
    pha
    lda $05
    pha
    
    jsr sdReadBlock
    jsr fat32FindNextSector
    tax
    
    pla
    sta $05
    pla
    sta $06
    
    inc $06
    inc $06
    txa
    beq .readFileLoop
    
    lda #0
    rts
    
; Start streaming a file from SD card, and load the first 512 byte block
; Currently only works in the root directory
; Inputs - ZPG $07 - $11 - 8.3 filename of file to load
;          ZPG $14 - $15 - Address to save the file to (page aligned)
; Outputs - A - Status (0 = success, 1 = fail, 2 = reached end of file (file was only 512 bytes))
sdStartStreamFile:
    stz $00 ; used for detecting if we need to go to next sector
    stz sdCurrentSectorInCluster

    lda fat32RootDirClusterNum + 0
    sta sdCurrentClusterNum + 0
    lda fat32RootDirClusterNum + 1
    sta sdCurrentClusterNum + 1
    lda fat32RootDirClusterNum + 2
    sta sdCurrentClusterNum + 2
    lda fat32RootDirClusterNum + 3
    sta sdCurrentClusterNum + 3
    
    lda fat32RootDirBeginAddr + 0
    sta sdCurrentSectorNum + 0
    sta $01
    lda fat32RootDirBeginAddr + 1
    sta sdCurrentSectorNum + 1
    sta $02
    lda fat32RootDirBeginAddr + 2
    sta sdCurrentSectorNum + 2
    sta $03
    lda fat32RootDirBeginAddr + 3
    sta sdCurrentSectorNum + 3
    sta $04
    lda #sdBufferAddr >> 8 ; Address to save to
    sta $06
    lda #sdBufferAddr & $FF
    sta $05
    jsr sdReadBlock
    ; $12, $13 is used as the RAM addr of the current file entry we're looking at
    lda #sdBufferAddr & $FF
    sta $12
    lda #sdBufferAddr >> 8
    sta $13
.checkLoop: ; Loop to check if the current file is the one we want
    ldy #0
    lda ($12), Y ; Load the first byte of the file entry
    beq .fileNotFound ; If it's 0, we've reached the end of the directory
    cmp #$E5
    beq .skip ; If it's E5, this file is "unused" (deleted)
    ldy #$0B
    lda ($12), Y ; Load the attribute byte
    tax
    and #%00001111 ; If last 4 bits are set, this file is a LFN entry (should be ignored)
    cmp #%00001111
    beq .skip
    txa
    and #%00011000 ; Bit 4 = Entry is directory, Bit 3 = Entry is Volume ID
    bne .skip ; Check that both bits are 0
    ; Check filename
    ldy #$0
.filenameCheckLoop:
    lda ($12), Y
    cmp $07, Y
    bne .skip
    iny
    cpy #11
    bne .filenameCheckLoop
    bra .correctFile
.fileNotFound:
    lda #1
    rts
.skip: ; Go to next file
    lda $12
    clc
    adc #32
    sta $12
    bcc .noInc
    lda $00
    beq .nextChunk
    
    ldy #0
.pushFilenameLp: ; fat32FindNextSector overwrites the filename area $07-$11 so we need to save it
    lda $07, Y
    pha
    iny
    cpy #11
    bne .pushFilenameLp
    
    jsr fat32FindNextSector
    tax
    
    ldy #10
.pullFilenameLp:
    pla
    sta $07, Y
    dey
    cpy #$FF
    bne .pullFilenameLp
    
    txa
    bne .fileNotFound
    lda sdCurrentSectorNum + 0
    sta $01
    lda sdCurrentSectorNum + 1
    sta $02
    lda sdCurrentSectorNum + 2
    sta $03
    lda sdCurrentSectorNum + 3
    sta $04
    lda #sdBufferAddr >> 8 ; Address to save to
    sta $06
    lda #sdBufferAddr & $FF
    sta $05
    jsr sdReadBlock
    lda #sdBufferAddr & $FF ; Reset buffer addr
    sta $12
    lda #sdBufferAddr >> 8
    sta $13
    stz $00 ; Get the next sector
    jmp .checkLoop
.nextChunk: ; Go to the next 256 bytes of the current sector
    lda #$FF
    sta $00
    inc $13
.noInc:
    jmp .checkLoop
.correctFile: ; Load the file that was found
    stz sdCurrentSectorInCluster

    ldy #$1A ; Cluster Low, byte 1
    lda ($12), Y
    sta $00
    sta sdCurrentClusterNum + 0
    ldy #$1B ; Cluster Low, byte 2
    lda ($12), Y
    sta $01
    sta sdCurrentClusterNum + 1
    ldy #$14 ; Cluster High, byte 1
    lda ($12), Y
    sta $02
    sta sdCurrentClusterNum + 2
    ldy #$15 ; Cluster High, byte 2
    lda ($12), Y
    sta $03
    sta sdCurrentClusterNum + 3
    jsr fat32ClusterToSector
    
    lda $08
    sta sdCurrentSectorNum + 0
    lda $09
    sta sdCurrentSectorNum + 1
    lda $0A
    sta sdCurrentSectorNum + 2
    lda $0B
    sta sdCurrentSectorNum + 3
    
    lda $14 ; Where to put the block
    sta $05
    lda $15
    sta $06
;.readFileLoop:
    lda sdCurrentSectorNum + 0
    sta $01
    lda sdCurrentSectorNum + 1
    sta $02
    lda sdCurrentSectorNum + 2
    sta $03
    lda sdCurrentSectorNum + 3
    sta $04
    
    ;lda $06
    ;pha
    ;lda $05
    ;pha
    
    jsr sdReadBlock
    jsr fat32FindNextSector
    ;tax
    
    ;pla
    ;sta $05
    ;pla
    ;sta $06
    
    ;inc $06
    ;inc $06
    ;txa
    tax
    beq .notEndOfFile
    lda #2
    rts
.notEndOfFile:
    lda #0
    rts

; Get the next block of the current file stream
; Inputs: $05, $06 = Address to save to
; Outputs: A - Status (0 = success, 1 = reached end of file(last block has been loaded))
sdContinueStreamFile:
    lda sdCurrentSectorNum + 0
    sta $01
    lda sdCurrentSectorNum + 1
    sta $02
    lda sdCurrentSectorNum + 2
    sta $03
    lda sdCurrentSectorNum + 3
    sta $04
    jsr sdReadBlock
    jsr fat32FindNextSector
    tax
    beq .notEndOfFile
    lda #1
    rts
.notEndOfFile:
    lda #0
    rts
    
; Finds the next sector from the SD
; Takes the FAT into account
; Outputs - A - Status (0 - success, 1 - reached end of file / directory)
fat32FindNextSector:
    inc sdCurrentSectorInCluster
    lda fat32SectorsPerCluster
    cmp sdCurrentSectorInCluster
    beq .gotoNextCluster
    lda #1 ; Increment sector number
    sta $00
    stz $01
    stz $02
    stz $03
    lda sdCurrentSectorNum + 0
    sta $04
    lda sdCurrentSectorNum + 1
    sta $05
    lda sdCurrentSectorNum + 2
    sta $06
    lda sdCurrentSectorNum + 3
    sta $07
    jsr add32
    lda $08
    sta sdCurrentSectorNum + 0
    lda $09
    sta sdCurrentSectorNum + 1
    lda $0A
    sta sdCurrentSectorNum + 2
    lda $0B
    sta sdCurrentSectorNum + 3
    
    lda #0
    rts
    
.gotoNextCluster:
    stz sdCurrentSectorInCluster
    lda sdCurrentClusterNum + 0
    sta $00
    lda sdCurrentClusterNum + 1
    sta $01
    lda sdCurrentClusterNum + 2
    sta $02
    lda sdCurrentClusterNum + 3
    sta $03
    ldx #4
    jsr mul32x8 ; Multiply cluster num by 4 to get the relative FAT address (could optimise this to a bitshift later)
    
    lda $00 ; Mask off the bottom 9 bits into $0C-0D to use as the byte offset
    sta $0C
    lda $01
    and #$01
    sta $0D
    
    ldy #9 ; Shift address right 9 times (divide by 512 to get sector address)
.shftlp:
    clc
    ror $03
    ror $02
    ror $01
    ror $00
    dey
    bne .shftlp
    
    lda fat32FATBeginAddr + 0
    sta $04
    lda fat32FATBeginAddr + 1
    sta $05
    lda fat32FATBeginAddr + 2
    sta $06
    lda fat32FATBeginAddr + 3
    sta $07
    jsr add32 ; Add FAT begin to get absolute FAT address
    
    lda $08
    sta $01
    lda $09
    sta $02
    lda $0A
    sta $03
    lda $0B
    sta $04
    lda #sdBufferAddr >> 8
    sta $06
    lda #sdBufferAddr & $FF
    sta $05
    jsr sdReadBlock
    
    lda #sdBufferAddr & $FF ; Add byte offset of fat entry to buffer address
    clc
    adc $0C
    sta $0C
    lda #sdBufferAddr >> 8
    clc
    adc $0D
    sta $0D
    
    ldy #0 ; Read entry into $08 - $0B
    lda ($0C), Y
    sta $08
    ldy #1
    lda ($0C), Y
    sta $09
    ldy #2
    lda ($0C), Y
    sta $0A
    ldy #3
    lda ($0C), Y
    and #$0F ; Ignore top 4 bits of FAT entry
    sta $0B
    
    lda $08 ; If cluster number is all FFFFFFFF in FAT, we've reached end of file / directory
    cmp #$FF
    bne .validCluster
    lda $09
    cmp #$FF
    bne .validCluster
    lda $0A
    cmp #$FF
    bne .validCluster
    lda $0B
    cmp #$0F
    bne .validCluster
    
    lda #1
    rts
    
.validCluster:
    lda $08
    sta sdCurrentClusterNum + 0
    sta $00
    lda $09
    sta sdCurrentClusterNum + 1
    sta $01
    lda $0A
    sta sdCurrentClusterNum + 2
    sta $02
    lda $0B
    sta sdCurrentClusterNum + 3
    sta $03
    
    jsr fat32ClusterToSector
    lda $08
    sta sdCurrentSectorNum + 0
    lda $09
    sta sdCurrentSectorNum + 1
    lda $0A
    sta sdCurrentSectorNum + 2
    lda $0B
    sta sdCurrentSectorNum + 3
    
    lda #0
    rts

; Converts a FAT32 cluster number to a physical sector address
; Inputs:  ZPG $00, $01, $02, $03 - 32 bit FAT32 cluster address
; Outputs: ZPG $08, $09, $0A, $0B - 32 bit physical sector address
;          ZPG $04, $05, $06, $07 - garbage
fat32ClusterToSector:
    ; Cluster numbers start at 2 for some reason, so:
    ; SectorAddr = fat32ClusterBeginAddr + (ClusterAddr - 2) * fat32SectorsPerCluster
    lda #$FE ; Add FFFFFFFE (-2)
    sta $04
    lda #$FF
    sta $05
    sta $06
    sta $07
    jsr add32
    
    lda $08 ; Move result to $00
    sta $00
    lda $09
    sta $01
    lda $0A
    sta $02
    lda $0B
    sta $03
    
    ldx fat32SectorsPerCluster ; Multiply by fat32SectorsPerCluster
    jsr mul32x8
    
    lda fat32ClusterBeginAddr + 0 ; Add fat32ClusterBeginAddr
    sta $04
    lda fat32ClusterBeginAddr + 1
    sta $05
    lda fat32ClusterBeginAddr + 2
    sta $06
    lda fat32ClusterBeginAddr + 3
    sta $07
    jsr add32
    rts

; Reads a 512 byte block from the SD card
; Inputs: ZPG $01, $02, $03, $04 - 32 bit address of block (little endian)
;         ZPG $05, $06 - Starting address of where to put the block 
; Outputs: A, Y - Garbage
sdReadBlock:
    jsr sdSendDummies
    lda VIA2_RA
    and #~(SD_CLK | SD_CS)
    sta VIA2_RA
    lda #$51        ; Send CMD17 (0x51, address = argument, 0xFF CRC)
    jsr sdSendByte
    lda $04
    jsr sdSendByte
    lda $03
    jsr sdSendByte
    lda $02
    jsr sdSendByte
    lda $01
    jsr sdSendByte
    lda #$FF
    jsr sdSendByte
    
    jsr sdWaitResponse  ; Get first response
    
    jsr sdWaitData  ; Start of data block
    ldy #$0
.lp1:           ; get 256 bytes
    phy
    jsr sdGetByte
    ply
    sta ($05), Y
    iny
    bne .lp1
    inc $06
.lp2:           ; get next 256 bytes
    phy
    jsr sdGetByte
    ply
    sta ($05), Y
    iny
    bne .lp2

    jsr sdGetByte ; 16 bit CRC
    jsr sdGetByte
    jsr sdSendDummies
    rts
    
; Sends a byte directly to the SD card
; Inputs: A - Byte to send
; Outputs: A, Y, ZPG $00 - Garbage
sdSendByte:
    sta $00
    lda VIA2_RA ; Set A to current value of CLK and CS
    ldy #8      ; Loop thru 8 bits
.sendBitLoop:
    ora #SD_MOSI ; Set output bit to 1
    asl $00      ; Set carry to top bit of data
    bcs .bitHigh
    eor #SD_MOSI ; Set output bit to 0
.bitHigh:
    sta VIA2_RA
    
    ora #SD_CLK
    sta VIA2_RA ; Clock high
    eor #SD_CLK
    sta VIA2_RA ; Clock low
    
    dey
    bne .sendBitLoop
    rts
    
; Receives a byte directly from the SD card
; Outputs: A, ZPG $00 - Byte received
;          Y - Garbage
sdGetByte:
    lda VIA2_RA
    and #~(SD_CLK | SD_CS)
    ora #SD_MOSI
    sta VIA2_RA ; Set MOSI high, CS and CLK low
    ldy #8      ; Loop thru 8 bits
.getBitLoop:
    ora #SD_CLK
    sta VIA2_RA ; Clock high
    lda VIA2_RA ; Sample data
    eor #SD_CLK
    sta VIA2_RA ; Clock low
    cmp #SD_MISO ; Set Carry to top bit of A (MISO)
    rol $00     ; Rotate carry into the data byte stored at $00
    dey
    bne .getBitLoop
    
    lda $00
    rts
    
; Wait for the SD's response to a command
; Outputs: A, ZPG $00 - Response
;          Y - Garbage
sdWaitResponse:
    lda #$FF
    jsr sdSendByte
    lda VIA2_RA
    bmi sdWaitResponse ; if top bit (minus flag) is set, keep looping
    jsr sdGetByte ; Get response
    rts
    
; Wait for the start of a data packet
; Outputs: A, Y, ZPG $00 - Garbage
sdWaitData:
    jsr sdGetByte
    cmp #$FE
    bne sdWaitData
    rts
    
sdSendDummies: ; Send a couple dummy bytes with CS high
    lda VIA2_RA
    and #~SD_CLK
    ora #SD_CS
    sta VIA2_RA ; Set CS high
    lda #$FF
    jsr sdSendByte
    lda #$FF
    jsr sdSendByte
    rts

; Add 2 32 bit numbers (without carry)
; Inputs:  ZPG $00, $01, $02, $03 - Number 1
;          ZPG $04, $05, $06, $07 - Number 2
; Outputs: ZPG $08, $09, $0A, $0B - Result
add32:
    clc
    lda $00 ; First byte
    adc $04
    sta $08
    lda $01 ; Second byte
    adc $05
    sta $09
    lda $02 ; Third byte
    adc $06
    sta $0A
    lda $03 ; Fourth byte
    adc $07
    sta $0B
    rts
    
; Multiply a 32 bit number by an 8 bit number
; Inputs: ZPG $00, $01, $02, $03 - 32 bit number
;         X - 8 bit number
; Outputs: ZPG $00, $01, $02, $03 - Result
;          ZPG $04, $05, $06, $07 - Original 32 bit number
mul32x8:
    lda $00 ; Save copy of number so it can be added to itself
    sta $04
    lda $01
    sta $05
    lda $02
    sta $06
    lda $03
    sta $07
    txa
    beq .zero ; Special cases for 0 and 1
    dex
    beq .one
.1: ; simple multiplication by repeated addition
    clc
    lda $00 ; First byte
    adc $04
    sta $00
    lda $01 ; Second byte
    adc $05
    sta $01
    lda $02 ; Third byte
    adc $06
    sta $02
    lda $03 ; Fourth byte
    adc $07
    sta $03
    dex
    bne .1
    rts
.zero: ; If X is 0, return 0
    stz $00
    stz $01
    stz $02
    stz $03
.one: ; If X is 1, just return the same value that was passed
    rts
    
; http://6502org.wikidot.com/software-math-intdiv
; Divide 2 8 bit numbers
; Inputs:  ZPG 00 - Numerator
;          ZPG 01 - Denominator
; Outputs: ZPG 00 - Quotient
;          A - Remainder
;          X - Garbage
div8x8:
    lda #0
    ldx #8
    asl $00
.L1:rol
    cmp $01
    bcc .L2
    sbc $01
.L2:rol $00
    dex
    bne .L1
    rts

; Fills a block of memory with a specified value
; Inputs: ZPG 00, 01 - Starting address
;         A - Value to fill with
;         Y - Number of bytes to fill
fastmemfill:
    cpy #0
    beq .d
.lp:sta ($00), Y
    dey
    bne .lp
.d: rts

; Add a newline to the graphics buffer
; Outputs: A, X - Garbage
printnewline:
    lda #13     ; carriage return
    jsr printchar
    lda #10     ; line feed
    jsr printchar
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
    
; Print a hex number on the screen
; Inputs: A - Number to print
; Outputs: X - Garbage
printbyte:
    jsr binhex
    phx
    jsr printchar
    pla
    jsr printchar
    rts
    
;http://forum.6502.org/viewtopic.php?f=2&t=3164
; binhex: CONVERT BINARY BYTE TO HEX ASCII CHARS
; Inputs: A - byte to convert
; Outputs: A - MSN ASCII Char
;          X - LSN ASCII char
binhex:
    pha                 ;save byte
    and #%00001111      ;extract LSN
    tax                 ;save it
    pla                 ;recover byte
    lsr                 ;extract...
    lsr                 ;MSN
    lsr
    lsr
    pha                 ;save MSN
    txa                 ;LSN
    jsr .1              ;generate ASCII LSN
    tax                 ;save
    pla                 ;get MSN & fall thru
.1: cmp #$0a            ;convert nybble to hex ASCII equivalent...
    bcc .2              ;in decimal range
    adc #$66            ;hex compensate
.2: eor #%00110000      ;finalize nybble
    rts                 ;done
    
; Parses a 2 character hex string to a byte
; Inputs: A = First character
;         X = Second character
; Outputs: A = Parsed byte
;          X = 0 - success, 1 = invalid string
;          ZPG 00 - garbage
parseHexString:
    pha
    lda #$FF
    sta $00
    pla
.secondChar:
    cmp #48
    bcc .invalidChar
    cmp #58
    bcc .numberChar
    cmp #65
    bcc .invalidChar
    cmp #71
    bcc .uppercaseHexChar
    cmp #97
    bcc .invalidChar
    cmp #103
    bcc .lowercaseHexChar
.invalidChar:
    ldx #1
    rts
.lowercaseHexChar:
    sec
    sbc #97 - 10
    bra .doneAdjust
.uppercaseHexChar:
    sec
    sbc #65 - 10
    bra .doneAdjust
.numberChar:
    sec
    sbc #48
.doneAdjust:
    phy
    ldy #$FF
    cpy $00
    bne .done
    ply
    asl
    asl
    asl
    asl
    sta $00
    txa
    bra .secondChar
.done:
    ply
    ora $00
    ldx #0
    rts

; Display a hex number on the LED Display
; Leaves the "Decimal Point" LED untouched
; Inputs: A - lower 4 bits = digit to display
;displayLEDNumber:
;    phy
;    and #$0F
;    tay
;    lda VIA1_RA
;    and #%10000000
;    ora ledDisplayLUT, Y
;    sta VIA1_RA
;    ply
;    rts

; Write a specified value to a specified AY-3-8910 register.
; Inputs: A - Value to write.
;         X - Register to write to (0 to F)
writeSoundRegister:
    pha
    txa
    and #$0F
    sta SOUND_DATABUS ; Write address
    lda SOUND_BUSCTRL
    ora #SOUND_BUSMODE_ADDR ; Put bus in address mode
    sta SOUND_BUSCTRL
    ;lda SOUND_BUSCTRL ; not needed ...right?
    and #%11111100
    sta SOUND_BUSCTRL ; Put bus in "inactive" mode
    pla
    sta SOUND_DATABUS ; Write data
    lda SOUND_BUSCTRL
    and #%11111100
    ora #SOUND_BUSMODE_DATA
    sta SOUND_BUSCTRL ; Put bus in "data" mode
    and #%11111100
    sta SOUND_BUSCTRL ; Put bus in "inactive" mode
    rts
    
;turnOffLED:
;    lda #%11111111 ; Turn off connected LED
;    ldx #$7
;    jsr writeSoundRegister
;    lda #$00
;    ldx #$E
;    jmp writeSoundRegister
;    
;turnOnLED:
;    lda #%11111111 ; Turn off connected LED
;    ldx #$7
;    jsr writeSoundRegister
;    lda #$FF
;    ldx #$E
;    jmp writeSoundRegister
;    
;toggleLED:
;    lda $0630
;    beq .1
;    stz $0630
;    jsr turnOffLED
;.1: lda #$FF
;    sta $0630
;    jsr turnOnLED
;    rts
    
nmi:
    rti
    
irq:
    pha
    phx
    phy
    ;ldx #0
    lda VIA1_IFR
    and #%00010000
    beq .notGfxInterrupt
    jsr GfxInterrupt
    ;ldx #$FF
.notGfxInterrupt:
    lda VIA1_IFR
    and #%00000010
    beq .notKeyboardInterrupt
    jsr keyboardInterrupt
    ;ldx #$FF
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
    
keyboardInterrupt:
    lda sdosLoaded
    beq .notLoaded
    lda #0
    jmp $0700
.notLoaded:
    lda VIA1_RA ; Acknowledge interrupt
    rts
    
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

startString: string "Initialised - qBIOS version 0.3\r\nTesting memory:       bytes"
memtestFailString: string "\033[6C Fail\r\n"
memtestPassString: string "\033[6C OK\r\n"
initsdString: string "Initialising SD card..."
failString: string "Failed: "
successString: string "Success\r\n"
fsStartString: string "Initialising filesystem..."
fat32mbrString: string "Success\r\nFound FAT32 partition (with MBR)\r\n"
fat32nombrString: string "Success\r\nFound FAT32 partition (without MBR)\r\n"
loadingsdosString: string "Searching for SDOS...\r\n"
sdossuccessString: string "Found SDOS, booting...\r\n"
sdoserrorString: string "Error: SDOSBOOT.PRG not found!"
ledDisplayLUT:
    .byte %01111110 ; 0
    .byte %01001000 ; 1
    .byte %00111101 ; 2
    .byte %01101101 ; 3
    .byte %01001011 ; 4
    .byte %01100111 ; 5
    .byte %01110111 ; 6
    .byte %01001100 ; 7
    .byte %01111111 ; 8
    .byte %01001111 ; 9
    .byte %01011111 ; A
    .byte %01110011 ; B
    .byte %00110110 ; C
    .byte %01111001 ; D
    .byte %00110111 ; E
    .byte %00010111 ; F
    
    .org $FFFA
    .word nmi ; NMI vector
    .word reset ; Reset vector
    .word irq ; IRQ vector