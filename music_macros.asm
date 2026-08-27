MACRO Noise
	REPT _NARG
		IF \1 == 0
			db 1
		ELIF \1 == 1
			db 6
		ELIF \1 == 2
			db 11
		ELIF \1 == 3
			db 16
		ELSE
			FAIL "Unknown noise note"
		ENDC
		SHIFT
	ENDR
ENDM

DEF C_  EQU 1
DEF Cs_ EQU 2
DEF D_  EQU 3
DEF Ds_ EQU 4
DEF E_  EQU 5
DEF F_  EQU 6
DEF Fs_ EQU 7
DEF G_  EQU 8
DEF Gs_ EQU 9
DEF A_  EQU 10
DEF As_ EQU 11
DEF B_  EQU 12

MACRO Notes
	IF _NARG % 2 != 0
		FAIL "Note list needs an even number of arguments"
	ENDC
	REPT _NARG / 2
		db \1 + (\2 - 2) * 12
	ENDR
ENDM

MACRO EndSegment
	db $00
ENDM
