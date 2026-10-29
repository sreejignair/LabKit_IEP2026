# Lab — Delay-and-Sum on an FPGA: Fixed Point against Floating Point

**Time:** 90 minutes. **Tool:** Vivado, GUI only. No scripts, no terminal.

You will build an 8-channel ultrasound beamformer twice. The first uses ordinary
whole-number arithmetic. The second does exactly the same job in floating point.
Then you compare what each one costs on the chip.

---

## What you need

Three files, all supplied. Nothing to generate, nothing to download.

| File | What it is |
|---|---|
| `us_rom.v` | the ultrasound echo data, 8 channels, already inside the file |
| `das8_fixed.v` | the fixed-point beamformer |
| `das8_float.v` | the floating-point beamformer |

---

## Part 1 — Fixed point (35 min)

### Create the project

1. Open Vivado. **Create Project**, then **Next**.
2. Name it `das8_fixed`. Pick a folder you can find again. **Next**.
3. **RTL Project**. Tick **Do not specify sources at this time**. **Next**.
4. Choose your board under **Boards**, or your part under **Parts**. **Next**, then **Finish**.

### Add the design files

5. **Flow Navigator ▸ PROJECT MANAGER ▸ Add Sources**.
6. **Add or create design sources**, then **Next**.
7. **Add Files**. Select `us_rom.v` and `das8_fixed.v`. **OK**.
8. Tick **Copy sources into project**. **Finish**.

In the Sources panel you should now see `das8_fixed` at the top with `us_rom` and
`us_params` under it. If `das8_fixed` is not in bold at the top, right-click it and
choose **Set as Top**.

### Synthesise

9. **Flow Navigator ▸ SYNTHESIS ▸ Run Synthesis**. **OK**. Wait.
10. When it finishes, choose **Open Synthesized Design**. **OK**.

### Read the numbers

11. **Flow Navigator ▸ SYNTHESIZED DESIGN ▸ Report Utilization**. **OK**.
12. The report opens at the bottom. Write these down:

| | Fixed point |
|---|---|
| Slice LUTs | |
| Slice Registers | |
| DSPs | |
| Block RAM Tile | |

Look at the DSP number. Each one is a hardware multiplier. You have eight channels,
each with one multiply, so you should see a small number here.

---

## Part 2 — Floating point (40 min)

Same arithmetic, same data. Only the number format changes.

### A new project

13. **File ▸ Project ▸ Close**, then create a second project called `das8_float`,
    the same way, with the same board.

### Create the three IP cores first

The floating-point design uses AMD's floating-point IP. Build the cores before
adding the Verilog, or the design will not elaborate.

14. **Flow Navigator ▸ PROJECT MANAGER ▸ IP Catalog**.
15. In the search box type `floating`. Double-click **Floating-point**.

**Core 1 — fp_i2f**

| Setting | Value |
|---|---|
| Component Name | `fp_i2f` |
| Operation Selection | **Fixed-to-float** |
| Input: Precision Type | Custom, 16-bit, fraction width 0 |
| Result Precision Type | **Single** |
| Flow Control | **NonBlocking** |
| Latency | 2 |

Click **OK**, then **Generate**.

**Core 2 — fp_mul**

Open **Floating-point** again.

| Setting | Value |
|---|---|
| Component Name | `fp_mul` |
| Operation Selection | **Multiply** |
| Precision | **Single** for both input and result |
| Multiplier usage | **Full usage** |
| Flow Control | **NonBlocking** |
| Latency | 3 |

**OK**, then **Generate**.

**Core 3 — fp_add**

| Setting | Value |
|---|---|
| Component Name | `fp_add` |
| Operation Selection | **Add/Subtract**, then **Add** |
| Precision | **Single** |
| Flow Control | **NonBlocking** |
| Latency | 3 |

**OK**, then **Generate**.

### Add the design files

16. **Add Sources ▸ Add or create design sources ▸ Add Files**.
    Select `us_rom.v` and `das8_float.v`. Tick **Copy sources into project**. **Finish**.
17. Make sure `das8_float` is the top module.

### Synthesise and read the numbers

18. **Run Synthesis**, then **Open Synthesized Design**, then **Report Utilization**.

| | Fixed point | Floating point |
|---|---|---|
| Slice LUTs | | |
| Slice Registers | | |
| DSPs | | |
| Block RAM Tile | | |

---

## Part 3 — What you are looking at (15 min)

Answer these in your record sheet.

1. How many times more LUTs does the floating-point version use?
2. How many times more DSPs?
3. Both designs read the same data and compute the same sum. Where did all the
   extra hardware go?
4. This design has 8 channels. A real scanner has 128 or 256. Multiply your
   floating-point numbers by 16 and compare against the size of your device. Does
   it still fit?
5. Which format would you choose for the front end of an ultrasound machine, and
   why?

The answer to question 3 is the one that matters. A floating-point adder has to
compare two exponents, shift one number to line it up with the other, add, then
normalise and round the result. An integer adder just adds. All that extra logic is
the price of being able to represent a very large range of numbers, and in a
beamformer you do not need that range.

---

## Part 4 — Seeing it work (optional, 15 min)

So far you have compared cost. If you want to see the beamformer actually do
something, synthesise `das8_fixed` with `bypass` tied to 0 and then to 1, and look
at the value of `result`.

Open `das8_fixed.v` and find the input called `bypass`.

- `bypass = 0` — each channel is read at its own delay, so the echoes line up
- `bypass = 1` — every channel is read at the same moment, so they do not

| bypass | result |
|---|---|
| 0 | 1118766 |
| 1 | −248772 |

Aligning the channels makes the result **4.5 times larger** from exactly the same
data. That is delay-and-sum, and that ratio is the entire reason beamformers exist.

To see this on hardware, drive `bypass` from a switch and bring `result` out to an
ILA. Your instructor will demonstrate.

---

## If you want to go further: 16 channels

The design is written so that going to 16 channels means changing the loop bound in
`das8_fixed.v` from 8 to 16, regenerating the data file for 16 channels, and
widening the adder tree. The repository has notes on this. It is not part of the
session.

What you would find: the fixed-point version grows roughly in proportion, and the
floating-point version grows faster, because each extra channel brings another
converter, another multiplier and another adder with it.

---

## When something goes wrong

| What you see | What it means |
|---|---|
| `module us_rom not found` | you added only one file. Add `us_rom.v` as well |
| `fp_mul is not declared` | the IP cores were not generated. Do step 15 before adding the Verilog |
| `das8_fixed` is not bold in Sources | right-click it, **Set as Top** |
| Synthesis finishes with 0 DSPs | the tool mapped the multipliers into LUTs instead. Not wrong, but note it when you compare |
| Utilisation report is empty | you are looking at the elaborated design, not the synthesised one. Open the synthesised design first |

---

## Where the data came from

The echo samples in `us_rom.v` come from PICMUS, the Plane-wave Imaging Challenge in
Medical UltraSound, run at IEEE IUS 2016. Acquisition was on a Verasonics Vantage
with an L11-4v probe: 128 elements, 0.30 mm pitch, 5.208 MHz, sampled at 20.832 MHz.

> H. Liebgott, A. Rodriguez-Molares, F. Cervenansky, J. A. Jensen and O. Bernard,
> "Plane-Wave Imaging Challenge in Medical Ultrasound," *2016 IEEE International
> Ultrasonics Symposium (IUS)*, pp. 1–4, 2016.
> DOI 10.1109/ULTSYM.2016.7728908

The file header in `us_rom.v` states whether that copy holds real PICMUS samples or
simulated data using the same probe parameters. Check it before you quote results.
