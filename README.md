# Graphics Accelerator

An independent senior capstone project developing a small, synthesizable,
fixed-function graphics accelerator in SystemVerilog.

The project is being developed by Vaughan Ingram, Daniel Jarka, and Romil Shah
with AMD sponsorship. Its purpose is not to recreate a commercial GPU. Instead,
we are using a bounded graphics datapath to study the parts of accelerator
engineering that are easy to describe but difficult to get right in hardware:
numeric representation, pipeline control, variable-rate work, verification,
measurement, and architecture-level tradeoffs.

## Project in one sentence

The accelerator accepts fixed-point triangles, determines which pixels they
cover, processes those pixel fragments through a hardware pipeline, and emits a
deterministic pixel stream or framebuffer result.

## Why this project

Graphics is a useful vehicle for a serious hardware design project because one
triangle creates a variable amount of work. A small triangle may produce only a
few fragments; a large triangle may produce hundreds. Downstream stages can
also run at different rates, which makes buffering, backpressure, ordering, and
memory behavior central design concerns.

The project follows a measured engineering loop:

```text
Specify → design → implement → verify → measure → optimize → re-verify
```

The final result should demonstrate not only that the hardware produces the
right pixels, but also why the architecture behaves the way it does and what
changes improve it.

## Current milestone: geometry RTL beta

The current implementation is focused on the first complete geometry slice:

```text
Triangle input
      │
      ▼
Triangle setup
      │
      ▼
Rasterization
      │
      ▼
Covered-pixel stream
```

This slice establishes the core triangle-to-pixel behavior before adding color
and depth processing. The repository currently contains the setup and
rasterizer building blocks, along with the independent Python behavior model
used to define expected coverage.

The immediate RTL integration goal is a clean top-level path that accepts one
triangle transaction and emits the same covered-pixel sequence predicted by the
reference model.

## Architecture overview

The planned baseline pipeline is:

```text
Triangle input
      │
      ▼
Triangle setup
  area, winding, bounds,
  edge equations
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

Each stage has a focused responsibility and communicates through an explicit
streaming interface. That makes it possible to test stages independently,
inject stalls, and later change one part of the architecture without hiding
the effects in a monolithic block.

### Triangle setup

Triangle setup performs the work that is constant for every pixel of a
triangle. It computes the signed doubled area, identifies degenerate geometry,
normalizes winding, and calculates the candidate pixel bounds.

It then converts the triangle edges into integer equations of the form:

```text
E(x, y) = A·x + B·y + C
```

The sign of each edge equation at a pixel center determines whether the sample
is inside the triangle. Setup also produces top-left-rule metadata so adjacent
triangles share boundaries deterministically without cracks or double-owned
pixels.

### Rasterization

The baseline rasterizer scans the clipped bounding box in row-major order. For
each candidate pixel, it evaluates the three edge equations and emits a pixel
only when the coverage rules pass.

This is intentionally a simple baseline. It makes the work and its cost easy
to observe, giving us a clear reference point for later experiments such as
parallel coverage lanes, improved scan traversal, or deeper arithmetic
pipelining.

### Future fragment processing

Once geometry coverage is integrated and verified, the pipeline will be
extended with fixed-point interpolation for attributes such as depth and color.
The depth stage will compare fragments against stored depth values and control
which pixels reach the final output.

These stages are planned work, not claims about a finished commercial GPU.

## Current numerical contract

The initial beta uses a small, deterministic configuration:

| Item | Current choice |
| --- | --- |
| Screen coordinates | Signed 16-bit fixed point |
| Coordinate format | Q12.4 by default |
| Coordinate scale | 16 coordinate units per screen pixel |
| Simulation framebuffer | 64 × 64 pixels |
| Primitive ID | 8 bits |
| Pixel sampling | Pixel centers |
| Triangle convention | Winding normalization plus top-left rule |
| Candidate traversal | Row-major |
| Degenerate triangles | No covered-pixel output |

These are explicit engineering choices for a reproducible prototype. They are
not intended to represent proprietary AMD, NVIDIA, Apple, or Meta hardware.

## Flow control

The design uses ready/valid streaming interfaces at stage boundaries.

A transaction transfers only when both sides agree:

```text
transfer = valid && ready
```

When a downstream stage is unable to accept data, the upstream stage holds its
valid bit and transaction fields stable. This allows the design to handle
backpressure without dropping, duplicating, or reordering work.

The rasterizer is stateful because one triangle can produce a variable number
of pixels. Its scan position and output data must remain correct across both
normal progress and arbitrary downstream stalls.

## Verification strategy

The Python model serves as an independent behavioral specification. It defines
the expected geometric result without copying the RTL's control structure.

The verification plan includes:

- Directed triangles with known expected coverage
- Reversed winding and degenerate geometry
- Off-screen and framebuffer-boundary cases
- Shared-edge tests for the top-left rule
- Fixed-point and pixel-center boundary cases
- RTL-to-model output comparison
- Randomized triangle workloads
- Randomized downstream stalls and backpressure
- Assertions for ready/valid stability and transaction ordering
- Checks for lost, duplicated, or reordered pixel transactions

The goal is to prove the protocol and numerical behavior, not just inspect
whether one rendered image appears visually plausible.

## Performance and architecture study

After the baseline is correct, the team will characterize it using controlled
workloads. Candidate workload classes include:

- Small triangles that emphasize setup overhead
- Large triangles that stress rasterization throughput
- Sparse triangles that expose candidate-pixel work
- Overlapping triangles that stress depth behavior
- Bursty input that exercises buffering
- Artificial output stalls that expose backpressure effects

Instrumentation will distinguish useful work from waiting. Planned measurements
include triangle throughput, fragment throughput, latency, stage activity,
stall cycles, backpressure events, and buffer occupancy.

The optimization will be selected from measured evidence. Depending on the
bottleneck, it could involve additional rasterization lanes, deeper buffering,
reduced arithmetic serialization, improved scan localization, or a deeper
pipeline around a critical timing path. The final comparison will include both
performance improvement and hardware cost.

## Scope boundary

The initial project intentionally excludes:

- Programmable shaders
- Texture sampling and filtering
- Graphics APIs and drivers
- A commercial GPU instruction set
- Large cache hierarchies and a general-purpose memory system
- Reproduction of proprietary AMD or other vendor architecture

This boundary keeps the project focused on datapath design, verification, and
measurable microarchitectural decisions.

## Repository layout

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

## Development milestones

1. Freeze the triangle and pixel interface contract.
2. Complete and verify the triangle-to-pixel RTL beta.
3. Add interpolation and depth behavior to the model and RTL.
4. Integrate end-to-end verification with randomized stalls.
5. Characterize the baseline across controlled workloads.
6. Choose and implement one measured architectural optimization.
7. Re-run correctness, performance, and synthesis comparisons.
8. Document the final design, tradeoffs, limitations, and evidence.

## Running the current Python checks

From the repository root:

```powershell
python -m unittest discover -s tb/tests -v
```

The RTL beta is being brought up incrementally as the SystemVerilog tool flow
is finalized. RTL changes are intended to be checked against the independent
model rather than treated as correct solely because they compile.

## Team

- Vaughan Ingram — technical lead; architecture, RTL, integration, and sponsor communication
- Daniel Jarka — performance analysis, instrumentation, and verification
- Romil Shah — project execution, tooling, documentation, and integration

All major design decisions, verification evidence, and performance claims are
intended to be reproducible from the repository.

