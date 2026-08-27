#!/usr/bin/env python3
"""Replace placeholder local labels (.jmp_XXXX, .data_XXXX, .call_XXXX) with
names derived from their role in the code.

Nothing is invented: a label is classified by what actually branches to it and
what follows it.
  backward branch target      -> .loop
  label on db/dw/ds           -> .row<N>  (data table rows)
  block ends quickly in ret   -> .out
  otherwise (forward skip)    -> .skip
Duplicates inside one routine get a numeric suffix. Local labels are scoped to
the preceding global label, so reuse across routines is fine and intended.
"""
import re, os, sys, glob, subprocess, shutil, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
PH = re.compile(r'^\.((?:jmp|jr|jp|call|data|label|loc)_?[0-9A-Fa-f]{3,})\s*(;.*)?$', re.I)
GLOBAL = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)::?')
ANYLOCAL = re.compile(r'^\.([A-Za-z_][A-Za-z0-9_]*)')
BRANCH = re.compile(r'\b(?:jr|jp|call)\b(?:\s+(?:nz|z|nc|c)\s*,)?\s*(\.[A-Za-z_][A-Za-z0-9_]*)')
DATA = re.compile(r'^\s*(db|dw|ds)\b', re.I)

files = sorted(glob.glob("*.asm") + glob.glob("levels/*.asm"))
bak = tempfile.mkdtemp(prefix="sml-locals-")
for f in files:
    os.makedirs(os.path.join(bak, os.path.dirname(f)), exist_ok=True)
    shutil.copy2(f, os.path.join(bak, f))

total = 0
rmap = []
for f in files:
    L = open(f, errors="replace").read().splitlines()
    # routine spans
    bounds = [i for i, l in enumerate(L) if GLOBAL.match(l)] + [len(L)]
    for bi in range(len(bounds) - 1):
        a, b = bounds[bi], bounds[bi + 1]
        body = L[a:b]
        phs = [(k, PH.match(l).group(1)) for k, l in enumerate(body) if PH.match(l)]
        if not phs: continue
        taken = {ANYLOCAL.match(l).group(1) for l in body
                 if ANYLOCAL.match(l) and not PH.match(l)}
        rown = 0
        for k, old in phs:
            # what follows the label?
            nxt = next((body[j] for j in range(k + 1, b - a)
                        if body[j].strip() and not body[j].lstrip().startswith(";")), "")
            if DATA.match(nxt):
                base = f"row{rown}"; rown += 1
            else:
                srcs = [j for j, l in enumerate(body)
                        if f".{old}" in l and BRANCH.search(l.split(";")[0])]
                if any(j > k for j in srcs):
                    base = "loop"
                else:
                    seg = "\n".join(body[k + 1:k + 7])
                    base = "out" if re.search(r'^\s*ret\b', seg, re.M) else "skip"
            name = base
            n = 2
            while name in taken:
                name = f"{base}{n}"; n += 1
            taken.add(name)
            rmap.append((GLOBAL.match(L[a]).group(1), old, name))
            for j in range(b - a):
                body[j] = re.sub(rf'(?<![A-Za-z0-9_])\.{re.escape(old)}(?![A-Za-z0-9_])',
                                 f".{name}", body[j])
            total += 1
        L[a:b] = body
    open(f, "w").write("\n".join(L) + "\n")

# second pass: qualified cross-routine references, e.g. `Jmp_4966.jmp_498B`
for f in files:
    t = open(f, errors="replace").read()
    for rout, old, new in rmap:
        t = re.sub(rf'(?<![A-Za-z0-9_.]){re.escape(rout)}\.{re.escape(old)}(?![A-Za-z0-9_])',
                   f"{rout}.{new}", t)
    open(f, "w").write(t)

r = subprocess.run(["tools/verify.sh"], capture_output=True, text=True)
if r.returncode != 0:
    for f in files: shutil.copy2(os.path.join(bak, f), f)
    shutil.rmtree(bak); sys.exit(f"REVERTED:\n{r.stdout}{r.stderr}")
shutil.rmtree(bak)
print(f"renamed {total} placeholder local labels — verified output-neutral")
