include "rgbds_fasmg.asm"

;SECTION "RST00",    ROM0[$0000]
;    ret
;SECTION "RST01",    ROM0[$0008]
;    ret
;SECTION "RST02",    ROM0[$0010]
;    ret
;SECTION "RST03",    ROM0[$0018]
;    ret
;SECTION "RST04",    ROM0[$0020]
;    ret
;SECTION "RST05",    ROM0[$0028]
;    ret
;SECTION "RST06",    ROM0[$0030]
;    ret
;SECTION "RST07",    ROM0[$0038]
;    ret

;SECTION "VBLANK",   ROM0[$0040]

;SECTION "TIMER",    ROM0[$0050]

;SECTION "ENTRY",    ROM0[$0100]
;    nop

;SECTION "LOGO",     ROM0[$0104]
;    DB $CE, $ED, $66, $66, $CC, $0D, $00, $0B
;    DB $03, $73, $00, $83, $00, $0C, $00, $0D
;    DB $00, $08, $11, $1F, $88, $89, $00, $0E
;    DB $DC, $CC, $6E, $E6, $DD, $DD, $D9, $99
;    DB $BB, $BB, $67, $63, $6E, $0E, $EC, $CC

;SECTION "CODE",     ROM0[$0150]

;VRAM_TILE_SET   EQU $8000
;VRAM_TILE_REF   EQU $9800

;OAM_BASE        EQU $FE00
;OAM_SIZE_ENTRY  EQU $04
;OAM_OFFSET_X    EQU $08
;OAM_OFFSET_Y    EQU $10

;JOYPAD          EQU $FF00
;NR52            EQU $FF26
;LCDC            EQU $FF40
;SCY             EQU $FF42
;SCX             EQU $FF43
;LY              EQU $FF44

;SHADE_BG        EQU $FF47
;SHADE_S1        EQU $FF48
;SHADE_S2        EQU $FF49

;VBlankMin       EQU $90
;VBlankMax       EQU $99

;SCREEN_WIDTH    EQU $A0
;SCREEN_HEIGHT   EQU $90

;PUSH_REG:   MACRO
;            REPT    _NARG
;                push    \1
;            ENDR
;            ENDM
;
;PUSH_REG    bc,\
;            de

_interpret_line
display "ABC", $A << 0 << 1

_abc:   MACRO
            display "TEST", $A
        ENDM

_abc "HE"
