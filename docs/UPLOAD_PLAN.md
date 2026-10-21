# Upload plan

## What goes in, and why

| Path | Commit? | Reason |
|---|---|---|
| `docs/` | yes | the manuals are the authoritative documents |
| `exp6/ref/`, `exp6/rtl/`, `exp6/tb/`, `exp6/matlab/` | yes | source |
| `exp6/data/` | **yes** | so a student can run the testbench without Python; regenerable with `gen_vectors.py` |
| `exp7/scripts/` | yes | source |
| `exp7/data/` | **yes** | the committed sweep output is the expected result instructors check against |
| `slides/` | yes, **with the status note** | currently inconsistent with the kit — see the README |
| `__pycache__`, `sim`, `*.vcd`, Vivado dirs | no | covered by `.gitignore` |

`exp6/data/` is 1.2 MB, almost all of it `chan_mem.hex` (16 384 lines). That is small
enough to commit and saves every student a generation step.

## Suggested commit sequence

```bash
cd LabKit_IEP2026
git init
git remote add origin https://github.com/sreejignair/LabKit_IEP2026.git
git checkout -b main

git add .gitignore README.md docs/
git commit -m "Add lab manuals for Experiments 6 and 7, and the repository guide"

git add exp6/
git commit -m "Add Experiment 6: reference models, RTL, testbench, MATLAB and test vectors"

git add exp7/
git commit -m "Add Experiment 7: parameter sweep, Pareto analysis and results"

git add slides/
git commit -m "Add presentation decks (pending regeneration to match the kit)"

git push -u origin main
```

Four commits rather than one, so the history shows the structure.

## Before you push

1. Run the Quick Start block in the README end to end
2. Confirm `bf_golden.py` prints −51.1 dB
3. Try `iverilog` — if the HDL does not elaborate, either fix it or note it in the
   commit message so your supervisor is not surprised

## Known gaps, to be honest about in the first issue

1. The Verilog has never been compiled — no simulator was available when it was written
2. The MATLAB has never been executed
3. The slides quote figures from an earlier 64-channel model and disagree with the kit
