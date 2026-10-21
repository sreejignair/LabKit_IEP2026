"""Bit-accurate golden model for the Experiment 6 beamformer.

Integer-only, written to match the RTL operation for operation. Every intermediate
width and every truncation point is stated here, because the RTL must reproduce them
exactly for a bit-exact comparison to be possible.

DESIGN POINT (deliberately small so a student can hand-check it)
  N_CH    = 8     receive channels
  IN_W    = 12    channel sample, signed
  W_W     = 8     apodisation weight, signed
  FRAC_W  = 4     delay fraction bits (linear interpolation)
  ACC_W   = 32    accumulator, signed
  N_PTS   = 64    output points along the line

ARITHMETIC CONTRACT  (the RTL must match this exactly)
  diff = s1 - s0                      signed, IN_W+1 bits
  m    = diff * frac                  signed, IN_W+1+FRAC_W bits, frac unsigned
  s    = s0 + (m >>> FRAC_W)          arithmetic shift, truncates toward -inf
  p    = s * w                        signed
  acc  = acc + p                      signed ACC_W, saturating
"""
import numpy as np

N_CH, IN_W, W_W, FRAC_W, ACC_W, N_PTS = 8, 12, 8, 4, 32, 64
MEM_DEPTH = 2048

C, F0, FS, PITCH = 1540.0, 5e6, 40e6, 0.3e-3
ELEM = (np.arange(N_CH) - (N_CH - 1) / 2) * PITCH


def _sat(v, w):
    lo, hi = -(1 << (w - 1)), (1 << (w - 1)) - 1
    return max(lo, min(hi, int(v)))


def interp_fixed(s0, s1, frac):
    """s = s0 + ((s1 - s0) * frac) >>> FRAC_W.  Python >> on int is arithmetic."""
    diff = int(s1) - int(s0)
    m = diff * int(frac)
    return int(s0) + (m >> FRAC_W)


def beamform_fixed(mem, delay_int, delay_frac, apod):
    """One output point per row of delay_int. Returns raw accumulator values."""
    out = []
    for p in range(delay_int.shape[0]):
        acc = 0
        for ch in range(N_CH):
            n = int(delay_int[p, ch])
            s = interp_fixed(mem[n, ch], mem[n + 1, ch], delay_frac[p, ch])
            acc = _sat(acc + s * int(apod[ch]), ACC_W)
        out.append(acc)
    return np.array(out, dtype=np.int64)


# ---------------------------------------------------------------- stimulus
def make_channel_data(scatterers, nsamp=MEM_DEPTH, pulse_cycles=2.0):
    t = np.arange(nsamp) / FS
    x = np.zeros((nsamp, N_CH))
    sigma = pulse_cycles / F0            # Gaussian envelope, ~2 cycles long
    for (z, xpos, amp) in scatterers:
        r = np.sqrt((ELEM - xpos) ** 2 + z ** 2)
        tau = (z + r) / C
        for ch in range(N_CH):
            x[:, ch] += amp * np.exp(-((t - tau[ch]) ** 2) / (2 * sigma ** 2)) \
                            * np.cos(2 * np.pi * F0 * (t - tau[ch]))
    return x


def delay_tables(zs):
    di = np.zeros((len(zs), N_CH), dtype=np.int64)
    df = np.zeros((len(zs), N_CH), dtype=np.int64)
    for p, z in enumerate(zs):
        r = np.sqrt(ELEM ** 2 + z ** 2)
        q = np.round((z + r) / C * FS * (1 << FRAC_W)).astype(np.int64)
        di[p] = q >> FRAC_W
        df[p] = q & ((1 << FRAC_W) - 1)
    assert di.min() >= 0 and di.max() + 1 < MEM_DEPTH, \
        "delay falls outside the channel memory - increase MEM_DEPTH"
    return di, df


def quantise(x, bits):
    sc = float(np.max(np.abs(x)))
    q = np.round(x / sc * ((1 << (bits - 1)) - 1)).astype(np.int64)
    return np.clip(q, -(1 << (bits - 1)), (1 << (bits - 1)) - 1), sc


# ---------------------------------------------------------------- float reference
def beamform_float(x, zs, apod_f):
    out = np.zeros(len(zs))
    for p, z in enumerate(zs):
        r = np.sqrt(ELEM ** 2 + z ** 2)
        n = (z + r) / C * FS
        n0 = np.floor(n).astype(int)
        fr = n - n0
        s = x[n0, np.arange(N_CH)] * (1 - fr) + x[n0 + 1, np.arange(N_CH)] * fr
        out[p] = np.sum(apod_f * s)
    return out


def build(scatterers=((25e-3, 0.0, 1.0),), z0=24e-3, z1=26e-3):
    zs = np.linspace(z0, z1, N_PTS)
    x = make_channel_data(list(scatterers))
    apod_f = np.hanning(N_CH + 2)[1:-1]
    mem, in_scale = quantise(x, IN_W)
    apod, w_scale = quantise(apod_f, W_W)
    di, df = delay_tables(zs)
    y_fix = beamform_fixed(mem, di, df, apod)
    y_ref = beamform_float(x, zs, apod_f)
    lsb = (in_scale / ((1 << (IN_W - 1)) - 1)) * (w_scale / ((1 << (W_W - 1)) - 1))
    return dict(zs=zs, x=x, mem=mem, apod=apod, di=di, df=df,
                y_fix=y_fix, y_ref=y_ref, lsb=lsb,
                in_scale=in_scale, w_scale=w_scale)


if __name__ == "__main__":
    d = build()
    y_phys = d["y_fix"] * d["lsb"]
    err = y_phys - d["y_ref"]
    peak = np.max(np.abs(d["y_ref"]))
    used = int(np.ceil(np.log2(max(abs(d["y_fix"].min()), abs(d["y_fix"].max()))))) + 1
    print(f"accumulator range  : {d['y_fix'].min()} .. {d['y_fix'].max()}")
    print(f"bits actually used : {used}   (ACC_W = {ACC_W})")
    print(f"NRMSE vs float ref : {20*np.log10(np.sqrt(np.mean(err**2))/peak):.1f} dB")
    print(f"peak error / peak  : {np.max(np.abs(err))/peak:.3e}")
    # independent re-implementation, to prove the contract is unambiguous
    chk = []
    for p in range(N_PTS):
        a = 0
        for ch in range(N_CH):
            n = int(d["di"][p, ch]); f = int(d["df"][p, ch])
            s0 = int(d["mem"][n, ch]); s1 = int(d["mem"][n + 1, ch])
            a += (s0 + ((s1 - s0) * f >> FRAC_W)) * int(d["apod"][ch])
        chk.append(a)
    assert np.array_equal(np.array(chk), d["y_fix"]), "contract is ambiguous"
    print("independent re-implementation matches: contract is unambiguous")
