# Experiment 7 — Accuracy against hardware cost

Runs directly on the Experiment 6 beamformer. No new RTL is required to produce the
analysis; the RTL work is the synthesis subset in task 4.

---

## What is verified

`scripts/sweep.py` runs end to end and produces the table below. The **error column is
measured** on the bit-accurate model; the **cost column is an analytical model**. Keeping
those two apart is the methodological point of the experiment.

---

## The measured front

80 configurations, 15 non-dominated:

```
 cost   NRMSE      configuration
   62  -36.55 dB   IN=6  W=4  FRAC=2
   69  -37.99 dB   IN=6  W=4  FRAC=3
   81  -38.88 dB   IN=6  W=6  FRAC=3
   82  -39.17 dB   IN=8  W=4  FRAC=2
   91  -42.90 dB   IN=8  W=4  FRAC=3
  100  -43.77 dB   IN=8  W=4  FRAC=4
  107  -45.97 dB   IN=8  W=6  FRAC=3
  116  -48.16 dB   IN=8  W=6  FRAC=4
  134  -48.36 dB   IN=8  W=6  FRAC=6
  144  -52.43 dB   IN=10 W=6  FRAC=4
  166  -57.47 dB   IN=10 W=6  FRAC=6
  198  -60.88 dB   IN=12 W=6  FRAC=6
  262  -61.40 dB   IN=16 W=6  FRAC=6
  270  -61.60 dB   IN=12 W=12 FRAC=6
  358  -62.27 dB   IN=16 W=12 FRAC=6
```

### What the front says

**Delay fraction bits dominate.** Every configuration past cost 134 on the front has
FRAC=6. Widening the input word alone moves almost nothing: IN=12→16 at W=6 FRAC=6 costs
64 more and buys 0.5 dB.

**The knee is around cost 166**, IN=10 W=6 FRAC=6 at −57.5 dB. Going from there to the
best available point costs 2.2× the area for 4.8 dB.

**Weight width barely matters here.** W=6 appears throughout the upper front; W=12 buys
0.2 dB at 72 more cost. With only 8 channels the apodisation is coarse anyway.

Students should reach these conclusions themselves. They are listed here so you can tell
quickly whether a group's sweep is working.

---

## Running it

```bash
cd scripts
python3 sweep.py        # about a minute; writes ../data/sweep.csv and pareto.csv
```

Each configuration is averaged over **six scatterer configurations**. This matters: on a
single scatterer the weight-width curve is not monotonic and appears to show that fewer
bits are better. Averaging removes the artefact. If a group reports a non-monotonic
curve, ask how many cases they averaged.

---

## The cost model, and its limits

```
cost = IN_W * W_W            multiplier
     + (IN_W+1) * FRAC_W     interpolation multiplier
     + IN_W * 4              sample memory
```

It is a proxy, and task 6 exists because it is wrong in an instructive way. On an FPGA
with hard DSP blocks the multiplier cost is a **step function**, not a product: anything
that fits one DSP48 costs one DSP48, and anything that does not costs several plus
fabric. A group that synthesises six points and plots them against this model will see
the steps, and explaining them is where the marks are.

---

## Deliverable

A recommendation in four parts:

1. the choice — every word length, the rounding mode, the accumulator width
2. the evidence — measured error, measured resource, position on the front
3. the condition — test data, channel count, metric
4. the sensitivity — what would change it, and which parameter to move first

Six sentences is enough. A recommendation without a front behind it is an opinion.
