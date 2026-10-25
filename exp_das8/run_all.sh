#!/usr/bin/env bash
# Regenerate stimulus, then synthesise both variants on all three boards.
# Usage:  ./run_all.sh            synthesis only, fills the comparison table
#         ./run_all.sh ila        adds implementation + ILA + bitstream
set -e
ILA=${1:-}
echo ">>> regenerating stimulus and golden data"
python3 ref/das8_model.py
rm -f reports/utilisation.csv
for B in basys3 arty_a7_100 nexys_a7_100; do
    echo ">>> $B"
    vivado -mode batch -nojournal -nolog -source tcl/run_board.tcl -tclargs "$B" "$ILA"
done
echo
echo ">>> comparison table:"
column -s, -t reports/utilisation.csv
