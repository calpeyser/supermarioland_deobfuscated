; Endgame: gate, Tatanga, fake Daisy, real Daisy, airplane and credits
; Extracted from bank0.asm by tools/split.py. Addresses are pinned,
; so this file's contents sit at exactly the same ROM offsets as before.

INCLUDE "constants.asm"
INCLUDE "charmap.asm"
INCLUDE "inc/hardware.inc"
INCLUDE "macros.asm"
INCLUDE "enemies.asm"

SECTION "ending 0DF9", ROM0[$0DF9]

; leaving bonus game?
;@ --------------------------------------------------------------------
;@ GameState_1B_LeaveBonusGame   [00:0DF9]   17 lines
;@   writes    : hGameState, hScoreLeadingZero, rIF, rLCDC
;@   calls     : DisplayCoins, PrepareHUD, UpdateLives
;@ --------------------------------------------------------------------
GameState_1B_LeaveBonusGame:: ; DF9
	di
	xor a
	ldh [rLCDC], a	; turn off lcd
	call PrepareHUD
	call DisplayCoins
	call UpdateLives.displayLives
	xor a
	ldh [rIF], a
	ld a, (LCDCF_ON | LCDCF_WIN9C00 | LCDCF_OBJON | LCDCF_BGON); $C3
	ldh [rLCDC], a
	ei
	ld a, $08
	ldh [hGameState], a
	ldh [hScoreLeadingZero], a
	ret

;@ --------------------------------------------------------------------
;@ GameState_1C   [00:0E15]   18 lines
;@   reads     : hTimer
;@   writes    : hTimer, wLevelProgress
;@   calls     : Call_1736, Call_2491, LoadNextColumn
;@ --------------------------------------------------------------------
GameState_1C:: ; E15
	ldh a, [hTimer]		; wait 6 frames
	and a
	jr z, .nextState
	call LoadNextColumn	; doesn't seem to be necessary
	xor a
	ld [wLevelProgress], a
	call Call_2491			; explode enemies?
	call Call_1736		; mario animation?
	ret

.nextState
	ld a, $40			; 2/3 second
	ldh [hTimer], a
	ld hl, hGameState
	inc [hl]
	ret					; 1C → 1D

;@ --------------------------------------------------------------------
;@ GameState_1D   [00:0E31]   28 lines
;@   reads     : hTimer
;@   writes    : hTimer, wLevelProgress
;@   calls     : Call_2491
;@ --------------------------------------------------------------------
GameState_1D:: ; E31
	xor a
	ld [wLevelProgress], a
	call Call_2491
	ldh a, [hTimer]
	and a
	ret nz
	ldh a, [$FFE0]		; first column past the end
	sub a, $02			; above gate
	cp a, $40
	jr nc, .nowrap		; in case of wrap around
	add a, $20			; one screen width
.nowrap
	ld l, a
	ld h, $98
	ld de, 9 * $20		; bottom of the gate is 9 tiles under top
	add hl, de
	ld a, l
	ldh [$FFE0], a		; contains low byte of location of bottom of gate
	ld a, $05
	ldh [$FFFC], a		; gate consists of 4 segments (+1 because of shitty logic)
	ld a, $08
	ldh [hTimer], a
	ld hl, hGameState
	inc [hl]
	ret

; Open gate
;@ --------------------------------------------------------------------
;@ GameState_1E_OpenGate   [00:0E5D]   36 lines
;@   reads     : hTimer, rSTAT
;@   writes    : hActiveRomBank, hTimer, rROMB0
;@   calls     : InitSound
;@ --------------------------------------------------------------------
GameState_1E_OpenGate:: ; E5D
	ldh a, [hTimer]
	and a
	ret nz
	ldh a, [$FFFC]
	dec a
	jr z, .gateIsOpen
	ldh [$FFFC], a
	ldh a, [$FFE0]
	ld l, a
	ld h, $99
	sub a, $20
	ldh [$FFE0], a
.waitHBlank
	ldh a, [rSTAT] ; [$FF41]
	and a, %11
	jr nz, .waitHBlank
	ld [hl], " "
	ld a, $08
	ldh [hTimer], a
	ld a, $0B
	ld [$DFE0], a		; sound effect
	ret

.gateIsOpen
	ld a, $10
	ldh [hTimer], a
	ld a, BANK("banked audio")  ; $03
	ldh [hActiveRomBank], a
	ld [rROMB0], a
    call InitSound
	ld hl, hGameState
	inc [hl]			; 1E → 1F
	ret

; gate is open
;@ --------------------------------------------------------------------
;@ GameState_1F_GateOpen   [00:0E96]   14 lines
;@   reads     : hTimer
;@   writes    : hUnderground, wLevelEndCounter, wMarioJumpStatus
;@ --------------------------------------------------------------------
GameState_1F_GateOpen:: ; E96
	ldh a, [hTimer]
	and a
	ret nz
	xor a
	ld [wLevelEndCounter], a		; increments at end of level
	ld [wMarioJumpStatus], a		; jump status
	inc a
	ldh [hUnderground], a		; tiens, non zero in underground
	ld hl, hGameState
	inc [hl]			; 1F → 20
	ret

; Mario walks/flies off screen
GameState_28_MarioExitsScreen::
;@ --------------------------------------------------------------------
;@ GameState_20_WalkOffButton   [00:0EA9]   22 lines
;@   called by : GameState_2E_MarioAndDaisyWalking
;@   reads     : wMarioAnimationIndex, wMarioX
;@   writes    : hJoyHeld, hTimer
;@   calls     : AnimateMario, CheckMarioTileCollision
;@ --------------------------------------------------------------------
GameState_20_WalkOffButton:: ; EA9
	call .walkRight
	ld a, [wMarioX]		; mario on screen X
	cp a, $C0
	ret c
	ld a, $20
	ldh [hTimer], a
	ld hl, hGameState
	inc [hl]			; 20 → 21
	ret

.walkRight
	ld a, $10
	ldh [hJoyHeld], a	; simulate pressing Right button todo
	ld a, [wMarioAnimationIndex]		; animation index
	and a, $0F
	cp a, $0A			; animations >= $0A are sub or airplane
	call c, CheckMarioTileCollision
	call AnimateMario		; animate and move mario
	ret

; preparing Fake Daisy
;@ --------------------------------------------------------------------
;@ GameState_21_PrepareFakeDaisy   [00:0ECD]   47 lines
;@   called by : GameState_29
;@   reads     : hTimer
;@   writes    : hColumnLoadRequest, hScrollColumnPhase, hTimer
;@ --------------------------------------------------------------------
GameState_21_PrepareFakeDaisy:: ; ECD
	ldh a, [hTimer]
	and a
	ret nz
	call .prepareMarioAndDaisy
	xor a
	ldh [hColumnLoadRequest], a		; render status?
	ldh [hScrollColumnPhase], a		; switches between 0 and 8..
	ld a, $A1
	ldh [hTimer], a
	ld a, $0F
	ld [$DFE8], a		; Daisy music
	ld hl, hGameState
	inc [hl]			; 21 → 22
	ret

.prepareMarioAndDaisy::
	ld hl, wMarioY		; mario y position
	ld [hl], $7E
	inc l
	ld [hl], $B0		; mario x
	inc l
	ld a, [hl]			; C203
	and a, $F0
	ld [hl], a
	ld hl, $C210
	ld de, Data_211D
	ld b, $10
.loop
	ld a, [de]
	ldi [hl], a
	inc de
	dec b
	jr nz, .loop
	ld hl, $C211
	ld [hl], $7E		; object Y pos?
	inc l
	ld [hl], $00		; object X pos?
	inc l
	ld [hl], $22		; Daisy :)
	inc l
	inc l
	ld [hl], $20		; flipped
	ret


; scroll the screen
;@ --------------------------------------------------------------------
;@ GameState_22_ScrollScreen   [00:0F12]   22 lines
;@   called by : GameState_23_WalkToFakeDaisy
;@   reads     : hTimer
;@   writes    : hLevelIndex
;@   calls     : Call_1736, UpdateScrollProgress
;@ --------------------------------------------------------------------
GameState_22_ScrollScreen:: ; F12
	ldh a, [hTimer]
	and a
	jr z, .nextState
	ld hl, hScrollX
	inc [hl]
	call UpdateScrollProgress		; loads in columns?
	ld hl, wMarioX		; mario x pos
	dec [hl]
	ld hl, $C212		; fake daisy x pos
	dec [hl]
.animateMarioAndReturn
	call Call_1736
	ret

.nextState
	ldh a, [$FFFB]		; temporarily stores level index?
	ldh [hLevelIndex], a
	ld hl, hGameState
	inc [hl]			; 22 → 23
	ret

;@ --------------------------------------------------------------------
;@ GameState_23_WalkToFakeDaisy   [00:0F33]   31 lines
;@   reads     : wMarioAnimationIndex, wMarioX
;@   writes    : hJoyHeld, hTextCursorHi, hTextCursorLo, wMarioAnimationIndex
;@   calls     : AnimateMario, CheckMarioTileCollision, GameState_22_ScrollScreen
;@ --------------------------------------------------------------------
GameState_23_WalkToFakeDaisy:: ; F33
	ld a, $10			; right button
	ldh [hJoyHeld], a
	call CheckMarioTileCollision
	call AnimateMario
	ld a, [wMarioX]
	cp a, $4C			; almost middle of screen
	ret c
	ld a, [wMarioAnimationIndex]
	and a, $F0
	ld [wMarioAnimationIndex], a		; mario standing still
	ldh a, [$FFE0]		; top of gate?
	sub a, $40			; two tiles up
	add a, $04			; four to the right
	ld b, a
	and a, $F0
	cp a, $C0
	ld a, b
	jr nz, .nowrap
	sub a, $20
.nowrap
	ldh [hTextCursorLo], a
	ld a, $98
	ldh [hTextCursorHi], a
	xor a
	ldh [$FFFB], a
	ld hl, hGameState
	inc [hl]
	jr GameState_22_ScrollScreen.animateMarioAndReturn

; Fake Daisy speaking
;@ --------------------------------------------------------------------
;@ GameState_24_FakeDaisySpeaking   [00:0F6A]   17 lines
;@   writes    : hTimer
;@   calls     : PrintVictoryMessage
;@ --------------------------------------------------------------------
GameState_24_FakeDaisySpeaking:: ; F6A
	ld hl, Text_FE1
	call PrintVictoryMessage
	cp a, $FF		; end of speech
	ret nz
	ld hl, hGameState
	inc [hl]		; 24 → 25
	ld a, $80
	ld [$C210], a	; make sprite invisible
	ld a, $08
	ldh [hTimer], a
	ld a, $08
	ldh [$FFFB], a	; timer for morph
	ld a, $12
	ld [$DFE8], a	; music
	ret

;@ --------------------------------------------------------------------
;@ PrintVictoryMessage   [00:0F8A]   62 lines
;@   called by : GameState_24_FakeDaisySpeaking, GameState_2A_DaisySpeaking, GameState_2B_DaisyApproaching, GameState_2D_QuestOver
;@   reads     : hTextCursorHi, hTextCursorLo, hTimer
;@   writes    : hTextCursorHi, hTextCursorLo, hTimer
;@ --------------------------------------------------------------------
PrintVictoryMessage:: ; F8A
	ldh a, [hTimer]
	and a
	ret nz
	ldh a, [$FFFB]	; keeps track of how many letters were already printed
	ld e, a
	ld d, $00
	add hl, de
	ld a, [hl]
	ld b, a
	cp a, $FE
	jr z, .newline
	cp a, $FF
	ret z
	ldh a, [hTextCursorHi]
	ld h, a
	ldh a, [hTextCursorLo]
	ld l, a
.printLetter
	WAIT_FOR_HBLANK
	WAIT_FOR_HBLANK
	ld [hl], b
	inc hl
	ld a, h
	ldh [hTextCursorHi], a
	ld a, l
	and $0F
	jr nz, .nowrap
	bit 4, l
	jr nz, .nowrap
	ld a, l
	sub a, $20
.nextLetter
	ldh [hTextCursorLo], a
	inc e
	ld a, e
	ldh [$FFFB], a
	ld a, $0C
	ldh [hTimer], a
	ret

.nowrap
	ld a, l
	jr .nextLetter

.newline
	inc hl
	ldi a, [hl]			; next byte determines how many tiles to skip
	ld c, a
	ld b, $00
	ld a, [hl]
	push af
	ldh a, [hTextCursorHi]
	ld h, a
	ldh a, [hTextCursorLo]
	ld l, a
	add hl, bc
	pop bc
	inc de
	inc de
	jr .printLetter


SECTION "ending 0FFD", ROM0[$0FFD]

; Fake Daisy morphing
;@ --------------------------------------------------------------------
;@ GameState_25_FakeDaisyMorphing   [00:0FFD]   51 lines
;@   reads     : hTimer
;@   writes    : hTimer
;@ --------------------------------------------------------------------
GameState_25_FakeDaisyMorphing:: ; FFD
	ldh a, [hTimer]
	and a
	ret nz
	ldh a, [$FFFB]
	dec a
	jr z, .nextState
	ldh [$FFFB], a
	and a, $01
	ld hl, .morphSprite1
	jr nz, .exchangeSprite
	ld hl, .morphSprite2
	ld a, 3
	ld [$DFF8], a
.exchangeSprite
	call .writeSprite
	ld a, $08
	ldh [hTimer], a
	ret

.nextState
	ld hl, $C210
	ld [hl], $00		; make sprite visible
	ld hl, hGameState
	inc [hl]			; 25 → 26
	ret

.writeSprite
	ld de, wOAMBuffer + 4 * $7	; Daisy sprite
	ld b, 4 * 4					; 4 concomitant objects
.loop
	ldi a, [hl]
	ld [de], a
	inc e
	dec b
	jr nz, .loop
	ret

.morphSprite1
	db $78, $58, $06, $00
	db $78, $60, $06, $20
	db $80, $58, $06, $40
	db $80, $60, $06, $60

.morphSprite2
	db $78, $58, $07, $00
	db $78, $60, $07, $20
	db $80, $58, $07, $40
	db $80, $60, $07, $60

; Fake Daisy monster jumping away
;@ --------------------------------------------------------------------
;@ GameState_26_FakeDaisyEscaping   [00:1055]   45 lines
;@   reads     : hFrameCounter, hTimer
;@   writes    : hActiveRomBank, hTimer, rROMB0
;@   calls     : Call_1736
;@ --------------------------------------------------------------------
GameState_26_FakeDaisyEscaping:: ; 1055
	ldh a, [hTimer]
	and a
	ret nz
	ld hl, $C213		; sprite 1 animation index?
	ld [hl], $20		; jumping enemy
	ld bc, $C218
	ld hl, Data_216D	; jumping curve
	push bc
	call $490D			; animates smth?
	pop hl
	dec l
	ld a, [hl]
	and a
	jr nz, .advanceMonster
	ld [hl], $01
	ld hl, $C213
	ld [hl], $21		; jumping enemy on the ground
	ld a, $40
	ldh [hTimer], a
.advanceMonster
	ldh a, [hFrameCounter]
	and a, %1
	jr nz, .out
	ld hl, $C212
	inc [hl]
	ld a, [hl]
	cp a, $D0
	jr nc, .monsterOutOfView
.out
	call Call_1736
	ret

.monsterOutOfView
	ld hl, hGameState
	ld [hl], $12		; go to bonus game
	ld a, $02
	ldh [hActiveRomBank], a
	ld [rROMB0], a
	ret

; Shaking, explosions, blocks disappearing
; the blocks are removed by a constantly rotating bitmask ANDed with the tiles
; the bitmask goes
; 10111111 → 11100111 → 11101100 → 10001101 → 10100001 → 00100100 → 1000010 → 1000000
;@ --------------------------------------------------------------------
;@ GameState_27_RemoveBlocks   [00:1099]   73 lines
;@   reads     : hTimer, wScrollY
;@   writes    : hTimer, hUnderground, wLevelEndCounter, wLevelProgress, wScrollY
;@   calls     : Call_2491
;@ --------------------------------------------------------------------
GameState_27_RemoveBlocks::	; 1099
	ldh a, [$FFA7]
	and a
	jr nz, .screenShake
	ld a, $01
	ld [$DFF8], a		; explosion sound effect
	ld a, $20			; one explosion every 32 frames, about half a second
	ldh [$FFA7], a
.screenShake
	xor a
	ld [wLevelProgress], a
	call Call_2491		; sprite animation?
	ldh a, [hTimer]
	ld c, a
	and a, %11			; shake every 4 frames
	jr nz, .disintegrateBlocks
	ldh a, [$FFFB]
	xor a, $01
	ldh [$FFFB], a
	ld b, -4
	jr z, .updateScrollY
	ld b, 4
.updateScrollY
	ld a, [wScrollY]
	add b
	ld [wScrollY], a
.disintegrateBlocks
	ld a, c
	cp a, $80
	ret nc				; start disappearing block 128 frames before the end
	and a, $20 - 1		; every 32 frames
	ret nz
	ld hl, $8DD0		; all kinds of tiles, even tho only 3 are visible
	ld bc, 34 * $10		; 34 from the start, but it skips ahead somewhere
	ldh a, [$FFFC]		; starts at BF 10111111
	ld d, a
.maskTileRow
	WAIT_FOR_HBLANK
	ld a, [hl]
	and d
	ld e, a
	WAIT_FOR_HBLANK
	ld [hl], e
	inc hl
	ld a, h
	cp a, $8F
	jr nz, .dontSkipAhead
	ld hl, $9690
.dontSkipAhead
	rrc d				; rotate the bitmask to the right
	dec bc
	ld a, c
	or b
	jr nz, .maskTileRow
	ldh a, [$FFFC]
	sla a				; shift a new zero bit in the mask
	jr z, .allTilesGone
	swap a
	ldh [$FFFC], a
	ld a, $3F
	ldh [hTimer], a
	ret

.allTilesGone
	xor a
	ld [wScrollY], a		; stop screen shake
	ld [wLevelEndCounter], a
	inc a
	ldh [hUnderground], a
	ld hl, hGameState
	inc [hl]			; 27 → 28
	ret

;@ --------------------------------------------------------------------
;@ GameState_29   [00:1116]   41 lines
;@   writes    : hScrollX, hTextCursorHi, hTextCursorLo, hUnderground, rIF, rLCDC, wScrollY
;@   calls     : Call_1736, EraseTileMap, GameState_21_PrepareFakeDaisy, UpdateLevelColumns
;@ --------------------------------------------------------------------
GameState_29:: ; 1116
	di
	xor a
	ldh [rLCDC], a
	ldh [hUnderground], a
	ld hl, $9C00
	ld bc, $0100
	call EraseTileMap
	call UpdateLevelColumns.drawLevel
	call GameState_21_PrepareFakeDaisy.prepareMarioAndDaisy
	ld hl, wMarioX		; mario X position
	ld [hl], $38
	inc l
	ld [hl], $10		; Super Mario
	ld hl, $C212
	ld [hl], $78		; Daisy X position
	xor a
	ldh [rIF], a
	ldh [hScrollX], a
	ld [wScrollY], a
	ldh [$FFFB], a
	ld hl, wOAMBuffer
	ld b, 3*4			; 3 projectiles?
.loop
	ldi [hl], a
	dec b
	jr nz, .loop
	call Call_1736
	ld a, $98
	ldh [hTextCursorHi], a
	ld a, $A5
	ldh [hTextCursorLo], a
	ld a, $0F
	ld [$DFE8], a
	ld a, (LCDCF_ON | LCDCF_WIN9C00 | LCDCF_OBJON | LCDCF_BGON); $C3
	ldh [rLCDC], a
	ei
	ld hl, hGameState
	inc [hl]			; 29 → 2A
	ret

;@ --------------------------------------------------------------------
;@ GameState_2A_DaisySpeaking   [00:1165]   21 lines
;@   writes    : hTextCursorHi, hTextCursorLo
;@   calls     : PrintVictoryMessage
;@ --------------------------------------------------------------------
GameState_2A_DaisySpeaking:: ; 1165
	ld hl, .text_1183
	call PrintVictoryMessage
	cp a, $FF
	ret nz
	xor a
	ldh [$FFFB], a
	ld a, $99
	ldh [hTextCursorHi], a
	ld a, $02
	ldh [hTextCursorLo], a
	ld a, $23
	ld [$C213], a		; animation index?
	ld hl, hGameState
	inc [hl]			; 2A → 2B
	ret

.text_1183
	db "oh! daisy", $FE, $1B, "daisy", $FF

; Daisy running towards Mario
;@ --------------------------------------------------------------------
;@ GameState_2B_DaisyApproaching   [00:1194]   31 lines
;@   reads     : hFrameCounter
;@   calls     : Call_1736, PrintVictoryMessage
;@ --------------------------------------------------------------------
GameState_2B_DaisyApproaching:: ; 1194
	ld hl, .text_11BF
	call PrintVictoryMessage
	ldh a, [hFrameCounter]
	and a, $03
	ret nz
	ld hl, $C212		; daisy X pos
	ld a, [hl]
	cp a, $44
	jr c, .out
	dec [hl]
	call Call_1736
	ret

.out
	ld hl, hGameState
	inc [hl]
	ld hl, wOAMBuffer +  4 * $C
	ld [hl], $70		; Y pos
	inc l
	ld [hl], $3A		; X pos
	inc l
	ld [hl], "♥"		; sprite
	inc l
	ld [hl], 0
	ret

.text_11BF
	db "thank you mario.", $FF

; kiss ^_^
;@ --------------------------------------------------------------------
;@ GameState_2C_DaisyKiss   [00:11D0]   49 lines
;@   reads     : hFrameCounter
;@   writes    : hTextCursorHi, hTextCursorLo
;@ --------------------------------------------------------------------
GameState_2C_DaisyKiss:: ; 11D0
	ldh a, [hFrameCounter]
	and a, %1
	ret nz
	ld hl, wOAMBuffer + 4 * $C ; todo object macro?
	dec [hl]			; Y pos
	ldi a, [hl]
	cp a, $20			; if heart gets high
	jr c, .clearMessageAndOut
	ldh a, [$FFFB]
	and a
	ld a, [hl]
	jr nz, .goRight
	dec [hl]			; heart goes left
	cp a, $30
	ret nc
.out
	ldh [$FFFB], a
	ret

.goRight
	inc [hl]
	cp a, $50
	ret c
	xor a
	jr .out

.clearMessageAndOut
	ld [hl], $F0
	ld b, $6D
	ld hl, $98A5
.loop
	WAIT_FOR_HBLANK
	WAIT_FOR_HBLANK
	ld [hl], " "
	inc hl
	dec b
	jr nz, .loop
	xor a
	ldh [$FFFB], a
	ld a, $99
	ldh [hTextCursorHi], a
	ld a, $00
	ldh [hTextCursorLo], a
	ld hl, hGameState
	inc [hl]			; 2C → 2D
	ret

; your quest is over
;@ --------------------------------------------------------------------
;@ GameState_2D_QuestOver   [00:121B]   26 lines
;@   calls     : PrintVictoryMessage
;@ --------------------------------------------------------------------
GameState_2D_QuestOver:: ; 121B
	ld hl, .text_123F
	call PrintVictoryMessage
	cp a, $FF
	ret nz
	ld hl, $C213	; daisy run
	ld [hl], $24
	inc l
	inc l
	ld [hl], $00	; facing right?
	ld hl, $C241	; spaceship entity
	ld [hl], $7E	; Y pos
	inc l
	inc l
	ld [hl], $28	; spaceship
	inc l
	inc l
	ld [hl], $00	; facing right
	ld hl, hGameState
	inc [hl]		; 2D → 2E
	ret

.text_123F
	db "-your quest is over-", $FF

; Mario & Daisy walking
;@ --------------------------------------------------------------------
;@ GameState_2E_MarioAndDaisyWalking   [00:1254]   49 lines
;@   reads     : hColumnIndex, hFrameCounter, hScreenIndex
;@   writes    : hTimer, wMarioVisible
;@   calls     : GameState_20_WalkOffButton, UpdateScrollProgress
;@ --------------------------------------------------------------------
GameState_2E_MarioAndDaisyWalking::
	ldh a, [hFrameCounter]
	and a, $03
	jr nz, .skip
	ld hl, $C213		; daisy animation
	ld a, [hl]
	xor a, $01			; two daisy walking objects
	ld [hl], a
.skip
	ld hl, $C240		; spaceship
	ld a, [hl]
	and a
	jr nz, .walkMarioDaisy
	inc l				; move spaceship
	inc l
	dec [hl]			; X pos
	ld a, [hl]
	cp a, $50
	jr nz, .checkIfBothAreInSpaceship	; todo name
	ld a, $80			; Mario "enters" the spaceship (becomes invisible)
	ld [wMarioVisible], a
	jr .walkMarioDaisy

.checkIfBothAreInSpaceship
	cp a, $40
	jr nz, .walkMarioDaisy
	ld a, $80
	ld [$C210], a		; Daisy "enters" the spaceship
	ld a, $40
	ldh [hTimer], a		; 40 frames, 2/3 second
	ld hl, hGameState
	inc [hl]			; 2E → 2F
.walkMarioDaisy
	call GameState_20_WalkOffButton.walkRight
	call UpdateScrollProgress		; level rendering
	ldh a, [hScreenIndex]
	cp a, $03
	ret nz
	ldh a, [hColumnIndex]
	and a
	ret nz
	ld hl, $C240		; spaceship
	ld [hl], $00		; make visible?
	inc l
	inc l
	ld [hl], $C0		; X pos
	ret

; prepare for liftoff
;@ --------------------------------------------------------------------
;@ GameState_2F_PrepareLiftoff   [00:12A1]   21 lines
;@   reads     : hTimer
;@ --------------------------------------------------------------------
GameState_2F_PrepareLiftoff:: ; 12A1
	ldh a, [hTimer]
	and a
	ret nz
	ld hl, $C240		; spaceship
	ld de, wMarioVisible		; mario
	ld b, $06
.loop
	ldi a, [hl]
	ld [de], a
	inc e
	dec b
	jr nz, .loop		; todo macro?
	ld hl, wMarioAnimationIndex		; animation
	ld [hl], $26
	ld hl, $C241		; previous spaceship
	ld [hl], $F0		; out of sight, out of mind
	ld hl, hGameState
	inc [hl]			; 2F → 30
	ret

;@ --------------------------------------------------------------------
;@ GameState_30_AirplaneTakingOff   [00:12C2]   33 lines
;@   called by : GameState_31_AirplaneMovingForward
;@   reads     : hFrameCounter
;@   calls     : Call_1736
;@ --------------------------------------------------------------------
GameState_30_AirplaneTakingOff:: ; 12C2
	call Call_1736		; animate "Mario" (spaceship)
	ldh a, [hFrameCounter]
	ld b, a
	and a, 1
	ret nz
	ld hl, $C240
	ld [hl], $FF		; make invisible. Why not do this before?
	ld hl, wMarioY		; Y pos
	dec [hl]			; take off
	ldi a, [hl]
	cp a, $58
	jr z, .cruisingAltitude
	call .switchSpaceshipAnimation
	ret

.cruisingAltitude
	ld hl, hGameState
	inc [hl]				; 30 → 31
	ld a, $04
	ldh [$FFFB], a
	ret

.switchSpaceshipAnimation
	ldh a, [hFrameCounter]
	and a, 3
	ret nz
	inc l
	ld a, [hl]				; C203, animation
	xor a, 1				; switch exhaust flame
	ld [hl], a
	ret

;@ --------------------------------------------------------------------
;@ GameState_31_AirplaneMovingForward   [00:12F1]   91 lines
;@   called by : AnimateSpaceshipAndClouds, GameState_32_AirplaneLeavingHangar
;@   reads     : hNextColumnToLoad, hScrollX, wCurrentSong
;@   writes    : hColumnLoadRequest, hNextColumnToLoad, hScrollX, rLYC
;@   calls     : Call_1736, GameState_30_AirplaneTakingOff, UpdateScrollProgress
;@ --------------------------------------------------------------------
GameState_31_AirplaneMovingForward:: ; 12F1
	call .animateSpaceship
	call UpdateScrollProgress		; loads level
	ldh a, [hScrollX]
	inc a
	call z, .skip
	inc a
	call z, .skip
	ldh [hScrollX], a
	ld a, [wCurrentSong]		; wait until the song is over?
	and a
	ret nz
	ld a, $11
	ld [$DFE8], a
	ret

.animateSpaceship
	ld hl, wMarioX		; X pos
	call GameState_30_AirplaneTakingOff.switchSpaceshipAnimation
	call Call_1736		; animate entities
	ret

.skip
	push af
	ldh a, [$FFFB]
	dec a				; FFFB starts at 4. So traverse 4 blocks
	ldh [$FFFB], a
	jr nz, .out
	ldh [rLYC], a		; A is 0 here. Removes HUD?
	ld a, $21
	ldh [$FFFB], a
	ld a, $54
	ldh [hNextColumnToLoad], a
	call .clearColumn
	ld hl, $C210
	ld de, .row0
	call .replaceEntity
	ld hl, $C220		; cloud?
	ld de, .row1
	call .replaceEntity
	ld hl, $C230
	ld de, .row2
	call .replaceEntity
	ld hl, hGameState
	inc [hl]
.out
	pop af
	ret

.clearColumn
	ld hl, $C0B0
	ld b, $10
	ld a, $2C
.clearLoop
	ldi [hl], a
	dec b
	jr nz, .clearLoop
	ld a , 1
	ldh [hColumnLoadRequest], a
	ld b, $02
	ldh a, [hNextColumnToLoad]		; first not yet loaded column
	sub a, $20
	ld l, a
	ld h, $98
.clearLoop2
	WAIT_FOR_HBLANK
	ld [hl], " "
	ld a, l
	sub a, $20
	ld l, a
	dec b
	jr nz, .clearLoop2
	ret

.replaceEntity
	ld b, $05
.loop
	ld a, [de]
	ldi [hl], a
	inc de
	dec b
	jr nz, .loop
	ret

.row0
	db $00, $30, $D0, $29, $80
.row1
	db $80, $70, $10, $2A, $80
.row2
	db $80, $40, $70, $29, $80

;@ --------------------------------------------------------------------
;@ GameState_32_AirplaneLeavingHangar   [00:138E]   34 lines
;@   reads     : hScrollColumnPhase, hScrollX
;@   writes    : hScrollColumnPhase, hScrollX, hTextCursorHi, hTextCursorLo, hTimer, rLYC
;@   calls     : AnimateSpaceshipAndClouds, GameState_31_AirplaneMovingForward
;@ --------------------------------------------------------------------
GameState_32_AirplaneLeavingHangar:: ; 138E
	call AnimateSpaceshipAndClouds
	ldh a, [hScrollX]
	inc a
	inc a
	ldh [hScrollX], a
	and a, $08
	ld b, a
	ldh a, [hScrollColumnPhase]	; switches between 0 and 8, depending on column loaded
	cp b
	ret nz
	xor a, $08
	ldh [hScrollColumnPhase], a
	call GameState_31_AirplaneMovingForward.clearColumn
	ldh a, [$FFFB]
	dec a
	ldh [$FFFB], a
	ret nz
	xor a
	ldh [hScrollX], a
	ld a, $60
	ldh [rLYC], a
	ld hl, Text_1557
	ld a, h
	ldh [hTextCursorHi], a
	ld a, l
	ldh [hTextCursorLo], a
	ld a, $F0
	ldh [hTimer], a
	ld hl, hGameState
	inc [hl]		; 32 → 33
	ret


;@ --------------------------------------------------------------------
;@ GameState_33   [00:13C4]   89 lines
;@   called by : AnimateSpaceshipAndClouds
;@   reads     : hTextCursorHi, hTextCursorLo, hTimer, rDIV
;@   writes    : hTextCursorHi, hTextCursorLo
;@   calls     : AnimateSpaceshipAndClouds
;@ --------------------------------------------------------------------
GameState_33:: ; 13C4
.animateClouds
	ld hl, $C212	; clouds X pos
	ld de, $0010
	ld b, $03
.floatCloud
	dec [hl]		; float to the left
	ld a, [hl]
	cp a, $01
	jr nz, .checkCloudForReset
	ld [hl], $FE
	jr .nextCloud

.checkCloudForReset
	cp a, $E0
	jr nz, .nextCloud	; reset if cloud hits E0 from the right
	push hl
	ldh a, [rDIV]	; divider register, pseudorandom
	dec l			; Y position
	add [hl]
	and a, $7F		; make Y pos <= 7F
	cp a, $68		; clear between 3F and 68 (spaceship, the end)
	jr nc, .resetCloud
	and a, $3F
.resetCloud
	ldd [hl], a
	ld [hl], 0
	pop hl
.nextCloud
	add hl, de
	dec b
	jr nz, .floatCloud
	ret

.entryPoint:: ; 13F0
	call AnimateSpaceshipAndClouds
	ldh a, [hTimer]
	and a
	ret nz
	ldh a, [hTextCursorHi]
	ld h, a
	ldh a, [hTextCursorLo]
	ld l, a
	ld de, $9A42	; start of first line. Below the stage, scrolled in later
.printLine
	ld a, [hl]
	cp a, $FE		; end of line
	jr z, .eraseTillEndOfLine
	inc hl
	ld b, a
.printCharacter
	WAIT_FOR_HBLANK
	WAIT_FOR_HBLANK
	ld a, b
	ld [de], a
	inc de
	ld a, e
	cp a, $54
	jr z, .nextLine
	cp a, $93
	jr z, .startCreditsScroll
	jr .printLine

.eraseTillEndOfLine
	ld b, " "
	jr .printCharacter

.nextLine
	ld de, $9A87
	inc hl
	jr .printLine

.startCreditsScroll
	inc hl
	ld a, [hl]
	cp a, $FF
	jr nz, .nextState
	ld a, $FF
	ld [$C0DE], a
.nextState
	ld a, h
	ldh [hTextCursorHi], a
	ld a, l
	ldh [hTextCursorLo], a
	ld hl, hGameState
	inc [hl]			; 33 → 34
	ret

; credits entering
;@ --------------------------------------------------------------------
;@ GameState_34_CreditsEnter   [00:1441]   17 lines
;@   reads     : hFrameCounter
;@   writes    : hTimer
;@   calls     : AnimateSpaceshipAndClouds
;@ --------------------------------------------------------------------
GameState_34_CreditsEnter::
	call AnimateSpaceshipAndClouds
	ldh a, [hFrameCounter]
	and a, 3
	ret nz
	ld hl, wScrollY
	inc [hl]
	ld a, [hl]
	cp a, $20			; scroll $20 pxs up
	ret nz
	ld hl, hGameState
	inc [hl]			; 34 → 35
	ld a, $50
	ldh [hTimer], a
	ret


;@ --------------------------------------------------------------------
;@ GameState_35_CreditsStandStill   [00:145A]   10 lines
;@   reads     : hTimer
;@   calls     : AnimateSpaceshipAndClouds
;@ --------------------------------------------------------------------
GameState_35_CreditsStandStill:: ; 145A
	call AnimateSpaceshipAndClouds
	ldh a, [hTimer]
	and a
	ret nz
	ld hl, hGameState
	inc [hl]			; 35 → 36
	ret

; scroll credits up, out of sight
;@ --------------------------------------------------------------------
;@ GameState_36_CreditsScrollOut   [00:1466]   22 lines
;@   reads     : hFrameCounter
;@   writes    : hGameState, wScrollY
;@   calls     : AnimateSpaceshipAndClouds
;@ --------------------------------------------------------------------
GameState_36_CreditsScrollOut:: ; 1466
	call AnimateSpaceshipAndClouds
	ldh a, [hFrameCounter]
	and a, 3
	ret nz
	ld hl, wScrollY
	inc [hl]
	ld a, [hl]
	cp a, $50
	ret nz
	xor a
	ld [wScrollY], a
	ld a, [$C0DE]
	cp a, $FF
	ld a, $33
	jr nz, .out
	ld a, $37
.out
	ldh [hGameState], a
	ret

; spaceship flies off, prepare "THE END"
;@ --------------------------------------------------------------------
;@ GameState_37_SpaceshipDeparts   [00:1488]   47 lines
;@   reads     : hWinCount
;@   writes    : hTimer, hWinCount, wWinCount
;@   calls     : AnimateSpaceshipAndClouds, Call_1736
;@ --------------------------------------------------------------------
GameState_37_SpaceshipDeparts::
	call AnimateSpaceshipAndClouds
	ld hl, wMarioX		; X position
	inc [hl]
	ld a, [hl]
	cp a, $D0			; out of sight??
	ret nz
	dec l
	ld [hl], $F0
	push hl
	call Call_1736
	pop hl
	dec l
	ld [hl], $FF		; make invisible?
	ld hl, wOAMBuffer + 4 * $1C	; object 1C?
	ld de, .row0
	ld b, $18
.loop1
	ld a, [de]
	ldi [hl], a
	inc de
	dec b
	jr nz, .loop1
	ld b, $18
	xor a
.loop2
	ldi [hl], a
	dec b
	jr nz, .loop2
	ld a, $90
	ldh [hTimer], a
	ldh a, [hWinCount]
	inc a
	ldh [hWinCount], a
	ld [wWinCount], a
	ld hl, hGameState
	inc [hl]			; 37 → 38
	ret

.row0
	db $4E, $CC, $52, 00 ; T
	db $4E, $D4, $53, 00 ; H
	db $4E, $DC, $54, 00 ; E
	db $4E, $EC, $54, 00 ; E
	db $4E, $F4, $55, 00 ; N
	db $4E, $FC, $56, 00 ; D

;@ --------------------------------------------------------------------
;@ GameState_38_TheEndLettersFlying   [00:14DC]   67 lines
;@   called by : GameState_3A_GameOver
;@   reads     : hJoyPressed, hTimer
;@   writes    : hActiveRomBank, hGameState, hLevelIndex, hSuperStatus, hSuperballMario, hWorldAndLevel, rIE, rROMB0
;@   calls     : AnimateSpaceshipAndClouds, InitSound
;@ --------------------------------------------------------------------
GameState_38_TheEndLettersFlying::
	call AnimateSpaceshipAndClouds
	ldh a, [hTimer]
	and a
	ret nz
	ld hl, $C071		; letter object X position
	ld a, [hl]
	cp a, $3C
	jr z, .nextLetter
.animateLetter
	dec [hl]
	dec [hl]
	dec [hl]
	ret

.nextLetter
	ld hl, $C075
	ld a, [hl]
	cp a, $44
	jr nz, .animateLetter
	ld hl, $C079
	ld a, [hl]
	cp a, $4C
	jr nz, .animateLetter
	ld hl, $C07D
	ld a, [hl]
	cp a, $5C
	jr nz, .animateLetter
	ld hl, $C081
	ld a, [hl]
	cp a, $64
	jr nz, .animateLetter
	ld hl, $C085
	ld a, [hl]
	cp a, $6C
	jr nz, .animateLetter
	call .checkForButtonPress
	xor a
	ldh [hLevelIndex], a
	ldh [hSuperStatus], a
	ldh [hSuperballMario], a
	ld [wNumContinues], a
	ld a, $11
	ldh [hWorldAndLevel], a
	ret

.checkForButtonPress
	ldh a, [hJoyPressed]
	and a
	ret z
	call InitSound
.resetToMenu
	ld a, $02
	ldh [hActiveRomBank], a
	ld [rROMB0], a
	ld [wDemoSelect], a
	ld [$C0A4], a
	xor a
	ld [wGameTimer], a
	ld [wGameOverWindowEnabled], a
	ld [wGameOverTimerExpired], a
	ld a, $03
	ldh [rIE], a
	ld a, $0E
	ldh [hGameState], a	; init menu
	ret


