# Interview Panel Brief

## 90-second project explanation

> I am leading a three-person capstone to build a small fixed-function graphics accelerator in synthesizable SystemVerilog. It accepts fixed-point triangles and runs them through setup, rasterization, interpolation, depth testing, and pixel output. The important part is not just producing an image. We are building an independent Python reference model, a verification environment with scoreboarding, assertions, randomized stalls, and regression, and performance counters for throughput, latency, utilization, FIFO behavior, and backpressure. We will first establish a correct baseline, characterize it with controlled workloads, then choose an architectural optimization from the measured bottleneck and compare the baseline and optimized designs for both cycle-level performance and synthesis cost. The project gives us ownership of architecture, RTL, verification, and performance reasoning rather than treating those as separate activities.

## How to explain the rasterizer

For each triangle, setup computes a signed area and three edge equations. The bounding box limits the number of candidate pixels. At each pixel center, the rasterizer evaluates the edge functions; the signs determine coverage. A top-left tie-breaking rule gives shared edges deterministic ownership. Covered samples become fragments, while the scan cursor advances over uncovered samples without emitting work.

## How to explain the pipeline control

The pipeline uses ready/valid interfaces. A transaction transfers only when both signals are high. If a downstream stage stalls, the upstream stage holds its valid bit and data stable. Small elastic buffers decouple stages and make burstiness measurable. This is important because the rasterizer produces a variable number of fragments per triangle, while the depth/output side may have a different service rate.

## How to explain verification

The Python model is an independent executable specification. Directed tests cover simple triangles, boundaries, degenerates, shared edges, interpolation, and depth overlap. Random tests vary geometry and transaction sequences. The testbench compares the RTL fragment/framebuffer result with the model, while assertions check ready/valid stability, FIFO safety, reset behavior, ordering, and transaction conservation. Randomized downstream backpressure tests both protocol correctness and performance sensitivity.

## How to explain performance

Counters distinguish work from waiting. For a stage, `fire = valid && ready` represents a transfer, `valid && !ready` represents a stall, and `!valid` represents an empty stage. The design records triangles, fragments, pixels, depth passes/rejects, per-stage activity, backpressure, and FIFO occupancy. Workloads isolate behavior: small triangles stress setup, large triangles stress rasterization, overdraw stresses depth, bursty input stresses buffering, and artificial backpressure tests decoupling.

## How to explain the optimization strategy

We are intentionally not claiming the optimization in advance. The baseline produces evidence first. If measurements show the rasterizer is saturated, we may add parallel coverage lanes. If a long arithmetic path limits frequency, deeper pipelining may be better. If stalls are caused by insufficient decoupling, buffering may help—but only if the bottleneck is not downstream. We will rerun the same workloads and report throughput, latency, timing, resource cost, and whether the hypothesis was actually supported.

## Strong technical tradeoffs to discuss

- More parallel lanes can increase fragments/cycle but consume more area and memory bandwidth.
- Deeper pipelining can improve Fmax while increasing latency and control complexity.
- Larger FIFOs can absorb bursts but cannot improve a permanently slower stage.
- Fixed-point arithmetic is cheaper and more synthesizable than floating point, but requires explicit precision, rounding, overflow, and edge-case rules.
- A framebuffer makes the demo tangible, but memory port behavior can become the real throughput limit.
- UVM is not the goal by itself; a lightweight structured environment is appropriate if it gives better functional checking and reproducibility for this bounded design.

## Likely panel questions

### Why not build a complete GPU?

Because the project is studying hardware design, verification, and performance tradeoffs. Shaders, APIs, drivers, caches, and a full memory system would add breadth without improving the core experiment enough to justify the scope risk.

### What is the hardest correctness problem?

The interaction of fixed-point geometry, edge inclusion rules, variable-rate fragment generation, and backpressure. A rendered image can look plausible even when shared edges, stalls, or transaction conservation are wrong, so we verify those explicitly.

### What is the likely bottleneck?

We do not know yet, and that is intentional. The baseline instrumentation will distinguish setup throughput, rasterization throughput, interpolation arithmetic, depth-memory service rate, and buffering/backpressure effects.

### What would you do next?

Freeze the interface and numerical contract, implement the reference model, create golden tests, then build the smallest end-to-end RTL path. I would not choose a parallelization strategy until the baseline has produced evidence.

## Interview boundary

Describe this as an independent academic prototype influenced by general hardware engineering practice. Do not imply access to Apple or AMD proprietary architecture, implementation details, or confidential data.

