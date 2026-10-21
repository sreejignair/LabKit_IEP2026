# LabKit IEP 2026 — Mixed Precision for FPGA

Laboratory kit for **Experiment 6** (fixed-point beamforming against a MATLAB / Field II
reference) and **Experiment 7** (accuracy against hardware cost).

Everything here runs. The reference models were executed and their outputs are committed,
so a student can check their work without regenerating anything.

---

## Repository layout

```
docs/
  LAB_MANUAL_EXP6.md      full manual: theory, procedure, checkpoints, assessment
  LAB_MANUAL_EXP7.md      full manual for the trade-off analysis
  EXP6_NOTES.md           design notes and verification status
  EXP7_NOTES.md           design notes and expected results

exp6/
  ref/                    Python reference models — the specification
    bf_golden.py          bit-accurate model of the beamformer
    gen_vectors.py        writes every file the testbench reads
    fsm_check.py          cycle-level check of the RTL state machine
    gen_trace.py          cycle-by-cycle golden trace, for debugging
  rtl/                    Verilog
    bf_core.v             datapath and FSM
    bf_mem.v              channel memory and the two ROMs
    bf_top.v              sweeps all output points
  tb/tb_bf.v              self-checking testbench
  matlab/                 Field II reference generation and comparison
  data/                   generated vectors and golden results (committed)

exp7/
  scripts/sweep.py        parameter sweep and Pareto analysis
  data/                   sweep.csv and pareto.csv (committed)

slides/                   presentation decks — see the status note below
```

---

## Quick start

Requires Python 3 with numpy, a Verilog simulator (Icarus or equivalent), and MATLAB or
Octave for the reference comparison.

```bash
git clone https://github.com/sreejignair/LabKit_IEP2026.git
cd LabKit_IEP2026

# Experiment 6 — check the reference models
cd exp6/ref
python3 bf_golden.py        # expect: NRMSE -51.1 dB, 22 bits used
python3 gen_vectors.py      # regenerates ../data
python3 fsm_check.py        # expect: matches on all 64 points
python3 gen_trace.py        # writes the cycle-by-cycle trace

# Experiment 6 — simulate the RTL
cd ../..
iverilog -o sim -I exp6/data exp6/rtl/*.v exp6/tb/tb_bf.v
vvp sim                     # expect: PASS: all 64 points bit-exact

# Experiment 7 — the sweep
cd exp7/scripts
python3 sweep.py            # about a minute; expect 80 configs, 15 non-dominated
```

---

## Experiment 6 — step by step

Full detail in `docs/LAB_MANUAL_EXP6.md`. Summary:

**Phase 1 — reference and data (45 min)**

1. Run `bf_golden.py`. Confirm NRMSE is **−51.1 dB** and the accumulator uses **22 bits**.
2. Run `gen_vectors.py`. Open `exp6/data/delay_int.hex` and confirm entry 0 is `04df`
   (1247 decimal), and `delay_frac.hex` entry 0 is `6`.
3. Reproduce the hand-check by hand: at the peak point, channel 0, `addr = 1303`,
   `frac = 6`, `s0 = −1946`, `s1 = −1649` gives `s = −1835` and product `−27525`.

**Phase 2 — RTL (90 min)**

4. Read `rtl/bf_core.v` and locate each line of the arithmetic contract.
5. `iverilog -o sim -I exp6/data exp6/rtl/*.v exp6/tb/tb_bf.v && vvp sim`
6. If it fails, run `gen_trace.py` and diff your waveform against
   `exp6/data/golden_trace_point0.txt`. The first differing row names the fault;
   section 8 of the manual maps symptoms to causes.

**Phase 3 — MATLAB comparison (60 min)**

7. `gen_reference.m` — uses Field II if present, otherwise an equivalent synthetic
   generator. Record which you used.
8. Have the testbench write `exp6/data/rtl_out.txt`, one signed decimal value per line.
9. `compare_rtl.m` — reports the bit-exact check, NRMSE and peak error, and plots the
   overlay and error trace.

**Phase 4 — analysis (45 min)**

10. Re-run `bf_golden.py` with `IN_W = 16`, then `W_W = 12`, then `FRAC_W = 6` and `8`.
    Record NRMSE for each.
11. Answer: which term limits this design, and what is the evidence?

**The expected answer.** Delay quantisation dominates. Widening the input word from
12 to 16 bits changes NRMSE by 0.1 dB; raising `FRAC_W` from 4 to 8 gains almost 10 dB.
This is deliberate — a student who tries to buy accuracy with input bits will see
nothing happen.

---

## Experiment 7 — step by step

Full detail in `docs/LAB_MANUAL_EXP7.md`. Summary:

**Phase 1 — plan (45 min)**

1. Write the experiment plan **before running anything**: factors, levels, fixed
   conditions, metric and threshold, number of test cases to average.
2. Have it checked. A sweep run before the plan exists cannot be reported honestly.

**Phase 2 — error sweep (75 min)**

3. `python3 sweep.py` — 80 configurations, averaged over six scatterer cases.
4. Verify two configurations by hand against your Experiment 6 result.
5. Demonstrate the single-case artefact: edit `CASES` down to one scatterer, sweep
   `W_W` alone, and show the curve is **not monotonic**. Restore all six and show it is.

**Phase 3 — resource measurement (60 min)**

6. Pick six configurations spanning the front, including two near the knee.
7. Synthesise each. Record LUT, FF, DSP, BRAM, Fmax. Script it; do not use the GUI.
8. Keep the synthesis setup identical across all six, and record it.

**Phase 4 — analysis (60 min)**

9. Plot accuracy against modelled cost, and against measured DSP count. Mark the
   non-dominated set on both.
10. Explain where the model and the synthesis disagree.
11. Write the recommendation in the four-part form.

**The expected front.** 15 non-dominated points from 80. The knee sits at
`IN_W = 10, W_W = 6, FRAC_W = 6` — cost 166, −57.5 dB. Going beyond it costs 2.2× the
area for 4.8 dB.

---

## The supplied design point

```
N_CH = 8        IN_W = 12      W_W = 8       FRAC_W = 4
ACC_W = 32      N_PTS = 64     MEM_DEPTH = 2048
c = 1540 m/s    f0 = 5 MHz     fs = 40 MHz   pitch = 0.3 mm
single scatterer at 25 mm, depth sweep 24–26 mm
```

Eight channels, not sixty-four, so that a student can hand-check the arithmetic. The
accumulator bound is `IN_W + W_W + log2(N) = 23` bits; measured peak usage is 22, because
the Hann apodisation tapers the outer channels.

---

## The arithmetic contract

Two implementations agree bit for bit only if every width and rounding point agrees.

```
diff = s1 − s0              signed, IN_W+1
m    = diff · frac          signed, frac unsigned FRAC_W
s    = s0 + (m >>> FRAC_W)  arithmetic shift, truncates toward −infinity
p    = s · w                signed
acc  = acc + p              signed ACC_W, saturating
```

`>>> FRAC_W` truncates. It is **not** round-to-nearest. Change it in the RTL and you must
change `bf_golden.py` identically, or every comparison shows an unexplained error.

---

## Verification status

Please read before relying on anything here.

| Component | Status |
|---|---|
| `exp6/ref/*.py` | **executed and verified** |
| `exp6/data/*` | **generated by the verified scripts** |
| `exp6/rtl/*.v` | **written against the verified contract, not compiled** — no Verilog simulator was available when the kit was prepared |
| `exp6/tb/tb_bf.v` | **not compiled** |
| `exp6/matlab/*.m` | **not executed** — no MATLAB or Octave available |
| `exp7/scripts/sweep.py` | **executed and verified**; `pareto.csv` is its actual output |

The Python model is the specification and it is correct. If the Verilog does not
elaborate, fix the HDL against the contract above — do not change the model to match the
HDL.

**First action after cloning:** run the Icarus command in Quick Start. If it fails,
raise an issue so the HDL can be corrected before the session.

---

## Slides — status

`slides/` holds the two presentation decks. They were written **before** the code kit and
quote figures from an earlier 64-channel model:

| | Slides say | This kit gives |
|---|---|---|
| Exp 6, 12b/8b/4 delay bits | −70 dB | **−51.1 dB** |
| Exp 6 channel count | 64 | **8** |
| Exp 7 knee | cost 72, −70 dB | **cost 166, −57.5 dB** |

**Do not present the slides alongside this kit until they are regenerated.** The manuals
in `docs/` are authoritative; the slides are not yet consistent with them.

---

## Contributing

- Never edit `exp6/data/` by hand — regenerate with `gen_vectors.py`
- `params.vh` is generated, so the RTL and the data cannot drift apart
- If you change the arithmetic contract, change `bf_golden.py` and the RTL in the same
  commit, and regenerate the vectors
