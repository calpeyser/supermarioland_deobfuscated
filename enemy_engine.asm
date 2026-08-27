INCLUDE "constants.asm"
INCLUDE "charmap.asm"
INCLUDE "inc/hardware.inc"
INCLUDE "macros.asm"
INCLUDE "enemies.asm"

SECTION "enemy engine", ROM0[$2648]

;@ --------------------------------------------------------------------
;@ UpdateEnemies   [00:2648]   596 lines
;@   called by : Call_2491
;@   reads     : hEnemyCarryingMario, hEnemyFlags, hEnemyId, hEnemyMortalityAndSize, hEnemyScriptIndex, hEnemySpeed, hEnemyX, hEnemyY
;@   writes    : hEnemyCarryingMario, hEnemyFlags, hEnemyId, hEnemyScriptIndex, hEnemySpeed, hEnemySpriteIndex, hEnemyX, hEnemyY
;@   calls     : Call_1AAD, Call_24D6, Call_2B84, Call_2B9A, Call_2BBB, Call_2BE4, Call_2BFE, Call_2C21
;@ --------------------------------------------------------------------
UpdateEnemies:: ; 2648
	ld hl, $D100
.loop
	ld a, [hl]
	inc a
	jr z, .nextSlot
	push hl
	call CopyEnemySlotToBuffer.fromHL
	ld hl, Data_349E
	ldh a, [hEnemyId]		; enemy ID
	rlca
	ld d, $00
	ld e, a
	add hl, de
	ldi a, [hl]
	ld e, a
	ld a, [hl]
	ld d, a
	ld h, d
	ld l, e
	call .updateEnemy
	pop hl
	push hl
	call CopyBufferToEnemySlot.toHL
	pop hl
.nextSlot
	ld a, l
	add a, $10
	ld l, a
	cp a, $A0
	jp nz, .loop
	ret

.updateEnemy
	ldh a, [$FFC8]			;
	and a
	jr z, .runScript
	ldh a, [hEnemyFlags]			; bit 1 set if gravity works on it?
	bit 1, a
	jr z, .skip2
	call Call_2BBB			; check collision one tile down?
	jr nc, .skip		; no carry means the tile is solid
	ldh a, [hEnemyY]			; Y pos
	inc a					; fall down
	ldh [hEnemyY], a
	ret						; resume script when back on the ground

.skip
	ldh a, [hEnemyY]
	and a, $F8				; snap to tile grid
	ldh [hEnemyY], a
.skip2
	ldh a, [$FFC9]
	and a, $F0
	swap a
	ld b, a
	ldh a, [$FFC9]
	and a, $0F
	cp b
	jr z, .skip3
	inc b
	swap b
	or b
	ldh [$FFC9], a
	ret

.skip3
	ldh a, [$FFC9]
	and a, $0F
	ldh [$FFC9], a
	ldh a, [$FFC8]
	dec a
	ldh [$FFC8], a
	jp .moveEnemy

.runScript
	push hl
	ld d, $00
	ldh a, [hEnemyScriptIndex]			; script index
	ld e, a
	add hl, de
	ld a, [hl]
	ld [wCurrentCommand], a
	cp a, $FF				; end of script sentinel
	jr nz, .runCommand
	xor a					; end of script reached, restart
	ldh [hEnemyScriptIndex], a
	pop hl
	jr .runScript

.runCommand
	ldh a, [hEnemyScriptIndex]
	inc a
	ldh [hEnemyScriptIndex], a
	ld a, [wCurrentCommand]
	and a, $F0
	cp a, $F0
	jr z, .specialCommand	; Fx command with argument
	ld a, [wCurrentCommand]
	and a, $E0
	cp a, $E0				; Ex wait
	jr nz, .speedCommand
	ld a, [wCurrentCommand]
	and a, $0F				; wait command, wait the lower nibble number
	ldh [$FFC8], a			; of ticks? todo
	pop hl
	jr .updateEnemy

.speedCommand
	ld a, [wCurrentCommand]
	ldh [hEnemySpeed], a			; the speed is just the command itself
	ld a, $01
	ldh [$FFC8], a
	pop hl
	jp .updateEnemy

.specialCommand
	ldh a, [hEnemyScriptIndex]			; increment script index, load argument
	inc a
	ldh [hEnemyScriptIndex], a
	inc hl
	ld a, [hl]
	ld [wCommandArgument], a
	ld a, [wCurrentCommand]
	cp a, $F8					; F8 - Change sprite
	jr nz, .checkF0
	ld a, [wCommandArgument]
	ldh [hEnemySpriteIndex], a
	pop hl
	jr .runScript

.checkF0
	cp a, $F0					; F0 - Change orientation
	jr nz, .checkF1
	ld a, [wCommandArgument]
	and a, $C0					; 1100 0000
	jr z, .checkBits2And3
	bit 7, a			; bit 7, direct towards Mario in the Y direction?
	jr z, .checkBit6
	ldh a, [$FFC5]
	and a, $FD			; unset bit 1
	ld b, a
	ld a, [wMarioY]		; Y pos
	ld c, a
	ldh a, [hEnemyY]		; enemy Y pos
	sub c
	rla					; Put carry flag in lowest bit of A
	rlca				; Put carry flag in bit 1
	and a, $02
	or b
	ldh [$FFC5], a		; and OR it into FFC5
.checkBit6
	ld a, [wCommandArgument]
	bit 6, a			; Same but for X
	jr z, .checkBits2And3
	ld a, [wMarioX]		; Mario X
	ld c, a
	ldh a, [hEnemyX]		; Enemy X
	ld b, a
	ldh a, [hEnemyMortalityAndSize]
	and a, $70			; width in tiles, times 16
	rrca
	rrca				; half width in pixels
	add b				; add to enemy X to get X coodinate of center of enemy
	sub c
	rla					; Put carry flag in lowest bit of A
	and a, $01
	ld b, a
	ldh a, [$FFC5]
	and a, $FE
	or b
	ldh [$FFC5], a		; And OR it into FFC5
.checkBits2And3
	ld a, [wCommandArgument]
	and a, $0C			; bits 2 and 3, invert corresponding direction
	jr z, .checkBits4and5
	rra
	rra
	ld b, a
	ldh a, [$FFC5]
	xor b				; invert the corresponding bits in FFC5
	ldh [$FFC5], a
.checkBits4and5
	ld a, [wCommandArgument]
	bit 5, a			; bit 5, replace Y direction with bit 1
	jr z, .checkBit4
	and a, $02
	or a, $FD			; put bit 1 in a bitmask with all other bits set
	ld b, a
	ldh a, [$FFC5]
	set 1, a
	and b				; and apply to FFC5
	ldh [$FFC5], a
.checkBit4
	ld a, [wCommandArgument]
	bit 4, a			; bit 4, replace X direction with bit 0
	jr z, .out
	and a, $01			; same, but with bit 0
	or a, $FE
	ld b, a
	ldh a, [$FFC5]
	set 0, a
	and b
	ldh [$FFC5], a
.out
	pop hl
	jp .runScript

.checkF1
	cp a, $F1			; F1 - launch projectile
	jr nz, .checkF2
	ld a, $0A			; Temporarily store the current buffer
	call CopyBufferToEnemySlot
	call Call_24D6		; Overwrite current buffer. This makes sure the projectile
	ld a, $0A			; is spawned at the location of the enemy firing it
	call CopyEnemySlotToBuffer
	pop hl
	jp .runScript

.checkF2
	cp a, $F2			; F2 - set movement flags
	jr nz, .checkF3
	ld a, [wCommandArgument]
	ldh [hEnemyFlags], a
	pop hl
	jp .runScript

.checkF3
	cp a, $F3			; F3 - Change ID and reinitialize
	jr nz, .checkF4
	ld a, [wCommandArgument]
	ldh [hEnemyId], a
	cp a, $FF			; FF stands for an empty slot
	jp z, .enemyGone
	ld hl, hEnemyId
	call InitEnemy
	pop hl
	ld hl, Data_349E	; reinitialize script
	ldh a, [hEnemyId]
	rlca
	ld d, $00
	ld e, a
	add hl, de
	ldi a, [hl]
	ld e, a
	ld a, [hl]
	ld d, a
	ld h, d
	ld l, e
	jp .runScript

.checkF4
	cp a, $F4
	jr nz, .checkF5		; F4 - tick timer of some sort
	ld a, [wCommandArgument]
	ldh [$FFC9], a
	pop hl
	jp .runScript

.checkF5
	cp a, $F5			; F5 - Shoot with a 1 in 4 probability - Unused?
	jr nz, .checkF6
	ldh a, [rDIV]
	and a, $3			; "random" value from 0 to 3
	ld a, $F1
	jr z, .checkF1		; execute command F1 - launch projectile
	pop hl
	jp .runScript

.checkF6
	cp a, $F6			; F6 - Halt until Mario is close
	jr nz, .checkF7
	ld a, [wMarioX]		; Mario X
	ld b, a
	ldh a, [hEnemyX]		; enemy X
	sub b
	add a, $14			; set carry flag if Mario is within [-$14, $20 - $14 - 1]
	cp a, $20			; pixels of enemy
	ld a, [wCommandArgument]
	dec a				; does not touch carry flag, but can set zero flag
	jr z, .checkCarry
	ccf					; invery carry flag if argument is not 1
.checkCarry
	jr c, .dontHalt
	ldh a, [hEnemyScriptIndex]		; put script index back to the start of this command
	dec a				; effectively halting the script until Mario is close
	dec a				; or conversely not close
	ldh [hEnemyScriptIndex], a
	pop hl
	ret

.dontHalt
	pop hl
	jp .runScript

.checkF7
	cp a, $F7			; F7 - Explode all enemies :)
	jr nz, .checkF9
	call ExplodeAllEnemies
	pop hl
	ret

.checkF9
	cp a, $F9			; F9 - Sound effect
	jr nz, .checkFA
	ld a, [wCommandArgument]
	ld [$DFF8], a		; sound effect
	pop hl
	ret

.checkFA
	cp a, $FA			; FA - Sound effect
	jr nz, .checkFB
	ld a, [wCommandArgument]
	ld [$DFE0], a		; sound effect
	pop hl
	ret

.checkFB
	cp a, $FB			; FB - reset script until enemy is close enough
	jr nz, .checkFC
	ld a, [wCommandArgument]
	ld c, a
	ld a, [wMarioX]
	ld b, a
	ldh a, [hEnemyX]
	sub b
	cp c
	jr c, .enemyClose
	xor a
	ldh [hEnemyScriptIndex], a
	pop hl
	jp .runScript

.enemyClose				; Unnecessary. Bug
	pop hl
	jp .runScript

.checkFC
	cp a, $FC			; FC - position enemy at the right of the screen
	jr nz, .checkFD		; Only used for Tatanga?
	ld a, [wCommandArgument]
	ldh [hEnemyY], a
	ld a, $70
	ldh [hEnemyX], a
	pop hl
	jp .runScript

.checkFD
	cp a, $FD			; FD - Music
	jr nz, .unknownCommand
	ld a, [wCommandArgument]
	ld [$DFE8], a
	pop hl
	ret

.unknownCommand			; silently ignore...
	pop hl
	jp .runScript

.enemyGone
	pop hl
	ret

.moveEnemy				; X movement first
	ldh a, [hEnemySpeed]
	and a, $0F			; X speed
	jp z, .skip9		; if zero, no point in doing collision detection
	ldh a, [$FFC5]
	bit 0, a			; going right
	jr nz, .goingRight
	call Call_2B84		; some sort of collision detection. left bound?
	jr nc, .skip5
	ldh a, [hEnemyFlags]
	bit 0, a			; set if enemy doesn't walk off edges
	jr z, .loop2
	call Call_2BE4		; checks for collision bottom left bound, one tile down?
	jr c, .reverseAndGoRight	; carry means the tile isn't solid
.loop2
	ldh a, [hEnemySpeed]
	and a, $0F
	ld b, a
	ldh a, [hEnemyX]		; X
	sub b
	ldh [hEnemyX], a
	ldh a, [hEnemyCarryingMario]
	and a
	jp z, .skip9
	ld a, [wMarioFacing]		; dir mario is facing?
	ld c, a
	push bc
	ld a, $20			; 20 if facing left
	ld [wMarioFacing], a
	call Call_1AAD		; Mario side collision
	pop bc
	and a
	jr nz, .skip4
	ld a, [wMarioX]		; Y pos
	sub b
	ld [wMarioX], a
	cp a, $0F
	jr nc, .skip4
	ld a, $0F
	ld [wMarioX], a
.skip4
	ld a, c
	ld [wMarioFacing], a
	jp .skip9

.skip5
	ldh a, [hEnemyFlags]
	and a, $0C			; test bits 2 and 3
	cp a, 0
	jr z, .loop2		; bit 2 and 3 not set
	cp a, $4
	jr nz, .skip6
.reverseAndGoRight		; bit 2 set, bit 3 unset
	ldh a, [$FFC5]
	set 0, a
	ldh [$FFC5], a
	jp .skip9

.skip6
	cp a, $0C
	jp nz, .skip9
	xor a
	ldh [hEnemyScriptIndex], a
	ldh [$FFC8], a
	jp .skip9

.goingRight
	call Call_2B9A		; bottom right collision
	jr nc, .sideCollisionRight
	ldh a, [hEnemyFlags]		; carry, so non-solid tile
	bit 0, a			; bit 0: don't walk off edges?
	jr z, .loop3
	call Call_2BFE		; collision bottom right, one tile down
	jr c, .reverseAndGoLeft		; jump if not solid
.loop3
	ldh a, [hEnemySpeed]
	and a, $0F			; X speed
	ld b, a
	ldh a, [hEnemyX]		; X
	add b
	ldh [hEnemyX], a
	ldh a, [hEnemyCarryingMario]
	and a
	jr z, .skip9
	ld a, [wMarioFacing]		; direction mario is facing
	ld c, a
	push bc
	xor a
	ld [wMarioFacing], a
	call Call_1AAD		; mario collision?
	pop bc
	and a
	jr nz, .loop5
	ld a, [wMarioX]		; X pos
	add b
	ld [wMarioX], a
	cp a, $51
	jr c, .loop5
	ld a, [wLevelEndCounter]
	cp a, $07
	jr nc, .skip7
.loop4
	ld a, [wMarioX]		; X pos
	sub a, $50
	ld b, a
	ld a, $50
	ld [wMarioX], a
	ldh a, [hScrollX]
	add b
	ldh [hScrollX], a
	call Call_2C9F		; scroll enemies
.loop5
	ld a, c
	ld [wMarioFacing], a
	jr .skip9

.skip7
	ldh a, [hScrollX]
	and a, $0C			; 0000 1100
	jr nz, .loop4
	ldh a, [hScrollX]
	and a, $FC			; 1111 1100
	ldh [hScrollX], a
	jr .loop5

.sideCollisionRight
	ldh a, [hEnemyFlags]
	and a, $0C			; test bit 2 and 3
	cp a, 0
	jr z, .loop3		; neither bit set
	cp a, $4
	jr nz, .skip8
.reverseAndGoLeft		; bit 2 set, bit 3 not set | at an edge
	ldh a, [$FFC5]
	res 0, a			; moving left | reverse direction
	ldh [$FFC5], a
	jr .skip9

.skip8				; bit 2 and 3 set
	cp a, $0C
	jr nz, .skip9
	xor a				; both bits set
	ldh [hEnemyScriptIndex], a		; reset script
	ldh [$FFC8], a
.skip9				; 
	ldh a, [hEnemySpeed]
	and a, $F0
	jp z, .out2		; no Y speed, get out
	ldh a, [$FFC5]
	bit 1, a			; gravity
	jr nz, .skip12
	call Call_2C21		; upper left collision?
	jr nc, .skip10
.loop6
	ldh a, [hEnemySpeed]		; update Y position with Y speed
	and a, $F0
	swap a
	ld b, a
	ldh a, [hEnemyY]
	sub b
	ldh [hEnemyY], a
	ldh a, [hEnemyCarryingMario]
	and a
	jr z, .out2
	ld a, [wMarioY]
	sub b				; if carrying Mario, add the displacement to his Y coord
	ld [wMarioY], a
	jr .out2

.skip10
	ldh a, [hEnemyFlags]
	and a, $C0				; test bits 6 and 7
	cp a, $00
	jr z, .loop6			; jump if neither set
	cp a, $40				; test bit 6
	jp nz, .skip11		; could've been a JR, bug
	ldh a, [$FFC5]			; bit 6 set
	set 1, a				; moving down
	ldh [$FFC5], a
	jr .out2

.skip11
	cp a, $C0
	jr nz, .out2
	xor a
	ldh [hEnemyScriptIndex], a
	ldh [$FFC8], a
	jr .out2

.skip12
	call Call_2BBB		; collision one tile down
	jr nc, .skip13
.loop7
	ldh a, [hEnemySpeed]
	and a, $F0			; Y speed
	swap a
	ld b, a
	ldh a, [hEnemyY]
	add b
	ldh [hEnemyY], a
	ldh a, [hEnemyCarryingMario]		; carrying Mario
	and a
	jr z, .out2
	ld a, [wMarioY]
	add b				; if carrying, add to Mario's X position
	ld [wMarioY], a
	jr .out2

.skip13
	ldh a, [hEnemyFlags]
	and a, $30
	cp a, $00
	jr z, .loop7
	cp a, $10
	jr nz, .skip14
	ldh a, [$FFC5]
	res 1, a			; moving up
	ldh [$FFC5], a
	jr .out2

.skip14
	cp a, $30
	jr nz, .out2
	xor a
	ldh [hEnemyScriptIndex], a		; reset script
	ldh [$FFC8], a
.out2
	xor a
	ldh [hEnemyCarryingMario], a
	ret

; stomp enemy
;@ --------------------------------------------------------------------
;@ Call_2A01   [00:2A01]   26 lines
;@   called by : CheckMarioEnemyCollision, UpdateMarioPhysics
;@   calls     : InitEnemy
;@ --------------------------------------------------------------------
Call_2A01:: ; 2A01
	push hl
	ld a, [hl]
	ld e, a
	ld d, $00
	ld l, a
	ld h, $00
	sla e
	rl d
	sla e
	rl d
	add hl, de
	ld de, Data_3186
	add hl, de
	ld a, [hl]
	pop hl
	and a
	ret z
	push hl
	ld [hl], a
	call InitEnemy
	ld a, $FF
	pop hl
	ret

; enemy hit from down under
;@ --------------------------------------------------------------------
;@ Call_2A23   [00:2A23]   25 lines
;@   called by : SpawnFloatyAtMario
;@   calls     : InitEnemy
;@ --------------------------------------------------------------------
Call_2A23:: ; 2A23
	push hl
	ld a, [hl]
	ld e, a
	ld d, $00
	ld l, a
	ld h, $00
	sla e
	rl d
	sla e
	rl d
	add hl, de
	ld de, Data_3186
	add hl, de
	inc hl
	ld a, [hl]
	pop hl
	and a
	ret z
	ld [hl], a
	call InitEnemy
	ld a, $FF
	ret

; called when an enemy hits us on the side?
;@ --------------------------------------------------------------------
;@ Call_2A44   [00:2A44]   28 lines
;@   called by : CheckMarioEnemyCollision
;@   calls     : InitEnemy
;@ --------------------------------------------------------------------
Call_2A44:: ; 2A44
	push hl
	ld a, [hl]
	ld e, a
	ld d, $00
	ld l, a
	ld h, $00
	sla e
	rl d
	sla e
	rl d
	add hl, de
	ld de, Data_3186
	add hl, de
	inc hl
	inc hl
	ld a, [hl]
	pop hl
	cp a, $FF
	ret z
	and a
	ret z
	ld [hl], a
	call InitEnemy
	xor a
	ret

; hit by superball
;@ --------------------------------------------------------------------
;@ Call_2A68   [00:2A68]   54 lines
;@   called by : Call_200A
;@   writes    : wSfxRequestNoise
;@   calls     : InitEnemy
;@ --------------------------------------------------------------------
Call_2A68:: ; 2A68
	push hl
	ld a, l
	add a, $0C		; D1xC
	ld l, a
	ld a, [hl]
	and a, $3F		; health, like in 2AAD
	jr z, .skip
	ld a, [hl]
	dec a
	ld [hl], a
	pop hl
	ld a, [hl]
	cp a, HIYOIHOI
	jr z, .bossHitSFX
	cp a, KING_TOTOMESU
	jr z, .bossHitSFX
	jr .out

.bossHitSFX
	ld a, $01
	ld [wSfxRequestNoise], a	; creepy boss noise
.out
	ld a, $FE
	ret

.skip
	pop hl
	push hl
	ld a, [hl]
	ld e, a
	ld d, $00
	ld l, a
	ld h, $00
	sla e
	rl d
	sla e
	rl d
	add hl, de
	ld de, Data_3186
	add hl, de
	inc hl
	inc hl
	inc hl
	ld a, [hl]
	pop hl
	and a
	ret z
	ld [hl], a
	call InitEnemy
	ld a, $FF
	ret

; enemy hit by bullet in autoscroll
;@ --------------------------------------------------------------------
;@ Call_2AAD   [00:2AAD]   67 lines
;@   called by : Call_200A
;@   writes    : wSfxRequestNoise
;@   calls     : InitEnemy
;@ --------------------------------------------------------------------
Call_2AAD:: ; 2AAD
	push hl
	ld a, l
	add a, $0C		; "health"?
	ld l, a
	ld a, [hl]
	and a, $3F		; only the lower 6 bits are health
	jr z, .skip
	ld a, [hl]
	dec a
	ld [hl], a
	pop hl
	ld a, [hl]
	cp a, DRAGONZAMASU
	jr z, .bossHitSFX
	cp a, BIOKINTON
	jr z, .bossHitSFX
	cp a, TATANGA
	jr z, .explosionSFX
	jr .out

.explosionSFX
	ld a, $01
	ld [$DFF8], a	; explosion
	jr .out

.bossHitSFX
	ld a, $01
	ld [wSfxRequestNoise], a	; that weird scream bosses make when hit
.out
	ld a, $FE		; not dead yet?
	ret

.skip
	pop hl
	push hl
	ld a, [hl]
	cp a, $60		; tatanga
	jr nz, .skip2
	ld [$D007], a
.skip2
	ld a, [hl]
	ld e, a
	ld d, $00
	ld l, a
	ld h, $00
	sla e
	rl d
	sla e
	rl d
	add hl, de
	ld de, Data_3186
	add hl, de
	inc hl
	inc hl
	inc hl
	inc hl
	ld a, [hl]
	pop hl
	and a
	ret z
	ld [hl], a
	call InitEnemy
	ld a, $FF		; dead
	ret

; HL refers to the slot of the enemy touched whilst invincible
;@ --------------------------------------------------------------------
;@ Call_2B06   [00:2B06]   27 lines
;@   called by : CheckMarioEnemyCollision
;@   calls     : InitEnemy
;@ --------------------------------------------------------------------
Call_2B06:: ; 2B06
	push hl
	ld a, [hl]
	ld e, a
	ld d, $00
	ld l, a
	ld h, $00
	sla e
	rl d			; rotates possible carry in
	sla e
	rl d
	add hl, de		; HL = DE * 5
	ld de, Data_3186
	add hl, de
	inc hl
	inc hl
	inc hl
	inc hl
	ld a, [hl]
	pop hl
	and a
	ret z
	ld [hl], a
	call InitEnemy
	ld a, $FF
	ret

;@ --------------------------------------------------------------------
;@ ExplodeAllEnemies   [00:2B2A]   39 lines
;@   called by : GameState_07_LevelEndGate, UpdateEnemies
;@   writes    : hEnemyFlags, hEnemyId, hEnemyScriptIndex
;@ --------------------------------------------------------------------
ExplodeAllEnemies:: ; 2B2A
	ld hl, $D100
.loop
	ld a, [hl]
	cp a, $FF
	jr z, .nextEnemySlot
	push hl
	ld [hl], $27	; 0 ID of mid air explosion
	inc hl			; 1
	inc hl			; 2 Y
	inc hl			; 3 X
	inc hl			; 4
	ld [hl], $00
	inc hl			; 5
	inc hl			; 6
	inc hl			; 7
	inc hl			; 8
	inc hl			; A dimensions
	ld [hl], $00
	inc hl			; B
	inc hl			; C health?
	ld [hl], $00
	pop hl
.nextEnemySlot
	ld a, l
	add a, $10
	ld l, a
	cp a, $A0
	jr c, .loop
	ld a, $27
	ldh [hEnemyId], a
	xor a
	ldh [hEnemyScriptIndex], a
	ldh [hEnemyFlags], a
	inc a
	ld [$DFF8], a	; explosion sound
	ret

; enemy collision side check
;@ --------------------------------------------------------------------
;@ Call_2B5D   [00:2B5D]   29 lines
;@   reads     : hEnemyMortalityAndSize, hEnemyX, hEnemyY, hScrollX
;@   calls     : LookupTile
;@ --------------------------------------------------------------------
Call_2B5D:: ; 2B5D
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $04
	ldh [$FFAE], a
	ld c, a
	ldh a, [$FFC5]		; 1 if facing right
	bit 0, a
	jr .out

	ldh a, [hEnemyMortalityAndSize]
	and a, $70			; width
	rrca				; ...way more clever than the loop they usually use
	add c				; add the width to the X coordinate
	ldh [$FFAE], a
.out
	ldh a, [hEnemyY]
	ldh [$FFAD], a
	call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; another collision check, but not taking into account width (just left check?)
; also doesn't add 4 like the previous one
;@ --------------------------------------------------------------------
;@ Call_2B84   [00:2B84]   16 lines
;@   called by : UpdateEnemies
;@   reads     : hEnemyX, hEnemyY, hScrollX
;@   calls     : LookupTile
;@ --------------------------------------------------------------------
Call_2B84:: ; 2B84
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	ldh [$FFAE], a
	ldh a, [hEnemyY]
	ldh [$FFAD], a
	call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; collision check, adding width unconditionally (right bound?)
;@ --------------------------------------------------------------------
;@ Call_2B9A   [00:2B9A]   23 lines
;@   called by : UpdateEnemies
;@   reads     : hEnemyMortalityAndSize, hEnemyX, hEnemyY, hScrollX
;@   calls     : LookupTile
;@ --------------------------------------------------------------------
Call_2B9A:: ; 2B9A
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $8
	ld c, a
	ldh a, [hEnemyMortalityAndSize]
	and a, $70			; width in bits 4-6
	rrca				; A = width * 8, as there are 8 pixels per tile
	add c
	sub a, $8			; why is 8 added and subtracted?
	ldh [$FFAE], a
	ldh a, [hEnemyY]
	ldh [$FFAD], a
	call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; checks collision one tile lower
;@ --------------------------------------------------------------------
;@ Call_2BBB   [00:2BBB]   30 lines
;@   called by : UpdateEnemies
;@   reads     : hEnemyMortalityAndSize, hEnemyX, hEnemyY, hScrollX
;@ --------------------------------------------------------------------
Call_2BBB:: ; 2BBB
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $4		; middle of leftmost tile?
	ldh [$FFAE], a
	ld c, a
	ldh a, [$FFC5]	; bit 0 on if facing right
	bit 0, a
	jr .out	; bug maybe? Should have been jr nz?

	ldh a, [hEnemyMortalityAndSize]	; mortality and dimensions?
	and a, $70
	rrca
	add c
	ldh [$FFAE], a
.out
	ldh a, [hEnemyY]
	add a, $08		; one tile lower
	ldh [$FFAD], a
	Call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; functionally identical to the previous one, apart from not clobbering C
; unused?
;@ --------------------------------------------------------------------
;@ Call_2BE4   [00:2BE4]   20 lines
;@   called by : UpdateEnemies
;@   reads     : hEnemyX, hEnemyY, hScrollX
;@   calls     : LookupTile
;@ --------------------------------------------------------------------
Call_2BE4:: ; 2BE4
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $03
	ldh [$FFAE], a
	ldh a, [hEnemyY]
	add a, $08
	ldh [$FFAD], a
	call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret


; check for collision one tile down, 5 pixels to the right of the right bound?
; unused?
;@ --------------------------------------------------------------------
;@ Call_2BFE   [00:2BFE]   24 lines
;@   called by : UpdateEnemies
;@   reads     : hEnemyMortalityAndSize, hEnemyX, hEnemyY, hScrollX
;@   calls     : LookupTile
;@ --------------------------------------------------------------------
Call_2BFE:: ; 2BFE
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $5
	ld c, a
	ldh a, [hEnemyMortalityAndSize]
	and a, $70
	rrca
	add c
	sub a, $8		; to compensate for offset coordinates (Y-16, X-8)? todo
	ldh [$FFAE], a
	ldh a, [hEnemyY]
	add a, $8
	ldh [$FFAD], a
	call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; top collision? upper left?
;@ --------------------------------------------------------------------
;@ Call_2C21   [00:2C21]   35 lines
;@   called by : UpdateEnemies
;@   reads     : hEnemyMortalityAndSize, hEnemyX, hEnemyY, hScrollX
;@   calls     : LookupTile
;@ --------------------------------------------------------------------
Call_2C21:: ; 2C21
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $04
	ldh [$FFAE], a
	ld c, a
	ldh a, [$FFC5]
	bit 0, a
	jr .skip		; Should've been JR NZ?

	ldh a, [hEnemyMortalityAndSize]
	and a, $70			; 
	rrca
	add c
	ldh [$FFAE], a
.skip
	ldh a, [hEnemyMortalityAndSize]
	and a, $07			; height
	dec a
	swap a
	rrca				; multiply by 8
	ld c, a
	ldh a, [hEnemyY]
	sub c
	ldh [$FFAD], a
	call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; Yet another collision detection routine, upper left bound?
;@ --------------------------------------------------------------------
;@ Call_2C52   [00:2C52]   24 lines
;@   reads     : hEnemyMortalityAndSize, hEnemyX, hEnemyY, hScrollX
;@ --------------------------------------------------------------------
Call_2C52:: ; 2C52
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $03
	ldh [$FFAE], a
	ldh a, [hEnemyMortalityAndSize]
	and a, $07
	dec a
	swap a
	rrca
	ld c, a
	ldh a, [hEnemyY]
	sub c
	ldh [$FFAD], a
	Call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; another one. upper right bound?
;@ --------------------------------------------------------------------
;@ Call_2C74   [00:2C74]   30 lines
;@   reads     : hEnemyMortalityAndSize, hEnemyX, hEnemyY, hScrollX
;@ --------------------------------------------------------------------
Call_2C74:: ; 2C74
	ldh a, [hEnemyX]
	ld c, a
	ldh a, [hScrollX]
	add c
	add a, $05
	ld c, a
	ldh a, [hEnemyMortalityAndSize]
	and a, $70
	rrca
	sub c
	sub a, $08
	ldh [$FFAE], a
	ldh a, [hEnemyMortalityAndSize]
	and a, $07
	dec a
	swap a
	rrca
	ld c, a
	ldh a, [hEnemyY]
	sub c
	ldh [$FFAD], a
	Call LookupTile
	cp a, $5F
	ret c
	cp a, $F0
	ccf
	ret

; scroll all enemies by B
;@ --------------------------------------------------------------------
;@ Call_2C9F   [00:2C9F]   24 lines
;@   called by : Call_1D26, Call_4FB2, UpdateEnemies
;@   reads     : hEnemyX
;@   writes    : hEnemyX
;@ --------------------------------------------------------------------
Call_2C9F:: ; 2C9F
	ld a, b
	and a
	ret z
	ldh a, [hEnemyX]		; X
	sub b
	ldh [hEnemyX], a
	push hl
	push de
	ld hl, $D103
	ld de, $0010
.loop
	ld a, [hl]
	sub b
	ld [hl], a
	add hl, de
	ld a, l
	cp a, $A0
	jr c, .loop
	pop de
	pop hl
	ret

; HL points to enemy slot (powerup slot?)
InitEnemy:: ; 2CBB
	push hl
	ld a, [hl]			; enemy ID
	ld d, $00
	ld e, a
	rlca
	add e				; times three
	rl d
	ld e, a
	ld hl, Data_3375
	add hl, de
	ldi a, [hl]
	ld b, a
	ldi a, [hl]
	ld d, a
	ld a, [hl]			; Store the data in B, D and A
	pop hl
	inc hl
	inc hl
	inc hl
	inc hl
	ld [hl], $00		; D1x4
	inc hl
	inc hl
	inc hl
	ld [hl], b			; D1x7 first byte
	inc hl				; some sort of behaviour? goomba is 6. koopa is 7
	ld [hl], $00		; D1x8
	inc hl
	ld [hl], $00		; D1x9
	inc hl
	ld [hl], d			; D1xA second byte
	inc hl				; hittable and dimensions
	inc hl
	ld [hl], a			; D1xC third byte
	ret

; Fill buffer from enemy slot
CopyEnemySlotToBuffer:: ; 2CE5
	swap a
	ld hl, $D100
	ld l, a
.fromHL
	ld de, hEnemyId
	ld b, $0D			; bytes D, E, F are unused?
.loop
	ldi a, [hl]
	ld [de], a
	inc de
	dec b
	jr nz, .loop
	ret

; Fills enemy slot from buffer
CopyBufferToEnemySlot:: ; 2CF7
	swap a				; same as multiplying by 16. Slots are 16 bytes apart
	ld hl, $D100
	ld l, a
.toHL
	ld de, hEnemyId
	ld b, $0D
.loop
	ld a, [de]
	ldi [hl], a
	inc de
	dec b
	jr nz, .loop
	ret
