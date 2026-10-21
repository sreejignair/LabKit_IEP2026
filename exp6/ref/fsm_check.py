"""Cycle-level simulation of the bf_core state machine.

This is not a Verilog simulator. It reproduces the state sequence, the one-cycle
memory latency and the register updates exactly as written in bf_core.v, so that a
timing error in the FSM - reading s0 or s1 on the wrong cycle - is caught here.
"""
import numpy as np, bf_golden as G

d = G.build()
mem, di, df, apod = d["mem"], d["di"], d["df"], d["apod"]
N_CH, FRAC_W, ACC_W = G.N_CH, G.FRAC_W, G.ACC_W

S_IDLE, S_RD0, S_WAIT, S_RD1, S_MAC = range(5)

def sat(v, w):
    lo, hi = -(1 << (w-1)), (1 << (w-1))-1
    return (max(lo, min(hi, v)), not (lo <= v <= hi))

results, cycles = [], 0
for p in range(G.N_PTS):
    state, ch, acc, s0 = S_RD0, 0, 0, 0
    mem_ch, mem_addr = 0, 0
    q = 0                      # memory output register, 1 cycle latency
    done_pt = False
    while not done_pt:
        q_next = int(mem[mem_addr, mem_ch])          # sampled at this posedge
        if state == S_RD0:
            mem_ch, mem_addr = ch, int(di[p, ch]); state = S_WAIT
        elif state == S_WAIT:
            mem_addr = int(di[p, ch]) + 1;           state = S_RD1
        elif state == S_RD1:
            s0 = q                                   # q must be s0 here
            assert s0 == int(mem[int(di[p, ch]), ch]), f"s0 wrong at p={p} ch={ch}"
            state = S_MAC
        elif state == S_MAC:
            s1 = q                                   # q must be s1 here
            assert s1 == int(mem[int(di[p, ch])+1, ch]), f"s1 wrong at p={p} ch={ch}"
            samp = s0 + (((s1 - s0) * int(df[p, ch])) >> FRAC_W)
            acc, _ = sat(acc + samp * int(apod[ch]), ACC_W)
            if ch == N_CH-1:
                results.append(acc); done_pt = True
            else:
                ch += 1; state = S_RD0
        q = q_next
        cycles += 1

results = np.array(results, dtype=np.int64)
assert np.array_equal(results, d["y_fix"]), "FSM result differs from the golden model"
print(f"FSM simulation matches the golden model on all {G.N_PTS} points")
print(f"cycles per output point : {cycles//G.N_PTS}  ({N_CH} channels)")
print(f"total cycles for a line : {cycles}")
print(f"at 100 MHz that is      : {cycles/100e6*1e6:.1f} us per line")
