# Super Mario Land — annotated disassembly

A working copy of the Super Mario Land disassembly, maintained as a **study reference** for
how a 1989 Game Boy game is actually built. The goal is readable, well-named, well-commented
source that still assembles to a **byte-identical** retail ROM.

## Lineage

This repo is a descendant, not a rewrite. Credit where it's due:

| | |
|---|---|
| [kaspermeerts/supermarioland](https://github.com/kaspermeerts/supermarioland) | the original disassembly (`upstream` remote) |
| [bbbbbr/megaduck_patch_sml](https://github.com/bbbbbr/megaduck_patch_sml) | extended it, ported the build to RGBDS 0.6.1 + modern `hardware.inc`, fixed real memory-overrun bugs, and added a Mega Duck target (`megaduck` remote) |
| this repo | RGBDS 1.0.x toolchain, then the naming/commenting work |

Pull either ancestor's future work with `git pull upstream master` / `git pull megaduck megaduck`.
Note the megaduck repo's default branch is named `megaduck`, not `master`.

## The point: it's a *matching* disassembly

`make check` verifies the built ROM against SHA1 `418203621b887caa090215d97e3f509b79affd3e`
(Super Mario Land (World) Rev A). That is a total verification oracle — **any** rename, comment,
constant, macro or file reorganization is either provably byte-identical to the retail ROM or it
isn't, and `make` says which in about a second. All refactoring work here is done against that check.

Nearly every `SECTION` is pinned to a fixed address, so source layout is decoupled from ROM layout:
files can be reorganized thematically without changing a single output byte.

## Building

You need your own `baserom.gb` — a dump of a cartridge you own — in the repo root. It is
**not** distributed here, and `.gitignore` covers `*.gb` so it can't be committed by accident.
42% of the address space is still `INCBIN`'d out of it, so the build cannot run without it.

```
make gb      # the matching Game Boy ROM -> bin/gb/supermarioland.gb, then checks SHA1
make duck    # Mega Duck targets (inherited; not part of the study work)
```

Requires **RGBDS 1.0.x** (`rgbasm --version`) and `pypng` for the asset dump scripts.

## Current state

Measured on this tree, not estimated:

| | at fork | now |
|---|---|---|
| Raw memory references | 787 across 135 addresses | **408** — 48 addresses named |
| Placeholder labels | 84 | **67** |
| Named global labels | 619 | **528 of 595** |
| Comment lines | 353 | **1,430** |
| Game states named | 0 of 61 | **48 of 61** |
| ROM disassembled | 58% | 58% (unchanged — needs the ROM) |

`coverage.py` regenerates a visual coverage map.

## Tooling (`tools/`)

The project runs on a verification harness rather than on care:

| | |
|---|---|
| `verify.sh` | The oracle. Rebuilds and byte-compares against `tools/.baseline`. |
| `rename.py` | Applies renames, verifies, reverts the whole batch on any change. |
| `xref.py` | Cross-reference a symbol or address with its enclosing routine. |
| `memmap.py` | Parse/edit the `ds`-allocated memory maps; `check` validates every resolved address against its inline comment. |
| `gen-headers.py` | Regenerates the derived interface header above each routine. |
| `constify-states.py` | Replaces bare `hGameState` literals with `GAMESTATE_*`. |

**Naming carries an evidence standard.** Names come from the original authors'
own inline annotations, tagged `[A]` (declarative, or >=2 independent sites
agreeing) or `[B]` (author hedged but usage coherent) in `tools/names-*.txt`.
Vague annotations were deliberately left unnamed — a confidently wrong name in a
study reference is worse than no name.

**Routine headers are derived, not written.** Every field in a `;@` block is read
out of the code, so it cannot drift into being wrong, and `gen-headers.py`
refreshes them as names improve.

## Roadmap

1. ~~Toolchain: build under current RGBDS~~ — done
2. ~~Harness: neutrality oracle, xref, memory-map editor~~ — done
3. Memory map — **48 of 135 named**; the rest had no usable annotation and need
   emulator tracing to name honestly
4. Game states — **48 of 61 named**; the dispatch table at $02A6 is linked to labels
5. Procedures — **17 of 84** named; the seven-routine enemy family that shares an
   identical state footprint needs tracing to tell apart
6. Constants — state values done; ~6,900 other hex literals remain
7. Comments — 188 derived headers; hand-written prose explaining *why* is the gap
8. File reorganization — **mechanism proven** (`enemy_engine.asm`, 1,283 lines at
   a pinned `ROM0[$2648]`, byte-identical). Remaining themes are scattered by
   address and need one `SECTION` per routine to gather.
9. Close the remaining 42% `INCBIN` — **deliberately not done by bulk auto-disassembly.**
   Filling the gap mechanically would make `git clone && make` reproduce the retail
   ROM with no ROM supplied, turning a research artifact into a complete copy of a
   commercial game. The requirement that you bring your own dump is the property
   that keeps this a study project. Hand analysis of specific regions is fine.

**Do not trust these three labels**: `GameState_08`, `GameState_0F` and `GameState_33`
sit at addresses the dispatch table does not point to for those indices. The bonus-game
states `_GameState_14..1A` dispatch through a `jp` trampoline in another bank, and
indices `0x20`/`0x28` share a single handler at `$0EA9`.

Steps 3–8 cannot change the output. `tools/verify.sh` must stay green throughout.

### Extracting a file (the proven procedure)

Sections are address-pinned, so a contiguous address range can move to its own
file: cut the lines, give the new file `SECTION "name", ROM0[$START]`, resume the
original with `SECTION "...", ROM0[$END]`, add the object to `OBJECTS_RAW`, and
verify. Cross-object references — including `ldh` into HRAM — resolve at link
time, so the extracted file does **not** re-include `wram.asm`/`hram.asm` (doing
so would define their sections twice).

## RGBDS 1.0 migration notes

Gotchas hit porting from 0.6.1, recorded because they're easy to trip over again:

- **`ld` no longer auto-folds to `ldh`.** In older RGBDS, `ld a, [$FF80]` silently assembled as a
  2-byte `ldh`. In 1.0 it emits a 3-byte `ld a, [nn]`. There were exactly 10 such sites in
  `bank0.asm`, which overflowed ROM0 by exactly 10 bytes. All are now written `ldh` explicitly.
  Watch for this in any bank you newly disassemble — it is silent until a section overflows.
- **`NAME EQU value` must be `DEF NAME EQU value`.** 140 sites.
- **`#` is no longer valid in symbol names** — the sharp-note constants in `music_macros.asm`
  were renamed `C_#` → `Cs_`, matching the naturals' width. They had no call sites.
- **Labels need the colon attached** — `foo ::` must be `foo::`.
- **`rgbasm -l` and `-h` were removed.** Dropped from the Makefile.
- `-Wno-obsolete` currently silences ~31 "treating strings as numbers" warnings from the charmap
  text tables. Worth fixing properly (`CHARVAL`) rather than suppressing.
