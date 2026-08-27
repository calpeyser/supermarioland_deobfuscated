# Where the game logic lives

A reading guide. Start here rather than opening `bank0.asm`.

## The shape of it

Super Mario Land is a **state machine driven from the VBlank interrupt**. Almost
everything hangs off one byte, `hGameState`, which selects one of 61 handlers.

```
  VBlank interrupt  ->  hGameState  ->  rst $28 (TableJump at $0028)
                                             |
                        dispatch table at $02A6, 62 entries
                                             |
              +------------------------------+------------------------------+
              |                              |                              |
        0x00 Gameplay               0x03..0x06 death,            0x1B..0x38 endgame
      (the main game loop)          level-clear, win               and credits
```

The dispatcher is worth understanding first. It is reached through `rst $28`, a
one-byte restart instruction, **not** a `call` — which is why searching for
callers of the state handlers finds nothing. `TableJump` pops the return address
off the stack, uses it as the base of an inline table of 16-bit addresses that
literally follows the `rst $28`, indexes it by `A`, and jumps there.

## Which file to open

| File | What's in it |
|---|---|
| **`player.asm`** | **Mario.** Physics, animation, hitbox, collision with tiles and with enemies, injury and death, invincibility, the superball. Start here. |
| **`enemy_engine.asm`** | The enemy engine — per-slot state, the behaviour script interpreter, spawning and despawning. |
| **`ending.asm`** | The whole endgame: gate, Tatanga, fake Daisy, real Daisy, airplane, credits. Self-contained; ignore it while learning the core loop. |
| `bank0.asm` | Boot, interrupts, the state dispatch table, the menu, level streaming, HUD, and data tables. Still the biggest file. |
| `bank1/2/3.asm` | Bank-switched code: level data, the bonus game, and the sound engine. |
| `music.asm` | Music data and the note format. |
| `wram.asm` / `hram.asm` | **The memory map — read this second.** Every named variable with its address. |

## The variables that explain the most

Naming memory is what makes the code readable, so these carry the most meaning:

- `wMarioX`, `wMarioY` — position. `wMarioSpeed`, `wMarioJumpStatus`, `wMarioOnGround` — motion.
- `wMarioAnimationIndex`, `wMarioFacing`, `wMarioWalkRunSpeed` (`$02` walking, `$04` running).
- `hEnemyId`, `hEnemyX`, `hEnemyY`, `hEnemyHealth`, `hEnemyScriptIndex` — the enemy scratch
  block. Enemies are copied into this HRAM buffer, updated, and copied back to their slot.
- `hHitboxTop/Bottom/Left/Right` — the shared bounding box used by every collision check.
- `hScrollX`, `hNextColumnToLoad`, `hColumnLoadRequest` — the level streams in one column of
  tiles at a time as the screen scrolls.

## How to read a routine

Every non-trivial routine carries a `;@` header block listing its callers, the
memory it reads and writes, and what it calls. Those are **generated from the
code** by `tools/gen-headers.py`, so they cannot drift out of date — but they
also describe mechanism, not intent.

## Reading order

1. `TableJump` at `$0028` and the dispatch table at `$02A6` in `bank0.asm` — the spine.
2. `wram.asm` and `hram.asm` — the vocabulary.
3. `GameState_00_Gameplay` — the main loop, and what it calls each frame.
4. `player.asm` — Mario.
5. `enemy_engine.asm` — everything else that moves.

## Caveats worth knowing before you trust a label

- **`GameState_08`, `GameState_0F` and `GameState_33` sit at addresses the dispatch
  table does not point to** for those indices. Do not read them as "the handler for
  state N".
- The bonus-game states `_GameState_14..1A` dispatch through a `jp` trampoline in
  another bank, so the table's target is not the handler itself.
- Indices `0x20` and `0x28` share a single handler at `$0EA9`.
- **42% of the ROM is still `INCBIN`** from the original — those regions have no
  source at all, and holes in a file are usually that, not a mistake.
- Names came from the original authors' inline annotations, graded `[A]`/`[B]` in
  `tools/names-*.txt`. Anything they hedged is still a hypothesis.
