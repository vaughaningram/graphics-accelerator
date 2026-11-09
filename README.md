# Pipelined Graphics Accelerator

**RTL design, verification, and performance characterization**

This repository contains the implementation and evaluation of a synthesizable,
fixed-function graphics pipeline developed for a senior capstone project and
sponsored by AMD.

The design begins with a geometry datapath that accepts screen-space triangles,
determines their covered pixels, and emits those pixels through a streaming RTL
interface. The complete design will extend this path with fixed-point attribute
interpolation, depth testing, framebuffer behavior, and a measured
architecture optimization.

> **Current status — Geometry RTL beta**
> Triangle setup and rasterizer stages are implemented. The next integration
> step is the top-level triangle-to-pixel path and its SystemVerilog simulation.

## Project scope

| Area | Design direction |
| --- | --- |
| Hardware | Synthesizable SystemVerilog RTL |
| Graphics function | Fixed-function triangle processing |
| Initial datapath | Triangle input → setup → rasterization → pixel stream |
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
Depth test / framebuffer
  compare, accept, and store
      │
      ▼
Pixel output
```

The first working slice stops after rasterization. This gives the team a small,
complete geometry path that can be integrated and verified before adding the
state and arithmetic of later stages.

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

### Later stages

After the geometry path is integrated, the pipeline will evaluate depth and
color at each covered sample. A depth stage will compare each fragment with the
stored depth value and control whether the fragment reaches the output.

Those stages are part of the target architecture; the current beta is focused
on establishing the triangle-to-pixel contract first.

## Design contract

The initial prototype uses a deliberately small and reproducible configuration:

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

The Python model is an independent behavioral specification for the geometry
rules. It defines expected coverage without reproducing the RTL state machine,
which gives the hardware an external reference for comparison.

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
2. Integrate the triangle setup and rasterizer into the first RTL beta.
3. Compare the RTL pixel stream against the independent model.
4. Add interpolation and depth behavior.
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

The SystemVerilog flow is being brought up alongside the RTL beta. The target
verification flow will compile the design, drive triangle transactions, apply
backpressure, and compare the emitted pixel sequence against the Python model.

## Project context

This is an independent academic hardware project. The repository is intended to
make the design decisions, verification evidence, and performance claims
reproducible for technical reviewers and future users of the work.

