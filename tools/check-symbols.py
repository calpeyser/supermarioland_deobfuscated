#!/usr/bin/env python3
"""Guard against losing names and comments — damage the checksum cannot see.

tools/verify.sh proves the ROM is byte-identical, which is blind to deleting a
label or a comment. This snapshots the human-meaning content instead.

  tools/check-symbols.py --set   record the current symbol/comment inventory
  tools/check-symbols.py         fail if any global label vanished or the
                                 comment count dropped
"""
import re, os, sys, glob, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
SNAP = "tools/.symbols.json"

def inventory():
    g, loc, cmt = set(), 0, 0
    for f in sorted(glob.glob("*.asm") + glob.glob("levels/*.asm") + glob.glob("inc/*.inc")):
        t = open(f, errors="replace").read()
        g |= set(re.findall(r'^([A-Za-z_][A-Za-z0-9_]*)::', t, re.M))
        g |= set(re.findall(r'^DEF\s+([A-Za-z_][A-Za-z0-9_]*)', t, re.M))
        loc += len(re.findall(r'^\.[A-Za-z_]', t, re.M))
        cmt += len(re.findall(r'^\s*;', t, re.M))
    return {"globals": sorted(g), "locals": loc, "comments": cmt}

cur = inventory()
if "--set" in sys.argv:
    json.dump(cur, open(SNAP, "w"), indent=1)
    print(f"recorded {len(cur['globals'])} globals, {cur['locals']} locals, {cur['comments']} comments")
    raise SystemExit

if not os.path.exists(SNAP):
    sys.exit("no snapshot; run tools/check-symbols.py --set")
old = json.load(open(SNAP))
lost = sorted(set(old["globals"]) - set(cur["globals"]))
problems = []
if lost:
    problems.append(f"{len(lost)} global label(s) vanished: {', '.join(lost[:12])}")
for k in ("locals", "comments"):
    if cur[k] < old[k]:
        problems.append(f"{k} dropped {old[k]} -> {cur[k]}")
if problems:
    print("SYMBOL LOSS:\n  " + "\n  ".join(problems), file=sys.stderr); sys.exit(1)
gained = len(set(cur["globals"]) - set(old["globals"]))
print(f"OK  {len(cur['globals'])} globals (+{gained}), {cur['locals']} locals, {cur['comments']} comments")
