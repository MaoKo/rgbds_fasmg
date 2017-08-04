macro comment? begin?*
    local _reverse
    _reverse = string (`begin bswap (lengthof `begin))
    macro ?! line?&
        if (`line = _reverse)
            purge ?
        end if
    end macro
end macro

macro _check_kind?
    iterate <i, j>, "",string, $00,integer, 0.0,float
        macro _is_#j value?*, error?
            if (~(value eqtype i))
                err "Operand must be of type: ", (`j)
                match _, error
                    err error
                end match
            end if
        end macro
    end iterate
end macro

_check_kind

macro _signed? number?*
    _is_integer number
    _inline_if (number < $00), <err "Constant mustn't be negative: ", (`number)>
end macro

macro _division_zero?   expression?*
    _is_integer expression
    _inline_if (~(elementsof (expression))), err "Division by zero"
end macro

macro   _bound? value?*, bitness?*, kind?
    _is_integer value
    _inline_if (elementsof (value)), err "Linear polynomial cannot be part of immediate"

    local _value, _slimit, _ulimit
    _value = value

    _ulimit = (1 shl bitness)
    _slimit = (1 shl (bitness - 1))

    match =SIGNED?, kind
        _inline_if ((_value >= _slimit) | (_value < (-_slimit))),\
                    err "Immediate value not fit in signed range"
    else match =UNSIGNED?, kind
        _inline_if ((_value < $00) | (_value >= _ulimit)),\
                    err "Immediate value not fit in unsigned range"
    else match , kind
        _inline_if ((_value < (-_slimit)) | (_value >= _ulimit)), err ""
    end match
end macro

macro _reverse_string? result?*
    result = string result
    result = (result bswap (lengthof result))
end macro

macro reverse?
    indx    (1 + %% - %)
end macro

macro forward?
    indx    (%)
end macro

macro _iterate_string?! iter?*, str?*
    _is_string str
    _string = (+str)
    _back_result        equ 
    match _, _result
        _back_result    equ _
    end match
    _result equ
    repeat (lengthof (str)), i:0
        local   _char
        _char   equ (string ((_string shr (i * $08)) and $FF))
        match _, _result
            _result equ _result,
        end match
        _result equ _result _char
    end repeat
    match _, _result
        iterate iter, _
end macro

macro _end_iterate_string?!
        end iterate
    end match
    restore _string
    _result equ _back_result
end macro

macro _find_item? predicate?*, argument?*, list?*&
    predicate = 0
    iterate _item, list
        match =_item?, argument
            predicate = 1
            break
        end match
    end iterate
end macro

macro _inline_if?: condition?*, true?*, false?
    local _defined
    if (condition)
        macro invoker?
            true
        end macro
    else match _, false
        macro invoker?
            false
        end macro
    else
        macro invoker?
        end macro
    end match
    invoker
    purge invoker?
end macro

_count_symbols  = 0
_count_section  = 0
_db             equ
