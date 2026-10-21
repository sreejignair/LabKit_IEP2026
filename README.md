exp6/
  ref/bf_golden.py      bit-accurate model - the specification
  ref/gen_vectors.py    generates every file the testbench reads
  ref/fsm_check.py      cycle-level check of the state machine timing
  rtl/bf_core.v         the beamformer datapath and FSM
  rtl/bf_mem.v          channel memory and the two ROMs
  rtl/bf_top.v          sweeps all output points
  tb/tb_bf.v            self-checking testbench
  matlab/               Field II reference generation and comparison
  data/                 generated - run gen_vectors.py first

exp7/
  scripts/sweep.py      the parameter sweep and Pareto analysis
  data/                 generated

Verification status — read this first
Component
Status
Python models and sweeps
run and verified here
FSM timing
verified by cycle-level simulation against the golden model
Verilog
written but not compiled — no simulator was available
MATLAB
written but not executed — no MATLAB or Octave available


The Python model is the specification and it is correct. If the Verilog does not elaborate, fix the Verilog against the contract in exp6/README.md.
Start here
cd exp6/ref && python3 bf_golden.py && python3 gen_vectors.py && python3 fsm_check.py
cd ../../exp7/scripts && python3 sweep.py

Expected: NRMSE −51.1 dB for the Experiment 6 design point, FSM matching on all 64 points, and a 15-point Pareto front from 80 configurations.
