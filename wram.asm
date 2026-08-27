SECTION "wram", WRAM0

wOAMBuffer::
	ds $A0

wScore::	; C0A0
	ds 3

wLivesEarnedLost::
	ds 1	; C0A3

ds 1		; C0A4

wGameOverWindowEnabled:: ; C0A5
	db

wNumContinues::	; C0A6
	db

db ; C0A7

wContinueWorldAndLevel:: ; C0A8
	db

wSuperballTTL:: ; C0A9
	db

	ds 1		; C0AA
wLevelProgress:: ; C0AB [A] "progress in level" (3 sites)
	ds 1
wDeathAnimationCounter:: ; C0AC [A] "death animation counter"
	ds 1

wGameOverTimerExpired:: ; C0AD
	db

ds $C0 - $AE

wTopScore:: ; C0C0
	ds 3

	ds 10		; C0C3
wBlockContents:: ; C0CD [A] "contents of block"
	ds 1
	ds 4		; C0CE
wLevelEndCounter:: ; C0D2 [A] "starts incrementing at end of level"
	ds 1

wInvincibilityTimer:: ; C0D3
	db

	ds 3		; C0D4
wDemoTimer:: ; C0D7 [A] "Demo timer"
	ds 1
	ds 4		; C0D8
wDemoSelect:: ; C0DC [A] "Demo select"
	ds 1
wDeathY:: ; C0DD [B] "death Y position?"
	ds 1
	ds 1		; C0DE

wScrollY:: ; C0DF
	db

ds 1		; C0E0

wWinCount:: ; C0E1
	db

	ds 286		; C0E2
wMarioVisible:: ; C200 [A] "mario visible"
	ds 1
wMarioY:: ; C201 [A] "Mario Y pos" / "player Y pos" / "Y pos"
	ds 1
wMarioX:: ; C202 [A] "Mario X pos" / "mario x pos" / "X pos"
	ds 1
wMarioAnimationIndex:: ; C203 [A] "animation index, upper nibble is 1 if large mario"
	ds 1
wMarioHasControl:: ; C204 [B] "mario in control?"
	ds 1
wMarioFacing:: ; C205 [A] "dir facing" / "direction mario is facing"
	ds 1
	ds 1		; C206
wMarioJumpStatus:: ; C207 [A] "jump status"
	ds 1
	ds 2		; C208
wMarioOnGround:: ; C20A [A] "1 if mario on the ground"
	ds 1
wMarioAnimationFrameCounter:: ; C20B [A] "animation frame counter"
	ds 1
wMarioSpeed:: ; C20C [B] "momentum?" / "speed?"
	ds 1
	ds 1		; C20D
wMarioWalkRunSpeed:: ; C20E [A] "02 walking, 04 running" (3 sites)
	ds 1
wMarioStepPhase:: ; C20F [B] "01 standing still, flips between 1 and 0 walking"
	ds 1
	ds 3568		; C210
wObjectAttributes:: ; D000 [B] "object flags" / "object attributes, lower 3 bits"
	ds 1
	ds 1		; D001

wCurrentCommand:: ; D002
	db

wCommandArgument:: ; D003
	db

ds $D013 - $D004

wObjectsDrawn:: ; D013 The upper 20 objects are used for enemies
	db

wBackgroundAnimated::	; D014
	db

; D100 - D190: enemies
ds $DA00 - $D015

wGameTimer:: ; DA00-DA02
	ds 3

wFloaty0_TTL:: ; DA03-DA06
	db
wFloaty1_TTL::
	db
wFloaty2_TTL::
	db
wFloaty3_TTL::
	db

wFloaty0_SpriteIfCoin:: ; DA07-DA0A
	db
wFloaty1_SpriteIfCoin::
	db
wFloaty2_SpriteIfCoin::
	db
wFloaty3_SpriteIfCoin::
	db

wNextFloatyOAMIndex:: ; DA0B
	ds 1

wFloaty0_IsCoin:: ; DA0C - DA0F
	db
wFloaty1_IsCoin::
	db
wFloaty2_IsCoin::
	db
wFloaty3_IsCoin::
	db

ds $DA15 - $DA10

wLives::	db	; $DA15

ds 1	; DA16
ds 1 	; DA17

wLadderLocationHi::	; DA18
	db

wLadderLocationLo:: ; DA19
	db

ds 1 ; DA1A

wBonusGameEndTimer:: ; DA1B
	db

ds 1				; DA1C

wGameTimerExpiringFlag:: ; DA1D do i have a better name?
	db

wBonusGameGrowAnimationFlag:: ; DA1E Long name...
	db

wBonusGameAnimationTimer:: ; DA1F
	db

ds $22 - $20

wBonusGameFrameCounter:: ; DA22
	db

wLadderTiles:: ; DA23
	ds 4

wLadderStatus:: ; DA27 [B] "ladder status?" / "ladder position in floors?"
	ds 1
	ds 1468		; DA28
wSoundNoteIndex:: ; DFE4 [B] "when sound has ended, increment and load a new note"
	ds 1
	ds 4		; DFE5
wCurrentSong:: ; DFE9 [A] "currently playing song"
	ds 1
	ds 6		; DFEA
wSfxRequestNoise:: ; DFF0 [A] "SFX channel, only has boss cry"
	ds 1
	ds 4		; DFF1
wRandomValue:: ; DFF5 [A] "random number from D0 to FF"
	ds 1
	ds 3		; DFF6
wCurrentlyPlayingSound:: ; DFF9 [A] "currently playing music and sfx"
	ds 1
	ds 5		; DFFA
