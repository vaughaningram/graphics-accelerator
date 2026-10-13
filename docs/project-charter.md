# Project Charter

## Working title

Pipelined Graphics Accelerator — RTL Design, Verification, and Performance Characterization

## Team and ownership

| Member | Primary emphasis | Shared responsibilities |
| --- | --- | --- |
| Vaughan Ingram | Technical lead; architecture, RTL, integration, sponsor contact | RTL, verification, performance, documentation |
| Daniel Jarka | Performance lead; instrumentation and analysis | RTL, verification, integration, documentation |
| Romil Shah | Project manager; milestones and execution | RTL, verification, integration, documentation |

Primary emphasis is not a silo. Each member should be able to explain the full datapath, verification strategy, and performance conclusions.

## Problem statement

Build a synthesizable graphics accelerator that converts triangle data into framebuffer or output-stream pixels while handling fixed-point arithmetic, pipeline latency, ready/valid flow control, stalls, backpressure, and workload-dependent performance variation.

## Core engineering question

After establishing a correct baseline, which measured microarchitectural bottleneck most limits useful throughput, and what is the quantified tradeoff of changing the architecture to address it?

## Minimum viable product

The MVP must:

- Accept a defined triangle transaction format.
- Produce deterministic rasterized output for a documented framebuffer/output format.
- Include triangle setup, rasterization, at least one interpolated attribute, depth testing, and output storage/streaming.
- Use synthesizable SystemVerilog with registered stage boundaries.
- Use ready/valid interfaces at stage boundaries or an explicitly documented equivalent.
- Match an independent software reference model on directed and randomized tests.
- Exercise stalls/backpressure and prove no transaction loss, duplication, or reordering.
- Report cycle counts, throughput, latency, stage activity, and stall/backpressure metrics.
- Produce a baseline-versus-optimized comparison driven by measurements.
- Include synthesis/timing/resource results for the selected target or tool flow.

## Initial exclusions

The first milestone excludes programmable shaders, a commercial GPU ISA, CUDA/OpenGL/Vulkan/DirectX integration, texture mapping/filtering, full caches or memory systems, and reproduction of proprietary AMD/RDNA implementation details.

## Engineering principles

1. Keep the scope bounded; add features only after the baseline is correct and measurable.
2. Define interfaces and numerical behavior before writing each block.
3. Keep the reference model independent of RTL implementation details.
4. Treat performance counters as part of the experiment infrastructure, not as an afterthought.
5. Select the optimization from measured evidence, not preference.
6. Re-run the same correctness and performance workloads for baseline and optimized designs.
7. Record assumptions, seeds, tool versions, and configuration with every result.

## Proposed phase gates

### Gate 0 — Architecture contract

Agree on coordinate/depth/color formats, framebuffer size, transaction schema, triangle convention, reset behavior, and the first simulator/tool flow.

### Gate 1 — Reference model

Implement a clear software model with golden tests for triangle coverage, interpolation, depth behavior, and edge cases.

### Gate 2 — Baseline pipeline

Integrate the simplest complete synthesizable pipeline and connect it to the testbench with deterministic output comparison.

### Gate 3 — Robust verification

Add randomized triangles, randomized downstream stalls, assertions, scoreboard checks, and a repeatable regression command.

### Gate 4 — Baseline characterization

Run small, large, sparse, overdraw, saturated, bursty, and artificial-backpressure workloads. Identify the limiting stage or interaction.

### Gate 5 — Optimization experiment

State a bottleneck hypothesis, implement one meaningful architectural change, re-run the same tests/workloads, and compare throughput, latency, timing, utilization, and resource cost.

### Gate 6 — Synthesis and final evidence

Freeze the designs, reproduce synthesis, curate plots/tables, document limitations, and prepare the final demo/report.

## Decisions still requiring team/sponsor agreement

- Target environment: FPGA board, ASIC-style synthesis estimate, or both.
- Simulator and language/tool support.
- Initial framebuffer dimensions and output interface.
- Fixed-point formats and rounding/saturation rules.
- Top-level command/triangle interface and transaction IDs.
- Triangle fill convention for shared edges and degenerates.
- Whether depth is a full framebuffer, a bounded tile, or an abstract memory model in the first milestone.
- Which performance counters are architectural RTL counters versus simulation-only instrumentation.
- The exact schedule and rubric-driven deliverables.

## Sponsor boundary

AMD feedback may inform scope, methodology, and engineering tradeoffs. The implementation remains an independent educational prototype and must not depend on confidential information or attempt to reproduce proprietary commercial architecture.

