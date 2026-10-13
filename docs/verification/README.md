# Verification Plan

## Verification layers

1. Unit tests for arithmetic and triangle-coverage primitives.
2. Stage-level ready/valid and stall tests.
3. End-to-end RTL versus Python reference-model comparison.
4. Randomized triangles and randomized backpressure.
5. Assertions for protocol, FIFO, ordering, reset, and transaction conservation.
6. Regression summaries containing failures, seeds, counters, and coverage evidence.

## Required edge cases

- Degenerate and near-degenerate triangles
- Screen-boundary and partially off-screen triangles
- Shared-edge fill behavior
- Minimum/maximum coordinate and depth values
- Depth pass and depth reject
- Downstream stalls while valid is asserted
- FIFO empty, near-full, and full conditions
- Reset during idle and at documented transaction boundaries

## Reference-model rule

The model should express intended graphics behavior independently of RTL stage structure. It may share data-format definitions, but it should not duplicate RTL control logic.

