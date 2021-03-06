include "z80.asm"
format binary as 'o'

macro _insert_string? result?*, str?*
    local _result, _char, _double
    define  result
    restore result
    _result = result
    _double = 0
    _iterate_string char, str
        _char = char
        if (_double)
            _double = 0
        else if (char = "'")
            if (%% <> %)
                indx (% + 1)
                _inline_if (char = "'"), _double = 1
            end if
            _inline_if (~(_double)), _char = '"'
        end if
        _append_string _result, _char
    _end_iterate_string
    result = _result
end macro

macro _eval_string? result?*, expand?*
    local _expand
    _is_string  expand
    eval "_expand = ", expand
    _is_string _expand
    _insert_string result, _expand
end macro

macro _expand_string? result?*, str?*
    _expand_macro_param result, str
    local _brace, _expand, _result
    _result = ""
    _brace  = 0
    _iterate_string char, result
        if (_brace)
            _inline_if (char = "}"), _brace = 0, <_append_string _expand, char>
            _inline_if (~(_brace)),  <_eval_string _result, _expand>
        else if (char = "{")
            _expand = ""
            _brace  = 1
        else
            _append_string _result, char
        end if
    _end_iterate_string
    _inline_if (_brace), err "Missing }"
    result = _result
end macro

macro _expand_macro_param? result?*, str?*
    local _result, _escape, _not_defined, _char
    _escape = 0
    _result = ""
    _iterate_string char, str
        _char = char
        if (_escape)
            _char = ""
            if ((char >= "1") & (char <= "9"))
                _not_defined = 0
                match _name, _macro_name
                    repeat 1, i:char - "0"
                        _inline_if (_#_name#_#i = ""), _not_defined = 1
                        _insert_string _result, _#_name#_#i
                    end repeat
                else
                    _not_defined = 1
                end match
                _inline_if (_not_defined), err "MACRO argument not defined"
            else if (char = "@")
                _inline_if (~(_random_label)), err "Only available in MACRO/REPT block"
                _append_string _result, "_"
                repeat 1, i:_random_count
                    _append_string _result, `i
                end repeat
                _random_use = 1
            else
                _append_string _result, "\"
                _char = char
            end if
            _escape = 0
        else if (char = "\")
            _escape = 1
            _char   = ""
        end if
        _append_string _result, _char
    _end_iterate_string
    result = _result
end macro

macro _escape_string? result?*, str?*
    local _escape, _result, _char
    _result = ""
    _escape = 0
    _iterate_string char, str
        _char = char
        if (_escape)
            local _found
            _found = 0
            iterate <target, value>,  "n",$0A, "t",$09, "r",$0D, "\","\",\
                                      "{","{", "}","}", '"','"', "'","'"
                if (char = target)
                    _char = string value
                    _found = 1
                    break
                end if
            end iterate
            _inline_if (~(_found)), <err "Illegal character escape '", char, "'">
            _escape = 0
        else if (char = "\")
            _escape = 1
        end if
        _inline_if (~(_escape)), <_append_string _result, _char>
    _end_iterate_string
    result = _result
end macro

macro _preprocess_string? result?*, str?*
    _expand_string result, str
    _escape_string result, result
end macro

macro printt? string?*
    local _result
    _preprocess_string _result, string
    display _result
end macro

macro printv? number?*
    _bound number, $10, UNSIGNED
    local _result, _number
    _is_integer number
    _result = 0
    _number = trunc number
    while (_number)
        _result = (_result shl $10) or (_number mod $10)
        _inline_if ((_result and $0F) >= $0A), _result = (_result - $0A) + "A",\
                                               _result = _result + "0"
        _number = _number / $10
    end while
    display "$", string _result
end macro

macro printi? number
    _bound number, $10, SIGNED
    local _result, _number
    _is_integer number
    _result = 0
    _number = trunc number
    if (_number < $00)
        display "-"
        _number = _number * (-1)
    end if
    while (_number)
        _result = (_result shl $08) + ((_number mod 10) + "0")
        _number = _number / 10
    end while
    display string _result
end macro

macro warn? string?*
    _interpret_string _warn_string, string
    printt "warning: {__file__}("
    printi  __line__
    printt "):\n\t{_warn_string}"
end macro

macro fail? string?*
    _preprocess_string _error_string, string
    printt "ERROR: {__file__}("
    printi  __line__
    printt "):\n\t{_error_string}"
    err     _error_string
end macro

_random_label   = 0
_random_count   = 0
_random_use     = 0

macro _reset_random_use?
    _inline_if (_random_use), _random_count = _random_count + 1
    _random_use = 0
end macro

macro _interpret_off
    restruc ?
    purge   ?
    macro end?.macro?!
        esc end macro
        purge end?.macro?
        _interpret_line
    end macro
end macro

macro _expand_local_label?: _result?*, _input?*&
    local   _after, _before, _continue
    _continue   = 1
    _after      = 0
    _before     = 0

    local   _target, _r1, _r2
    restore _target, _r1, _r2

    local _syntax_error
    _syntax_error = 0

    match  _1 .= _local _2, _input
        _syntax_error = 1
    else match .= _local _, _input
        _syntax_error = 1
    else match _ .= _local, _input
        _syntax_error = 1
    else match .= _local, _input
        _syntax_error = 1
    else match _ ., _input
        _syntax_error = 1
    end match
    _inline_if (_syntax_error), err "Space can't follow dot"

    match  _1= . _local _2, _input
        _expand_local_label _r1, _1
        _expand_local_label _r2, _2
        _target equ `_local
        _before = 1
        _after  = 1
    else match . _local _, _input
        _expand_local_label _r1, _
        _target equ `_local
        _after  = 1
    else match _= . _local, _input
        _expand_local_label _r1, _
        _target equ `_local
        _before = 1
    else match . _local, _input
        _target equ `_local
    else
        _result equ _input
        _continue   = 0
    end match

    if (_continue)
        macro eval? _variable?*, line?&
            eval "_variable equ ", line
        end macro

        iterate i, _r1, _r2
            local i#_str
            match _, i
                i#_str  equ `_
            end match
        end iterate

        if (_before)
            _inline_if (_after),\
                <eval _result, _r1_str, " ", _last_label, ".", _target, _r2_str>,\
                <eval _result, _r1_str, " ", _last_label, ".", _target>
        else    
            _inline_if (_after),\
                <eval _result, _last_label, ".", _target, _r1_str>,\
                <eval _result, _last_label, ".", _target>
        end if
        purge eval?, _check_symbol?
    end if
end macro

macro _expand_operator?: _symbol?*, _result?*, _input?*&
    local _r1, _r2, _continue
    irpv _value, _symbol
        _continue = 0
        match _item =, _replace, _value
            match _1 _item _2, _input
                _expand_operator _symbol, _r1, _1
                _expand_operator _symbol, _r2, _2
                _result     equ _r1 _replace _r2
            else match _ _item, _input
                _expand_operator _symbol, _r1, _
                _result     equ _r1 _replace
            else match _item _, _input
                _expand_operator _symbol, _r1, _
                _result     equ _replace _r1
            else match _item, _input
                _result     equ _replace
            else
                _continue = 1
            end match
            _inline_if (~(_continue)), break
        end match
    end irpv
    _inline_if (_continue), _result equ _input
end macro

macro _interpret_line?:
    display "INTERPRET", $A
    macro ?! params&
        display "PARAMS = ", `params, $A
        local _new_params, _symbol
        _new_params equ params
        if ((_start_macro) | (_start_rept))
            local _result
            _expand_string _result, `params
            eval    "_new_params equ ", _result
        end if

        _symbol equ  <<, shl
        _symbol equ  >>, shr
        _symbol equ >==,  ge
        _symbol equ <==,  le
        _symbol equ   >,  gt
        _symbol equ   <,  lt
        _symbol equ  =%, mod
        _symbol equ  =^, xor
        _symbol equ   +,   +
        _symbol equ   -,   -
        _symbol equ   *,   *
        _symbol equ   /,   /

        _expand_operator    _symbol, _new_params, _new_params
        _expand_local_label _new_params, _new_params

        macro invoker?
        end macro
        match _, _new_params
            macro invoker?  
                esc _
            end macro
            _search_label
            match =MACRO? _line, _
                _interpret_off
            end match
        end match
        invoker
        restruc ?
        purge   invoker?
    end macro
end macro

macro incbin? arguments?*&
    match _file =, offset =, size, arguments
        file _file:offset, size
    else
        file arguments
    end match
end macro

_start_rept =: 0

macro rept? count?*
    _signed count
    _start_rept     =: 1
    _random_label   =: 1
    _reset_random_use
    repeat count
end macro

macro endr?!
        _reset_random_use
    end repeat
    _restore_args _macro_name
    restore _start_rept, _random_label
end macro

;macro union?
;    _unionStart =: $
;end macro

;macro nextu?!
;    if (~(defined _unionStart))
;        err "Found NEXTU outside of a UNION construct"
;    end if
;    org _unionStart
;end macro

;macro endu?!
;    if (~(defined _unionStart))
;        err "Found ENDU outside of a UNION construct"
;    end if
;    restore _unionStart
;end macro

_start_macro    =:  0
_macro_name     equ

macro _define_macro? name?*
    esc macro name line?&
    _reset_random_use
    local _new_line
    _new_line   equ line

    _NARG   =: -1
    match , _new_line
        _NARG   = 0
    end match

    local _empty_arg
    _empty_arg = 0
    match _1 =, =, _2, _new_line
        _empty_arg = 1
    else match _ =, =,, _new_line
        _empty_arg = 1
    else match =, =, _, _new_line
        _empty_arg = 1
    else match =, =,, _new_line
        _empty_arg = 1
    end match

    _inline_if (_empty_arg), err "Empty argument not allowed"

    local _before
    repeat 256, i:1
        _before = ""
        match _before =, _rest, _new_line
            _expand_string _#name#_#i, `_before
            _new_line   equ _rest
        else match _, _new_line
            _before = `_
        else match _ =,, _new_line
            _before = `_
        else
            _#name#_#i  = ""
        end match
        if (_before <> "")
            _expand_string _#name#_#i, _before
            _new_line   equ
            _NARG       = i
        end if
    end repeat
    _inline_if (_NARG eq -1), <err "Too many argument for the macro: ", `name>
    _start_macro    =:  1
    _random_label   =:  1
    _macro_name     equ name
    _interpret_line
end macro

macro shift?
    _inline_if (~(_start_macro)), err "SHIFT instruction must be in MACRO"
    local _shift_tmp
    match _name, _macro_name
        _shift_tmp  = _#_name#_1
        repeat 255, i:1, j:2
            _inline_if (~(_start_rept)),\
                        _#_name#_#i =   _#_name#_#j,\
                        _#_name#_#i =:  _#_name#_#j
        end repeat
        _inline_if (~(_start_rept)),\
                    _#_name#_256    =   _shift_tmp,\
                    _#_name#_256    =:  _shift_tmp
    else
        err "MACRO name is empty which lead to loss arguments"
    end match
end macro

macro _restore_args? name?*
    match _name, name
        repeat 256, i:1
            restore _#_name#_#i
        end repeat
    end match
end macro

macro endm?!
    purge ?
;    _restore_args _macro_name
    restore _start_macro, _random_label, _macro_name, _NARG
    esc end macro
end macro

ROM0    := 3
ROMX    := 2 
VRAM    := 1
SRAM    := 5
WRAM0   := 0
WRAMX   := 5
OAM     := 7
HRAM    := 4

macro section?  name?*, type?*, options?&   
    restruc ?
    _is_string name, "Name section must be a string"

    local _valid, _found, _type, _org, _bank, _align
    _found  =  0
    _org    = -1

    _type       equ type
    match kind [ base ], type
        _bound  base, $10, UNSIGNED
        _org  = base
        _type   equ kind
    end match

    _find_item  _valid, _type, ROM0,  ROMX,\
                               VRAM,  SRAM,\
                              WRAM0, WRAMX,\
                                       OAM,\
                                      HRAM

    _inline_if  (~(_valid)), err "Section type unknown"
    _bank   = -1
    _align  = -1

    match option_1 =, option_2, options
        match =BANK? [ _1 ] =, =ALIGN? [ _2 ], options
            _bank   = _1
            _align  = _2
        else match =ALIGN? [ _1 ] =, =BANK? [ _2 ], options
            _align  = _1
            _bank   = _2
        else
            err "Syntax error"
        end match
        _signed _bank
        _signed _align
    else match option, options
        match =BANK? [ _ ], option
            _signed _
           _bank   = _
        else match =ALIGN? [ _ ], option
            _signed _
            _align  = _
        else
           err "Syntax error"
        end match
    end match

    if (_align <> -1)
        if (_org <> -1)
            err "Align can't be specified with addr"
        else if ((_align < 0) | (_align > 16))
            err "Align must fit between 0-16"
        end if
    else if (_bank <> -1)
        if ((_bank <= $000) | (_bank > $1FF)))
            err "Bank number must fit between $000-$1FF"
        else if ((_type <> ROMX) & (_type <> VRAM) & (_type <> SRAM) & (_type <> WRAMX))
            err "BANK only allowed for ROMX, WRAMX, SRAM, or VRAM sections"
        end if
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
            _inline_if          (_align = -1), _align = 0
            _section_align_#i   = 1 shl _align
            _count_patches_#i   = 0
            virtual at $00
                _area_#i::
            end virtual
            _db EQU i
        end repeat
        _inline_if              (_org = -1), _org = 0
        section _org
    else
        err "TODO"
    end if
end macro

macro _define   kind?*, def?*, res?*, kpatch?*
    macro kind? line?&
        if (_count_section = 0)
            err "Code generation before SECTION directive"
        else
            repeat 1, i:_db
                match _, line
                    if ((_section_type_#i <> ROM0) & (_section_type_#i <> ROMX))
                        err "Section '", _section_#i,\
                            "' cannot contain code or data (not ROM0 or ROMX)"
                    else
                        virtual _area_#i
                            local _current, _value
                            iterate item, line
                                _current = ($ - $$)
                                _value = item
                                if ((elementsof (item)) <> 0)
                                    _rpn_expression _current, kpatch, item
                                    _value = 0
                                end if
                                def _value
                            end iterate
                        end virtual
                    end if
                else
                    virtual _area_#i
                        res 1
                    end virtual
                end match
            end repeat
        end if
    end macro
end macro

_define db, db, rb, _BYTE
_define dw, dw, rw, _WORD
_define dl, dd, rd, _LONG

macro ds? count?*
    _signed count
    repeat count
        db
    end repeat
end macro

_LOCAL  := 0
_IMPORT := 1
_EXPORT := 2

_last_label = ""

macro _search_label?
    display "SEARCH", $A
    struc (name?) ? line&
        display "NAME = ", `name, $A
        display "LINE = ", `line, $A
        macro invoker?
        end macro
        match : =MACRO?, line
            macro invoker?
                _interpret_off
                _define_macro name
            end macro
        else
            local _is_label, _new_line, _type
            _is_label   = 0
            _type       = _LOCAL

            _new_line   equ
            iterate i, :==, ==:, ::, :
                match i _, line
                    _is_label = 1
                    _new_line   equ _
                else match i, line
                    _is_label = 1
                end match
                if (_is_label)
                    _inline_if (_in_virtual | ((`i eq ":==") | (`i eq "==:"))), _is_label = 0,\
                               <_inline_if  (`i = "::"), _type = _EXPORT>
                    break
                end if
            end iterate
            if (_is_label)
                match . _local, name
                    err "Local label must not be alone"
                else match _global . _local, name
                else
                    _last_label = `name
                end match
                element name : _count_symbols

                if (used name)
                    _inline_if (~(_count_section)), err "getsecid: Unknown section"
                    _count_symbols = _count_symbols + 1
                    repeat 1, i:_count_symbols
                        _label_#i                   = `name
                        _label_scope_#i             = _type
                        _label_line_#i              = __line__
                        _label_section_id_#i        = (_db - 1)
                        repeat 1, j:_db
                            virtual _area_#j
                                _label_offset_#i    = ($ - $$)
                            end virtual
                        end repeat
                    end repeat
                end if
                match _, _new_line
                    macro invoker?
                        esc _
                    end macro
                end match
            else
                macro invoker?
                    esc name line
                end macro
            end if
        end match
        restruc ?
        invoker
        purge   invoker?
    end struc
end macro

include "postpone.asm"
_interpret_line

