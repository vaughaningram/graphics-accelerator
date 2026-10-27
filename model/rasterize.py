"""Deterministic fixed-point triangle coverage."""

from typing import List

from .fixed import edge_function
from .setup import setup_triangle
from .types import Config, Pixel, Triangle


def _inside(edge_value: int, top_left: bool) -> bool:
    """Apply the top-left rule to one oriented edge."""

    return edge_value > 0 or (edge_value == 0 and top_left)


def rasterize_triangle(triangle: Triangle, config: Config = Config()) -> List[Pixel]:
    """Return covered pixels in deterministic row-major order.

    This is the first executable behavioral contract for the accelerator.  It
    intentionally performs only setup, coverage, and ordering; interpolation
    and depth testing are the next model stages.
    """

    setup = setup_triangle(triangle, config)
    if setup is None:
        return []

    x_min, x_max, y_min, y_max = setup.x_min, setup.x_max, setup.y_min, setup.y_max
    if x_min > x_max or y_min > y_max:
        return []

    edges = setup.edges
    scale = config.coord_scale
    half = scale // 2
    pixels: List[Pixel] = []

    for y in range(y_min, y_max + 1):
        py = y * scale + half
        for x in range(x_min, x_max + 1):
            px = x * scale + half
            covered = all(
                _inside(edge.evaluate(px, py), edge.top_left) for edge in edges
            )
            if covered:
                pixels.append(Pixel(x, y, setup.triangle.primitive_id))

    return pixels

