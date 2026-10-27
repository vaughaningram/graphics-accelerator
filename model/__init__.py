"""Reference model for the graphics accelerator."""

from .types import Config, Pixel, Triangle, Vertex
from .rasterize import rasterize_triangle

__all__ = ["Config", "Pixel", "Triangle", "Vertex", "rasterize_triangle"]

