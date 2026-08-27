#!/usr/bin/env python3
"""Generate a derived interface header above each non-trivial routine.

Everything in the block is read out of the code itself — callers, the memory
symbols touched, the subroutines invoked, size and ROM address — so it cannot
drift into being wrong. Idempotent: existing generated blocks are replaced.

  tools/gen-headers.py            # write headers
  tools/gen-headers.py --strip    # remove them again
"""
import re, os, sys, glob, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
MARK = ";@ "
LBL = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)::?')
MEM = re.compile(r'\b([whr][A-Z][A-Za-z0-9_]*)\b')
CALL = re.compile(r'\b(?:call|jp|jr)\b(?:\s+(?:nz|z|nc|c)\s*,)?\s*([A-Za-z_][A-Za-z0-9_]*)')
MIN_LINES = 6

def strip(lines):
    return [l for l in lines if not l.startswith(MARK)]

def routines(lines):
    out, cur, start = [], None, 0
    for i, l in enumerate(lines):
        m = LBL.match(l)
        if m:
            if cur: out.append((cur, start, i))
            cur, start = m.group(1), i
    if cur: out.append((cur, start, len(lines)))
    return out

src = {f: strip(open(f, errors="replace").read().splitlines())
       for f in sorted(glob.glob("*.asm") + glob.glob("levels/*.asm"))}
if "--strip" in sys.argv:
    for f, L in src.items(): open(f, "w").write("\n".join(L) + "\n")
    print("headers removed"); raise SystemExit

# ROM addresses from the linker's symbol file, if a build is present
addr = {}
symf = "bin/gb/supermarioland.sym"
if os.path.exists(symf):
    for line in open(symf):
        m = re.match(r'([0-9a-f]{2}):([0-9a-f]{4})\s+(\S+)\s*$', line)
        if m and "." not in m.group(3):
            addr[m.group(3)] = f"{m.group(1)}:{m.group(2).upper()}"

defined = {n for f, L in src.items() for n, _, _ in routines(L)}
callers = collections.defaultdict(set)
for f, L in src.items():
    for name, a, b in routines(L):
        for l in L[a:b]:
            for t in CALL.findall(l.split(";")[0]):
                if t in defined and t != name: callers[t].add(name)

count = 0
for f, L in src.items():
    out, prev = [], 0
    for name, a, b in routines(L):
        out.extend(L[prev:a]); prev = a
        body = [l.split(";")[0] for l in L[a:b]]
        if len(body) < MIN_LINES: continue
        reads = sorted({m for l in body for m in MEM.findall(l)
                        if re.search(r'ldh?\s+a\s*,\s*\[|\b(?:cp|and|or|xor|add|sub)\b.*\[', l)})
        writes = sorted({m for l in body for m in MEM.findall(l)
                         if re.search(r'ldh?\s+\[', l)})
        subs = sorted({t for l in body for t in CALL.findall(l) if t in defined and t != name})
        if not (reads or writes or subs): continue
        blk = [f"{MARK}{'-'*68}", f"{MARK}{name}" +
               (f"   [{addr[name]}]" if name in addr else "") + f"   {b-a} lines"]
        if callers[name]: blk.append(f"{MARK}  called by : " + ", ".join(sorted(callers[name])[:6]))
        if reads:  blk.append(f"{MARK}  reads     : " + ", ".join(reads[:8]))
        if writes: blk.append(f"{MARK}  writes    : " + ", ".join(writes[:8]))
        if subs:   blk.append(f"{MARK}  calls     : " + ", ".join(subs[:8]))
        blk.append(f"{MARK}{'-'*68}")
        out.extend(blk); count += 1
    out.extend(L[prev:])
    open(f, "w").write("\n".join(out) + "\n")
print(f"generated {count} routine headers")
