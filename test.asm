include "rgbds_fasmg.asm"

abc:    MACRO
            printt "HELLO\1\n"
            SHIFT
            printt "WORLD\2\n"
        ENDM

abc 1,2

purge ?

display _abc_1, $A
