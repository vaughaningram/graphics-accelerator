# Performance Methodology

## Baseline metrics

Collect at least:

- Total cycles and pipeline latency
- Triangles accepted/completed
- Fragments generated/completed
- Pixels written
- Depth tests, passes, and rejects
- Per-stage active, idle, and stall cycles
- Backpressure and FIFO full/empty cycles
- FIFO occupancy statistics

## Workload suite

- Small-triangle front-end pressure
- Large-triangle fragment pressure
- Sparse geometry
- High-overdraw/depth pressure
- Saturated input
- Bursty input
- Controlled artificial downstream backpressure

## Analysis rule

Every optimization begins with a written bottleneck hypothesis and ends with a comparison against the same workload, configuration, and correctness suite used for the baseline.

Report both cycle-level and time-based throughput:

`time-based throughput ≈ useful work/cycle × clock frequency`

Resource cost, timing, and throughput must be discussed together.

