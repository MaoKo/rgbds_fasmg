postpone
    purge   ?

;    if (defined _unionStart)
;        _level = 0
;        while (defined _unionStart)
;            restore _unionStart
;            _level = _level + 1
;        end while
;        err "Unterminated UNION construct (", _level + "0", " levels)!"
;    end if

    _magic  := "RGB6"
    purge db?, dw?, dl?

    db _magic
    dd _count_symbols
    dd _count_section
    
    repeat _count_symbols, i:1
        db _label_#i
        db 0
        db _label_scope_#i
        if (_label_scope_#i <> _IMPORT)
            db __file__
            db 0
            dd _label_line_#i
            dd _label_section_id_#i
            dd _label_offset_#i
        end if
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
            dd _count_patches_#i
            repeat _count_patches_#i, j:1
                virtual _patches_#i#_#j
                    _patches_length_#i#_#j = (($ - $$) - $09)
                end virtual
                db __file__
                db 0
                load line:dword     from _patches_#i#_#j:$00
                load offset:dword   from _patches_#i#_#j:$04
                load kind:byte      from _patches_#i#_#j:$08
                dd line
                dd offset
                db kind
                dd _patches_length_#i#_#j
                repeat _patches_length_#i#_#j, k:$09
                    load _byte:byte from _patches_#i#_#j:k
                    db _byte
                end repeat
            end repeat
        end if
    end repeat
end postpone

