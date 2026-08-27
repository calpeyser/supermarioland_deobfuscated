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

| | |
|---|---|
| ROM disassembled | **58%** — bank 0: 75%, bank 1: 34%, bank 2: 62%, bank 3: 60% |
| Global labels | 701, of which 84 are still placeholders (`Call_5CF`, `Data_3FC4`) |
| Comment lines | 353, against ~11,000 instructions |
| Named RAM | 36 WRAM + 37 HRAM symbols (~81 HRAM bytes still unidentified) |

`coverage.py` regenerates a visual coverage map.

## Roadmap

Work is ordered so the cheap ROM-invariant passes come first:

1. ~~Toolchain: build under current RGBDS~~ — done
2. Name the 84 placeholder labels and the local labels, from their call sites
3. Lift the ~6,900 raw hex literals into named constants
4. Finish the HRAM map — the remaining unnamed bytes are the game's hot state
5. Per-routine header comments: inputs, outputs, registers clobbered, callers
6. Reorganize source into thematic files (free, thanks to fixed-address sections)
7. Close the remaining 42% of `INCBIN` — real reverse engineering, larger than 1–6 combined

Steps 2–6 cannot change the output, so `make check` must stay green through all of them.

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
