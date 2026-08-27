#!/usr/bin/env python3
"""Parse and edit the ds-allocated memory maps (hram.asm / wram.asm).

  tools/memmap.py dump hram.asm            # every slot with its resolved address
  tools/memmap.py check hram.asm           # verify resolved addrs vs the inline ; XXXX comments
  tools/memmap.py add hram.asm ADDR NAME [comment]   # name a byte, splitting ds runs
"""
import re, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
BASE = {"hram.asm": 0xFF80, "wram.asm": 0xC000}

def parse(path):
    """-> list of slots [{addr, size, name, comment, line_idx}], plus raw lines."""
    lines = open(path, errors="replace").read().splitlines()
    addr = BASE[path]
    slots, pending = [], None
    for i, raw in enumerate(lines):
        code = raw.split(";")[0].strip()
        comment = raw.split(";", 1)[1].strip() if ";" in raw else ""
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)::?\s*(.*)$', code)
        if m:
            pending = (m.group(1), comment, i)
            rest = m.group(2).strip()
            if not rest: continue
            code = rest          # label and directive share one line
        m = re.match(r'^(ds|db|dw)\b(.*)$', code)
        if m:
            kind, arg = m.group(1), m.group(2).strip()
            if kind == "db": size = 1
            elif kind == "dw": size = 2
            elif not arg: size = 1
            else:
                expr = arg.replace("$", "0x")
                try: size = eval(expr, {"__builtins__": {}}, {})
                except Exception: sys.exit(f"{path}:{i+1}: cannot evaluate size {arg!r}")
            name, cmt, li = pending if pending else (None, comment, i)
            slots.append(dict(addr=addr, size=size, name=name, comment=cmt, line=li, end=i))
            addr += size; pending = None
    return slots, lines, addr

def cmd_dump(path):
    slots, _, end = parse(path)
    for s in slots:
        tag = s["name"] or "-"
        print(f"  ${s['addr']:04X}+{s['size']:<4d} {tag:32s} {s['comment'][:44]}")
    print(f"  end = ${end:04X}")

def cmd_check(path):
    """The files carry ; FFxx comments. Resolved address must agree -> proves the arithmetic."""
    slots, _, end = parse(path)
    bad = ok = 0
    for s in slots:
        m = re.search(r'\b((?:FF|C|D)[0-9A-F]{2,3})\b', s["comment"].upper())
        if not m: continue
        want = int(m.group(1), 16)
        if want == s["addr"]: ok += 1
        else:
            bad += 1
            print(f"  MISMATCH {s['name'] or '-'}: comment says ${want:04X}, resolves to ${s['addr']:04X}")
    print(f"{path}: {ok} addresses agree with their comment, {bad} disagree, end=${end:04X}")
    return bad

def cmd_add(path, addr_s, name, comment=""):
    addr = int(addr_s.lstrip("$"), 16)
    slots, lines, _ = parse(path)
    tgt = next((s for s in slots if s["addr"] <= addr < s["addr"] + s["size"]), None)
    if tgt is None: sys.exit(f"${addr:04X} is outside {path}")
    if tgt["name"] and tgt["size"] == 1:
        sys.exit(f"${addr:04X} is already named {tgt['name']}")
    if tgt["name"]: sys.exit(f"${addr:04X} falls inside named block {tgt['name']}")
    before = addr - tgt["addr"]
    after = tgt["addr"] + tgt["size"] - addr - 1
    block = []
    if before: block.append(f"\tds {before}\t\t; {tgt['addr']:04X}")
    block.append(f"{name}:: ; {addr:04X}" + (f" {comment}" if comment else ""))
    block.append("\tds 1")
    if after: block.append(f"\tds {after}\t\t; {addr+1:04X}")
    lines[tgt["line"]:tgt["end"] + 1] = block
    open(path, "w").write("\n".join(lines) + "\n")

cmd = sys.argv[1]
if cmd == "dump": cmd_dump(sys.argv[2])
elif cmd == "check": sys.exit(1 if cmd_check(sys.argv[2]) else 0)
elif cmd == "add": cmd_add(*sys.argv[2:])
else: sys.exit(__doc__)
