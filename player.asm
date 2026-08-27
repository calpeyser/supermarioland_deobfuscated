; Mario: hitbox, physics, animation, tile and enemy collision, power-ups
; Extracted from bank0.asm by tools/split.py. Addresses are pinned,
; so this file's contents sit at exactly the same ROM offsets as before.

INCLUDE "constants.asm"
INCLUDE "charmap.asm"
INCLUDE "inc/hardware.inc"
INCLUDE "macros.asm"
INCLUDE "enemies.asm"

SECTION "player 084E", ROM0[$084E]

; called from main gameplay subroutine
; player "entity" (enemy, powerup) collision
;@ --------------------------------------------------------------------
;@ CheckMarioEnemyCollision   [00:084E]   254 lines
;@   called by : GameState_00_Gameplay, GameState_0D_AutoScrollLevel
;@   reads     : hFloatyControl, hGameState, hStompChain, hStompChainTimer, hSuperStatus, wInvincibilityTimer, wMarioAnimationIndex, wMarioX
;@   writes    : hFloatyControl, hFloatyX, hFloatyY, hHitboxBottom, hHitboxLeft, hHitboxRight, hHitboxTop, hStompChain
;@   calls     : Call_2A01, Call_2A44, Call_2B06, Call_A10, ComputeHitbox, InjureMario, KillMario
;@ --------------------------------------------------------------------
CheckMarioEnemyCollision:: ; 84E
	ldh a, [hStompChainTimer]
	and a
	jr z, .skip			; don't decrement below zero
	dec a
	ldh [hStompChainTimer], a
.skip
	ld de, -$10
	ld b, $0A
	ld hl, $D190
.enemyLoop
	ld a, [hl]
	cp a, $FF
	jr nz, .skip2
.nextEnemy
	add hl, de
	dec b
	jr nz, .enemyLoop	; loop over all enemies/entities
	ret

.skip2
	ldh [$FFFB], a
	ld a, l
	ldh [$FFFC], a
	push bc
	push hl
	ld bc, $000A
	add hl, bc
	ld c, [hl]			; D1xA mortal + width + height
	inc l
	inc l
	ld a, [hl]			; D1xC health?
	ldh [$FF9B], a
	ld a, [wMarioY]		; Mario Y pos
	ld b, a
	ldh a, [hSuperStatus]
	cp a, $02
	jr nz, .skip3
	ld a, [wMarioAnimationIndex]
	cp a, $18
	jr z, .skip3
	ld a, -$2
	add b
	ld b, a
.skip3
	ld a, b
	ldh [hHitboxTop], a		; bounding box top?
	ld a, [wMarioY]
	add a, $6
	ldh [hHitboxBottom], a		; bounding box bottom?
	ld a, [wMarioX]		; Mario X pos
	ld b, a
	sub a, $03
	ldh [hHitboxLeft], a		; bounding box left?
	ld a, $02
	add b
	ldh [hHitboxRight], a		; BB right
	pop hl
	push hl
	call ComputeHitbox		; hitbox detection
	and a
	jp z, .noCollision
	ldh a, [$FFFC]
	cp a, $90			; powerups only appear in the last slot
	jp z, .powerUpCollision
	ldh a, [$FFFB]		; gets overwritten immediately. Bug?
	ldh a, [hGameState]
	cp a, $0D			; autoscroll
	jr z, .skip4
	ld a, [wInvincibilityTimer]
	and a
	jr z, .skip5
.skip4
	dec l
	jp .skip6

.skip5
	ld a, [wMarioX]		; mario x pos
	add a, $06
	ld c, [hl]
	dec l
	sub c
	jr c, .skip6
	ld a, [wMarioX]
	sub a, $06
	sub b
	jr nc, .skip6
	ld b, [hl]
	dec b
	dec b
	dec b
	ld a, [wMarioY]
	sub b
	jr nc, .skip6
	dec l
	dec l
	push hl
	ld bc, $000A
	add hl, bc
	bit 7, [hl]			; 7 bit set, enemy can't die
	pop hl
	jr nz, .out
	call Call_A10		; hit enemy
	call Call_2A01
	and a
	jr z, .out
	ld hl, wMarioOnGround		; 1 if on ground
	ld [hl], 0
	dec l
	dec l
	ld [hl], $D			; C208
	dec l
	ld [hl], 1			; C207 jump status
	ld hl, wMarioAnimationIndex		; animation
	ld a, [hl]
	and a, $F0
	or a, $04			; flying
	ld [hl], a
.enemyKilled
	ld a, $03
	ld [$DFE0], a		; stomp sound
	ld a, [wMarioX]		; X pos
	add a, -$4
	ldh [hFloatyX], a	; todo comment
	ld a, [wMarioY]
	sub a, $10
	ldh [hFloatyY], a
	ldh a, [$FF9E]
	ldh [hFloatyControl], a
	ldh a, [hStompChainTimer]
	and a
	jr z, .resetStompChain
	ldh a, [hStompChain]
	cp a, 3				; maximum chain of 3
	jr z, .calculateScoreReward
	inc a
	ldh [hStompChain], a
.calculateScoreReward
	ld b, a
	ldh a, [hFloatyControl]
	cp a, $50			; Floaties above $50 are not score but coins and 1UPs
	jr z, .resetStompChain
.loop					; Shift BCD encoded score reward. Works out to a 
	sla a				; multiplication by 2, except for a weird jump
	dec b				; from 800 → 1000
	jr nz, .loop
	ldh [hFloatyControl], a
.resetStompChainTimer	; 50 frames? 5/6ths of a second? No wonder chaining
	ld a, $32			; is so hard in this game
	ldh [hStompChainTimer], a
	jr .out

.resetStompChain
	xor a
	ldh [hStompChain], a
	jr .resetStompChainTimer

.skip6	; enemy side hit?
	dec l
	dec l
	ld a, [wInvincibilityTimer]
	and a
	jr nz, .skip7			; try to kill enemy?
	ldh a, [hSuperStatus]
	cp a, $03
	jr nc, .out				; if superstatus is 4 (or more?), Mario has some
	call Call_2A44			; i-frames
	and a
	jr z, .out
	ldh a, [hSuperStatus]
	and a
	jr nz, .injureAndOut
	call KillMario
.out
	pop hl
	pop bc
	ret

.noCollision
	pop hl
	pop bc
	jp .nextEnemy

.injureAndOut
	call InjureMario
	jr .out

.skip7
	call Call_2B06			; like 2AXX calls, a lookup into tables
	and a					; between $3000 and $4000
	jr z, .out
	jr .enemyKilled

.powerUpCollision
	ldh a, [$FFFB]
	cp a, $29				; mushroom
	jr z, .pickupMushroom
	cp a, $34				; Star
	jr z, .pickupStar
	cp a, $2B				; 1 UP
	jr z, .pickup1UP
	cp a, $2E				; Flower
	jr nz, .out
.pickupFlower
	ldh a, [hSuperStatus]
	cp a, $02				; if we lost our Super before picking up
	jr nz, .becomeSuper		; the flower, it functions like a mushroom
	ldh [hSuperballMario], a
.playPowerUpSound
	ld a, 4
	ld [$DFE0], a
.spawn1000ScoreFloaty
	ld a, $10
	ldh [hFloatyControl], a
.positionFloaty
	ld a, [wMarioX]
	add a, -$4
	ldh [hFloatyX], a		; todo comment
	ld a, [wMarioY]
	sub a, $10
	ldh [hFloatyY], a			; Y position of floaty number
	dec l
	dec l
	dec l
	ld [hl], $FF
	jr .out

.pickupMushroom
	ldh a, [hSuperStatus]
	cp a, $02
	jr z, .spawn1000ScoreFloaty
.becomeSuper
	ld a, $01
	ldh [hSuperStatus], a
	ld a, $50
	ldh [hTimer], a
	jr .playPowerUpSound

.pickupStar
	ld a, $F8
	ld [wInvincibilityTimer], a
	ld a, $0C
	ld [$DFE8], a				; Galop Infernal
	jr .spawn1000ScoreFloaty

.pickup1UP
	ld a, $FF
	ldh [hFloatyControl], a		; 1UP floaty
	ld a, $08
	ld [$DFE0], a				; life up
	ld a, 1
	ld [wLivesEarnedLost], a
	jr .positionFloaty

;@ --------------------------------------------------------------------
;@ InjureMario   [00:09E0]   11 lines
;@   called by : CheckMarioEnemyCollision, CheckMarioTileCollision
;@   writes    : hSuperStatus, hSuperballMario, hTimer
;@ --------------------------------------------------------------------
InjureMario:: ; 9E0
	ld a, 3
	ldh [hSuperStatus], a
	xor a
	ldh [hSuperballMario], a
	ld a, $50
	ldh [hTimer], a
	ld a, $06
	ld [$DFE0], a			; injury music
	ret

;@ --------------------------------------------------------------------
;@ KillMario   [00:09F1]   18 lines
;@   called by : CheckMarioEnemyCollision, CheckMarioTileCollision, Init
;@   reads     : wMarioY
;@   writes    : hGameState, hSuperballMario, rTMA, wDeathY, wMarioVisible
;@ --------------------------------------------------------------------
KillMario:: ; 9F1
	ld a, [$D007]
	and a
	ret nz
	ld a, GAMESTATE_PREPARE_DEATH				; pre dying
	ldh [hGameState], a
	xor a
	ldh [hSuperballMario], a; superball capability
	ldh [rTMA], a
	ld a, $02
	ld [$DFE8], a			; sound effect
	ld a, $80
	ld [wMarioVisible], a
	ld a, [wMarioY]			; Mario Y pos
	ld [wDeathY], a			; death Y pos?
	ret

; called when a hit is detected on an enemy?
Call_A10::
	push hl
	push de
	ldh a, [$FF9B]			; enemy... health?
	and a, %11000000
	swap a
	srl a
	srl a				; put two upper bits in lowest position
	ld e, a
	ld d, $00
	ld hl, .row0
	add hl, de
	ld a, [hl]
	ldh [$FF9E], a
	pop de
	pop hl
	ret

.row0
; corresponding top nibbles
;      0-3  4-7  8-B  C-F
	db $01, $04, $08, $50

; called when Mario hits a bouncing block, to hit the enemy above it
;@ --------------------------------------------------------------------
;@ SpawnFloatyAtMario   [00:0A2D]   92 lines
;@   called by : GameState_00_Gameplay
;@   reads     : wMarioX, wMarioY
;@   writes    : hFloatyControl, hFloatyX, hFloatyY
;@   calls     : Call_2A23, Call_A10
;@ --------------------------------------------------------------------
SpawnFloatyAtMario:: ; A2D
	ldh a, [$FFEE]
	and a
	ret z
	cp a, $C0
	ret z				; return if no collision, and if not with a coin
	ld de, $0010
	ld b, $0A
	ld hl, $D100		; enemies. and hittable objects
.loop
	ld a, [hl]
	cp a, $FF			; ff means no object
	jr nz, .checkEnemyHit
.nextEnemy
	add hl, de
	dec b
	jr nz, .loop
	ret

.checkEnemyHit
	push bc
	push hl
	ld bc, $000A
	add hl, bc			; D1xA, lower 7 bits is width + height, 7th bit is ?
	bit 7, [hl]
	jr nz, .noHit		; bit 7 is immortality?
	ld c, [hl]
	inc l
	inc l				; D1xC, health?
	ld a, [hl]
	ldh [$FF9B], a		; used in Call_A10 at least
	pop hl
	push hl
	inc l
	inc l
	ld b, [hl]			; D1x2 Y pos
	ld a, [wMarioY]		; player Y pos
	sub b				; Y coordinates are inverted
	jr c, .noHit		; enemy needs to be above player
	ld b, a
	ld a, $14
	sub b
	jr c, .noHit		; but not too much above the player either
	cp a, $07			; A contains $14 - (playerY - enemyY) and has to be < 7
	jr nc, .noHit		; meaning playerY - enemyY has to be at least $D
	inc l
	ld a, c				; c contains the width + height
	and a, $70			; just width
	swap a
	ld c, a
	ld a, [hl]			; D1x3 X pos, points to left bound of leftmost tile
.loopR
	add a, $08			; one tile per width
	dec c
	jr nz, .loopR
	ld c, a				; C contains right bound of enemy
	ld b, [hl]			; B contains left bound of enemy
	ld a, [wMarioX]		; Mario X pos
	sub a, $06			; Mario is 12 pixels wide
	sub c
	jr nc, .noHit		; left bound has to be smaller than right bound of enemy
	ld a, [wMarioX]
	add a, $06
	sub b
	jr c, .noHit
	dec l
	dec l
	dec l				; D1x0
	push de
	call Call_A10
	call Call_2A23		; prepares death animation
	pop de
	and a
	jr z, .noHit
	ld a, [wMarioX]		; X pos
	add a, $FC			; or -4
	ldh [hFloatyX], a
	ld a, [wMarioY]		; Y pos
	sub a, $10
	ldh [hFloatyY], a
	ldh a, [$FF9E]
	ldh [hFloatyControl], a
.noHit
	pop hl
	pop bc
	jp .nextEnemy

; TODO clean up these comments
; collision detection between enemy and bounding box defined by
; T B L R FFA0 FFA1 FFA2 FF8F (-_-)
; HL contains D1x0 of enemy under consideration?
; C is some sort is width? XY in both nibbles?
;@ --------------------------------------------------------------------
;@ ComputeHitbox   [00:0AAF]   51 lines
;@   called by : Call_200A, CheckMarioEnemyCollision
;@   reads     : hHitboxBottom, hHitboxLeft, hHitboxRight, hHitboxTop
;@ --------------------------------------------------------------------
ComputeHitbox:: ; AAF
	inc l
	inc l				; D1x2 Y pos
	ld a, [hl]
	add a, $08			; Y pos is top left of bottom left object tile
	ld b, a				; so add 8 to get coordinate of bottom of enemy
	ldh a, [hHitboxTop]		; top of bounding box?
	sub b				; top - bottom
	jr nc, .noCollision ; NC if bottom < top (don't forget Y coords grow downwards)
	ld a, c
	and a, $0F			; lower nibble, height in tiles?
	ld b, a
	ld a, [hl]			; still Y pos
.loopHeight
	dec b
	jr z, .checkBottomOfBB
	sub a, $08			; subtract (c & 0F) tiles
	jr .loopHeight

.checkBottomOfBB
	ld b, a				; B contains top of enemy
	ldh a, [hHitboxBottom]		; bottom Y
	sub b
	jr c, .noCollision	; C if top > bottom (Y coords grow downwards)
; X detection
	inc l				; D1x3 X pos
	ldh a, [hHitboxRight]		; right BB x
	ld b, [hl]			; left X of enemy
	sub b
	jr c, .noCollision	; C if left X of enemy > right BB X
	ld a, c
	and a, $70			; upper nibble, but only 3 bits
	swap a
	ld b, a
	ld a, [hl]			; still X pos
.loopWidth
	add a, $08			; add width tiles to get the right bound of the enemy
	dec b
	jr nz, .loopWidth
	ld b, a
	ldh a, [hHitboxLeft]		; left BB x
	sub b
	jr nc, .noCollision	; NC if left BB x > right X of enemy
	ld a, 1				; collision detected
	ret

.noCollision
	xor a
	ret

; has to do with Mario riding on platforms and blocks
;@ --------------------------------------------------------------------
;@ UpdateMarioPhysics   [00:0AEA]   116 lines
;@   called by : GameState_00_Gameplay
;@   reads     : hHitboxTop, wMarioJumpStatus, wMarioX, wMarioY
;@   writes    : hHitboxTop, wMarioY
;@   calls     : Call_2A01
;@ --------------------------------------------------------------------
UpdateMarioPhysics:: ; AEA
	ld a, [wMarioJumpStatus]		; jump status
	cp a, 1
	ret z
	ld de, $0010
	ld b, $0A
	ld hl, $D100		; enemies again
.loop
	ld a, [hl]
	cp a, $FF
	jr nz, .checkEnemy
.nextEnemy
	add hl, de
	dec b
	jr nz, .loop
	ret

.checkEnemy
	push bc
	push hl
	ld bc, $000A
	add hl, bc
	bit 7, [hl]			; mortality?
	jp z, .notOnTop		; only dealing with immortal enemies (platforms, blocks?)
	ld a, [hl]			; mortal bit + width + height
	and a, $0F			; just height
	ldh [hHitboxTop], a		; hitbox? temporary storage?
	ld bc, -$8
	add hl, bc			; D1x2 Y pos
	ldh a, [hHitboxTop]		; ...why? do we jump into this?
	ld b, a
	ld a, [hl]			; Y pos
.loopT
	dec b
	jr z, .break		; decrement before subtracting tile height, as the Y pos
	sub a, $08			; already corresponds to the top bound
	jr .loopT

.break
	ld c, a				; enemy top bound
	ldh [hHitboxTop], a
	ld a, [wMarioY]		; player y pos
	add a, $06			; todo is mario 6 units tall or so?
	ld b, a				; mario bottom bound
	ld a, c
	sub b
	cp a, $07			; mario has to be less than 8 pixels above the enemy
	jr nc, .notOnTop
	inc l
	ld a, [wMarioX]		; mario x pos
	ld b, a
	ld a, [hl]			; enemy x pos
	sub b
	jr c, .checkRightBound	; if enemy x < mario x, ok
	cp a, $03
	jr nc, .notOnTop		; maximum 2 units of overhang? why not add before..
.checkRightBound
	push hl
	inc l
	inc l
	inc l
	inc l
	inc l
	inc l
	inc l
	ld a, [hl]			; D1xA
	and a, $70			; width
	swap a
	ld b, a
	pop hl
	ld a, [hl]			; x pos
.loopR
	add a, $08
	dec b
	jr nz, .loopR		; find right bound
	ld b, a
	ld a, [wMarioX]		; mario x pos
	sub b				; 
	jr c, .skip
	cp a, $03
	jr nc, .notOnTop
.skip
	dec l
	ldh a, [hHitboxTop]		; enemy top Y bound
	sub a, $0A
	ld [wMarioY], a		; position Mario 10 units above
	push hl
	dec l
	dec l				; D1x0
	call Call_2A01
	pop hl
	ld bc, $0009
	add hl, bc
	ld [hl], $01		; D1xB
	xor a
	ld hl, wMarioJumpStatus
	ldi [hl], a			; C207 jump status
	ldi [hl], a			; C208
	ldi [hl], a			; C209
	ld [hl], $01		; C20A 1 if mario on the ground
	ld hl, wMarioSpeed		; two INC L's would've been cheaper >_<
	ld a, [hl]
	cp a, $07			; momentum?
	jr c, .out
	ld [hl], $06
.out
	pop hl
	pop bc
	ret

.notOnTop
	pop hl
	pop bc
	jp .nextEnemy


SECTION "player 16F5", ROM0[$16F5]

;@ --------------------------------------------------------------------
;@ AnimateMario   [00:16F5]   39 lines
;@   called by : GameState_00_Gameplay, GameState_09_EnterPipe, GameState_0B_EnterPipeFromUnderground, GameState_0C_EmergeFromPipe, GameState_20_WalkOffButton, GameState_23_WalkToFakeDaisy
;@   reads     : wMarioAnimationIndex, wMarioOnGround, wMarioWalkRunSpeed
;@   calls     : Call_1736, Call_1D26
;@ --------------------------------------------------------------------
AnimateMario:: ; 16F5 Animate mario?
	call Call_1736
	ld a, [wMarioOnGround]			; 1 if mario on the ground
	and a
	jr z, .loop2
	ld a, [wMarioAnimationIndex]			; animation index
	and a, $0F				; low nibble
	cp a, $0A
	jr nc, .loop2		; JR if animation index is >= 0xA, which is sub and airplane stuff
	ld hl, wMarioAnimationFrameCounter			; animation frame counter?
	ld a, [wMarioWalkRunSpeed]			; 2 when walking, 4 when stuff
	cp a, $23
	ld a, [hl]
	jr z, .skip			; wait, can this ever happen... Bug?
	and a, $03
	jr nz, .loop2		; any 3 movement frames, change animation
.loop
	ld hl, wMarioAnimationIndex
	ld a, [hl]
	cp a, $18				; crouching Super Mario
	jr z, .loop2
	inc [hl]
	ld a, [hl]
	and a, $0F
	cp a, $04				; 3 sprites in the walking animation
	jr c, .loop2
	ld a, [hl]
	and a, $F0
	or a, $01
	ld [hl], a
.loop2
	call Call_1D26			; check movement keys, move mario?
	ret
.skip
	and a, $01
	jr nz, .loop2
	jr .loop


SECTION "player 17BC", ROM0[$17BC]

; called every frame?
;@ --------------------------------------------------------------------
;@ CheckMarioTileCollision   [00:17BC]   97 lines
;@   called by : GameState_00_Gameplay, GameState_20_WalkOffButton, GameState_23_WalkToFakeDaisy
;@   reads     : hScrollX, hSuperStatus, wInvincibilityTimer, wMarioJumpStatus, wMarioWalkRunSpeed
;@   writes    : wMarioWalkRunSpeed
;@   calls     : InjureMario, Jmp_175B, Jmp_1765, Jmp_185D, KillMario, LookupTile
;@ --------------------------------------------------------------------
CheckMarioTileCollision:: ; 17BC
	ld hl, wMarioJumpStatus			; jump status
	ld a, [hl]
	cp a, $01
	ret z
	ld hl, wMarioY			; Y pos
	ldi a, [hl]
	add a, $0B
	ldh [$FFAD], a
	ldh a, [hScrollX]
	ld b, a
	ld a, [hl]
	add b
	add a, $FE				; -2?
	ldh [$FFAE], a
	call LookupTile
	cp a, $70				; standing on pipe
	jr z, Jmp_1765
	cp a, $E1				; boss switch
	jp z, Jmp_175B			; can this be a JR?
	cp a, $60				; solid tiles
	jr nc, .skip2		; why is this a JP? Bug?
	ld a, [wMarioWalkRunSpeed]			; 02 walking, 04 running
	ld b, $04
	cp a, $04
	jr nz, .skip
	ld a, [wMarioJumpStatus]			; jump status
	and a
	jr nz, .skip
	ld b, $08
.skip
	ldh a, [$FFAE]
	add b
	ldh [$FFAE], a
	call LookupTile
	cp a, $60
	jr nc, .skip2
.loop
	ld hl, wMarioJumpStatus
	ld a, [hl]
	cp a, $02
	ret z					; return if descending
	ld hl, wMarioY			; Y pos
	inc [hl]
	inc [hl]
	inc [hl]				; falling without having jumped
	ld hl, wMarioOnGround
	ld [hl], 0				; Mario not on ground
	ld a, [wMarioWalkRunSpeed]
	and a
	ret nz
	ld a, $02
	ld [wMarioWalkRunSpeed], a
	ret

.skip2
	cp a, $ED				; spike
	push af
	jr nz, .skip4
	ld a, [wInvincibilityTimer]
	and a
	jr nz, .skip4
	ldh a, [hSuperStatus]
	and a
	jr z, .skip3
	cp a, $04				; i frames after hit
	jr z, .skip4
	cp a, $02
	jr nz, .skip4
	pop af
	call InjureMario
	jr Jmp_185D

.skip3
	pop af
	call KillMario
	jr Jmp_185D

.skip4
	pop af
	cp a, $F4				; Coin
	jr nz, Jmp_185D
	push hl
	pop de
	ld hl, $FFEE
	ld a, [hl]
	and a
	jr nz, .loop
	ld [hl], $C0
	inc l
	ld [hl], d
	inc l
	ld [hl], e
	ld a, $05
	ld [$DFE0], a			; coin sound
	jr .loop


SECTION "player 1F03", ROM0[$1F03]

;@ --------------------------------------------------------------------
;@ UpdateInvincibility   [00:1F03]   25 lines
;@   called by : GameState_00_Gameplay, GameState_0D_AutoScrollLevel
;@   reads     : hFrameCounter, wCurrentSong, wInvincibilityTimer, wMarioVisible
;@   writes    : wInvincibilityTimer, wMarioVisible
;@   calls     : StartLevelMusic
;@ --------------------------------------------------------------------
UpdateInvincibility:: ; 1F03
	ldh a, [hFrameCounter]
	and a, $03
	ret nz				; every 4 frames
	ld a, [wInvincibilityTimer]
	and a
	ret z
	cp a, $01
	jr z, .endOfInvincibility
	dec a
	ld [wInvincibilityTimer], a
	ld a, [wMarioVisible]
	xor a, $80			; blink Mario 7.5 times per second
	ld [wMarioVisible], a
	ld a, [wCurrentSong]		; currently playing song
	and a
	ret nz				; invincibility stops when the timer runs out,
.endOfInvincibility		; or the song stops
	xor a
	ld [wInvincibilityTimer], a
	ld [wMarioVisible], a		; mario visible
	call StartLevelMusic
	ret

; called every frame in non autoscroll levels
;@ --------------------------------------------------------------------
;@ UpdateSuperball   [00:1F2D]   122 lines
;@   called by : GameState_00_Gameplay
;@   reads     : wSuperballTTL
;@   writes    : wSuperballTTL
;@   calls     : Call_200A, FindNeighboringTile
;@ --------------------------------------------------------------------
UpdateSuperball:: ; 1F2D
	ld b, $01			; just one superball?
	ld hl, hProjectileStatus		; projectiles at A9, AA and AB?
	ld de, wOAMBuffer + 1 ; objects 0, X position
.superballLoop
	ldi a, [hl]
	and a
	jr nz, .moveSuperball
.nextSuperball			; XXX more than one? how?
	inc e
	inc e
	inc e
	inc e				; next object
	dec b
	jr nz, .superballLoop
	ret

.moveSuperball
	push hl
	push de
	push bc
	dec l				; hl = FFA9
	ld a, [wSuperballTTL]
	and a
	jr z, .removeSuperball
	dec a
	ld [wSuperballTTL], a
	bit 0, [hl]			; going right?
	jr z, .flyingLeft
	ld a, [de]			; X pos
	inc a
	inc a
	ld [de], a			; X → X + 2
	cp a, $A2
	jr c, .detectCollisionRight
.removeSuperball
	xor a
	res 0, e			; Guess they remembered this CPU has bit instructions
	ld [de], a			; a DEC DE would have sufficed
	ld [hl], a
	jr .enemyCollision

.detectCollisionRight
	add a, $03			; check collision a little in front
	push af
	dec e				; e is now the Y coord of the object
	ld a, [de]
	ldh [$FFAD], a		; used in collision detection
	pop af
	call FindNeighboringTile
	jr c, .verticalMotion	; c if no collision with solid
	ld a, [hl]
	and a, %11111100
	or a,  %00000010	; reverse direction, go left
	ld [hl], a
.verticalMotion
	bit 2, [hl]			; non zero if going up
	jr z, .flyingDown
	ld a, [de]
	dec a
	dec a
	ld [de], a
	cp a, $10
	jr c, .removeSuperball		; c if out of bounds
	sub a, $01
	ldh [$FFAD], a				; check collision uo
	inc e
	ld a, [de]
	call FindNeighboringTile
	jr c, .enemyCollision		; c if no collision
	ld a, [hl]
	and a, %11110011
	or  a, %00001000	; reverse direction, go down
	ld [hl], a
.enemyCollision
	pop bc
	pop de
	pop hl
	call Call_200A		; collision with enemy?
	jr .nextSuperball

.flyingDown
	ld a, [de]
	inc a
	inc a
	ld [de], a
	cp a, $A8				; todo screen width and such
	jr nc, .removeSuperball	; nc if out of bounds
	add a, $04				; check collision down
	ldh [$FFAD], a
	inc e
	ld a, [de]
	call FindNeighboringTile
	jr c, .enemyCollision		; c if no collision
	ld a, [hl]
	and a, %11110011
	or  a, %00000100	; reverse direction, go up
	ld [hl], a
	jr .enemyCollision

.flyingLeft
	ld a, [de]
	dec a
	dec a
	ld [de], a
	cp a, $04
	jr c, .removeSuperball		; if out of bounds
	sub a, $02			; detect collision to the left
	push af
	dec e
	ld a, [de]
	ldh [$FFAD], a
	pop af
	call FindNeighboringTile
	jr c, .verticalMotion
	ld a, [hl]
	and a, %11111100
	or a,  %00000001	; reverse direction, go right
	ld [hl], a
	jr .verticalMotion


