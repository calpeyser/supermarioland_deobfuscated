SECTION "High RAM", HRAM

hJoyHeld:: ; FF80 keys currently pressed
	ds 1

hJoyPressed:: ; FF81 keys pressed since last time
	ds 1

ds $85 - $82

hVBlankOccurred::	; FF85
	ds 1

	ds 9		; FF86
hHitboxRight:: ; FF8F [A] "BB right" / "right BB x"
	ds 1
	ds 9		; FF90

hSuperStatus:: ; FF99 TODO constants
	ds 1

hWinCount::		; FF9A TODO mirrored at C0E1?
	ds 1

ds 1			; FF9B unknown

hStompChainTimer:: ; FF9C
	ds 1

hStompChain::	; FF9D
	ds 1

	ds 1		; FF9E
hInMenuOrDemo:: ; FF9F [B] "only non zero in the menu" / "=28 in menu and during demo"
	ds 1
hHitboxTop:: ; FFA0 [B] "bounding box top?"
	ds 1
hHitboxBottom:: ; FFA1 [B] "bounding box bottom?" / "bottom Y"
	ds 1
hHitboxLeft:: ; FFA2 [B] "bounding box left?" / "left BB x"
	ds 1
hScrollColumnPhase:: ; FFA3 [B] "switches between 0 and 8, depending on scroll coord"
	ds 1

hScrollX::		; FFA4
	ds 1

ds 1			; FFA5 unknown

hTimer::		; FFA6 Generic frame based timer
	ds 1

	ds 2		; FFA7
hProjectileStatus:: ; FFA9 [A] "projectile status"
	ds 1
	ds 2		; FFAA

hFrameCounter:: ; FFAC
	ds 1

	ds 3		; FFAD
hTilemapAddrHi:: ; FFB0 [A] "goes from 98 to ~9B" = the BG tilemap page
	ds 1
hScoreLeadingZero:: ; FFB1 [B] "start by printing spaces instead of leading zeroes"
	ds 1

hGamePaused::	; FFB2
	ds 1

hGameState::	; FFB3
	ds 1

hWorldAndLevel::; FFB4
	ds 1

hSuperballMario::; FFB5
	ds 1

hDMARoutine::	; FFB6
	ds $A

hEnemyId:: ; FFC0 [A] "enemy ID"
	ds 1
hEnemySpeed:: ; FFC1 [B] "update Y position with Y speed"
	ds 1
hEnemyY:: ; FFC2 [A] "enemy Y pos buffer" / "Y pos"
	ds 1
hEnemyX:: ; FFC3 [A] "enemy X pos buffer" / "future X pos" / "X pos"
	ds 1
hEnemyScriptIndex:: ; FFC4 [A] "script index" (3 sites)
	ds 1
	ds 1		; FFC5
hEnemySpriteIndex:: ; FFC6 [A] "animation index/sprite index"
	ds 1
hEnemyFlags:: ; FFC7 [B] "flags" / "bit 1 set if gravity works on it?"
	ds 1
	ds 2		; FFC8
hEnemyMortalityAndSize:: ; FFCA [B] "mortality and dimensions"
	ds 1
hEnemyCarryingMario:: ; FFCB [A] "carrying Mario"
	ds 1
hEnemyHealth:: ; FFCC [A] "health, above C0 means boss"
	ds 1
	ds 3		; FFCD

hCurrentChannel:: ; FFD0 Used in music routine
	ds 1

ds $D5 - $D1

hPanTimer:: ; FFD5
	ds 1

hPanInterval:: ; FFD6
	ds 1

hPanCounter:: ; FFD7
	ds 1

hMonoOrStereo:: ; FFD8
	ds 1

hChannelEnableMask1:: ; FFD9
	ds 1

hChannelEnableMask2:: ; FFDA
	ds 1

ds $DE - $DB

hPauseTuneTimer:: ; FFDE
	ds 1

hPauseUnpauseMusic::; FFDF
	ds 1

ds 1			; FFE0

hSavedRomBank::	; FFE1
	ds 1

hTextCursorHi:: ; FFE2
	ds 1

hTextCursorLo:: ; FFE3
	ds 1

hLevelIndex::	; FFE4
	ds 1

hScreenIndex::	; FFE5
	ds 1

hColumnIndex::	; FFE6
	ds 1

hColumnPointerHi::	; FFE7
	ds 1

hColumnPointerLo:: ; FFE8
	ds 1

hNextColumnToLoad:: ; FFE9 [B] "first not yet loaded column"
	ds 1
hColumnLoadRequest:: ; FFEA [B] "01 if a new column needs to be loaded, 03 if..."
	ds 1

hFloatyX:: ; FFEB
	ds 1

hFloatyY:: ; FFEC
	ds 1

hFloatyControl:: ; FFED
	ds 1

	ds 7		; FFEE
hPipeExitScreen:: ; FFF5 [B] "screen which we'd've exited out of pipe"
	ds 1
	ds 3		; FFF6
hUnderground:: ; FFF9 [A] "nonzero if underground" (3 sites)
	ds 1

hCoins::	; FFFA
	ds 1

ds 2

hActiveRomBank::	; FFFD
	ds 1
