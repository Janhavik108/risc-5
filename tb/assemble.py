#!/usr/bin/env python3
"""Minimal two-pass assembler for the pipeline's RISC ISA (MIPS-style
R-type/I-type encoding). Produces a $readmemh-compatible hex file,
one 32-bit word per line, matching program order (word i -> byte addr 4*i).
"""
import sys

OPCODE = {
    'add': ('R', 0b100000), 'sub': ('R', 0b100010), 'and': ('R', 0b100100),
    'or':  ('R', 0b100101), 'slt': ('R', 0b101010),
    'addi': ('I', 0b001000), 'lw': ('I', 0b100011), 'sw': ('I', 0b101011),
    'beq': ('I', 0b000100),
}

def reg(r):
    return int(r.lstrip('$'))

def assemble(lines):
    # Pass 1: strip comments/labels, record label -> instruction index
    labels = {}
    instrs = []
    for raw in lines:
        line = raw.split('#')[0].strip()
        if not line:
            continue
        if line.endswith(':'):
            labels[line[:-1]] = len(instrs)
            continue
        if ':' in line and not line.startswith('.'):
            lbl, rest = line.split(':', 1)
            labels[lbl.strip()] = len(instrs)
            line = rest.strip()
            if not line:
                continue
        instrs.append(line)

    words = []
    for idx, line in enumerate(instrs):
        parts = line.replace(',', ' ').split()
        mnem = parts[0].lower()
        kind, code = OPCODE[mnem]
        if kind == 'R':
            rd, rs, rt = reg(parts[1]), reg(parts[2]), reg(parts[3])
            word = (0 << 26) | (rs << 21) | (rt << 16) | (rd << 11) | (0 << 6) | code
        else:
            if mnem in ('lw', 'sw'):
                rt = reg(parts[1])
                imm, base = parts[2].split('(')
                rs = reg(base.rstrip(')'))
                imm = int(imm)
            elif mnem == 'beq':
                rs, rt = reg(parts[1]), reg(parts[2])
                target = parts[3]
                if target in labels:
                    imm = labels[target] - (idx + 1)
                else:
                    imm = int(target)
            else:  # addi
                rt, rs = reg(parts[1]), reg(parts[2])
                imm = int(parts[3])
            imm16 = imm & 0xFFFF
            word = (code << 26) | (rs << 21) | (rt << 16) | imm16
        words.append(word & 0xFFFFFFFF)
    return words

def main():
    src_path, out_path = sys.argv[1], sys.argv[2]
    with open(src_path) as f:
        lines = f.readlines()
    words = assemble(lines)
    with open(out_path, 'w') as f:
        for w in words:
            f.write(f'{w:08x}\n')
    print(f'Assembled {len(words)} instructions -> {out_path}')

if __name__ == '__main__':
    main()
