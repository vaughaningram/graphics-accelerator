# Pipelined Graphics Accelerator

**RTL design, verification, and performance characterization**

This repository contains the implementation and evaluation of a synthesizable,
fixed-function graphics pipeline developed for a senior capstone project and
sponsored by AMD.

The current beta accepts screen-space triangles with vertex color and depth,
determines covered pixels, interpolates those attributes, and emits fragments
that pass a small depth buffer. The project continues with broader verification
and measured architecture work.

> **Current status — Limited-scope pixel pipeline**
> The RTL accepts screen-space triangles with per-vertex color and depth,
> rasterizes covered pixels, interpolates attributes, and emits pixels that
> pass a 64 × 64 depth test. A simulation demo produces frames from that output.
> Broader self-checking verification and performance characterization remain
> in progress.

## Project scope

| Area | Design direction |
| --- | --- |
| Hardware | Synthesizable SystemVerilog RTL |
| Graphics function | Fixed-function triangle processing |
| Initial datapath | Triangle input → setup → rasterization → interpolation → depth test → pixel output |
| Numeric representation | Signed fixed-point screen coordinates |
| Control model | Ready/valid streaming with backpressure |
| Reference behavior | Independent Python model |
| End goal | Verified baseline, measured bottleneck, and architecture-level optimization |

## Architecture

The planned baseline pipeline is organized as a sequence of explicit hardware
stages:

```text
Triangle input
      │
      ▼
Triangle setup
  area, winding, bounds,
  coverage metadata
      │
      ▼
Rasterizer
  pixel-center coverage,
  clipped scan traversal
      │
      ▼
Interpolator
  depth and color attributes
      │
      ▼
Depth test / pixel output
  compare against depth buffer,
  emit visible pixel stream
      │
      ▼
Pixel output
```

The current beta carries triangles from setup through rasterization,
interpolation, and depth testing to a ready/valid pixel output. The demo uses a
64 × 64 depth buffer; it does not include a color framebuffer or a display
interface.

### Triangle setup

Setup handles the work that does not need to be repeated independently for
every candidate pixel. It identifies degenerate triangles, normalizes their
orientation, calculates the clipped candidate region, and prepares the
coverage data used by the rasterizer.

### Rasterization

The baseline rasterizer scans the setup region in row-major order. It applies
the documented triangle-coverage rules to each candidate pixel and emits only
covered samples.

This deliberately straightforward implementation is useful as a baseline: its
work is visible, its ordering is deterministic, and its throughput limits can
be measured before considering parallel coverage lanes or other optimizations.

### Interpolation and depth

For each covered sample, the interpolator calculates depth and RGBA color from
the triangle's vertex attributes. The depth stage compares that sample against
the stored value for its pixel and forwards it only when it is nearer.

This is an initial functional implementation. It stops before programmable
shading, texture sampling, color blending, or writing a complete image to a
hardware framebuffer.

## RTL-rendered demos

These clips come from accepted pixel outputs of the SystemVerilog simulation.
Python prepares the triangles for each frame and rebuilds frames from the
recorded output pixels; triangle coverage, color/depth interpolation, and the
depth test run in RTL. The satellite's rotation and projection are prepared on
the host, so the demo does not claim a hardware 3D transform or a hardware
capture.

| Rotating satellite | Mountain sunset |
| --- | --- |
| ![Rotating satellite rendered from RTL pixel output](docs/media/rtl_satellite.gif) | ![Mountain sunset rendered from RTL pixel output](docs/media/rtl_sunset.gif) |

[Satellite MP4](docs/media/rtl_satellite.mp4) · [Sunset MP4](docs/media/rtl_sunset.mp4) · [Three-scene reel](docs/media/rtl_demo_reel.mp4)

To regenerate all three clips on Windows, install Python 3.10 or newer,
Icarus Verilog, and FFmpeg. Make sure `iverilog`, `vvp`, and `ffmpeg` are on
`PATH`, then run:

```powershell
python -m pip install -r requirements-demo.txt
.\scripts\run_showcase_videos.ps1
```

The frames, GIF previews, and MP4s are written under
`results/demo/generated/showcase/`.

## Design contract

The initial prototype uses a deliberately bounded and reproducible configuration:

| Parameter | Initial choice |
| --- | --- |
| Screen coordinates | Signed 16-bit fixed point |
| Coordinate format | Q12.4 |
| Coordinate scale | 16 units per screen pixel |
| Simulation bounds | 64 × 64 pixels |
| Primitive ID | 8 bits |
| Pixel sample location | Pixel centers |
| Triangle convention | Deterministic shared-edge coverage |
| Candidate traversal | Row-major |
| Degenerate triangles | No covered-pixel output |

These values define the starting engineering contract. They are choices for a
bounded educational prototype, not claims about the implementation of AMD,
NVIDIA, Apple, Meta, or any other commercial GPU.

## Streaming and backpressure

The stages communicate with ready/valid interfaces. A transaction transfers
only when both signals are asserted:

```text
transfer = valid && ready
```

If a downstream stage cannot accept a transaction, the upstream stage holds its
valid bit and data stable. This makes stalls explicit and lets the verification
environment test whether work is preserved across backpressure.

The rasterizer is stateful because one triangle can produce a variable number
of pixels. Its scan position, triangle state, and output transaction must remain
consistent while the pipeline advances normally or waits on a stalled consumer.

## Verification

The Python model is intended to be an independent behavioral specification for
the geometry rules. The current video harness records RTL output for display;
it is not a golden-reference comparison. RTL-to-model checking and broader
self-checking verification remain next.

The verification environment is being developed around:

- Directed triangles with known expected pixel coverage
- Reversed winding and degenerate geometry
- Off-screen geometry and framebuffer boundaries
- Shared-edge tests for deterministic ownership
- Fixed-point and pixel-center boundary cases
- RTL-to-model output comparison
- Randomized triangles and primitive sequences
- Randomized downstream stalls and backpressure
- Assertions for ready/valid stability and ordering
- Conservation checks for lost, duplicated, or reordered transactions

The objective is to verify both numerical behavior and protocol behavior. A
single plausible-looking image is not sufficient evidence for a design that
must also behave correctly under stalls, boundary conditions, and different
workload shapes.

## Performance study

Once the baseline path is correct, the team will measure how work and waiting
are distributed across the pipeline. Planned counters include:

- Triangles accepted
- Candidate pixels evaluated
- Covered pixels generated
- Output pixels retired
- Active and stalled cycles
- Backpressure events
- Stage utilization
- Buffer occupancy
- End-to-end latency and sustained throughput

Controlled workloads will isolate different behaviors. Small triangles expose
setup overhead, large triangles stress rasterization throughput, overlapping
triangles exercise depth behavior, and bursty or artificially stalled traffic
tests buffering and flow control.

The optimization will be chosen from those measurements rather than assumed in
advance. Depending on the observed bottleneck, the experiment may evaluate
parallel rasterization lanes, deeper buffering, arithmetic pipelining, or a
more efficient scan strategy. The result will be compared against the same
baseline workloads using performance, timing, and hardware-cost evidence.

## Scope

The project intentionally focuses on a bounded fixed-function datapath. The
initial scope does not include:

- Programmable shaders
- Texture sampling or filtering
- Graphics APIs and drivers
- A commercial GPU instruction set
- Large cache hierarchies or a general-purpose memory system
- Reproduction of proprietary vendor architecture

Keeping this boundary fixed allows the team to go deeper on RTL design,
verification, and measured microarchitectural tradeoffs.

## Repository structure

```text
docs/
  Architecture, verification, performance, and experiment documentation

rtl/
  Synthesizable SystemVerilog stages and top-level integration

model/
  Independent Python reference model and workload behavior

tb/
  Testbench, drivers, monitors, scoreboards, assertions, and tests

scripts/
  Regression, analysis, and visualization utilities

synthesis/
  Tool setup, constraints, and reproducible synthesis notes

results/
  Curated measurements, plots, and baseline-versus-optimized evidence
```

## Development path

1. Freeze the triangle and pixel interface contract.
2. Verify the integrated triangle-to-pixel RTL slice.
3. Compare the RTL pixel stream against the independent model.
4. Complete RTL-to-model comparison for interpolation and depth behavior.
5. Exercise randomized stalls, assertions, and broader regression.
6. Characterize the baseline across controlled workloads.
7. Implement one optimization supported by measured evidence.
8. Re-run correctness, performance, and synthesis comparisons.

The final deliverable is intended to show the complete engineering loop:
architecture definition, synthesizable implementation, independent
verification, performance characterization, and a documented optimization
tradeoff.

## Current checks

From the repository root, run the Python coverage regression with:

```powershell
python -m unittest discover -s tb/tests -v
```

The integrated SystemVerilog geometry slice can be compiled and smoke-tested
with Icarus Verilog:

```powershell
New-Item -ItemType Directory -Force .sim_tmp
iverilog -g2012 -s geometry_smoke_tb -o .sim_tmp/geometry_smoke.vvp `
  rtl/triangle_setup/triangle_setup.sv `
  rtl/rasterizer/rasterizer.sv `
  rtl/graphics_accelerator/graphics_accelerator.sv `
  tb/rtl/geometry_smoke_tb.sv
vvp .sim_tmp/geometry_smoke.vvp
```

The smoke test drives a known triangle, checks the expected covered-pixel
sequence, and applies output backpressure. The target verification flow will
extend this with randomized triangles, broader stall patterns, assertions, and
RTL-to-model comparison.

## Project context

This is an independent academic hardware project. The repository is intended to
make the design decisions, verification evidence, and performance claims
reproducible for technical reviewers and future users of the work.
