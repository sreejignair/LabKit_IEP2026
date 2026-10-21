# NIT-T practical session — package contents

Three parts, one package. They share the same numbers: the lab manual, the slides and
the code all quote values produced by `exp6/ref/bf_golden.py`, so nothing can drift.

```
LAB MANUAL      exp6/LAB_MANUAL_EXP6.md          <- the spine; everything derives from it
                exp7/LAB_MANUAL_EXP7.md          (to follow)

SLIDES          ../nitt_lab/Exp6_*.pptx          (to be regenerated from the manual)
                ../nitt_lab/Exp7_*.pptx

CODE            exp6/ref/    golden model, vector generator, FSM check, cycle trace
                exp6/rtl/    beamformer, memories, top level
                exp6/tb/     self-checking testbench
                exp6/matlab/ Field II reference and comparison
                exp6/data/   generated test vectors and golden results
                exp7/scripts/sweep.py + exp7/data/
```

## Status

| Part | Experiment 6 | Experiment 7 |
|---|---|---|
| Lab manual | **complete** | to follow |
| Code | complete; Verilog not compiled here | complete and verified |
| Slides | exist, need regenerating from the manual | exist, same |

## Run order for the instructor, before the session

```bash
cd exp6/ref
python3 bf_golden.py      # -51.1 dB, 22 bits used
python3 gen_vectors.py    # writes ../data
python3 fsm_check.py      # FSM timing matches on all 64 points
python3 gen_trace.py      # cycle-by-cycle reference for debugging
cd ../.. && iverilog -o sim -I exp6/data exp6/rtl/*.v exp6/tb/tb_bf.v && vvp sim
cd exp7/scripts && python3 sweep.py
```
