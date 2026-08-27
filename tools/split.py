#!/usr/bin/env python3
"""Move a set of routines into their own thematic file, byte-identically.

  tools/split.py player.asm "Mario movement, animation and collision" R1 R2 ...

Sections are address-pinned, so ROM layout is independent of source layout. Each
contiguous run of extracted routines becomes one `SECTION ... [$addr]` in the new
file, and the source file resumes with its own pinned section after each hole.
Cross-object references resolve at link time, so the new file must NOT re-include
wram.asm/hram.asm (that would define their sections twice).
"""
import re, os, sys, glob, subprocess, shutil, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
GLOBAL = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)::?')
out_name, desc, wanted = sys.argv[1], sys.argv[2], set(sys.argv[3:])

sym = {}
for line in open("bin/gb/supermarioland.sym"):
    m = re.match(r'([0-9a-f]{2}):([0-9a-f]{4})\s+(\S+)\s*$', line)
    if m and "." not in m.group(3):
        sym.setdefault(m.group(3), (int(m.group(1), 16), int(m.group(2), 16)))

files = sorted(glob.glob("*.asm") + glob.glob("levels/*.asm"))
bak = tempfile.mkdtemp(prefix="sml-split-")
for f in files:
    os.makedirs(os.path.join(bak, os.path.dirname(f)), exist_ok=True)
    shutil.copy2(f, os.path.join(bak, f))
shutil.copy2("Makefile", os.path.join(bak, "Makefile"))

def fail(msg):
    for f in files: shutil.copy2(os.path.join(bak, f), f)
    shutil.copy2(os.path.join(bak, "Makefile"), "Makefile")
    if os.path.exists(out_name) and out_name not in files: os.remove(out_name)
    shutil.rmtree(bak); sys.exit(msg)

src = next((f for f in files if any(
    GLOBAL.match(l) and GLOBAL.match(l).group(1) in wanted
    for l in open(f, errors="replace"))), None)
if not src: fail("none of those routines found")

L = open(src, errors="replace").read().splitlines()
# Compute every routine's start first, then end each span at the NEXT span's
# start. Ending at the next label's own line would overlap the comment block
# that the walk-back already claimed, and reverse-order cutting would then
# strand local labels outside any routine.
starts = []
for i, l in enumerate(L):
    m = GLOBAL.match(l)
    if not m: continue
    s = i
    while s > 0 and (L[s-1].startswith(";@ ")
                     or (L[s-1].strip().startswith(";") and not L[s-1].startswith("SECTION"))):
        s -= 1
    s = max(s, starts[-1][1] + 1 if starts else 0)
    starts.append((m.group(1), i, s))
spans = [(n, s, (starts[k+1][2] if k + 1 < len(starts) else len(L)))
         for k, (n, i, s) in enumerate(starts)]

take = [(n, a, b) for n, a, b in spans if n in wanted]
missing = wanted - {n for n, _, _ in take}
if missing: fail(f"not in {src}: {', '.join(sorted(missing))}")
take.sort(key=lambda t: t[1])

# merge into contiguous line runs
runs = []
for n, a, b in take:
    if runs and a == runs[-1][1]: runs[-1] = (runs[-1][0], b, runs[-1][2] + [n])
    else: runs.append((a, b, [n]))

bank = sym[take[0][0]][0]
def sect(addr, tag):
    if bank == 0: return f'SECTION "{tag}", ROM0[${addr:04X}]'
    return f'SECTION "{tag}", ROMX[${addr:04X}], BANK[{bank}]'

body = [f"; {desc}", "; Extracted from " + src + " by tools/split.py. Addresses are pinned,",
        "; so this file's contents sit at exactly the same ROM offsets as before.", ""]
for inc in ("constants.asm", "charmap.asm", "inc/hardware.inc", "macros.asm", "enemies.asm"):
    if os.path.exists(inc): body.append(f'INCLUDE "{inc}"')
body.append("")

for a, b, names in runs:
    addr = sym[names[0]][1]
    body.append(sect(addr, f"{out_name[:-4]} {addr:04X}"))
    body.append("")
    body.extend(L[a:b])
    body.append("")

for a, b, names in sorted(runs, reverse=True):
    nxt = next((L[j] for j in range(b, len(L)) if GLOBAL.match(L[j])), None)
    repl = []
    if nxt:
        nm = GLOBAL.match(nxt).group(1)
        if nm in sym: repl = [sect(sym[nm][1], f"{src[:-4]} resume {sym[nm][1]:04X}"), ""]
    L[a:b] = repl

open(out_name, "w").write("\n".join(body) + "\n")
open(src, "w").write("\n".join(L) + "\n")

mk = open("Makefile").read()
obj = out_name[:-4] + ".o"
if obj not in mk:
    mk = mk.replace("OBJECTS_RAW := bank0.o", f"OBJECTS_RAW := bank0.o {obj}")
    open("Makefile", "w").write(mk)

r = subprocess.run(["tools/verify.sh"], capture_output=True, text=True)
if r.returncode != 0:
    fail(f"REVERTED:\n{r.stdout[-1200:]}{r.stderr[-1200:]}")
shutil.rmtree(bak)
print(f"{out_name}: {len(take)} routines in {len(runs)} pinned sections — verified output-neutral")
