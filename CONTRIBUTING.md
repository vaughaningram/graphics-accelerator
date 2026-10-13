# Contributing

## Branches and pull requests

- Keep `main` integration-ready.
- Create a focused branch for each change: `feat/...`, `fix/...`, `test/...`, `docs/...`, or `perf/...`.
- Open a pull request with the problem, implementation, verification evidence, and any performance impact.
- Request at least one teammate review before merging.
- Do not merge a change that modifies RTL behavior without updating the relevant test or reference-model expectation.

## Commit guidance

Use concise, imperative subjects, for example:

- `Add edge-function reference tests`
- `Implement ready-valid rasterizer output`
- `Measure baseline overdraw workload`

Keep generated waveforms, simulator work directories, and raw synthesis output out of Git unless a small curated artifact is specifically needed to support a conclusion.

## Technical review checklist

- Is the interface behavior documented?
- Are reset and stall cases covered?
- Does the Python model remain independent of RTL control flow?
- Are fixed-point widths, rounding, and overflow behavior explicit?
- Does the change affect latency, throughput, resource use, or timing?
- Is the result reproducible from a documented command and seed?

