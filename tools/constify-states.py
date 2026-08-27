#!/usr/bin/env python3
"""Replace bare hGameState literals with GAMESTATE_* constants.

Only rewrites the two exact instruction pairs (adjacent lines):
    ld a, $XX  /  ldh [hGameState], a
    ldh a, [hGameState]  /  cp a, $XX
so an unrelated $XX elsewhere is never touched. Verifies output-neutrality.
"""
import re, os, sys, glob, subprocess, shutil, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

NAMES = {}
for line in open("constants.asm"):
    m = re.match(r'DEF\s+(GAMESTATE_\w+)\s+EQU\s+\$([0-9A-F]{2})', line)
    if m: NAMES[m.group(2)] = m.group(1)

files = sorted(glob.glob("*.asm") + glob.glob("levels/*.asm"))
backup = tempfile.mkdtemp(prefix="sml-const-")
for f in files:
    os.makedirs(os.path.join(backup, os.path.dirname(f)), exist_ok=True)
    shutil.copy2(f, os.path.join(backup, f))

n = 0
for f in files:
    L = open(f, errors="replace").read().splitlines()
    for i, raw in enumerate(L):
        code = raw.split(";")[0].rstrip()
        m = re.match(r'(\s*ld\s+a,\s*)\$([0-9A-Fa-f]{2})\s*$', code)
        if m and i + 1 < len(L) and re.match(r'\s*ldh?\s*\[hGameState\],\s*a\s*$', L[i+1].split(";")[0]):
            v = m.group(2).upper()
            if v in NAMES:
                L[i] = raw.replace(f"${m.group(2)}", NAMES[v], 1); n += 1
        if re.match(r'\s*ldh?\s+a,\s*\[hGameState\]\s*$', code) and i + 1 < len(L):
            nxt = L[i+1]; c2 = nxt.split(";")[0].rstrip()
            m2 = re.match(r'(\s*cp\s+a?,?\s*)\$([0-9A-Fa-f]{2})\s*$', c2)
            if m2:
                v = m2.group(2).upper()
                if v in NAMES:
                    L[i+1] = nxt.replace(f"${m2.group(2)}", NAMES[v], 1); n += 1
    open(f, "w").write("\n".join(L) + "\n")

r = subprocess.run(["tools/verify.sh"], capture_output=True, text=True)
if r.returncode != 0:
    for f in files: shutil.copy2(os.path.join(backup, f), f)
    shutil.rmtree(backup); sys.exit(f"REVERTED:\n{r.stdout}{r.stderr}")
shutil.rmtree(backup)
print(f"replaced {n} bare state literals with constants — verified output-neutral")
