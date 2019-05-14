include "rpn.asm"

element register?

element B?      : register + 000b
element C?      : register + 001b
element D?      : register + 010b
element E?      : register + 011b
element H?      : register + 100b
element L?      : register + 101b
element _MEM?   : register + 110b
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
define  condition

namespace condition
    NZ? := CC + 00b
    Z?  := CC + 01b
    NC? := CC + 10b
    C?  := CC + 11b
end namespace

macro _is_memory? symbolic?*, argument?*&
    symbolic        equ
    match       [ memory ], argument
        symbolic    equ memory
    else match  ( memory ), argument
        symbolic    equ memory
    end match
end macro

macro _is_register? result?*, argument?*
    local   _memory
    result = 0
    _is_memory  _memory, argument
    match   _, _memory
        match   =HL?, _
            _metadata   = (_MEM metadata 1)
            result      = 1
        end match
    else
        _value = argument
        if (_value eq _value element 1)
            _find_item  result, <argument>, B,C,D,E,H,L,A
            _inline_if (~(result)), <_find_item  result, <argument>, BC,DE,HL,SP,AF>
            _inline_if (result),    _metadata = (_value metadata 1)
        end if
    end match
end macro

macro   _match_register?        argument?*
    local   _valid
    _is_register    _valid, argument
    _inline_if      (~(_valid)), err "Register not matched"
end macro

macro   _not_match_register?    argument?*
    local   _valid
    _is_register    _valid, argument
    _inline_if      (_valid), err "Register matched"
end macro

macro _match_condition? argument?*
    local   _valid
    _find_item _valid, argument, NZ,Z,NC,C
    _inline_if (~(_valid)), err "Not a valid condition found"
end macro

macro _scale? number?*
    _is_integer number
    _inline_if ((_metadata scale number) = -01b), err "Scale not supported by this index"
end macro

macro _ensure?  kind?*
    match =R08?, kind
        _inline_if (~(_metadata relativeto register)),  err "Register of 8-bit is required"
    else match =R16?, kind
        _inline_if (_metadata relativeto register),     err "Register of 16-bit is required"
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
    _destination    equ
    match   cond =, target, arguments
        _match_condition    cond
        _destination    equ target
        db  ((001b shl $05) or ((condition.cond - CC) shl $03))
    else
        _destination    equ arguments
        db  00011000b
    end match
    _not_match_register _destination
    if (~(elementsof (_destination)))
        _bound ((_destination) - $02), $08, SIGNED
        db  ((_destination) - $02)
    else
        db  0
        repeat 1, i:_db
            virtual _area_#i
                _rpn_expression (($ - $$) - $01), _JR, _destination
            end virtual
        end repeat
    end if
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
        local _valid
        match =A?, _A
            _is_register _valid, argument
            if (_valid)
                _ensure r08
                db ((10b shl $06) or (_#type shl $03) or (_metadata - register))
            else
                if ((elementsof (argument)) = 0)
                    local _value
                    _value = (argument)
                    _bound _value, $08
                end if
                db ((11b shl $06) or (_#type shl $03) or (110b))
                db (argument)
            end if
        else
            err "First operand of ALU operation must be A"
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
    _is_integer argument
    _inline_if ((elementsof (argument)) <> 0), err "Address for RST must be absolute"
    _inline_if (argument mod $08), <err "Invalid address ", `argument, " for RST">
    _bound  (argument shr $03), $03, UNSIGNED
    db ((11b shl $06) or (argument) or (111b))
end macro

macro   ret?    cond?& 
    match _condition, cond
        _match_condition _condition
        db ((110b shl $05) or ((condition._condition - CC) shl $03))
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
        match cond =, target, arguments
            _match_condition cond
            _destination equ target
            db ((110b shl $05) or ((condition.cond - CC) shl $03) or (010b))
        else
            _destination equ arguments
            db 11000011b
        end match
        _inline_if ((elementsof (_destination)) = 0), <_bound _destination, $10>
        dw _destination
    end match
end macro

macro   call?   argument?*&
    local _destination
    match cond =, target, argument
        _match_condition cond
        _destination equ target
        db ((110b shl $05) or ((condition.cond - CC) shl $03) or (110b))
    else
        _destination equ argument
        db 11001101b
    end match
    _inline_if ((elementsof (_destination)) = 0), <_bound _destination, $10>
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
    end match
    macro ld#argument#?  destination?*, source?*
        local _direction, _current, _count
        _count = 0
        iterate _item, <destination>, <source>
            _match_register _item
            if (_metadata eq (A metadata 1))
                _current = _reg_mem
            else if (_metadata eq (_MEM metadata 1))
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
        _inline_if  (_count = 0),         \
                    _direction = _mem_reg,\
                    _direction = _reg_mem
        _memory     equ
        _is_memory  _memory, _item
        match _, _memory
            match =HL? +, _
                _inline_if  (_count = 0),          \
                            <ldi [HL], source>,    \
                            <ldi destination, [HL]>
            else match =HL? -, _
                _inline_if  (_count = 0),          \
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

                _inline_if  (_count = 0),          \
                            _match_register source,\
                            _match_register destination

                if (~(_metadata eq (A metadata 1)))
                    err "A register must be an operand"
                end if

                if ((_address eq $FF00) | (value eq $FF00))
                    _bound _offset,  $08
                    db ((111b shl $05) or (_direction shl $04)), _offset
                else match =C?, value
                    db ((111b shl $05) or (_direction shl $04) or (0010b))
                else if ((elementsof (value)) = 0)
                    _bound value, $10
                    db ((111b shl $05) or (_direction shl $04) or (1010b))
                    dw value
                else
                    _match_register value
                    _ensure r16
                    _scale $01
                    db (((_metadata scale $01) shl $04) or (_direction shl $03) or (010b))
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
    _is_memory  _memory, destination
    match , _memory
        _is_memory  _memory, source
    end match

    match =HL?, _memory
        _memory equ
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

