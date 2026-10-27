"""Reference model for the graphics accelerator."""

from .setup import setup_triangle
from .types import Config, EdgeEquation, Pixel, SetupResult, Triangle, Vertex
from .rasterize import rasterize_triangle

__all__ = [
    "Config",
    "EdgeEquation",
    "Pixel",
    "SetupResult",
    "Triangle",
    "Vertex",
    "rasterize_triangle",
    "setup_triangle",
]

