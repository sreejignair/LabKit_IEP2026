#!/usr/bin/env python3
"""Generate us_rom.v - the ultrasound data, baked into Verilog as literals.

Run ONCE by an instructor. The output is committed. Students never run this.

Two sources, in order of preference:
  --h5 <PICMUS rf file>   real scanner data (preferred, cited)
  (no --h5)               a simulation using the SAME probe parameters as PICMUS,
                          clearly labelled as such in the file header
"""
import argparse, numpy as np

# PICMUS / Verasonics L11-4v parameters
FS, C0, F0, PITCH, N_EL = 20.832e6, 1540.0, 5.208e6, 0.30e-3, 128
N_CH, N_SAMP, W = 8, 64, 12           # what the lab uses

def from_simulation(focus_mm):
    """Scatterer at the focal depth, same probe geometry as PICMUS."""
    xe = (np.arange(N_CH) - (N_CH - 1) / 2) * (PITCH * 4)   # every 4th element
    z = focus_mm * 1e-3
    tau = (z + np.sqrt(xe ** 2 + z ** 2)) / C0
    n0 = int(tau.min() * FS) - 8                             # window start
    t = (np.arange(n0, n0 + N_SAMP)) / FS
    sig = 2.0 / F0
    d = np.array([np.exp(-((t - tau[i]) ** 2) / (2 * sig ** 2))
                  * np.cos(2 * np.pi * F0 * (t - tau[i])) for i in range(N_CH)])
    return d, (np.rint(tau * FS).astype(int) - n0), xe, "simulated"

def from_picmus(path, focus_mm):
    import h5py
    with h5py.File(path, "r") as f:
        found = {}
        f.visititems(lambda n, o: found.__setitem__(n.lower(), n)
                     if hasattr(o, "shape") else None)
        key = next((v for k, v in found.items() if k.endswith("data/real")), None)
        raw = np.asarray(f[key][()])
    if raw.ndim == 3 and raw.shape[2] < raw.shape[1]:
        raw = np.transpose(raw, (0, 2, 1))
    tx = raw.shape[0] // 2                                   # middle = 0 degrees
    step = N_EL // N_CH
    sel = np.arange(N_CH) * step + step // 2
    xe = (sel - (N_EL - 1) / 2) * PITCH
    z = focus_mm * 1e-3
    tau = (z + np.sqrt(xe ** 2 + z ** 2)) / C0
    n0 = int(tau.min() * FS) - 8
    d = raw[tx][sel, n0:n0 + N_SAMP]
    return d, (np.rint(tau * FS).astype(int) - n0), xe, "PICMUS"

ap = argparse.ArgumentParser()
ap.add_argument("--h5"); ap.add_argument("--focus-mm", type=float, default=20.0)
ap.add_argument("--out", default="rtl/us_rom.v")
a = ap.parse_args()

d, delay, xe, src = (from_picmus(a.h5, a.focus_mm) if a.h5
                     else from_simulation(a.focus_mm))
assert d.shape == (N_CH, N_SAMP), d.shape
assert delay.min() >= 0 and delay.max() < N_SAMP, f"delays {delay} outside the window"

scale = float(np.max(np.abs(d)))
q = np.clip(np.rint(d / scale * ((1 << (W - 1)) - 1)), -(1 << (W - 1)), (1 << (W - 1)) - 1).astype(int)
apod = np.rint(np.hanning(N_CH + 2)[1:-1] * 127).astype(int)

spread = delay.max() - delay.min()
print(f"source: {src}   focus {a.focus_mm} mm   delay spread {spread} samples")
print(f"delays: {delay.tolist()}")
print(f"apod  : {apod.tolist()}")

hdr = ("// Real scanner data from PICMUS (IEEE IUS 2016).\n"
       "// H. Liebgott et al., 2016 IEEE IUS, pp. 1-4. DOI 10.1109/ULTSYM.2016.7728908\n"
       "// https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/download\n"
       if src == "PICMUS" else
       "// SIMULATED echo data, using the same probe parameters as PICMUS\n"
       "// (Verasonics L11-4v: 0.30 mm pitch, 5.208 MHz, sampled at 20.832 MHz).\n"
       "// Replace with real PICMUS data by re-running make_rom.py with --h5.\n")

L = []
L.append("// ---------------------------------------------------------------------------")
L.append("// us_rom.v   -  the ultrasound echo data, built into the design")
L.append("//")
L.append("// GENERATED FILE - do not edit. Produced by make_rom.py.")
L.append("//")
for line in hdr.strip().split("\n"): L.append(line)
L.append("//")
L.append(f"// {N_CH} channels x {N_SAMP} samples, {W}-bit signed.")
L.append(f"// Focal depth {a.focus_mm} mm. Delay spread across the aperture: {spread} samples.")
L.append("// ---------------------------------------------------------------------------")
L.append("`timescale 1ns/1ps")
L.append("")
L.append("module us_rom (")
L.append("    input  wire       clk,")
L.append("    input  wire [2:0] ch,      // which channel, 0..7")
L.append("    input  wire [5:0] addr,    // which sample,  0..63")
L.append(f"    output reg signed [{W-1}:0] q")
L.append(");")
L.append("    always @(posedge clk) begin")
L.append("        case ({ch, addr})")
for c in range(N_CH):
    L.append(f"            // ---- channel {c}")
    for s in range(N_SAMP):
        idx = (c << 6) | s
        L.append(f"            9'd{idx:<3}: q <= -12'sd{-q[c,s]};" if q[c, s] < 0
                 else f"            9'd{idx:<3}: q <=  12'sd{q[c,s]};")
L.append("            default: q <= 0;")
L.append("        endcase")
L.append("    end")
L.append("endmodule")
L.append("")
L.append("")
L.append("// ---------------------------------------------------------------------------")
L.append("// us_params.v  -  the delays and weights that go with the data above")
L.append("// ---------------------------------------------------------------------------")
L.append("module us_params (")
L.append("    input  wire [2:0] ch,")
L.append("    output reg  [5:0] delay,   // sample index for this channel")
L.append("    output reg signed [7:0] weight")
L.append(");")
L.append("    always @(*) begin")
L.append("        case (ch)")
for c in range(N_CH):
    L.append(f"            3'd{c}: begin delay = 6'd{delay[c]:<2}; weight = 8'sd{apod[c]:<3}; end")
L.append("            default: begin delay = 6'd0; weight = 8'sd0; end")
L.append("        endcase")
L.append("    end")
L.append("endmodule")

open(a.out, "w").write("\n".join(L) + "\n")
print(f"wrote {a.out}  ({len(L)} lines)")

# golden result, for the lab manual
acc = sum(int(q[c, delay[c]]) * int(apod[c]) for c in range(N_CH))
print(f"\nGOLDEN: summing each channel at its own delay gives {acc}")
nod = sum(int(q[c, delay[0]]) * int(apod[c]) for c in range(N_CH))
print(f"        with NO delays applied it gives {nod}")
print(f"        ratio {abs(acc)/max(abs(nod),1):.2f}x  ->  that is the point of the lab")
