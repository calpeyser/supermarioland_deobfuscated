INCLUDE "constants.asm"
INCLUDE "sound_constants.asm"

SECTION "bank 1", ROMX, BANK[1]
; Unused slots are filled with repeats of other pointers
; todo should be named levelscreenpointers or so?
LevelPointers:: ; 4000 Same every bank
LevelPointersBank1:: ; 1:4000
	dw $55BB
	dw $55E2
	dw $5605
	dw $55BB	; 2-1
	dw $55E2	; 2-2
	dw $5605	; 2-3
	dw $55BB
	dw $55E2
	dw $5605
	dw $5630	; 4-1
	dw $5665	; 4-2
	dw $5694	; 4-3
	dw $55BB

LevelEnemyPointers:: ; 401A
LevelEnemyPointersBank1:: ; 1:401A
	dw $5311
	dw $5405
	dw $54D5
	dw $5179	; 2-1
	dw $5222	; 2-2
	dw $529B	; 2-3
	dw $5311
	dw $5405
	dw $54D5
	dw $5311	; 4-1
	dw $5405	; 4-2
	dw $54D5	; 4-3

INCBIN "gfx/enemiesWorld2.2bpp"
INCBIN "gfx/backgroundWorld2.2bpp"

INCBIN "gfx/enemiesWorld4.2bpp"
INCBIN "gfx/backgroundWorld4.2bpp"

;@ --------------------------------------------------------------------
;@ Call_4FB2   [01:4FB2]   35 lines
;@   called by : GameState_0D_AutoScrollLevel
;@   reads     : hFrameCounter, hScrollX, wLevelEndCounter
;@   writes    : hScrollX
;@   calls     : Call_1D26, Call_2C9F, Call_50CC
;@ --------------------------------------------------------------------
Call_4FB2:: ; 4FB2
	ldh a, [hFrameCounter]
	and a, $01
	ret nz
	ld a, [wLevelEndCounter]
	cp a, $07
	jr c, .skip
	ldh a, [hScrollX]
	and a, $0C
	jr nz, .skip
	ldh a, [hScrollX]
	and a, $FC
	ldh [hScrollX], a
	ret

.skip
	ldh a, [hScrollX]
	inc a
	ldh [hScrollX], a
	ld b, $01
	call Call_1D26.skip10	; scroll sprites?
	call Call_2C9F				; scroll enemies?
	ld hl, wMarioX				; X coord
	dec [hl]
	ld a, [hl]
	and a
	jr nz, .out
	ld [hl], $F0
.out
	ld c, $08
	call Call_50CC
	ld hl, wMarioX
	inc [hl]
	ret

;@ --------------------------------------------------------------------
;@ Call_4FEC   [01:4FEC]   101 lines
;@   called by : GameState_0D_AutoScrollLevel
;@   reads     : hJoyHeld, hScrollX, hSuperStatus, wLevelEndCounter
;@   calls     : Call_5089, Call_50CC, LookupTile
;@ --------------------------------------------------------------------
Call_4FEC:: ; 4FEC
	ldh a, [hJoyHeld]
	bit 6, a					; up button
	jr nz, .skip2
	bit 7, a					; down button
	jr nz, .skip
.loop
	ldh a, [hJoyHeld]
	bit 4, a					; right button
	jr nz, .out
	bit 5, a					; left button
	ret z
	ld c, $FA
	call Call_50CC
	ld hl, wMarioX
	ld a, [hl]
	cp a, $10
	ret c
	dec [hl]
	ld a, [wLevelEndCounter]
	cp a, $07
	ret nc
	dec [hl]
	ret

.out
	ld c, $08
	call Call_50CC
	ld hl, wMarioX
	ld a, [hl]
	cp a, $A0
	ret nc
	inc [hl]
	ret

.skip
	call Call_5089
	cp a, $FF
	jr z, .loop
	ld hl, wMarioY				; Y coord
	ld a, [hl]
	cp a, $94					; ?
	jr nc, .loop
	inc [hl]
	jr .loop

.skip2
	call .skip3
	cp a, $FF
	jr z, .loop
	ld hl, wMarioY
	ld a, [hl]
	cp a, $30
	jr c, .loop
	dec [hl]
	jr .loop

.skip3
	ld hl, wMarioY
	ldh a, [hSuperStatus]
	ld b, $FD
	and a
	jr z, .skip4
	ld b, $FC
.skip4
	ldi a, [hl]
	add b
	ldh [$FFAD], a
	ldh a, [hScrollX]
	ld b, [hl]
	add b
	add a, $02
	ldh [$FFAE], a
	call LookupTile
	cp a, $60
	jr nc, .out2
	ldh a, [$FFAE]
	add a, $FA
	ldh [$FFAE], a
	call LookupTile
	cp a, $60
	ret c
.out2
	cp a, $F4
	jr z, .skip5
	ld a, $FF
	ret

.skip5
	push hl
	pop de
	ld hl, $FFEE
	ld [hl], $C0
	inc l
	ld [hl], d			; FFEF
	inc l
	ld [hl], e			; FFF0
	ld a, SFX_COIN
	ld [$DFE0], a
	ret

;@ --------------------------------------------------------------------
;@ Call_5089   [01:5089]   43 lines
;@   called by : Call_4FEC
;@   reads     : hScrollX
;@   calls     : Jmp_1B45, LookupTile
;@ --------------------------------------------------------------------
Call_5089:: ; 5089
	ld hl, wMarioY
	ldi a, [hl]
	add a, $0A
	ldh [$FFAD], a
	ldh a, [hScrollX]
	ld b, a
	ld a, [hl]
	add b
	add a, $FE
	ldh [$FFAE], a
	call LookupTile
	cp a, $60
	jr nc, .skip
	ldh a, [$FFAE]
	add a, $04
	ldh [$FFAE], a
	call LookupTile
	cp a, $E1
	jp z, Jmp_1B45			; end of level?
	cp a, $60
	jr nc, .skip
	ret

.skip
	cp a, $F4
	jr nz, .out
	push hl
	pop de
	ld hl, $FFEE
	ld [hl], $C0
	inc l
	ld [hl], d
	inc l
	ld [hl], e
	ld a, SFX_COIN
	ld [$DFE0], a
	ret

.out
	ld a, $FF
	ret

;@ --------------------------------------------------------------------
;@ Call_50CC   [01:50CC]   51 lines
;@   called by : Call_4FB2, Call_4FEC
;@   reads     : hScrollX, hSuperStatus
;@   calls     : Jmp_1B45, LookupTile
;@ --------------------------------------------------------------------
Call_50CC:: ; 50CC
	ld de, $0502
	ldh a, [hSuperStatus]
	cp a, $02
	jr z, .loop
	ld de, $0501
.loop
	ld hl, wMarioY
	ldi a, [hl]
	add d
	ldh [$FFAD], a
	ld b, [hl]
	ld a, c
	add b
	ld b, a
	ldh a, [hScrollX]
	add b
	ldh [$FFAE], a
	push de
	call LookupTile
	pop de
	cp a, $60
	jr c, .out
	cp a, $F4			; coin?
	jr z, .skip
	cp a, $E1			; boss switch
	jp z, Jmp_1B45
	cp a, $83			; mushroom...
	jp z, Jmp_1B45
	pop hl
	ret

.out
	ld d, $FD
	dec e
	jr nz, .loop
	ret

.skip
	push hl
	pop de
	ld hl, $FFEE
	ld [hl], $C0
	inc l
	ld [hl], d
	inc l
	ld [hl], e
	ld a, SFX_COIN
	ld [$DFE0], a
	ret

;@ --------------------------------------------------------------------
;@ CheckSuperballEnemyHit   [01:5118]   77 lines
;@   called by : GameState_0D_AutoScrollLevel
;@   reads     : wMarioX
;@   writes    : hEnemyX, hEnemyY, hGameState, hHitboxBottom, hSuperStatus, hSuperballMario, hTimer
;@   calls     : Call_200A, FindNeighboringTile
;@ --------------------------------------------------------------------
CheckSuperballEnemyHit:: ; 5118
	ld b, $03				; 3 projectiles
	ld hl, hProjectileStatus			; projectile status
	ld de, wOAMBuffer + 1
.loop
	ldi a, [hl]
	and a
	jr nz, .skip
.loop2
	inc e
	inc e
	inc e
	inc e
	dec b
	jr nz, .loop
	ret

.skip
	push hl
	push de
	push bc
	dec l
	ld a, [de]
	inc a
	inc a
	ld [de], a
	ldh [hHitboxBottom], a
	ldh [hEnemyX], a			; isn't this for enemies?
	cp a, $A9
	jr c, .skip2
.loop3
	xor a
	res 0, e
	ld [de], a
	ld [hl], a
	jr .skip3

.skip2
	add a, $02
	push af
	dec e
	ld a, [de]
	ldh [hEnemyY], a
	add a, $06
	ldh [$FFAD], a
	pop af
	call FindNeighboringTile
	jr c, .skip3
	jr .loop3

.skip3
	pop bc
	pop de
	pop hl
	call Call_200A			; collision with enemy
	jr .loop2

.out
	ld a, [wMarioX]
	cp a, $01
	jr c, .skip4
	cp a, $ED
	ret c
.skip4
	xor a
	ldh [hSuperStatus], a
	ldh [hSuperballMario], a
	inc a
	ldh [hGameState], a		; dead
	inc a
	ld [$DFE8], a			; MUS_DEATH
	ld a, $90
	ldh [hTimer], a
	ret

SECTION "bank 1 levels", ROMX[$55BB], BANK[1]
INCBIN "baserom.gb", $55BB, $8000 - $55BB
