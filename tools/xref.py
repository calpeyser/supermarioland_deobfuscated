#!/usr/bin/env python3
"""Cross-reference a symbol or raw address across the disassembly.

  tools/xref.py $FFAE          # every reference, with enclosing routine + context
  tools/xref.py hGameState -c3 # 3 lines of context either side
  tools/xref.py --summary $FFAE  # just the access pattern (read/write counts, routines)
"""
import re, sys, glob, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
LBL = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)::?')

def load():
    out = {}
    for f in sorted(glob.glob("*.asm") + glob.glob("levels/*.asm")):
        out[f] = open(f, errors="replace").read().splitlines()
    return out

def routine_at(lines, i):
    for j in range(i, -1, -1):
        m = LBL.match(lines[j])
        if m:
            return m.group(1)
    return "?"

def main():
    args = [a for a in sys.argv[1:]]
    summary = "--summary" in args
    if summary: args.remove("--summary")
    ctx = 0
    for a in list(args):
        if a.startswith("-c"):
            ctx = int(a[2:]); args.remove(a)
    if not args: sys.exit(__doc__)
    target = args[0]
    pat = re.compile(rf'(?<![A-Za-z0-9_$]){re.escape(target)}(?![A-Za-z0-9_])')

    src = load()
    hits = [(f, i, l) for f, L in src.items() for i, l in enumerate(L)
            if pat.search(l.split(";")[0])]
    if not hits:
        print(f"no references to {target}"); return

    reads = writes = 0
    routines = collections.Counter()
    for f, i, l in hits:
        code = l.split(";")[0]
        if re.search(r'ldh?\s+a\s*,\s*\[', code) or re.search(r'\b(cp|and|or|xor|add|sub|inc|dec)\b.*\[', code):
            reads += 1
        if re.search(r'ldh?\s+\[', code):
            writes += 1
        routines[routine_at(src[f], i)] += 1

    print(f"{target}: {len(hits)} references — {reads} read, {writes} write")
    print(f"  touched by {len(routines)} routines: " +
          ", ".join(f"{k}({v})" for k, v in routines.most_common(10)))
    if summary: return
    print()
    for f, i, l in hits:
        print(f"--- {f}:{i+1}  in {routine_at(src[f], i)}")
        lo, hi = max(0, i - ctx), min(len(src[f]), i + ctx + 1)
        for j in range(lo, hi):
            print(("  > " if j == i else "    ") + src[f][j])

main()
