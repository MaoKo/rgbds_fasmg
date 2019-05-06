include "z80.asm"
format binary as 'o'

macro _append_string? result?*, str?*
    local _result, _length, _char, _double
    _result = result
    _iterate_string char, str
        _length = lengthof  (_result)
        _result = string    (_result or (char shl (_length * $08)))
    _end_iterate_string
    result = _result
end macro

macro _insert_string? result?*, str?*
    local _result, _char, _double
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
    _not_defined = 0
    _escape = 0
    _result = ""
    _iterate_string char, str
        _char = char
        if (_escape)
            _char = ""
            if ((char >= "1") & (char <= "9"))
                repeat 1, i:char - "0"
                    _insert_string _result, _a#i
                end repeat
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

macro _reset?
    purge   ?
    restruc ?
end macro

macro _restart
    _reset
    _search_label
end macro

macro _interpret_line?
    macro ?! params&
        local _result
        _expand_string _result, `params
        eval    _result
    end macro
end macro

macro rept? count?*
    _reset
    _signed count
    _start_rept     =: 1
    _random_label   =: 1
    _reset_random_use
    _interpret_line
    repeat count
end macro

macro endr?!
        _reset_random_use
    end repeat
    _restart
    restore _start_rept, _random_label
end macro

macro incbin? arguments?*&
    match _file =, offset =, size, arguments
        file _file:offset, size
    else
        file arguments
    end match
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

_count_macro    = 0

macro _define_macro? name?*
    _reset
    _count_macro = _count_macro + 1
    esc macro name line?&
    _reset_random_use
    local _new_line, _last_index
    _new_line   equ line
    repeat 9, i:1
        match _ =, _rest, _new_line
            _new_line   equ _rest
            _expand_string _a#i, `_
        else match _, _new_line
            _new_line   equ
            _expand_string _a#i, `_
            _last_index = i
        else
            _a#i        equ
        end match
    end repeat
    _start_macro    =:  1
    _random_label   =:  1
    _interpret_line
end macro

macro endm?!
    _restart
    esc end macro
    restore _start_macro, _random_label
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
    _reset
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
    _search_label
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
                            _current = ($ - $$)
                            _value = line
                            if ((elementsof (line)) <> 0)
                                _rpn_expression _current, kpatch, line
                                _value = 0
                            end if
                            def _value
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
_in_virtual = 0

macro virtual? line*&
    _in_virtual = 1
    virtual line
end macro

macro end?.virtual?!
    end virtual
    _in_virtual = 0
end macro

macro _search_label?
    struc (name?) ?! line&
        local _is_macro
        _is_macro = 0
        match : =MACRO?, line
            _is_macro = 1
        else
            local _is_label, _new_line, _type
            _is_label = 0
            _new_line   equ

            iterate i, ::, :
                _type = _LOCAL
                match i _, line
                    _is_label = 1
                    _new_line   equ _
                else match i, line
                    _is_label = 1
                end match
                if (_is_label)
                    _inline_if  (~(_in_virtual))             ,\
                                element name : _count_symbols,\
                                _is_label = 0
                    if (`i = "::")
                        _type = _EXPORT
                    end if
                    break
                end if
            end iterate
            if (_is_label)
                local _local, _local_name
                _local = 0
                _local_name = `name
                match . _NAME?, name
                    _local = 1
                    _local_name = `_NAME
                else
                    _last_label = `name
                end match
                if (used name)
                    if (~(_count_section))
                        err "getsecid: Unknown section"
                    end if
                    _count_symbols = _count_symbols + 1
                    repeat 1, i:_count_symbols
                        _label_#i               = _local_name
                        _label_local_#i         = _local
                        if (_local)
                            _label_last_#i      = _last_label
                        end if
                        _label_scope_#i         = _type
                        _label_line_#i          = __line__
                        _label_section_id_#i    = (_db - 1)
                        repeat 1, j:_db
                            virtual _area_#j
                                _label_offset_#i        = ($ - $$)
                            end virtual
                        end repeat
                    end repeat
                end if
                match _, _new_line
                    _
                end match
            else
                name line
            end if
        end match
        _inline_if (_is_macro), _define_macro name
    end struc
end macro

include "postpone.asm"

_restart

