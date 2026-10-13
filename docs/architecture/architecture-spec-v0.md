# Graphics Accelerator Architecture — v0 Proposal

This is a proposed architecture for discussion and implementation. It is specific enough to explain in an interview, but the candidate widths and buffer depths remain subject to team review.

## One-sentence description

The accelerator accepts a stream of fixed-point triangles, converts each triangle into covered pixel fragments using edge equations, interpolates depth and color, performs an ordered depth test, and emits visible pixels through an elastic ready/valid pipeline.

## Why this scope

The design deliberately stops at a fixed-function raster pipeline. That gives the team real problems in datapath arithmetic, stateful variable-rate work generation, flow control, memory ordering, verification, and performance analysis without introducing shader programming, APIs, drivers, or a full GPU memory system.

## Proposed v0 boundary

| Parameter | Proposed starting point | Why it is useful |
| --- | --- | --- |
| Framebuffer | 64 × 64 simulation target | Fast regressions and easy visual inspection |
| Coordinates | Signed 16-bit fixed point with 4 fractional bits | Supports off-screen clipping and subpixel positions |
| Depth | Unsigned 16-bit fixed point | Sufficient for a bounded prototype and simple comparisons |
| Color | RGB888 or RGBA8888 | Easy software comparison and visualization |
| Triangle convention | Normalize winding, then use a top-left fill rule | Prevents cracks/double ownership on shared edges |
| Baseline rasterization | One candidate pixel evaluated at a time | Simple reference point that exposes throughput limits |
| Stage buffers | Small elastic register/FIFO boundaries | Allows backpressure experiments without hiding control flow |
| Output | Pixel stream; optional model-side framebuffer | Separates core pipeline from storage policy |

These are engineering defaults, not claims about Apple or AMD implementations.

## Datapath

```text
triangle input
      │
      ▼
input FIFO / command boundary
      │
      ▼
triangle setup
  area, winding, bounds,
  edge coefficients,
  interpolation coefficients
      │
      ▼
rasterizer
  clipped scan traversal,
  edge-function coverage
      │
      ▼
interpolator
  depth and color evaluation,
  fixed-point quantization
      │
      ▼
depth test / framebuffer state
  compare, accept/reject,
  deterministic write ordering
      │
      ▼
output FIFO / pixel stream
```

Every boundary carries `valid`, `ready`, and a transaction record. A transfer occurs only on `valid && ready`.

## Stage responsibilities

### 1. Input boundary

The input boundary accepts a triangle only when the first stage has capacity. It assigns or preserves a primitive ID for scoreboard correlation. An input FIFO can absorb short bursts without changing the functional ordering of triangles.

### 2. Triangle setup

Setup performs the work that is constant for every pixel of a triangle:

- Compute signed twice-area to detect degenerates and determine winding.
- Normalize orientation or record the sign used by coverage tests.
- Compute a clipped integer bounding box.
- Build edge-function coefficients.
- Prepare depth/color plane coefficients or per-pixel increments.

For an edge from `a` to `b`, the coverage function can be written as:

`E_ab(x,y) = (y_a - y_b)x + (x_b - x_a)y + x_a y_b - x_b y_a`

At a pixel center, the sign of the three edge functions determines whether the sample is inside. The top-left rule changes the equality case for horizontal/top-left edges so adjacent triangles do not both claim or both reject a shared edge.

The setup stage is a natural place to discuss arithmetic width, signed overflow, winding normalization, and whether division/reciprocal calculation is multi-cycle or pipelined.

### 3. Rasterizer

The baseline rasterizer scans the clipped bounding box in deterministic row-major order. It evaluates the three edge functions at the current sample location. Covered samples become fragment transactions; uncovered samples advance the scan cursor without producing output.

The rasterizer is stateful because one input triangle produces a variable number of fragments. Its scan coordinates advance only when the current candidate has been accepted by the next internal step. If downstream backpressure prevents progress, the current triangle and cursor remain stable.

This stage is intentionally a likely performance bottleneck. A later optimization might use multiple coverage lanes, tile localization, or a more parallel candidate generator—but the optimization should be chosen after measurements.

### 4. Interpolator

For an attribute `q`, the implementation can use a plane form:

`q(x,y) = A_q x + B_q y + C_q`

The setup stage can compute coefficients, and the interpolator can evaluate them at each covered pixel. An alternative is incremental stepping: add a fixed `Δx` when moving across a row and a fixed `Δy` when moving to the next row. Incremental stepping can reduce multipliers but makes scan-order and restart behavior important.

The v0 design should document where quantization occurs, how negative values round, and how overflow is detected or prevented. The Python model must implement those rules explicitly rather than relying on host-language floating-point behavior.

### 5. Depth test and framebuffer state

For each fragment, the depth stage reads the stored depth, compares it using the selected convention, and writes depth/color only for an accepted fragment. Primitive order must be deterministic so overlapping triangles produce reproducible results.

The first simulation implementation may use arrays for depth and color. The architecture should still model the intended memory semantics, including read latency, write timing, and whether the target memory is single-port or dual-port. This keeps simulation results relevant to later synthesis.

### 6. Output boundary

Accepted pixels are emitted as a stream and may also be captured by a model-side framebuffer for image comparison. The output FIFO is a useful place to inject artificial backpressure and validate that earlier stages hold state correctly.

## Flow control model

Each registered stage follows the elastic-register rule:

```text
stage_ready = !stage_valid || downstream_ready
```

On a clock edge:

- If the stage accepts new input, it captures the input record.
- If the stage transfers its current record and has no replacement, it clears `valid`.
- If `valid=1` and downstream `ready=0`, it holds both data and control state stable.

Assertions should check stability under stall, no transfer without a valid transaction, and conservation of accepted versus retired transactions.

## Reset and frame control

Reset clears all valid bits, FIFO pointers, scan state, counters, and in-flight transaction state. Clearing a full depth/color memory should be modeled as an explicit initialization or frame-clear operation rather than assuming every memory bit can be reset in one cycle.

The team should decide whether frame boundaries use a control transaction, a separate `start_frame/end_frame` interface, or an external reset/clear sequence.

## Baseline versus optimization

The baseline should favor clarity and determinism:

- One triangle setup context at a time.
- One rasterization candidate at a time.
- Small stage buffers.
- Simple fixed-point datapaths.
- Full counters and traceability.

After characterization, write a hypothesis such as:

> Large-triangle workloads saturate the rasterizer because coverage is evaluated serially; adding two independent coverage lanes should increase fragment throughput, subject to depth-memory bandwidth and timing cost.

Possible measured optimizations include more rasterization lanes, deeper buffering, reduced arithmetic serialization, improved scan localization, or a deeper pipeline around a critical path. The final choice must follow the counters and synthesis results.

