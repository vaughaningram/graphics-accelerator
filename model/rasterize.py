"""Deterministic fixed-point triangle coverage."""

from typing import Iterable, List, Tuple

from .fixed import clamp, edge_function
from .types import Config, Pixel, Triangle, Vertex


def _area(triangle: Triangle) -> int:
    return edge_function(
        triangle.v0.x,
        triangle.v0.y,
        triangle.v1.x,
        triangle.v1.y,
        triangle.v2.x,
        triangle.v2.y,
    )


def _swap_winding(triangle: Triangle) -> Triangle:
    """Reverse winding while preserving each vertex's attributes."""

    return Triangle(triangle.v0, triangle.v2, triangle.v1, triangle.primitive_id)


def _is_top_left(a: Vertex, b: Vertex) -> bool:
    """Top-left classification for screen coordinates with y increasing down."""

    dy = b.y - a.y
    dx = b.x - a.x
    return dy < 0 or (dy == 0 and dx > 0)


def _inside(edge_value: int, top_left: bool) -> bool:
    """Apply the top-left rule to one oriented edge."""

    return edge_value > 0 or (edge_value == 0 and top_left)


def normalized_triangle(triangle: Triangle) -> Triangle | None:
    """Return a positive-area triangle, or ``None`` for a degenerate one."""

    area = _area(triangle)
    if area == 0:
        return None
    return triangle if area > 0 else _swap_winding(triangle)


def triangle_bounds(triangle: Triangle, config: Config) -> Tuple[int, int, int, int]:
    """Return the inclusive, framebuffer-clipped pixel bounding box."""

    scale = config.coord_scale
    # Pixel centers are x*scale + scale/2.  The floor/ceil conversion below
    # finds every pixel whose center could be inside the vertex bounding box.
    min_x = (min(triangle.v0.x, triangle.v1.x, triangle.v2.x) - scale // 2) // scale
    max_x = (max(triangle.v0.x, triangle.v1.x, triangle.v2.x) - scale // 2) // scale
    min_y = (min(triangle.v0.y, triangle.v1.y, triangle.v2.y) - scale // 2) // scale
    max_y = (max(triangle.v0.y, triangle.v1.y, triangle.v2.y) - scale // 2) // scale
    return (
        clamp(min_x, 0, config.width - 1),
        clamp(max_x, 0, config.width - 1),
        clamp(min_y, 0, config.height - 1),
        clamp(max_y, 0, config.height - 1),
    )


def rasterize_triangle(triangle: Triangle, config: Config = Config()) -> List[Pixel]:
    """Return covered pixels in deterministic row-major order.

    This is the first executable behavioral contract for the accelerator.  It
    intentionally performs only setup, coverage, and ordering; interpolation
    and depth testing are the next model stages.
    """

    triangle = normalized_triangle(triangle)
    if triangle is None:
        return []

    x_min, x_max, y_min, y_max = triangle_bounds(triangle, config)
    if x_min > x_max or y_min > y_max:
        return []

    vertices = (triangle.v0, triangle.v1, triangle.v2)
    top_left = tuple(_is_top_left(vertices[i], vertices[(i + 1) % 3]) for i in range(3))
    scale = config.coord_scale
    half = scale // 2
    pixels: List[Pixel] = []

    for y in range(y_min, y_max + 1):
        py = y * scale + half
        for x in range(x_min, x_max + 1):
            px = x * scale + half
            covered = all(
                _inside(
                    edge_function(
                        vertices[i].x,
                        vertices[i].y,
                        vertices[(i + 1) % 3].x,
                        vertices[(i + 1) % 3].y,
                        px,
                        py,
                    ),
                    top_left[i],
                )
                for i in range(3)
            )
            if covered:
                pixels.append(Pixel(x, y, triangle.primitive_id))

    return pixels

