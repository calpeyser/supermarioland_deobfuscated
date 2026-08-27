#!/usr/bin/env python3
"""Turn the hGameState dispatch table's raw `dw $XXXX` into label references.

Only rewrites an entry when a global label exists at exactly that (bank,address),
so an entry pointing into an undisassembled hole or a jp trampoline is left alone.
Verifies output-neutrality.
"""
import re, os, sys, subprocess, shutil, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
sym = {}
for line in open("bin/gb/supermarioland.sym"):
    m = re.match(r'([0-9a-f]{2}):([0-9a-f]{4})\s+(\S+)\s*$', line)
    if m and "." not in m.group(3):
        sym.setdefault((int(m.group(1), 16), int(m.group(2), 16)), m.group(3))

bak = tempfile.mkdtemp(prefix="sml-jt-")
shutil.copy2("bank0.asm", os.path.join(bak, "bank0.asm"))
L = open("bank0.asm", errors="replace").read().splitlines()
i = next(k for k, l in enumerate(L) if l.startswith("dw $0627"))
n = skipped = 0
for k in range(i, i + 62):
    m = re.match(r'dw \$([0-9A-Fa-f]{4}) ; (0x[0-9A-F]{2})\s*(.*)$', L[k])
    if not m: break
    a = int(m.group(1), 16)
    lbl = sym.get((0, a)) if a < 0x4000 else next(
        (sym[(b, a)] for b in (1, 2, 3) if (b, a) in sym), None)
    if not lbl:
        skipped += 1; continue
    note = m.group(3).strip()
    L[k] = f"\tdw {lbl}".ljust(52) + f"; {m.group(2)} {note}".rstrip()
    n += 1
open("bank0.asm", "w").write("\n".join(L) + "\n")
r = subprocess.run(["tools/verify.sh"], capture_output=True, text=True)
if r.returncode != 0:
    shutil.copy2(os.path.join(bak, "bank0.asm"), "bank0.asm")
    shutil.rmtree(bak); sys.exit(f"REVERTED:\n{r.stdout}{r.stderr}")
shutil.rmtree(bak)
print(f"linked {n} table entries to labels, left {skipped} raw — verified output-neutral")
