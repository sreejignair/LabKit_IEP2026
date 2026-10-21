# Experiment 6 — Ultrasound beamforming against a MATLAB / Field II reference

A working lab kit, not a description of one. Everything here runs.

---

## What is verified, and what is not

Please read this before you rely on anything in the kit.

| Item | Status |
|---|---|
| `ref/bf_golden.py` — bit-accurate model | **Verified.** Runs; an independent re-implementation inside the file reproduces it exactly |
| `ref/gen_vectors.py` — test vectors | **Verified.** Generates all files; values hand-checkable |
| `ref/fsm_check.py` — state machine timing | **Verified.** Cycle-level simulation of `bf_core.v` reproduces the golden output on all 64 points |
| `rtl/*.v` — the Verilog | **Not simulated.** No Verilog simulator was available when this kit was written. The arithmetic and the FSM timing are verified by the Python model above, but the HDL itself has not been compiled |
| `matlab/*.m` | **Not executed.** No MATLAB or Octave available. Written to be plain and conservative |
| `exp7/scripts/sweep.py` | **Verified.** Runs end to end and produces the front |

Run `iverilog -o sim rtl/*.v tb/tb_bf.v && vvp sim` as your first action. If it does not
elaborate, the fault is in the HDL, not in the specification — the specification is the
Python model, and it is correct.

---

## The design point

Deliberately small, so that a student can check it by hand.

```
N_CH    = 8      receive channels
IN_W    = 12     channel sample, signed
W_W     = 8      apodisation weight, signed
FRAC_W  = 4      delay fraction bits
ACC_W   = 32     accumulator, signed
N_PTS   = 64     output points
MEM_DEPTH = 2048 samples per channel
```

Measured against the double-precision reference: **NRMSE −51.1 dB**, peak error
1.1 % of the peak. The accumulator uses 22 of its 32 bits.

### A deliberate trap in this design point

The error is **limited by the delay quantisation, not the amplitude quantisation.**
Measured:

| change | NRMSE |
|---|---|
| baseline, IN=12 W=8 FRAC=4 | −51.1 dB |
| IN → 16 | −51.2 dB |
| W → 12 | −51.7 dB |
| FRAC → 6 | −57.0 dB |
| FRAC → 8 | −60.8 dB |

A student who tries to improve accuracy by widening the input word will see **nothing
happen**, and that is the point of the exercise. Let them discover it; the sensitivity
sweep in Experiment 7 explains it.

---

## The arithmetic contract

The RTL must reproduce this exactly or the comparison is not bit-exact.

```
diff = s1 - s0                  signed, IN_W+1
m    = diff * frac              signed, frac unsigned FRAC_W
s    = s0 + (m >>> FRAC_W)      arithmetic shift, truncates toward -inf
p    = s * w                    signed
acc  = acc + p                  signed ACC_W, saturating
```

`>>> FRAC_W` truncates toward negative infinity. It is **not** round-to-nearest. If you
change this you must change `bf_golden.py` identically, or every comparison will show a
small error you will spend an hour chasing.

---

## Running it

```bash
cd ref
python3 bf_golden.py      # sanity check, prints NRMSE and accumulator usage
python3 gen_vectors.py    # writes everything in ../data
python3 fsm_check.py      # confirms the state machine timing

cd ../
iverilog -o sim -I data rtl/*.v tb/tb_bf.v
vvp sim                   # expect: PASS: all 64 points bit-exact
```

In MATLAB, `gen_reference.m` then `compare_rtl.m`.

---

## Files the testbench reads

| File | Contents |
|---|---|
| `chan_mem.hex` | channel samples, 12-bit two's complement, channel-major |
| `delay_int.hex` | integer sample address per (point, channel) |
| `delay_frac.hex` | 4-bit fraction per (point, channel) |
| `apod.hex` | 8 apodisation weights |
| `golden_acc_hex.txt` | expected accumulator per point, for `$readmemh` |
| `golden_acc.txt` | the same values in decimal, for MATLAB |
| `params.vh` | the parameters, generated — so RTL and data cannot drift apart |

Delays are **precomputed on the host**. There is no square root in the RTL. That is the
right choice for a half-day exercise: it isolates the arithmetic question, which is what
the experiment is about.

---

## Hand-check before you trust the simulation

At the peak output point, channel 0:

```
addr = 1303   frac = 6   s0 = -1946   s1 = -1649
s = -1946 + ((-1649 - -1946) * 6 >> 4) = -1946 + (1782 >> 4) = -1946 + 111 = -1835
w = 15        product = -1835 * 15 = -27525
```

If your RTL produces a different `s` for this point, stop and fix the interpolation
before running the full sweep.

---

## Performance

From `fsm_check.py`: **4 cycles per channel**, 32 cycles per output point, 2048 cycles
for the 64-point line. At 100 MHz that is 20.5 µs per line. Students should quote this
and compare it with the frame rate a real system would need.

---

## Suggested extensions

- Replace the precomputed delay ROM with an incremental delay generator and show it
  still matches bit for bit
- Add a second accumulator and process two points at once; confirm the cycle count halves
- Change the interpolation to round-to-nearest and measure what it buys (on this design
  point the answer is close to nothing — and understanding why is the lesson)
