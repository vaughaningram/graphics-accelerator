"""Triangle setup shared by the reference model and its tests."""

from typing import Optional, Tuple

from .fixed import clamp, edge_function
from .types import Config, EdgeEquation, SetupResult, Triangle, Vertex


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
    return Triangle(triangle.v0, triangle.v2, triangle.v1, triangle.primitive_id)


def _is_top_left(a: Vertex, b: Vertex) -> bool:
    dy = b.y - a.y
    dx = b.x - a.x
    return dy < 0 or (dy == 0 and dx > 0)


def _edge(a: Vertex, b: Vertex) -> EdgeEquation:
    dx = b.x - a.x
    dy = b.y - a.y
    return EdgeEquation(
        a=-dy,
        b=dx,
        c=dy * a.x - dx * a.y,
        top_left=_is_top_left(a, b),
    )


def _triangle_bounds(triangle: Triangle, config: Config) -> Tuple[int, int, int, int]:
    scale = config.coord_scale
    half = scale // 2

    def ceil_div(value: int, divisor: int) -> int:
        return -((-value) // divisor)

    min_x = ceil_div(min(triangle.v0.x, triangle.v1.x, triangle.v2.x) - half, scale)
    max_x = (max(triangle.v0.x, triangle.v1.x, triangle.v2.x) - scale // 2) // scale
    min_y = ceil_div(min(triangle.v0.y, triangle.v1.y, triangle.v2.y) - half, scale)
    max_y = (max(triangle.v0.y, triangle.v1.y, triangle.v2.y) - scale // 2) // scale
    return (
        clamp(min_x, 0, config.width - 1),
        clamp(max_x, 0, config.width - 1),
        clamp(min_y, 0, config.height - 1),
        clamp(max_y, 0, config.height - 1),
    )


def setup_triangle(triangle: Triangle, config: Config = Config()) -> Optional[SetupResult]:
    """Normalize winding and calculate the rasterizer's immutable setup data."""

    area = _area(triangle)
    if area == 0:
        return None

    normalized = triangle if area > 0 else _swap_winding(triangle)
    area = abs(area)
    x_min, x_max, y_min, y_max = _triangle_bounds(normalized, config)
    vertices = (normalized.v0, normalized.v1, normalized.v2)
    edges = tuple(_edge(vertices[i], vertices[(i + 1) % 3]) for i in range(3))
    return SetupResult(normalized, area, x_min, x_max, y_min, y_max, edges)  # type: ignore[arg-type]

