SECTION "RST00",    ROM0[$0000]
    ret
SECTION "RST01",    ROM0[$0008]
    ret
SECTION "RST02",    ROM0[$0010]
    ret
SECTION "RST03",    ROM0[$0018]
    ret
SECTION "RST04",    ROM0[$0020]
    ret
SECTION "RST05",    ROM0[$0028]
    ret
SECTION "RST06",    ROM0[$0030]
    ret
SECTION "RST07",    ROM0[$0038]
    ret

SECTION "VBLANK",   ROM0[$0040]
    jp VBlankHandler

SECTION "TIMER",    ROM0[$0050]
    jp TimerHandler

SECTION "ENTRY",    ROM0[$0100]
    nop
    jp _start

SECTION "LOGO",     ROM0[$0104]
    DB $CE, $ED, $66, $66, $CC, $0D, $00, $0B
    DB $03, $73, $00, $83, $00, $0C, $00, $0D
    DB $00, $08, $11, $1F, $88, $89, $00, $0E
    DB $DC, $CC, $6E, $E6, $DD, $DD, $D9, $99
    DB $BB, $BB, $67, $63, $6E, $0E, $EC, $CC
    DB $DD, $DC, $99, $9F, $BB, $B9, $33, $3E

SECTION "CODE",     ROM0[$0150]

VRAM_TILE_SET   EQU $8000
VRAM_TILE_REF   EQU $9800

OAM_BASE        EQU $FE00
OAM_SIZE_ENTRY  EQU $04
OAM_OFFSET_X    EQU $08
OAM_OFFSET_Y    EQU $10

JOYPAD          EQU $FF00
NR52            EQU $FF26
LCDC            EQU $FF40
SCY             EQU $FF42
SCX             EQU $FF43
LY              EQU $FF44

SHADE_BG        EQU $FF47
SHADE_S1        EQU $FF48
SHADE_S2        EQU $FF49

VBlankMin       EQU $90
VBlankMax       EQU $99

SCREEN_WIDTH    EQU $A0
SCREEN_HEIGHT   EQU $90

PUSH_REG:   MACRO
            REPT    _NARG
            push    \1
            SHIFT
            ENDR
            ENDM

POP_REG:    MACRO
_I  =   _NARG
            REPT    _NARG
_J  =   $00
            REPT    _I
            IF  _J >= $01
                PURGE   _LAST
            ENDC
_LAST   EQUS "\1"
            SHIFT
_J  =   _J + $01
            ENDR
            pop     _LAST
            PURGE   _LAST
_I  =   _I - $01
            ENDR
            PURGE   _I, _J
            ENDM

; Wait until VBlank is reached
_waitVBlank:
    ld a, [LY]
    cp VBlankMin
    jr c, _waitVBlank
    cp VBlankMax
    jr z, _waitVBlank
    ret

; Basic memcpy
; hl DSt
; de src
; bc sze

_memcpy:
    inc bc
    jr .check
.loop
    ld a, [de]
    ld [hl], a
    inc de
    inc l
.check
    dec bc
    ld a, b
    or c
    jr nz, .loop
    ret

; Basic memset
; hl DSt
; d  val
; bc sze

_memset:
    inc bc
    jr .check
.loop
    ld a, d
    ld [hl], a
    inc l
.check
    dec bc
    ld a, c
    or b
    jr nz, .loop
    ret

; Basic unsigned division
; hl dividend
; de divisor
; hl quotient
; de remainder

_unsignedDivision:
    ld bc, $00
.loop
    ld a, h
    cp d
    jr c, .end
    jr nz, .next
    ld a, l
    cp e
    jr c, .end
.next
    ld a, h
    sub d
    ld h, a
    ld a, l
    sbc e
    ld l, a
    inc bc
    jr .loop
.end
    PUSH_REG    bc, hl
    POP_REG     hl, de
    ret

_reset_background:
    ld hl, VRAM_TILE_REF
    xor a
    ld d, a
    ld bc, $20 * $20
    call _memset
    ret

_reset_oam:
    ld hl, OAM_BASE
    xor a
    ld d, a
    ld bc, OAM_SIZE_ENTRY * $28
    call _memset
    ret

_turnOffLCD:
    call _waitVBlank
    ld a, [LCDC]
    res $07, a
    ld [LCDC], a
    ret

RIGHT   EQU $00
LEFT    EQU $01
UP      EQU $02
DOWN    EQU $03
BTN_A   EQU $04
BTN_B   EQU $05
START   EQU $06
SELECT  EQU $07

DPAD    EQU %00100000
BTNS    EQU %00010000

_readInput:
    ld a, BTNS
    ld [JOYPAD], a
REPT    $05
    ld a, [JOYPAD]
ENDR
    cpl
    and %00001111
    swap a
    ld b, a
    ld a, DPAD
    ld [JOYPAD], a
REPT    $05
    ld a, [JOYPAD]
ENDR
    cpl
    and %00001111
    or b
    ld b, a
    ld a, DPAD | BTNS ; unselect all input
    ld [JOYPAD], a
    ld a, b
    ret

PAD_X           EQU $10
PAD_Y           EQU $20

PAD_SPEED       EQU $02

PAD_SIZE_W      EQU $08
PAD_SIZE_H      EQU $20

PAD_DOWN        EQU $01
PAD_UP          EQU $02
PAD_IDLE        EQU $03

BALL_X          EQU $80
BALL_Y          EQU $80

BALL_SPEED_Y    EQU $01
BALL_SPEED_X    EQU $01

; FOR BALL SPEED X
BALL_RIGHT      EQU $01
BALL_LEFT       EQU $02

; FOR BALL SPEED Y
BALL_UP         EQU $01
BALL_DOWN       EQU $02

; FOR BOTH
BALL_IDLE       EQU $00

BALL_VELOCITY   EQU $5A
BALL_RATIO      EQU $1E

BALL_SIZE_W     EQU $08
BALL_SIZE_H     EQU $08

TILE_PAD        EQU $01
TILE_BALL       EQU $02

OAM_NONE        EQU $00

; {b,c}{d,e}    -> 2 Point of 4 Point Object
; {h,l}         -> Target Point

_checkCollisionPoint:
    ld a, h
    cp b
    jr c, .no_collision
    ld a, l
    cp c
    jr c, .no_collision
    ld a, h
    cp d
    jr c, .continue_1
    jr z, .continue_1
    jr .no_collision
.continue_1
    ld a, l 
    cp e
    jr c, .continue_2
    jr z, .continue_2
    jr .no_collision
.continue_2
    scf
    jr .end
.no_collision
    scf
    ccf
.end
    ret

_loadBallCoord:
    ld a, [BallX]
    ld b, a
    add (BALL_SIZE_W - $01)
    ld d, a
    ld a, [BallY]
    ld c, a
    add (BALL_SIZE_H - $01)
    ld e, a
    ret

_loadPadCoord:
    ld a, PAD_X
    ld b, a
    add (PAD_SIZE_W - $01)
    ld d, a
    ld a, [PadY]
    ld c, a
    add (PAD_SIZE_H - $01)
    ld e, a
    ret

PAD_COLLISION_UP    EQU $00
PAD_COLLISION_DOWN  EQU $01

CHECK_PAD_COLLISION:    MACRO
                        call _loadBallCoord
                        ld a, PAD_X
                        ld h, a
                        ld a, [PadY]
                        IF (\1 == PAD_COLLISION_DOWN)
                            add ((PAD_SIZE_H - $01) + PAD_SPEED)
                        ELSE
                            sub (PAD_SPEED)
                        ENDC
                        ld l, a
                        call _checkCollisionPoint
                        jr c, .end\@
                        ld a, h
                        add (PAD_SIZE_W - $01)
                        ld h, a
                        call _checkCollisionPoint
.end\@
                        ENDM

_updateInputPad:
    call _readInput
    bit DOWN, a
    jr nz, .down
    bit UP, a
    jr nz, .up
    ld a, PAD_IDLE
    ld [PadMove], a
    jr .end
.down
    bit UP, a
    jr nz, .end
    CHECK_PAD_COLLISION PAD_COLLISION_DOWN
    jr nc, .ball_down
    ld a, [BallY]
    sub PAD_SIZE_H
    jr .set
.ball_down
    ld a, PAD_DOWN
    ld [PadMove], a

    ld a, [PadY]
    add PAD_SPEED
    cp (SCREEN_HEIGHT + OAM_OFFSET_Y - PAD_SIZE_H)
    jr c, .set
    ld a, (SCREEN_HEIGHT + OAM_OFFSET_Y - PAD_SIZE_H)
    jr .set
.up
    CHECK_PAD_COLLISION PAD_COLLISION_UP
    jr nc, .ball_up
    ld a, [BallY]
    add BALL_SIZE_H
    jr .set
.ball_up
    ld a, PAD_UP
    ld [PadMove], a

    ld a, [PadY]
    sub PAD_SPEED
    cp OAM_OFFSET_Y
    jr nc, .set
    ld a, OAM_OFFSET_Y
.set
    ld [PadY], a
    call _updateOAMPad
.end
    ret

_updateOAMPad:
    ld hl, OAM_BASE
    ld b, (PAD_SIZE_H / $08)
    ld a, [PadY]
.loop
    ld [hl], a
    add PAD_SIZE_W
    inc l
    ld [hl], PAD_X
    inc l
    ld [hl], TILE_PAD
    inc l
    ld [hl], OAM_NONE
    inc l
    dec b
    jr nz, .loop
    ret

_updateBallY:
    ld a, [BallY]
    ld b, a
    ld a, [SpeedY]
    add b
    cp (SCREEN_HEIGHT + (OAM_OFFSET_Y - $08))
    jr nc, .height_overflow
    cp OAM_OFFSET_Y
    jr c, .height_underflow
    jr .update_height
.height_overflow
    ld a, BALL_UP
    ld [BallYDir], a
    ld a, (SCREEN_HEIGHT + (OAM_OFFSET_Y - $08))
    jr .update_height
.height_underflow
    ld a, BALL_DOWN
    ld [BallYDir], a
    ld a, OAM_OFFSET_Y
.update_height
    ld [BallY], a
    ret

_updateBallX:
    ld a, [BallX]
    ld b, a
    ld a, [SpeedX]
    add b
    cp (SCREEN_WIDTH + (OAM_OFFSET_X - $08))
    jr nc, .width_overflow
    cp OAM_OFFSET_X
    jr c, .width_underflow
    jr .update_width
.width_overflow
    ld a, BALL_RIGHT
    ld [BallXDir], a
    ld a, (SCREEN_WIDTH + (OAM_OFFSET_X - $08))
    jr .update_width
.width_underflow
    ld a, BALL_LEFT
    ld [BallXDir], a
    ld a, OAM_OFFSET_X
.update_width
    ld [BallX], a
    ret

_updateBallVel:
    ld a, [PadMove]
    cp PAD_IDLE
    jr z, .end
    ld b, a
    ld a, [BallYDir]
    cp BALL_UP
    jr z, .ball_up
    cp BALL_DOWN
    jr z, .ball_down
    jr .end
.ball_up
    ld a, b
    cp PAD_UP
    jr z, .set_vel
    jr .end
.ball_down
    ld a, b
    cp PAD_UP
    jr z, .end
.set_vel
    ld a, BALL_VELOCITY
    ld [BallVel], a
.end
    ret

_checkBallCollision:
    call _loadPadCoord
    ld a, [BallX]
    ld h, a
    ld a, [BallY]
    ld l, a

    call _checkCollisionPoint
    jr c, .positive_speed

    ld a, h
    add (BALL_SIZE_W - $01)
    ld h, a

    call _checkCollisionPoint
    jr c, .negative_speed

    ld a, l
    add (BALL_SIZE_H - $01)
    ld l, a

    call _checkCollisionPoint
    jr c, .negative_speed

    ld a, h
    sub (BALL_SIZE_W - $01)
    ld h, a

    call _checkCollisionPoint
    jr c, .positive_speed
    jr .end
.positive_speed
    ld a, BALL_LEFT
    ld [BallXDir], a
    jr .update_ball
.negative_speed
    ld a, BALL_RIGHT
    ld [BallXDir], a
.update_ball
;    ld a, [PadY]
;    add (PAD_SIZE_H / $02)
;    ld b, a
;    ld a, [BallY]
;    add (BALL_SIZE_H / $02)
;    cp b
;    ld a, BALL_UP
;    jr c, .update_y
;    ld a, BALL_DOWN
;.update_y
;    ld [BallYDir], a
    call _updateBallVel
    call _restoreBallPos
.end
    ret

_updateOAMBall:
    ld hl, OAM_BASE + (OAM_SIZE_ENTRY * (PAD_SIZE_H / $08))
    ld a, [BallY]
    ld [hl], a
    inc l
    ld a, [BallX]
    ld [hl], a
    inc l
    ld [hl], TILE_BALL
    inc l
    ld [hl], OAM_NONE
    ret

_setBallSpeed:
    xor a
    ld h, a

    ld a, [BallVel]
    ld l, a

    cp $00
    jr z, .next
    dec a
    ld [BallVel], a
    ld de, BALL_RATIO
    call _unsignedDivision
.next

    ld a, [BallXDir]
    cp BALL_RIGHT
    jr z, .ball_right
    cp BALL_LEFT
    jr .ball_left
    xor a
    jr z, .set_speed_x
.ball_right
    ld a, l
    cpl
    inc a
    ld l, a
    ld a, -BALL_SPEED_X
    jr .set_speed_x
.ball_left
    ld a,  BALL_SPEED_X
.set_speed_x
    add l
    ld [SpeedX], a

    ld a, [BallYDir]
    cp BALL_UP
    jr z, .ball_up
    cp BALL_DOWN
    jr z, .ball_down
    xor a
    jr .set_speed_y
.ball_up
    ld a, -BALL_SPEED_Y
    jr .set_speed_y
.ball_down
    ld a,  BALL_SPEED_Y
.set_speed_y
    ld [SpeedY], a
    ret

_updateBall:
    ld a, [BallX]
    ld [SaveBallX], a
    call _updateBallY
    ld a, [BallY]
    ld [SaveBallY], a
    call _updateBallX
    call _checkBallCollision
    call _setBallSpeed
    call _updateOAMBall
    ret

_restoreBallPos:
    ld a, [SaveBallX]
    ld [BallX], a
    ld a, [SaveBallY]
    ld [BallY], a
    ret

_initObject:
    ld a, PAD_Y
    ld [PadY], a
    ld a, BALL_X
    ld [BallX], a
    ld a, BALL_Y
    ld [BallY], a
    ld a, BALL_SPEED_X
    ld [SpeedX], a
    ld a, BALL_SPEED_Y
    ld [SpeedY], a
    xor a
    ld [BallVel], a
    ld [PadMove], a
    ld a, BALL_RIGHT
    ld [BallXDir], a
    ld a, BALL_UP
    ld [BallYDir], a
    ret

_start:
    di
    ld sp, $FFE4

;    xor a
;    ld [NR52], a

    call _turnOffLCD

    ld hl, VRAM_TILE_SET
    ld de, TileBase
    ld bc, $10 * $03
    call _memcpy

    xor a
    ld [SCX], a
    ld [SCY], a
  
    ld a, %11100100
    ld [SHADE_BG], a
    ld [SHADE_S1], a
    ld [SHADE_S2], a

    call _reset_background
    call _reset_oam

    call _initObject

    call _updateOAMPad
    call _updateOAMBall

    ld a, %10010011
    ld [LCDC], a

;    ld a, %00000011
;    ld [$FF0F], a
    ld a, %00010000
    ld [$FF41], a
    ld a, %00000001
    ld [$FFFF], a

    ei
.loop:
    jr .loop

setsnd:
    ld a, %10000000
    ld [$FF26], a
    ld a, %01110111
    ld [$FF24], a
    ld a, %00010001
    ld [$FF25], a
    ld a, %10111000
    ld [$FF11], a
    ld a, %11110000
    ld [$FF12], a
    ret

hibeep:
    call setsnd
    ld a, %11000000
    ld [$FF13], a
    ld a, %11000111
    ld [$FF14], a
    ret

VBlankHandler:
    PUSH_REG    af, bc, de, hl
    call _updateInputPad
    call _updateBall
    POP_REG     af, bc, de, hl
    reti

TimerHandler:
    reti

TileBase:
    DB  $99, $00, $CC, $00, $66, $00
    DB  $33, $00, $99, $00, $CC, $00
    DB  $66, $00, $33, $00

    DB  $A9, $D6, $95, $EA, $A9, $D6
    DB  $95, $EA, $A9, $D6, $95, $EA
    DB  $A9, $D6, $95, $EA

    DB  $3C, $3C, $42, $7E, $85, $FB
    DB  $81, $FF, $A1, $DF, $B1, $CF
    DB  $42, $7E, $3C, $3C

SECTION "GLOBAL",   WRAM0[$C000]

PadY:       DS  $01
PadMove:    DS  $01

BallX:      DS  $01
BallY:      DS  $01

BallVel:    DS  $01

SaveBallX:  DS  $01
SaveBallY:  DS  $01

SpeedX:     DS  $01
BallXDir:   DS  $01

SpeedY:     DS  $01
BallYDir:   DS  $01
