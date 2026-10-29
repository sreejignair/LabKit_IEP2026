# 8-Channel Delay-and-Sum: Fixed Point against Floating Point

A single Vivado lab for a one-day session. Students build the same 8-channel
ultrasound beamformer twice, once in integer arithmetic and once in IEEE-754
floating point, and compare what each costs on the chip.

Everything is done in the Vivado GUI. There is nothing to run first, no scripts,
no data files to fetch.

## Files

| File | Purpose |
|---|---|
| `LAB_MANUAL.md` | the student handout, click by click |
| `rtl/us_rom.v` | the ultrasound data, built into the Verilog |
| `rtl/das8_fixed.v` | fixed-point beamformer, 43 lines |
| `rtl/das8_float.v` | floating-point beamformer, 82 lines |
| `make_rom.py` | instructor only, regenerates `us_rom.v` |

Students need three files: `us_rom.v`, `das8_fixed.v`, `das8_float.v`.

## What the lab shows

Both designs read the same eight channels, apply the same delays and weights, and
produce the same sum. The only difference is the number format. The utilisation
reports then make the cost of floating point visible rather than asserted.

There is also a `bypass` input on the fixed design. With the delays applied the
result is 1118766; with every channel read at the same moment it is −248772. A
factor of 4.5 from the same data, which is the point of delay-and-sum.

## Data

The samples come from PICMUS, the plane-wave imaging challenge from IEEE IUS 2016.
Verasonics Vantage, L11-4v probe, 128 elements at 0.30 mm pitch, 5.208 MHz, sampled
at 20.832 MHz.

> H. Liebgott, A. Rodriguez-Molares, F. Cervenansky, J. A. Jensen and O. Bernard,
> "Plane-Wave Imaging Challenge in Medical Ultrasound," 2016 IEEE International
> Ultrasonics Symposium (IUS), pp. 1-4, 2016. DOI 10.1109/ULTSYM.2016.7728908

PICMUS is free to use; the only condition is that the paper is cited. It is cited
in the manual, in this file and in the header of `us_rom.v`.

**The copy in this repository is simulated data using the PICMUS probe parameters,
not PICMUS samples.** The header of `us_rom.v` says so. To replace it with real
scanner data, download the archive from the link above and run:

```
python3 make_rom.py --h5 <picmus_file>_rf.hdf5 --focus-mm 20
```

The design files do not change. Only `us_rom.v` is regenerated.

## Checked and not checked

| | |
|---|---|
| Data generation and the golden result | run and verified |
| RTL wiring against the golden result | verified by parsing `us_rom.v` and recomputing |
| Verilog elaboration and synthesis | **not run** — no Vivado was available |
| IP core dialog settings | written from the IP documentation, not clicked through |

Build both projects once before the session. If the floating-point design will not
elaborate, the cause is almost always a latency or precision setting in one of the
three IP cores that does not match the manual.

## 16 channels

Out of scope for the session, kept here because it comes up. Going to 16 channels
means regenerating `us_rom.v` with `N_CH = 16`, changing the generate loop bound,
and widening the adder tree. The fixed-point version grows roughly in proportion.
The floating-point version grows faster, because every extra channel adds a
converter, a multiplier and an adder.
