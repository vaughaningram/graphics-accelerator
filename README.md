# Graphics Accelerator

Senior capstone project by Vaughan Ingram, Daniel Jarka, and Romil Shah, sponsored by AMD.

## Project thesis

Design and implement a bounded, fixed-function graphics accelerator in synthesizable SystemVerilog; establish correctness with an independent software reference model; characterize the baseline across controlled workloads; identify a measured bottleneck; and implement an architectural optimization whose performance and hardware cost can be quantified.

The central loop is:

**Specify → design → implement → verify → measure → optimize → re-verify → synthesize → compare**

This is an accelerator study, not an attempt to reproduce a commercial GPU.

## Initial scope

The planned baseline pipeline is:

`Triangle input → setup → rasterization → interpolation → depth test → framebuffer/output`

The design will emphasize ready/valid flow control, registered stages, fixed-point arithmetic, buffering, assertions, automated regression, and performance instrumentation.

Shaders, textures, graphics APIs, drivers, large cache hierarchies, and proprietary AMD architecture are out of scope for the initial project.

## Repository map

| Path | Purpose |
| --- | --- |
| `docs/` | Architecture, verification, performance, and experiment documentation |
| `rtl/` | Synthesizable SystemVerilog |
| `tb/` | Testbench, drivers, monitors, scoreboards, assertions, and tests |
| `model/` | Independent Python reference model and workload generation |
| `scripts/` | Regression, analysis, and visualization tooling |
| `synthesis/` | Tool setup, constraints, and reproducible synthesis notes |
| `results/` | Curated baseline/optimized measurements and plots |

## First engineering gates

1. Freeze the minimum viable interface and numerical format.
2. Implement and verify one end-to-end baseline path before adding features.
3. Add counters and controlled workloads before choosing an optimization.

Open decisions are recorded in [`docs/project-charter.md`](docs/project-charter.md) and the architecture decision log.

## Team workflow

- `main` is the integration branch.
- Use short-lived branches such as `feat/triangle-setup` or `test/random-stalls`.
- Every RTL change should include or update a test and, when relevant, a reference-model comparison.
- Performance claims should include the workload, configuration, simulator/synthesis tool, seed, and raw counter evidence.
- Keep sponsor feedback and project decisions in the repository rather than only in chat or meetings.

## Status

Repository scaffold and v0 architecture plan created. RTL implementation and toolchain selection are next.


