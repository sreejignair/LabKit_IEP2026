# Experiment 6 — Fixed-Point Beamforming against a MATLAB / Field II Reference

**Duration** half day (4 hours) · **Prerequisites** Experiments 1 and 2 · **Group size** 2

---

## 1. Learning outcomes

On completing this experiment a student should be able to:

1. Derive the receive focusing delay for a linear array and express it in samples
2. Decompose a delay into an integer memory address and a fractional interpolation weight
3. State a fixed-point arithmetic contract precisely enough that two independent
   implementations produce bit-identical results
4. Size an accumulator from the operand widths and the channel count, by derivation
5. Verify an RTL datapath against a numerical reference, and localise a mismatch to a
   single arithmetic stage
6. Distinguish error caused by amplitude quantisation from error caused by delay
   quantisation, from the shape of the error trace alone

---

## 2. Theory

### 2.1 The receive delay

A point at depth `z` on the array axis, with element `i` at lateral position `x_i`:

```
    r_i   = sqrt( x_i² + z² )             receive path length
    tau_i = ( z + r_i ) / c               transmit (plane wave) + receive
    n_i   = tau_i · fs                    delay in samples
```

The transmit term is `z` because a plane-wave transmit is assumed. For a focused
transmit, replace `z` with the transmit path to the focus and back.

`n_i` is not an integer. Writing `F` for the number of fraction bits:

```
    N_i      = round( n_i · 2^F )
    n_int    = N_i >> F                   memory address
    n_frac   = N_i & (2^F − 1)            interpolation weight, 0 … 2^F − 1
```

**Worked example.** `z = 24 mm`, element 0 at `x = −1.05 mm`, `c = 1540 m/s`,
`fs = 40 MHz`, `F = 4`:

```
    r_0  = sqrt(1.05² + 24²) mm = 24.0230 mm
    tau  = (24 + 24.0230)e-3 / 1540 = 31.1838 µs
    n    = 31.1838e-6 × 40e6 = 1247.35 samples
    N    = round(1247.35 × 16) = 19958
    n_int = 19958 >> 4 = 1247      n_frac = 19958 & 15 = 6
```

Confirm this against `delay_int.hex` and `delay_frac.hex`, entries for point 0,
channel 0. If your arithmetic disagrees, resolve it before continuing — everything
downstream depends on it.

### 2.2 Linear interpolation, and why the fraction width matters

```
    s = s0 + ( (s1 − s0) · frac ) >>> F
```

The worst-case interpolation error occurs midway between samples. For a sinusoid of
frequency `f0` sampled at `fs`, linear interpolation between two neighbours gives

```
    interpolated = true · cos( π f0 / fs )
```

so the worst-case relative amplitude error is

```
    1 − cos( π f0 / fs ) = 1 − cos(22.5°) = 0.0761    at f0 = 5 MHz, fs = 40 MHz
```

about 7.6 %, or −22.4 dB at the midpoint. This is the worst case, at `frac = 0.5`;
averaged over the sweep the contribution is far smaller, which is why the measured
NRMSE is −51 dB and not −22 dB. Separately, quantising the delay to `F` fraction bits
introduces a timing error uniformly distributed over ±2^-(F+1) samples, which for a
narrowband signal appears as a phase error and therefore as a loss of coherence across
the aperture.

**This is the dominant error term in the supplied design point.** Section 7 asks you to
demonstrate that.

### 2.3 Accumulator width, derived

Let the channel sample be `IN_W` bits signed and the apodisation weight `W_W` bits
signed. The interpolated sample `s` lies between `s0` and `s1`, so it still occupies
`IN_W` bits. The product occupies `IN_W + W_W` bits. Summing `N` such products:

```
    ACC_W ≥ IN_W + W_W + ceil( log2 N )
```

For the supplied design point, `12 + 8 + log2(8) = 12 + 8 + 3 = 23 bits`.

The kit uses `ACC_W = 32`. Measured peak usage on the supplied stimulus is **22 bits** —
below the bound because the Hann apodisation tapers the outer channels, so the worst case
is never reached. Record both numbers: the bound and the measured usage. The gap is a
legitimate finding, not an error.

### 2.4 The arithmetic contract

Two implementations agree bit-for-bit only if every width and every rounding point
agrees. The contract for this experiment:

```
    diff = s1 − s0                 signed, IN_W+1 bits
    m    = diff · frac             signed, frac unsigned F bits
    s    = s0 + (m >>> F)          arithmetic shift, truncates toward −infinity
    p    = s · w                   signed, IN_W+W_W+1 bits
    acc  = acc + p                 signed ACC_W, saturating
```

`>>> F` is a truncation, **not** round-to-nearest. It biases every interpolated sample
slightly negative. This is a deliberate choice: it is the cheapest hardware, and
Experiment 7 asks whether it is worth replacing.

---

## 3. The supplied design point

```
    N_CH      = 8        receive channels
    IN_W      = 12       channel sample, signed
    W_W       = 8        apodisation weight, signed
    FRAC_W    = 4        delay fraction bits
    ACC_W     = 32       accumulator, signed
    N_PTS     = 64       output points
    MEM_DEPTH = 2048     samples per channel
    c = 1540 m/s   f0 = 5 MHz   fs = 40 MHz   pitch = 0.3 mm
    single scatterer at z = 25 mm, on axis
    depth sweep 24 mm to 26 mm
```

Expected result against the double-precision reference: **NRMSE −51.1 dB**, peak error
1.1 % of peak.

---

## 4. Pre-lab preparation

Submit before the session. Answers are discussed in the first fifteen minutes.

**Q1** Compute `n_int` and `n_frac` for point 0, channel 3, from the parameters in
section 3. Show the arithmetic.

**Q2** The depth sweep runs 24 mm to 26 mm. Compute the smallest and largest sample
address the beamformer will request, and hence the minimum `MEM_DEPTH`.
*(Check: the supplied kit requests addresses 1246 to 1352.)*

**Q3** Derive the accumulator bound for `N_CH = 64` with the same operand widths. State
whether 32 bits still suffices.

**Q4** For `IN_W = 12`, what is the numerical value of one LSB if the scale factor is
`max|x| = 1.0`? Express the worst-case interpolation error from section 2.2 in LSB, and
comment on whether interpolation or amplitude quantisation is the larger term.

**Q5** `s0 = −1946`, `s1 = −1649`, `frac = 6`, `F = 4`. Compute `s` using the contract
in section 2.4. Then compute it again using round-to-nearest instead of truncation, and
state the difference in LSB.

---

## 5. Procedure

### Phase 1 — reference and data (45 min)

**Step 1.1** Run the reference generator.

```bash
cd exp6/ref
python3 bf_golden.py
```

Expected output:

```
accumulator range  : -1118460 .. 936174
bits actually used : 22   (ACC_W = 32)
NRMSE vs float ref : -51.1 dB
peak error / peak  : 1.105e-02
independent re-implementation matches: contract is unambiguous
```

**Checkpoint A.** If NRMSE is not −51.1 dB, your environment differs from the supplied
one. Stop and resolve it; every later number depends on this.

**Step 1.2** Generate the test vectors.

```bash
python3 gen_vectors.py
```

This writes `../data/`. Open `delay_int.hex` and confirm entry 0 reads `04df`
(1247 decimal) and `delay_frac.hex` entry 0 reads `6`. This is the answer to pre-lab Q1
for channel 0.

**Step 1.3** Hand-check one multiply-accumulate. At the peak output point, channel 0:

```
    addr = 1303   frac = 6   s0 = −1946   s1 = −1649
    diff = −1649 − (−1946) = 297
    m    = 297 × 6 = 1782
    s    = −1946 + (1782 >> 4) = −1946 + 111 = −1835
    w    = 15
    p    = −1835 × 15 = −27525
```

**Checkpoint B.** Reproduce this by hand. If you cannot, you have misread the contract,
and no amount of RTL debugging will help.

### Phase 2 — RTL (90 min)

**Step 2.1** Read `../exp6/rtl/bf_core.v` and identify, in the code, each line of the contract
in section 2.4. Write the line numbers in your observation sheet.

**Step 2.2** Elaborate and simulate.

```bash
cd ..
iverilog -o sim -I data rtl/*.v tb/tb_bf.v
vvp sim
```

Expected: `PASS: all 64 points bit-exact against the golden model`.

**Step 2.3** If it does not pass, use the cycle trace rather than guessing.

```bash
cd ref && python3 gen_trace.py
```

This writes `data/golden_trace_point0.txt`, a cycle-by-cycle record of state, memory
address, memory output, `s0`, the interpolated sample, the product and the accumulator,
for output point 0. Dump the same signals from your simulation and compare row by row.
The first row that differs names the fault. Section 8 maps the common differences to
their causes.

**Checkpoint C.** Bit-exact on all 64 points.

### Phase 3 — the MATLAB comparison (60 min)

**Step 3.1** Generate the reference in MATLAB.

```matlab
cd exp6/matlab
gen_reference
```

Uses Field II if present, otherwise an equivalent synthetic generator. Record which.

**Step 3.2** Have your testbench write `data/rtl_out.txt`, one signed decimal
accumulator value per line.

**Step 3.3** Compare.

```matlab
compare_rtl
```

Reports the bit-exact check, NRMSE, peak error, and plots the overlay and the error
trace.

**Checkpoint D.** NRMSE within 0.5 dB of −51.1 dB.

### Phase 4 — analysis (45 min)

**Step 4.1** Establish what limits the error. Re-run `bf_golden.py` with each of the
following single changes and record NRMSE:

| change | expected NRMSE |
|---|---|
| baseline | −51.1 dB |
| `IN_W = 16` | −51.2 dB |
| `W_W = 12` | −51.7 dB |
| `FRAC_W = 6` | −57.0 dB |
| `FRAC_W = 8` | −60.8 dB |

**Step 4.2** Answer: which term limits this design, and what is the evidence?

**Checkpoint E.** You can state, with numbers, why widening the input word achieves
nothing here.

---

## 6. Results to record

| Quantity | Your value |
|---|---|
| Reference generator used (Field II or synthetic) | |
| Scale factor | |
| `n_int`, `n_frac` for point 0 channel 0 | |
| Hand-checked product at the peak point | |
| Bit-exact: yes / no | |
| If no, first differing point and cycle | |
| Accumulator bound (derived) | |
| Accumulator peak usage (measured) | |
| NRMSE against the double-precision reference | |
| Peak error, as a fraction of peak | |
| Cycles per output point | |
| Cycles per line, and µs at your clock | |
| NRMSE at `FRAC_W = 6` | |
| Which term limits the error, and why | |

---

## 7. Analysis questions

**A1** The accumulator bound is 23 bits but only 22 are used. Explain the discrepancy
in terms of the apodisation window, and state the stimulus that would reach the bound.

**A2** Your error trace is concentrated at the pulse and near zero elsewhere. What does
that tell you about the dominant error source? What would a delay-limited error trace
look like instead?

**A3** Widening `IN_W` from 12 to 16 changed NRMSE by 0.1 dB. Explain this using the
idea of a dominant error term, and predict what `IN_W = 8` would give.

**A4** The interpolation truncates rather than rounds. Predict the sign of the mean
error this introduces, then measure it. Does it match your prediction?

**A5** The design uses 4 cycles per channel. Identify which of the four is a wasted
cycle for a memory with one cycle of latency, and propose a restructuring that removes
it. What does it cost?

**A6** If the transmit were focused at 25 mm rather than plane-wave, which equation in
section 2.1 changes, and would the delay table still be valid at 24 mm?

---

## 8. Troubleshooting

Use the cycle trace. Compare your simulation against
`data/golden_trace_point0.txt` row by row; the first mismatch names the fault.

| Symptom in the trace | Cause |
|---|---|
| `mem_q` correct but one cycle late everywhere | memory modelled with 2-cycle latency, or an extra register in the path |
| `s0` captured equal to `s1` | `s0` latched in the wrong state — it must be captured in `RD1`, not `MAC` |
| `samp` correct for positive samples, wrong for negative | logical shift `>>` used instead of arithmetic `>>>`, or a wire not declared `signed` |
| `samp` off by one for some frac values | rounding added to the shift; the contract specifies truncation |
| `prod` sign wrong | apodisation ROM read as unsigned |
| `acc` correct for a few channels then diverges | accumulator narrower than `ACC_W`, or sign extension of the product truncated |
| `acc` correct but the final `result` is wrong | `result` captured one cycle early, before the last accumulate |
| Everything correct but every point is zero | delay addresses outside the written region of the memory — check `MEM_DEPTH` |

**The last row is the most common failure in this experiment.** The pulse sits around
sample 1300. A memory sized 1024 would contain only zeros at the addresses the
beamformer requests, and every output would be zero with no error message. The assertion
in `delay_tables()` exists to catch exactly this.

---

## 9. Assessment

| Component | Marks | Earned by |
|---|---|---|
| Pre-lab | 10 | all five questions attempted, arithmetic shown |
| Reference and vectors | 15 | checkpoints A and B, hand-check reproduced |
| RTL correctness | 30 | checkpoint C, bit-exact on all 64 points |
| Comparison | 20 | checkpoint D, NRMSE and peak error quantified, error trace plotted |
| Analysis | 20 | checkpoint E, A1–A6 answered with evidence |
| Observation sheet | 5 | complete and legible |

A mismatch that is correctly diagnosed using the cycle trace earns more than an
undiagnosed pass.

---

## Appendix A — file formats

| File | Format |
|---|---|
| `chan_mem.hex` | `IN_W`-bit two's complement, one word per line, channel-major: all `MEM_DEPTH` words of channel 0, then channel 1 … |
| `delay_int.hex` | 16-bit, one per (point, channel), point-major |
| `delay_frac.hex` | `FRAC_W`-bit, same ordering |
| `apod.hex` | `W_W`-bit, one per channel |
| `golden_acc_hex.txt` | `ACC_W`-bit two's complement, for `$readmemh` |
| `golden_acc.txt` | the same in signed decimal, for MATLAB |
| `golden_trace_point0.txt` | cycle-by-cycle reference for point 0 |
| `params.vh` | generated Verilog parameters — never edit by hand |

## Appendix B — verification status of the supplied kit

| Component | Status |
|---|---|
| `bf_golden.py`, `gen_vectors.py`, `fsm_check.py`, `gen_trace.py` | executed and verified |
| `rtl/*.v` | written against the verified contract, **not compiled** — no simulator was available when the kit was prepared |
| `matlab/*.m` | written, **not executed** |

If the Verilog does not elaborate, the specification is still correct: it is the Python
model. Fix the HDL against section 2.4.
