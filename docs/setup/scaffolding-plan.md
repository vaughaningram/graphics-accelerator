# Repository and Scaffolding Plan

## GitHub configuration

Recommended repository slug: `graphics-accelerator`.

Start public only after checking that the repository contains no AMD-confidential material, internal names, proprietary examples, or sponsor-provided files. The project itself should remain an independent educational prototype.

Recommended initial configuration:

- Default branch: `main`
- Collaborators: Vaughan, Daniel, and Romil
- Pull requests required for `main`
- At least one teammate review before merge
- Issues and Projects enabled
- Actions enabled once the simulator/toolchain is selected
- Repository topics: `systemverilog`, `rtl`, `hardware-verification`, `graphics`, `computer-architecture`

## First GitHub milestones

### M0 — Architecture contract

Freeze the transaction schema, coordinate/depth/color formats, framebuffer boundary, triangle fill rule, reset behavior, and simulator choice.

### M1 — Reference model

Implement a software rasterization model and golden tests before the full RTL pipeline.

### M2 — Baseline RTL

Implement the smallest complete pipeline with deterministic output and ready/valid behavior.

### M3 — Verification infrastructure

Add drivers, monitors, scoreboard, assertions, randomized stalls, coverage, and regression commands.

### M4 — Performance characterization

Run controlled workload classes and identify the measured bottleneck.

### M5 — Optimization experiment

Implement one architecture change tied to a written bottleneck hypothesis and compare it against the same baseline workloads.

### M6 — Synthesis and final evidence

Reproduce timing/resource measurements, curate results, and document limitations.

## Suggested initial issue split

### Vaughan

- Own the architecture contract and top-level transaction schema.
- Implement the first setup-stage/reference-model alignment.
- Lead integration and sponsor-facing technical reviews.

### Daniel

- Define counters and workload formats.
- Build the performance-results schema and analysis plan.
- Contribute a baseline workload generator and characterization scripts.

### Romil

- Create milestones, issue templates, and meeting decision records.
- Track toolchain setup and regression reproducibility.
- Own documentation completeness and release/demo checklists.

All three members should review and understand every major stage.

## Initial implementation order

1. `model/` — integer/fixed-point reference behavior and golden cases.
2. `rtl/common/` — package definitions and ready/valid register slices.
3. `rtl/triangle_setup/` — area, winding normalization, bounds, and coefficients.
4. `rtl/rasterizer/` — clipped scan traversal and edge-function coverage.
5. `rtl/interpolation/` — depth/color evaluation with documented quantization.
6. `rtl/depth/` — deterministic read/compare/write behavior.
7. `rtl/output/` — pixel stream and optional simulation framebuffer.
8. `tb/` — end-to-end driver, monitor, scoreboard, assertions, and regression.

