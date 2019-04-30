macro comment? begin?*
    local _reverse
    _reverse = string (`begin bswap (lengthof `begin))
    macro ?! line?&
        if (`line = _reverse)
            purge ?
        end if
    end macro
end macro

element register?

element B?      : register + 000b
element C?      : register + 001b
element D?      : register + 010b
element E?      : register + 011b
element H?      : register + 100b
element L?      : register + 101b
element _MHL?   : register + 110b
element A?      : register + 111b

iterate i, 1,2,3
    element coef#i?
end iterate

element BC?     : (coef1 *  0b) + (coef2 *  00b) + (coef3 *  00b)
element DE?     : (coef1 *  1b) + (coef2 *  01b) + (coef3 *  01b)
element HL?     : (coef1 * -1b) + (coef2 *  10b) + (coef3 *  10b)
element SP?     : (coef1 * -1b) + (coef2 *  11b) + (coef3 * -01b)
element AF?     : (coef1 * -1b) + (coef2 * -01b) + (coef3 *  11b)

element CC?

NZ? := CC + 00b
Z?  := CC + 01b
NC? := CC + 10b
;element  C?     := CC + 11b

macro   _find_item? predicate?*, argument?*, list?*&
    iterate _item, list
        match =_item?, argument
            predicate = 1
            break
        end match
    end iterate
end macro

macro   _inline_if? condition?*, true?*, false?*
    if (condition)
        true
    else
        false
    end if
end macro

macro   _is_memory? symbolic?*, argument?*&
    match       [ memory ], argument
        symbolic equ memory
    else match  ( memory ), argument
        symbolic equ memory
    end match
end macro

macro   _match_register?    argument?*
    local   _valid, _memory
    _valid      = 0
    _memory     equ
    _is_memory  _memory, argument
    match   _, _memory
        match   =HL?, _
            _metadata   = _MHL metadata 1
            _valid      = 1
        else
            err ""
        end match
    else
        _value = argument
        if (_value eq _value element 1)
            _find_item  _valid, <argument>, B,C,D,E,H,L,A
            if (~(_valid))
                _find_item  _valid, <argument>, BC,DE,HL,SP,AF
            end if
            if (_valid)
                _metadata = _value metadata 1
            end if
        end if
    end match
    if (~(_valid))
        err     ""
    end if
end macro

macro _match_condition? argument?*
    local   _valid
    _valid  = 0
    _find_item _valid, argument, NZ,Z,NC,C
    if (~(_valid))
        err ""
    end if
end macro

macro _scale? number?*
    if ((_metadata scale number) = -01b)
        err ""
    end if
end macro

macro _ensure?  kind?*
    match =R08?, kind
        if (~(_metadata relativeto register))
            err     ""
        end if
    else match =R16?, kind
        if (_metadata relativeto register)
            err     ""
        end if
    else
        err         ""
    end match
end macro

macro   _bound? value?*, bitness?*, kind?
    local _value, _slimit, _ulimit
    _value = value
    _ulimit = (1 shl bitness)
    _slimit = (1 shl (bitness - 1))
    match =SIGNED?, kind
        if ((_value >= _slimit) | (_value < (-_slimit)))
            err ""
        end if
    else match =UNSIGNED?, kind
        if ((_value < $00) | (_value >= _ulimit))
            err ""
        end if
    else match , kind
        if ((_value < (-_slimit)) | (_value >= _ulimit))
            err ""
        end if
    else
        err     ""
    end match
end macro

macro   nop?
    db  00000000b
end macro

_inc?   := 0b
_dec?   := 1b

macro   _build_operation?   type?*
    macro type? argument?*
        _match_register argument
        if (_metadata relativeto register)
            db (((_metadata - register) shl $03) or (10b shl $01) or (_#type))
        else
            _scale $02
            db (((_metadata scale $02) shl $04) or (_#type shl $03) or (011b))
        end if
    end macro
end macro

iterate _operation, inc, dec
    _build_operation    _operation
end iterate

macro   stop?
    db  00010000b
end macro

macro   jr? arguments?*&
    local   _destination
    match   condition =, target, arguments
        _match_condition condition
        _destination    = target
        db  ((001b shl $05) or ((condition - CC) shl $03))
    else
        _destination    = arguments
        db  00011000b
    end match
    _bound (_destination - $02), $08, SIGNED
    db  (_destination - $02)
end macro

macro   daa?
    db  00100111b
end macro

macro   cpl?
    db  00101111b
end macro

macro   scf?
    db  00110111b
end macro

macro   ccf?
    db  00111111b
end macro

macro   halt?
    db  01110110b
end macro

_add?   := 000b
_adc?   := 001b
_sub?   := 010b
_sbc?   := 011b
_and?   := 100b
_xor?   := 101b
_or?    := 110b
_cp?    := 111b

macro _build_alu?   type?*
    macro type? _A?*, argument?*
        local _value
        match =A?, _A
            _value = argument
            if ((_value eqtype $00) & ((elementsof _value) = 0))
                _bound _value, $08
                db ((11b shl $06) or (_#type shl $03) or (110b)), _value
            else
                _match_register argument
                _ensure r08
                db ((10b shl $06) or (_#type shl $03) or (_metadata - register))
            end if
        else
            err ""
        end match
    end macro

    macro type? arguments?*&
        match destination =, source, arguments
            type destination, source
        else
            type A, arguments
        end match
    end macro
end macro

iterate _alu, add, adc, sub, sbc, and, xor, or, cp
    _build_alu  _alu
    match =_alu?, ADD
        macro add? arguments?*&
            match =HL? =, source, arguments
                _match_register source
                _ensure r16
                _scale  $02
                db (((_metadata scale $02) shl $04) or (1001b))
            else match =SP? =, number, arguments
                _bound number, $08, SIGNED
                db 11101000b, number
            else
                add arguments
            end match
        end macro
    end match
end iterate

_pop?   := _inc
_push?  := _dec

macro   _build_operation?   type?*
    macro type? argument?*
        _match_register argument
        _ensure r16
        _scale $03
        db ((11b shl $06) or ((_metadata scale $03) shl $04) or (_#type shl $02) or (01b))
    end macro
end macro

iterate _operation, pop, push
    _build_operation    _operation
end iterate

macro   rst?    argument?*
    if (argument mod $08)
        err ""
    end if
    _bound  (argument shr $03), $03, UNSIGNED
    db ((11b shl $06) or (argument) or (111b))
end macro

macro   ret?    condition?& 
    match _condition, condition
        _match_condition _condition
        db ((110b shl $05) or ((_condition - CC) shl $03))
    else
        db 11001001b
    end match
end macro

macro   reti?
    db 11011001b
end macro

macro   jp? arguments?*&
    match =HL?, arguments
        db 11101001b
    else
        local _destination
        match condition =, target, arguments
            _match_condition condition
            _destination = target
            db ((110b shl $05) or ((condition - CC) shl $03) or (010b))
        else
            _destination = arguments
            db 11000011b
        end match
        _bound _destination, $10
        dw _destination
    end match
end macro

macro   call?   argument?*&
    local _destination
    match condition =, target, argument
        _match_condition condition
        _destination = target
        db ((110b shl $05) or ((condition - CC) shl $03) or (110b))
    else
        _destination = argument
        db 11001101b
    end match
    _bound _destination, $10
    dw _destination
end macro

macro   di?
    db 11110011b
end macro

macro   ei?
    db 11111011b
end macro

_left   := 0b
_right  := 1b

macro   _build_direction?   type?*
    local _direction
    match =L?, type
        _direction = _left
    else match =R?, type
        _direction = _right
    else
        err ""
    end match
    macro r#type#ca?
        db ((_direction shl $03) or (111b))
    end macro
    macro r#type#a?
        db ((0001b shl $04) or (_direction shl $03) or (111b))
    end macro
    macro r#type#c? argument?*
        _match_register argument
        _ensure r08
        db 11001011b, ((_direction shl $03) or (_metadata - register))
    end macro
    macro r#type?   argument?*
        _match_register argument
        _ensure r08
        db 11001011b, ((01b shl $04) or (_direction shl $03) or (_metadata - register))
    end macro
    macro s#type#a? argument?*
        _match_register argument
        _ensure r08
        db 11001011b, ((10b shl $04) or (_direction shl $03) or (_metadata - register))
    end macro
end macro

iterate _direction, L, R
    _build_direction _direction
end iterate

macro swap? argument?*
    _match_register argument
    _ensure r08
    db 11001011b, ((110b shl $03) or (_metadata - register))
end macro

macro srl?  argument?*
    _match_register argument
    _ensure r08
    db 11001011b, ((111b shl $03) or (_metadata - register))
end macro

macro bit?  offset?*, target?*
    _bound offset, $03, UNSIGNED
    _match_register target
    _ensure r08
    db 11001011b, ((01b shl $06) or (offset shl $03) or (_metadata - register))
end macro

macro res?  offset?*, target?*
    _bound offset, $03, UNSIGNED
    _match_register target
    _ensure r08
    db 11001011b, ((10b shl $06) or (offset shl $03) or (_metadata - register))
end macro

macro set?  offset?*, target?*
    _bound offset, $03, UNSIGNED
    _match_register target
    _ensure r08
    db 11001011b, ((11b shl $06) or (offset shl $03) or (_metadata - register))
end macro

_mem_reg    := 0b
_reg_mem    := 1b

macro   _build_ld?  argument?*
    local _operation
    match =I?, argument
        _operation = _inc
    else match =D?, argument
        _operation = _dec
    else
        err ""
    end match
    macro ld#argument#?  destination?*, source?*
        local _direction, _current, _count
        _count = 0
        iterate _item, <destination>, <source>
            _match_register _item
            if (_metadata eq (A metadata 1))
                _current = _reg_mem
            else if (_metadata eq (_MHL metadata 1))
                _current = _mem_reg
            else
                err ""
            end if
            if (~(_count))
                _direction = _current
            end if
            _count = _count + 1
        end iterate
        db ((1b shl $05) or (_operation shl $04) or (_direction shl $03) or (010b))
    end macro
end macro

iterate _ld, I, D
    _build_ld   _ld
end iterate

macro ld?   destination?*, source?*
    local _memory, _direction, _count, _address, _offset
    _count = 0
    iterate _item, <destination>, <source>
        _inline_if  _count = 0,           \
                    _direction = _mem_reg,\
                    _direction = _reg_mem
        _memory     equ
        _is_memory  _memory, _item
        match _, _memory
            match =HL? +, _
                _inline_if  _count = 0,            \
                            <ldi [HL], source>,    \
                            <ldi destination, [HL]>
            else match =HL? -, _
                _inline_if  _count = 0,            \
                            <ldd [HL], source>,    \
                            <ldd destination, [HL]>
            else match value, _
                _address = 0
                _offset = 0
                match address + offset, value
                    _address    = address
                    _offset     = + offset
                else match address - offset, value
                    _address    = address
                    _offset     = - offset
                end match

                if ((_address eq $FF00) | (value eq $FF00))
                    _inline_if  _count = 0,            \
                                _match_register source,\
                                _match_register destination

                    if (~(_metadata eq (A metadata 1)))
                        err ""
                    end if
                    _bound _offset,  $08
                    db ((111b shl $05) or (_direction shl $04)), _offset
                else
                    if ((elementsof (value)) = 0)
                        _inline_if  _count = 0,                \
                                    _match_register source,    \
                                    _match_register destination

                        _bound value, $10
                        if (_metadata eq (A metadata 1))
                            db ((111b shl $05) or (_direction shl $04) or (1010b))
                            dw value
                        end if
                    else match =C?, value
                        db ((111b shl $05) or (_direction shl $04) or (0010b))
                    end match
                end if
            end match
            break
        end match
        _count = _count + 1
    end iterate
    if (_count = 2)
        err ""
    end if
end macro

macro ld?   destination?*, source?*
    local _memory
    _memory     equ
    _is_memory  _memory, destination
    match , _memory
        _is_memory  _memory, source
    end match

    match _, _memory
        match =SP?, source
            _bound _, $10
            db 00001000b
            dw _
        else
            ld destination, source
        end match
    else match =SP?, destination
        match =HL?, source
            db 11111001b
        else
            err ""
        end match
    else match =HL?, destination
        local _offset
        _offset = 0
        match =SP? + number, source
            _offset = + number
        else match =SP? - number, source
            _offset = - number
        else match =SP?, source
        else
            err "" 
        end match
        _bound _offset, $08
        db 11111000b
        db _offset
    else
        _match_register destination
        if (_metadata relativeto register)
            local _dest_reg
            _dest_reg = _metadata - register
            if ((elementsof (source)) = 0)
                _bound source, $08
                db ((_dest_reg shl $03) or (110b))
                db source
            else
                _match_register source
                _ensure r08
                db ((01b shl $06) or (_dest_reg shl $03) or (_metadata - register))
            end if
        else
            _bound source, $10
            _scale $02
            db (((_metadata scale $02) shl $04) or (0001b))
            dw source
        end if
    end match
end macro

;macro ld?   destination?*, source?*
;    local _memory, _address, _offset
;    _memory     equ
;    _is_memory  _memory, destination
;    match _, _memory
;        match =HL? +, _
;            ldi [HL], source
;        else match =HL? -, _
;            ldd [HL], source
;        else match value, _
;            _address = 0
;            _offset = 0
;            match address + offset, value
;                _address = address
;                _offset = + offset
;            else match address - offset, value
;                _address = address
;                _offset = - offset
;            end match
;            if (_address eq $FF00)
;                _match_register source
;                if (~(_metadata eq (A metadata 1)))
;                    err ""
;                end if
;                _bound _offset,  $08
;                db 11100000b, _offset
;            else
;                if (((value) eqtype $00) & ((elementsof (value)) = 0))
;                    _match_register source
;                    _bound value, $10
;                    if (_metadata eq (SP metadata 1))
;                        db 00001000b
;                    else if (_metada eq (A metadata 1))
;                        db 11101010
;                    else
;                       err ""
;                   end if
;                    dw value
;                else
;                    _match_register value
;                    if (~(_metadata relativeto register))
;                        _scale $01
;                        db (((_metadata scale $01) shl $04) or (010b))
;                    end if
;                end if
;            end if
;        end match
;    end match
;end macro

macro _signed? number?*
    if (number < $00)
        err "Constant mustn't be negative: ", (`number)
    end if
end macro

macro rept? count?*
    _signed count
    repeat count
end macro

macro endr?!
    end repeat
end macro

macro incbin? arguments?*&
    match _file =, offset =, size, arguments
        file _file:offset, size
    else
        file arguments
    end match
end macro

macro ds? count?*
    _signed count
    emit count: $00
end macro

macro union?
    _unionStart =: $
end macro

macro nextu?!
    if (~(defined _unionStart))
        err "Found NEXTU outside of a UNION construct"
    end if
    org _unionStart
end macro

macro endu?!
    if (~(defined _unionStart))
        err "Found ENDU outside of a UNION construct"
    end if
    restore _unionStart
end macro

postpone
    if (defined _unionStart)
        _level = 0
        while (defined _unionStart)
            restore _unionStart
            _level = _level + 1
        end while
        err "Unterminated UNION construct (", _level + "0", " levels)!"
    end if

    purge db?, dw?, dl?

    db "RGB6"
    dd _count_symbols
    dd _count_section
    
    repeat _count_symbols
    end repeat

    repeat _count_section, i:1
        db _section_#i
        db 0
        virtual _area_#i
            _length_#i = $ - $$
        end virtual
        dd _length_#i
        db _section_type_#i
        dd _section_org_#i
        dd _section_bank_#i
        dd _section_align_#i
        if ((_section_type_#i eq ROM0) | (_section_type_#i eq ROMX))
            repeat _length_#i
                load _byte:byte from _area_#i:%-1
                db _byte
            end repeat
            dd 0
        end if
    end repeat
end postpone

ROM0    := 3
ROMX    := 2 
VRAM    := 1
SRAM    := 5
WRAM0   := 0
WRAMX   := 5
OAM     := 7
HRAM    := 4

macro section?  name?*, type?*, options?&
    if (~(name eqtype ""))
        err ""
    end if

    local _valid, _found, _type, _org, _bank, _align
    _found  =  0
    _org    = -1

    _type       equ type
    match kind [ base ], type
        _bound  base, $10, UNSIGNED
        _org  = base
        _type   equ kind
    end match

    _valid = 0
    _find_item  _valid, _type, ROM0,  ROMX,\
                               VRAM,  SRAM,\
                              WRAM0, WRAMX,\
                                       OAM,\
                                      HRAM
    if (~(_valid))
        err ""
    end if

    _bank   = -1
    _align  = -1
    match option_1 =, option_2, options
        match =BANK? [ _1 ] =, =ALIGN? [ _2 ], options
            _bank   = _1
            _align  = _2
        else match =ALIGN? [ _1 ] =, =BANK? [ _2], options
            _align  = _1
            _bank   = _2
        else
            err ""
        end match
    else match option, options
        match =BANK? [ _ ], option
            _bank   = _
        else match =ALIGN? [ _ ], option
            _align  = _
        else
            err ""
        end match
    end match

    if (_align <> -1)
        if (_org <> -1)
            err ""
        else if ((_align < 0) | (_align > 16))
            err ""
        end if
    else if ((_bank <> -1) & ((_bank <= 0) | (_bank > $1FF)))
        err     ""
    end if

    repeat _count_section, i:1
        if (name eq _section_#i)
            _found = 1
            _db EQU i
            break  
        end if
    end repeat
    if (~(_found))
        _count_section = _count_section + 1
        repeat 1, i:_count_section
            _section_#i         = name
            _section_type_#i    = _type
            _section_org_#i     = _org
            _section_bank_#i    = _bank
            _section_align_#i   = _align
            virtual at $00
                _area_#i::
            end virtual
            _db EQU i
        end repeat
    end if
end macro

_count_symbols = 0
_count_section = 0

macro _define   kind?*, def?*, res?*
    macro kind? line?&
        if (_count_section = 0)
            err "Code generation before SECTION directive"
        else match , line
            res
        else
            repeat 1, i:_count_section
                virtual _area_#i
                    def line
                end virtual
            end repeat
        end match
    end macro
end macro

_define db, db, rb
_define dw, dw, rw
_define dl, dd, rd

