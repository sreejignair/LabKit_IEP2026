"""Experiment 7 - accuracy against hardware cost.

Sweeps the three word-length factors on the Experiment 6 beamformer, measures the
numerical error against the double-precision reference, and pairs it with an
analytical resource model. Writes a table and the non-dominated set.

The error is MEASURED. The cost is a MODEL. Task 6 of the experiment asks you to
replace the model column with real synthesis numbers for a subset of rows and to
explain where the two disagree.

Run:  python3 sweep.py            (about a minute)
"""
import csv, importlib, os, sys
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "exp6", "ref"))
import bf_golden as G

# six scatterer configurations - averaging over these removes the single-case artefact
CASES = [
    [(24.0e-3, 0.0, 1.0)],
    [(25.0e-3, 0.0, 1.0)],
    [(26.0e-3, 0.6e-3, 1.0)],
    [(24.5e-3, -0.9e-3, 1.0)],
    [(25.5e-3, 0.3e-3, 1.0)],
    [(24.2e-3, 0.0, 1.0), (25.8e-3, 0.5e-3, 0.6)],
]


def nrmse_db(in_w, w_w, frac_w):
    """Mean NRMSE across the six cases, in dB."""
    importlib.reload(G)
    G.IN_W, G.W_W, G.FRAC_W = in_w, w_w, frac_w
    vals = []
    for sc in CASES:
        d = G.build(scatterers=tuple(sc))
        e = d["y_fix"] * d["lsb"] - d["y_ref"]
        vals.append(np.sqrt(np.mean(e ** 2)) / np.max(np.abs(d["y_ref"])))
    return 20 * np.log10(np.mean(vals))


def cost_model(in_w, w_w, frac_w):
    """Relative area. Multiplier dominates and scales with the operand product;
    the interpolation multiplier scales with the fraction width; memory scales
    with the sample width."""
    mult   = in_w * w_w
    interp = (in_w + 1) * frac_w
    mem    = in_w * 4
    return mult + interp + mem


def main():
    rows = []
    for in_w in (6, 8, 10, 12, 16):
        for w_w in (4, 6, 8, 12):
            for frac_w in (2, 3, 4, 6):
                e = nrmse_db(in_w, w_w, frac_w)
                rows.append(dict(in_w=in_w, w_w=w_w, frac_w=frac_w,
                                 nrmse_db=round(e, 2),
                                 cost=cost_model(in_w, w_w, frac_w)))
                print(f"  IN={in_w:2d} W={w_w:2d} FRAC={frac_w}  "
                      f"NRMSE={e:7.2f} dB  cost={rows[-1]['cost']:4d}")

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "sweep.csv"), "w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0]))
        wr.writeheader(); wr.writerows(rows)

    nd = [r for r in rows
          if not any(o["cost"] <= r["cost"] and o["nrmse_db"] < r["nrmse_db"] - 0.01
                     for o in rows)]
    nd.sort(key=lambda r: r["cost"])
    with open(os.path.join(out, "pareto.csv"), "w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0]))
        wr.writeheader(); wr.writerows(nd)

    print(f"\n{len(rows)} configurations, {len(nd)} non-dominated")
    print("\nPareto front (cost, error, configuration):")
    for r in nd:
        print(f"   cost {r['cost']:4d}   {r['nrmse_db']:7.2f} dB   "
              f"IN={r['in_w']} W={r['w_w']} FRAC={r['frac_w']}")

    # knee: largest drop in error per unit cost along the front
    best, best_g = None, -1e9
    for a, b in zip(nd, nd[1:]):
        g = (a["nrmse_db"] - b["nrmse_db"]) / max(b["cost"] - a["cost"], 1)
        if g > best_g:
            best_g, best = g, b
    if best:
        print(f"\nsteepest remaining gain reaches: IN={best['in_w']} W={best['w_w']} "
              f"FRAC={best['frac_w']} at cost {best['cost']}, {best['nrmse_db']:.2f} dB")


if __name__ == "__main__":
    main()
