#!/usr/bin/env python3
"""Apply symbol renames and prove they changed no output bytes.

  tools/rename.py OLD NEW [OLD NEW ...]
  tools/rename.py -f renames.txt        # whitespace-separated OLD NEW per line, # comments

Applies every rename as a whole-word substitution across all .asm/.inc sources,
rebuilds, and compares against tools/.baseline. Reverts everything on mismatch,
so a failed batch leaves the tree exactly as it was.
"""
import re, sys, subprocess, glob, os, shutil, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

def sources():
    return sorted(glob.glob("*.asm") + glob.glob("levels/*.asm") + glob.glob("inc/*.inc"))

def parse_args(argv):
    if argv[:1] == ["-f"]:
        pairs = []
        for line in open(argv[1]):
            line = line.split("#")[0].strip()
            if line:
                a, b = line.split()
                pairs.append((a, b))
        return pairs
    if len(argv) % 2:
        sys.exit("need OLD NEW pairs")
    return list(zip(argv[::2], argv[1::2]))

def main():
    pairs = parse_args(sys.argv[1:])
    if not pairs:
        sys.exit("nothing to do")

    defined = set()
    for f in sources():
        defined |= set(re.findall(r'^([A-Za-z_][A-Za-z0-9_]*)::?', open(f, errors="replace").read(), re.M))
        defined |= set(re.findall(r'^DEF\s+([A-Za-z_][A-Za-z0-9_]*)', open(f, errors="replace").read(), re.M))
    for old, new in pairs:
        if old.startswith('$'):
            # address -> symbol: the symbol must already be defined in the memory map
            if new not in defined:
                sys.exit(f"refusing: {new!r} is not defined in hram.asm/wram.asm")
        elif new in defined:
            sys.exit(f"refusing: target name {new!r} already exists")

    backup = tempfile.mkdtemp(prefix="sml-rename-")
    for f in sources():
        os.makedirs(os.path.join(backup, os.path.dirname(f)), exist_ok=True)
        shutil.copy2(f, os.path.join(backup, f))

    counts = {}
    for f in sources():
        text = orig = open(f, errors="replace").read()
        for old, new in pairs:
            if old.startswith('$') and (f in ("hram.asm", "wram.asm") or f.startswith("inc/")):
                continue
            pat = (rf'(?<![A-Za-z0-9_$]){re.escape(old)}(?![A-Za-z0-9_])'
                   if old.startswith('$') else rf'\b{re.escape(old)}\b')
            text, n = re.subn(pat, new, text)
            counts[old] = counts.get(old, 0) + n
        if text != orig:
            open(f, "w").write(text)

    missed = [o for o, _ in pairs if counts.get(o, 0) == 0]
    ok = subprocess.run(["tools/verify.sh"], capture_output=True, text=True)
    if ok.returncode != 0:
        for f in sources():
            shutil.copy2(os.path.join(backup, f), f)
        shutil.rmtree(backup)
        sys.exit(f"REVERTED — build changed or failed:\n{ok.stdout}{ok.stderr}")
    shutil.rmtree(backup)

    for old, new in pairs:
        print(f"  {old:24s} -> {new:<28s} {counts.get(old,0):4d} sites")
    if missed:
        print(f"WARNING: no occurrences found for: {', '.join(missed)}")
    print(f"verified output-neutral ({len(pairs)} renames)")

main()
