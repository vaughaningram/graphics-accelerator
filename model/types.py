"""Data types shared by the reference-model stages.

Coordinates are stored as signed fixed-point integers.  With the default
configuration, one screen pixel is 16 coordinate units (Q12.4).
"""

from dataclasses import dataclass
from typing import Tuple


RGBA = Tuple[int, int, int, int]


@dataclass(frozen=True)
class Config:
    width: int = 64
    height: int = 64
    coord_frac_bits: int = 4
    depth_bits: int = 16

    @property
    def coord_scale(self) -> int:
        return 1 << self.coord_frac_bits


@dataclass(frozen=True)
class Vertex:
    """A vertex using fixed-point screen coordinates."""

    x: int
    y: int
    depth: int = 0
    color: RGBA = (255, 255, 255, 255)

    @classmethod
    def from_pixels(
        cls,
        x: float,
        y: float,
        *,
        config: Config = Config(),
        depth: int = 0,
        color: RGBA = (255, 255, 255, 255),
    ) -> "Vertex":
        """Create a vertex from pixel-space coordinates.

        The conversion is intentionally explicit and rounded to the nearest
        fixed-point value so test vectors do not silently use floating point
        inside the rasterizer.
        """

        scale = config.coord_scale
        return cls(round(x * scale), round(y * scale), depth, color)


@dataclass(frozen=True)
class Triangle:
    v0: Vertex
    v1: Vertex
    v2: Vertex
    primitive_id: int = 0


@dataclass(frozen=True)
class Pixel:
    x: int
    y: int
    primitive_id: int = 0

