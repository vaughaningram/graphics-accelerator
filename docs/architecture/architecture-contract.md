# Architecture Contract — Draft 0

This document is the first design checkpoint. Values marked **candidate** are starting points for team review, not frozen requirements.

## System boundary

The accelerator accepts one triangle transaction at a time through a top-level ready/valid input and emits accepted pixel transactions through a top-level ready/valid output. Internal stages may buffer work and must preserve transaction ordering.

## Candidate baseline parameters

| Item | Candidate value | Decision needed |
| --- | --- | --- |
| Simulation framebuffer | 64 × 64 | Confirm test/runtime target |
| Screen coordinates | Signed fixed point, candidate S12.4 | Confirm range and subpixel precision |
| Depth | Unsigned fixed point, candidate U0.16 | Confirm compare direction and clear value |
| Color | 8 bits/channel, candidate RGB888 or RGBA8888 | Choose output representation |
| Triangle fill rule | Candidate top-left convention | Define shared-edge behavior |
| Degenerate triangles | Candidate: emit no fragments | Confirm required behavior |
| Depth comparison | Candidate: less-than | Confirm convention |
| Output | Candidate pixel stream plus optional simulation framebuffer | Define storage boundary |
| Reset | Synchronous reset; all valid bits cleared | Confirm clock/reset assumptions |

## Transaction sketches

### Triangle input

The final packed representation is TBD. The logical fields are:

- `vertex0`, `vertex1`, `vertex2` screen coordinates
- Per-vertex depth
- Per-vertex color or other interpolated attribute
- Optional transaction ID for scoreboard/debug correlation

### Pixel output

The logical fields are:

- Pixel coordinate
- Interpolated depth
- Color/attribute value
- Optional transaction ID or primitive ID

## Required invariants

- A stage may accept input only when `in_valid && in_ready` is true.
- A producer holds transaction data stable while `valid=1` and `ready=0`.
- A transaction is neither dropped nor duplicated across stage boundaries.
- Output ordering matches the documented rasterization/primitive ordering rule.
- No fragment outside the documented framebuffer bounds is emitted.
- Fixed-point overflow, truncation, and rounding behavior are explicit and testable.
- Reset clears all in-flight valid state and returns counters/state to documented values.

## First team meeting decisions

1. Freeze the numeric formats and triangle convention.
2. Decide whether the first integrated output is a stream, a memory-backed framebuffer, or both.
3. Select the simulator and the minimum reproducible regression command.
4. Define the first golden triangle set by hand, including one overlap/depth case.

