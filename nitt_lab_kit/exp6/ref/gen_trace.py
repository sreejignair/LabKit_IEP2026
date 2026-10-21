"""Cycle-by-cycle golden trace for the first output point.

Lets a student line their simulator waveform up against known-good values and find
the exact cycle where their RTL diverges, instead of guessing.
"""
import os
import numpy as np
import bf_golden as G

d = G.build()
mem, di, df, apod = d["mem"], d["di"], d["df"], d["apod"]
S_RD0, S_WAIT, S_RD1, S_MAC = "RD0", "WAIT", "RD1", "MAC"
NAMES = {S_RD0: 1, S_WAIT: 2, S_RD1: 3, S_MAC: 4}

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
POINT = 0

rows, cyc = [], 0
state, ch, acc, s0, q = S_RD0, 0, 0, 0, 0
mem_ch = mem_addr = 0
done = False
while not done:
    q_next = int(mem[mem_addr, mem_ch])
    rec = dict(cyc=cyc, state=state, ch=ch, mem_ch=mem_ch, mem_addr=mem_addr,
               mem_q=q, s0=s0, acc=acc, samp="", prod="")
    if state == S_RD0:
        mem_ch, mem_addr = ch, int(di[POINT, ch]); state = S_WAIT
    elif state == S_WAIT:
        mem_addr = int(di[POINT, ch]) + 1;        state = S_RD1
    elif state == S_RD1:
        s0 = q;                                   state = S_MAC
    elif state == S_MAC:
        s1 = q
        samp = s0 + (((s1 - s0) * int(df[POINT, ch])) >> G.FRAC_W)
        prod = samp * int(apod[ch])
        rec["samp"], rec["prod"] = samp, prod
        acc += prod
        if ch == G.N_CH - 1: done = True
        else: ch += 1; state = S_RD0
    rec["acc_next"] = acc
    rows.append(rec)
    q = q_next
    cyc += 1

hdr = ["cyc", "state", "ch", "mem_ch", "mem_addr", "mem_q", "s0", "samp", "prod", "acc_next"]
lines = ["  ".join(f"{h:>9}" for h in hdr)]
for r in rows:
    lines.append("  ".join(f"{str(r[h]):>9}" for h in hdr))
txt = "\n".join(lines)
open(os.path.join(OUT, "golden_trace_point0.txt"), "w").write(
    f"# cycle-by-cycle trace, output point {POINT}\n"
    f"# acc_next is the accumulator AFTER the update on that cycle\n"
    f"# final accumulator for this point: {acc}\n{txt}\n")
print(txt)
print(f"\nfinal accumulator for point {POINT}: {acc}")
assert acc == int(d["y_fix"][POINT]), "trace disagrees with the golden model"
print("trace agrees with the golden model")
