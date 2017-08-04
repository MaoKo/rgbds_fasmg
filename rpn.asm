include "utils.asm"

_ADD    := $00
_SUB    := $01
_MUL    := $02
_DIV    := $03
_MOD    := $04
_UNNEG  := $05
_OR     := $10
_AND    := $11
_XOR    := $12
_UNNOT  := $12
_LOGAND := $21
_LOGOR  := $22
_LOGNOT := $23
_LOGEQU := $30
_LOGNE  := $31
_LOGGT  := $32
_LOGLT  := $33
_LOGGE  := $34
_LOGLE  := $35
_SHL    := $40
_SHR    := $41
_INT    := $80
_SYM    := $81

_BYTE   := $00
_WORD   := $01
_LONG   := $02
_JR     := $03

macro _rpn_binary?  expression?*, operator?*, value?*, line?*&
    local _length, _current, _replace
    _length     = 0
    operator    equ
    iterate i, line
        match j= v, i
            _replace        equ j
            _shl            equ <<
            _shr            equ >>
            _gt             equ >
            _ge             equ >==
            _lt             equ <
            _le             equ <==
            iterate k, shl, shr, gt, ge, lt, le
                match =j, k
                    _replace    equ _#k
                    break
                end match
            end iterate
            restore _shl, _shr, _gt, _ge, _lt, _le
            match _, _replace
                match term_1 =_ term_2, expression
                    _current = (lengthof (`term_1))
                    if ((_current < _length) | (~(_length)))
                        _length     = _current
                        operator    equ _
                        value       equ v
                    end if
                end match
            end match
        end match
    end iterate
end macro

macro _rpn_parser?:     offset?*, expression?*
    local _operator, _value, _check_div
    iterate i,  <*      _MUL,   /   _DIV,    mod _MOD>                          ,\ 
                <shl    _SHL,   shr _SHR>                                       ,\
                <|      _OR,    &   _AND,    xor _XOR>                          ,\
                <+      _ADD,   -   _SUB>                                       ,\
                <gt     _LOGGT, ge  _LOGGE,  lt  _LOGLT, le  _LOGLE, !== _LOGNE>,\
                <||     _LOGOR, &&  _LOGAND, === _LOGEQU>
        _rpn_binary expression, _operator, _value, i
        match _, _operator
            break
        end match
    end iterate

    match ( sub? ), expression
        _rpn_parser sub
    else match ~ term, expression
        _rpn_parser term
        db _UNNEG
    else match - term, expression
        _rpn_parser term
        db _UNNOT
    else match + term, expression
        _rpn_parser term
    else match _, _operator
        match term_1 =_ term_2, expression
            _check_div = 0
            _rpn_parser term_1
            _rpn_parser term_2
            match =/, _
                _check_div = 1
            else match =%, _
                _check_div = 1
            end match
            if (_check_div)
                _division_zero term_2
            end if
            db  _value
        end match
    else match ! term, epxression
        _rpn_parser term
        db _LOGNOT
    else match term, expression
        if (elementsof (term))
            db _SYM
            dd (term metadata 1)
        else
            db _INT
            local _is_offset
            _is_offset = 0
            match =$, term
                _is_offset = 1
            else match =@, term
                _is_offset = 1
            end match
            _inline_if  (_is_offset),\
                        dd offset   ,\
                        dd term
        end if
    else
        err "Invalid expression"
    end match
end macro

macro _rpn_expression?  offset?*, kind?*, expression?*
    match , _db
        err "Section not defined yet"
    else match i, _db
        _count_patches_#i = _count_patches_#i + 1
        local _offset
        _offset = offset
        repeat 1, j:_count_patches_#i
            virtual at $00
                _patches_#i#_#j::
                    emit $04: __line__
                    emit $04: _offset
                    emit $01: kind
            end virtual
            iterate <name, size>, db?, 1, dw?, 2, dd?, 4
                macro name line*&
                    virtual _patches_#i#_#j
                        emit size: line
                    end virtual
                end macro
            end iterate
        end repeat
        _rpn_parser offset, expression
        purge db?, dw?, dd?
    end match
end macro
