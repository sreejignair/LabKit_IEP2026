"""Golden model for the 8-channel DAS synthesis comparison.

Produces identical stimulus for the fixed-point and floating-point RTL so the two
can be compared against the same reference, and generates the memory init files.

Datapath (both versions):
    delay line  ->  linear interpolation  ->  apodisation multiply  ->  adder tree
"""
import os, numpy as np

N_CH, IN_W, W_W, FRAC_W, ACC_W = 8, 12, 8, 4, 32
DEPTH = 2048                     # samples per channel delay line
C, F0, FS, PITCH = 1540.0, 5e6, 40e6, 0.3e-3
EL = (np.arange(N_CH) - (N_CH - 1) / 2) * PITCH
N_PTS = 64

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sim")
os.makedirs(OUT, exist_ok=True)


def channel_data(z_scat=20e-3, pulse_cycles=2.0):
    """RF echo from one scatterer, with the window sized from the geometry."""
    tau = (z_scat + np.sqrt(EL ** 2 + z_scat ** 2)) / C
    need = int(tau.max() * FS) + 80
    assert need < DEPTH, f"delay line too short: need {need}, have {DEPTH}"
    t = np.arange(DEPTH) / FS
    sigma = pulse_cycles / F0
    x = np.zeros((DEPTH, N_CH))
    for ch in range(N_CH):
        x[:, ch] = np.exp(-((t - tau[ch]) ** 2) / (2 * sigma ** 2)) \
                   * np.cos(2 * np.pi * F0 * (t - tau[ch]))
    return x


def delay_tables(zs):
    di = np.zeros((len(zs), N_CH), dtype=np.int64)
    df = np.zeros((len(zs), N_CH), dtype=np.int64)
    for p, z in enumerate(zs):
        q = np.round((z + np.sqrt(EL ** 2 + z ** 2)) / C * FS * (1 << FRAC_W)).astype(np.int64)
        di[p] = q >> FRAC_W
        df[p] = q & ((1 << FRAC_W) - 1)
    assert di.min() >= 0 and di.max() + 1 < DEPTH, "delay outside the line"
    return di, df


def q(x, bits):
    sc = float(np.max(np.abs(x)))
    return np.clip(np.round(x / sc * ((1 << (bits - 1)) - 1)),
                   -(1 << (bits - 1)), (1 << (bits - 1)) - 1).astype(np.int64), sc


def das_fixed(mem, di, df, apod):
    """Exactly what rtl/das8_fixed.v computes."""
    out = []
    for p in range(di.shape[0]):
        acc = 0
        for ch in range(N_CH):
            n = int(di[p, ch]); f = int(df[p, ch])
            s0, s1 = int(mem[n, ch]), int(mem[n + 1, ch])
            s = s0 + (((s1 - s0) * f) >> FRAC_W)     # arithmetic shift, truncates
            acc += s * int(apod[ch])
        out.append(acc)
    return np.array(out, dtype=np.int64)


def das_float(x, di, df, apod_f):
    """What rtl/das8_float.v computes, in double as the reference."""
    out = []
    for p in range(di.shape[0]):
        acc = 0.0
        for ch in range(N_CH):
            n = int(di[p, ch]); f = int(df[p, ch]) / (1 << FRAC_W)
            s = x[n, ch] * (1 - f) + x[n + 1, ch] * f
            acc += s * apod_f[ch]
        out.append(acc)
    return np.array(out)


def hexw(v, bits):
    return format(int(v) & ((1 << bits) - 1), "0{}x".format((bits + 3) // 4))


def f32hex(v):
    import struct
    return format(struct.unpack("<I", struct.pack("<f", float(v)))[0], "08x")


if __name__ == "__main__":
    zs = np.linspace(18e-3, 22e-3, N_PTS)
    x = channel_data()
    apod_f = np.hanning(N_CH + 2)[1:-1]
    mem, in_sc = q(x, IN_W)
    apod, w_sc = q(apod_f, W_W)
    di, df = delay_tables(zs)

    y_fix = das_fixed(mem, di, df, apod)
    y_ref = das_float(x, di, df, apod_f)
    lsb = (in_sc / ((1 << (IN_W - 1)) - 1)) * (w_sc / ((1 << (W_W - 1)) - 1))
    err = y_fix * lsb - y_ref
    print(f"fixed-point NRMSE vs double : "
          f"{20*np.log10(np.sqrt(np.mean(err**2))/np.max(np.abs(y_ref))):.1f} dB")
    used = int(np.ceil(np.log2(np.abs(y_fix).max()))) + 1
    print(f"accumulator: bound {IN_W+W_W+3} bits, actually used {used} bits")

    # ---- memory files, fixed point
    with open(os.path.join(OUT, "chan_fixed.hex"), "w") as f:
        for ch in range(N_CH):
            for n in range(DEPTH):
                f.write(hexw(mem[n, ch], IN_W) + "\n")
    with open(os.path.join(OUT, "apod_fixed.hex"), "w") as f:
        for ch in range(N_CH):
            f.write(hexw(apod[ch], W_W) + "\n")
    # ---- memory files, floating point (IEEE-754 single)
    with open(os.path.join(OUT, "chan_float.hex"), "w") as f:
        for ch in range(N_CH):
            for n in range(DEPTH):
                f.write(f32hex(x[n, ch]) + "\n")
    with open(os.path.join(OUT, "apod_float.hex"), "w") as f:
        for ch in range(N_CH):
            f.write(f32hex(apod_f[ch]) + "\n")
    # ---- delays, shared
    with open(os.path.join(OUT, "delay_int.hex"), "w") as f:
        for p in range(N_PTS):
            for ch in range(N_CH):
                f.write(hexw(di[p, ch], 16) + "\n")
    with open(os.path.join(OUT, "delay_frac.hex"), "w") as f:
        for p in range(N_PTS):
            for ch in range(N_CH):
                f.write(hexw(df[p, ch], FRAC_W) + "\n")
    # ---- golden outputs
    with open(os.path.join(OUT, "golden_fixed.hex"), "w") as f:
        for v in y_fix:
            f.write(hexw(v, ACC_W) + "\n")
    with open(os.path.join(OUT, "golden_float.hex"), "w") as f:
        for v in y_ref:
            f.write(f32hex(v) + "\n")
    with open(os.path.join(OUT, "scales.txt"), "w") as f:
        f.write(f"in_scale {in_sc:.12e}\nw_scale {w_sc:.12e}\nlsb {lsb:.12e}\n")
    print(f"wrote stimulus and golden files to sim/  ({N_CH} ch, {DEPTH} deep, {N_PTS} points)")
