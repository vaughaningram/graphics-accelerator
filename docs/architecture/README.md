# Architecture

## Baseline pipeline candidate

`triangle_input → triangle_setup → rasterizer → interpolator → depth_test → output`

Each stage should document:

- Transaction schema and data widths
- Ready/valid behavior
- Latency and maximum throughput
- Internal state and buffering
- Reset semantics
- Numerical corner cases
- Assertions and directed tests

## Architecture decision log

### ADR-000 — Start with a bounded fixed-function pipeline

**Status:** Proposed

**Decision:** Begin with triangle setup, rasterization, interpolation, depth testing, and framebuffer/output. Defer shaders, textures, graphics APIs, caches, and a full memory subsystem.

**Rationale:** This preserves enough structure for meaningful pipeline, verification, and performance questions while protecting the capstone from feature creep.

**Validation:** The baseline must be complete, synthesizable, verified, instrumented, and characterized before scope expands.

## Near-term design task

Write the architecture contract before implementing RTL. The contract should define the smallest end-to-end triangle transaction and the exact expected output for the reference model.

