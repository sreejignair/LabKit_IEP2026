# Experiment 7 — Accuracy against Hardware Cost

**Duration** half day (4 hours) · **Prerequisites** Experiments 4 and 6 · **Group size** 2

---

## 1. Learning outcomes

On completing this experiment a student should be able to:

1. Design a parameter sweep that isolates one factor at a time
2. Distinguish a measured quantity from a modelled one, and report each correctly
3. Recognise and correct a non-monotonic result caused by a single test case
4. Construct a Pareto front and identify the non-dominated set
5. Locate the knee of a front and explain why it is not automatically the answer
6. State a precision recommendation in a form that survives review

---

## 2. Theory

### 2.1 Two different quantities

**Accuracy** is measured. You run the design and compare against a reference.

**Resource** can be either measured or modelled. Synthesis measures it; an analytical
model estimates it. The two are not interchangeable, and a report that confuses them is
not reproducible.

This experiment uses:

```
    error  = NRMSE in dB, measured on the bit-accurate model of Experiment 6
    cost   = IN_W · W_W            multiplier
           + (IN_W+1) · FRAC_W     interpolation multiplier
           + IN_W · 4              sample memory
```

The cost expression is a **model**. Task 4 asks you to replace part of it with real
synthesis numbers and explain the disagreement.

### 2.2 Why the cost model fails on an FPGA

The model assumes multiplier area scales with the product of operand widths, which is
true for fabric multipliers built from LUTs. On an FPGA with hard DSP blocks it is
false: a DSP48E1 provides a 25 × 18 signed multiplier, so

- any operand pair fitting inside 25 × 18 costs **one DSP block**, whether it is
  4 × 4 or 24 × 17
- anything larger costs **several DSP blocks plus fabric glue**

So the real cost curve is a **step function**, not a product. Below the step the model
over-penalises wide operands; above it, the model badly under-penalises them. Finding
and explaining the steps is the core analytical work of this experiment.

### 2.3 Dominance

Configuration **A dominates B** if A is at least as accurate as B and costs no more.
A dominated configuration should never be chosen: something else is better or equal on
both axes.

The **non-dominated set**, or Pareto front, is everything not dominated by anything
else. A legitimate choice always lies on the front.

The **knee** is where the front changes slope — past it, further accuracy costs
disproportionately. It is usually, but not always, the right answer. If the
specification demands more accuracy than the knee provides, the knee is irrelevant and
you pay for the front point that meets the specification.

### 2.4 Why one test case is not enough

Quantisation error is **deterministic** for a fixed input. For one particular stimulus a
particular delay alignment can cause errors to cancel by coincidence. That cancellation
does not generalise.

The visible symptom is a **non-monotonic curve**: more bits measuring worse than fewer.
A student who reports this as a finding has reported an artefact. Averaging over several
distinct stimuli breaks the coincidence and restores monotonicity.

The supplied sweep averages over **six scatterer configurations** for this reason.

---

## 3. Expected results

These are produced by the supplied `exp7/scripts/sweep.py`, which averages over six
cases. Use them to check that a group's sweep is working.

### 3.1 The Pareto front

80 configurations, 15 non-dominated:

| cost | NRMSE | IN_W | W_W | FRAC_W |
|---:|---:|---:|---:|---:|
| 62 | −36.55 dB | 6 | 4 | 2 |
| 69 | −37.99 dB | 6 | 4 | 3 |
| 81 | −38.88 dB | 6 | 6 | 3 |
| 82 | −39.17 dB | 8 | 4 | 2 |
| 91 | −42.90 dB | 8 | 4 | 3 |
| 100 | −43.77 dB | 8 | 4 | 4 |
| 107 | −45.97 dB | 8 | 6 | 3 |
| 116 | −48.16 dB | 8 | 6 | 4 |
| 134 | −48.36 dB | 8 | 6 | 6 |
| 144 | −52.43 dB | 10 | 6 | 4 |
| **166** | **−57.47 dB** | **10** | **6** | **6** |
| 198 | −60.88 dB | 12 | 6 | 6 |
| 262 | −61.40 dB | 16 | 6 | 6 |
| 270 | −61.60 dB | 12 | 12 | 6 |
| 358 | −62.27 dB | 16 | 12 | 6 |

### 3.2 What the front says

**Delay fraction bits dominate.** Every front point above cost 134 has `FRAC_W = 6`.

**The knee is at cost 166** — `IN_W = 10`, `W_W = 6`, `FRAC_W = 6`, giving −57.5 dB.
Moving from there to the best point on the front costs **2.2× the area for 4.8 dB**.

**Widening the input word alone buys almost nothing.** From cost 198 to 262 —
`IN_W` 12 → 16 at the same weights and delay — costs 64 more and gains **0.5 dB**.

**Weight width barely matters at eight channels.** `W_W = 6` appears throughout the
upper front; `W_W = 12` buys 0.2 dB for 72 more cost. With only eight channels the
apodisation window is coarse, so extra weight resolution has nothing to resolve.

---

## 4. Pre-lab preparation

**Q1** Configuration A costs 64 at −66 dB; B costs 72 at −70 dB. Is A dominated?
Is B? Justify both answers from the definition in section 2.3.

**Q2** Using the cost model in section 2.1, compute the cost of `IN_W = 12`,
`W_W = 8`, `FRAC_W = 4`. Then state what that configuration would cost in DSP blocks
on a device whose hard multiplier is 25 × 18.

**Q3** A sweep shows error improving 6 dB per bit, then flattening. Explain the
flattening in terms of a dominant error term, and state which parameter you would
change next.

**Q4** Propose a single-number cost function combining error and resource. State
explicitly what its weighting assumes about the application.

**Q5** A configuration meets the error target but misses the timing constraint. Is it
on the front? Explain what a two-axis front cannot show.

---

## 5. Procedure

### Phase 1 — plan the experiment (45 min)

**Step 1.1** Write the experiment plan **before running anything**. It must state:

- the factors and their levels
- everything held fixed: test data, channel count, accumulator width, synthesis settings
- the metric, and the threshold you will judge against
- how many test cases you will average over

**Checkpoint A.** Have the plan checked. A sweep run before the plan exists cannot be
reported honestly, because the metric will have been chosen after seeing the data.

### Phase 2 — the error sweep (75 min)

**Step 2.1** Run the supplied sweep.

```bash
cd exp7/scripts
python3 sweep.py
```

Takes about a minute. Writes `../data/sweep.csv` and `../data/pareto.csv`.

**Step 2.2** Verify two configurations by hand against your Experiment 6 result.
`IN_W = 12`, `W_W = 8`, `FRAC_W = 4` on the Experiment 6 single-scatterer stimulus
should give **−51.1 dB**. The sweep averages over six cases so its value will differ
slightly; confirm you understand why.

**Checkpoint B.** Your sweep reproduces the front in section 3.1.

**Step 2.3** Demonstrate the single-case artefact. Edit `CASES` in `sweep.py` to contain
only one scatterer, sweep `W_W` alone, and plot. Then restore all six and repeat.

**Checkpoint C.** You can show a non-monotonic curve and its corrected version, and
explain the mechanism.

### Phase 3 — the resource measurement (60 min)

**Step 3.1** Choose **six configurations spanning the front** — at least one near each
end and two near the knee.

**Step 3.2** For each, set the parameters in `exp6/rtl/` and run synthesis. Record
**LUT, FF, DSP, BRAM and Fmax**. Script this; do not use the GUI.

**Step 3.3** Keep the synthesis setup identical across all six: same tool version, same
device, same constraints, same optimisation effort. Record them.

**Checkpoint D.** Six rows of real synthesis data, with the setup documented.

### Phase 4 — analysis and recommendation (60 min)

**Step 4.1** Plot accuracy against the modelled cost, and again against measured DSP
count. Mark the non-dominated set on each.

**Step 4.2** Compare the two. Identify where the model and the synthesis disagree, and
explain it using section 2.2.

**Step 4.3** Write the recommendation in the four-part form of section 7.

**Checkpoint E.** A recommendation naming a specific configuration, with evidence.

---

## 6. Results to record

| Quantity | Your value |
|---|---|
| Factors and levels swept | |
| Fixed conditions | |
| Metric and threshold, declared in advance | |
| Number of test cases averaged | |
| Any non-monotonic curve observed, and its cause | |
| Number of configurations evaluated | |
| Size of the non-dominated set | |
| Knee configuration and its error | |
| Synthesis setup: tool, version, device, constraints | |
| LUT / FF / DSP / BRAM / Fmax for six configurations | |
| Where the cost model disagrees with synthesis | |
| Recommended configuration | |

---

## 7. The recommendation

Four parts. Six sentences is enough.

1. **The choice** — every word length, the rounding mode, the accumulator width
2. **The evidence** — measured error, measured resource, position on the front
3. **The condition** — test data, channel count, metric under which the claim holds
4. **The sensitivity** — what would change it, and which parameter to move first

**Model answer, from the supplied data:**

> We recommend IN_W = 10, W_W = 6, FRAC_W = 6 with a 32-bit accumulator and truncating
> interpolation. This gives −57.5 dB NRMSE against the double-precision reference,
> averaged over six scatterer configurations, at a relative cost of 166. It is the knee
> of the Pareto front: reaching −62 dB from here costs 2.2× the area for 4.8 dB. The
> claim holds for an 8-channel aperture on the supplied stimulus. If the specification
> tightens beyond −60 dB, increase IN_W to 12 before touching W_W, which buys almost
> nothing at this channel count.

---

## 8. Analysis questions

**A1** Every front point above cost 134 has `FRAC_W = 6`. What does that tell you about
which error term dominates, and does it agree with what you found in Experiment 6?

**A2** `IN_W` 12 → 16 costs 64 and buys 0.5 dB. Explain using the idea of a dominant
error term, and predict what it would buy if `FRAC_W` were 10 instead of 6.

**A3** Your synthesis shows two configurations with very different modelled costs using
the same number of DSP blocks. Explain, and state what this implies about using the
model to choose between them.

**A4** The front has 15 points out of 80. What fraction is dominated, and why is it
still worth evaluating the dominated configurations?

**A5** Propose a third axis that this two-axis analysis has hidden, and describe how you
would present a three-way trade-off.

**A6** The recommendation in section 7 is conditional on an 8-channel aperture. Predict
how the front would move for 64 channels, and justify it.

---

## 9. Common failures

| Failure | Consequence |
|---|---|
| One test case | a non-monotonic curve reported as a finding |
| Synthesis settings changed partway | resource numbers not comparable; the whole table is void |
| Metric chosen after seeing the data | the analysis becomes a justification exercise |
| Modelled cost reported as synthesis result | the reader cannot tell what was measured |
| No normalisation | total resource compared across different channel counts |
| Front plotted, no recommendation made | the deliverable is a decision, not a plot |

---

## 10. Assessment

| Component | Marks | Earned by |
|---|---|---|
| Pre-lab | 10 | five questions attempted with reasoning |
| Method | 20 | checkpoint A — plan written first, conditions fixed |
| Error sweep | 25 | checkpoints B and C, including the artefact demonstration |
| Resource measurement | 20 | checkpoint D — six scripted synthesis runs, setup recorded |
| Analysis | 20 | model against synthesis, disagreement explained |
| Recommendation | 5 | four-part form, conditions and sensitivity stated |

A recommendation that differs from the knee earns full marks if the reasoning is sound.

---

## Appendix — verification status

`exp7/scripts/sweep.py` was executed when this manual was prepared; the front in
section 3.1 is its actual output. The synthesis numbers in Phase 3 are yours to
produce — none are supplied, because they depend on your device and tool version.
