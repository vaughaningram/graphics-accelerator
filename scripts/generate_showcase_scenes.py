"""Prepare screen-space triangle scenes for the RTL-rendered video showcase."""

from __future__ import annotations

import math
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "results" / "demo" / "generated" / "showcase"
SCENE_FILE = OUT_DIR / "scene_triangles.dat"
FRAMES_PER_SCENE = 24
SCENE_COUNT = 3
TRIANGLES_PER_FRAME = 18
COORD_SCALE = 16

SCENE_NAMES = ("satellite", "sunset", "orbit")
RGB = tuple[int, int, int]
Vertex3 = tuple[float, float, float]
Triangle = tuple[tuple[float, float, int, RGB], ...]


def rgba(color: RGB) -> int:
    red, green, blue = color
    return (red << 24) | (green << 16) | (blue << 8) | 255


def mix_color(a: RGB, b: RGB, amount: float) -> RGB:
    return tuple(round(x + (y - x) * amount) for x, y in zip(a, b))  # type: ignore[return-value]


def screen_triangle(
    points: Iterable[tuple[float, float]], depths: Iterable[int], colors: Iterable[RGB]
) -> Triangle:
    return tuple((x, y, depth, color) for (x, y), depth, color in zip(points, depths, colors))  # type: ignore[return-value]


def background_triangles(top: RGB, bottom: RGB) -> list[Triangle]:
    tl, tr = mix_color(top, (min(255, top[0] + 8), min(255, top[1] + 8), min(255, top[2] + 18)), 0.55), top
    bl, br = bottom, mix_color(bottom, (min(255, bottom[0] + 15), min(255, bottom[1] + 5), min(255, bottom[2] + 15)), 0.65)
    return [
        screen_triangle(((0, 0), (64, 0), (64, 64)), (62000,) * 3, (tl, tr, br)),
        screen_triangle(((0, 0), (64, 64), (0, 64)), (62000,) * 3, (tl, br, bl)),
    ]


def rotate_vertex(vertex: Vertex3, frame: int) -> tuple[float, float, float]:
    x, y, z = vertex
    angle = 2.0 * math.pi * frame / FRAMES_PER_SCENE
    tilt = math.radians(20.0 + 13.0 * math.sin(angle * 2.0))
    roll = math.radians(7.0 * math.sin(angle))

    x1 = x * math.cos(angle) + z * math.sin(angle)
    z1 = -x * math.sin(angle) + z * math.cos(angle)
    y2 = y * math.cos(tilt) - z1 * math.sin(tilt)
    z2 = y * math.sin(tilt) + z1 * math.cos(tilt)
    x3 = x1 * math.cos(roll) - y2 * math.sin(roll)
    y3 = x1 * math.sin(roll) + y2 * math.cos(roll)
    return x3, y3, z2


def satellite_scene(frame: int) -> list[Triangle]:
    points: list[Triangle] = []
    model: list[tuple[Vertex3, RGB]] = []
    body: tuple[Vertex3, ...] = (
        (0.0, 1.15, 0.0), (0.92, 0.0, 0.0), (0.0, 0.0, 0.92),
        (-0.92, 0.0, 0.0), (0.0, 0.0, -0.92), (0.0, -1.15, 0.0),
    )
    faces = (
        ((0, 1, 2), (40, 227, 245)), ((0, 2, 3), (20, 150, 245)),
        ((0, 3, 4), (95, 92, 250)), ((0, 4, 1), (65, 196, 230)),
        ((5, 2, 1), (245, 174, 53)), ((5, 3, 2), (255, 108, 76)),
        ((5, 4, 3), (210, 66, 159)), ((5, 1, 4), (156, 93, 240)),
    )

    def add_model_triangle(vertices: tuple[Vertex3, Vertex3, Vertex3], palette: tuple[RGB, RGB, RGB]) -> None:
        projected = []
        for vertex, color in zip(vertices, palette):
            rx, ry, rz = rotate_vertex(vertex, frame)
            sx, sy = 32.0 + 9.6 * rx, 32.0 - 10.4 * ry
            depth = max(0, min(65535, round(32768.0 - 7600.0 * rz)))
            projected.append((sx, sy, depth, color))
        points.append(tuple(projected))

    for face, base in faces:
        verts = tuple(body[index] for index in face)
        shades = tuple(mix_color(base, (170, 235, 255), level) for level in (0.00, 0.20, 0.43))
        add_model_triangle(verts, shades)  # type: ignore[arg-type]

    # Four split solar panels keep the silhouette readable as the craft turns.
    panel_colors = ((22, 218, 247), (29, 105, 226), (37, 176, 231), (72, 237, 213))
    for side in (-1, 1):
        intervals = ((1.12, 2.05), (2.05, 3.02)) if side > 0 else ((-2.05, -1.12), (-3.02, -2.05))
        for segment, (xa, xb) in enumerate(intervals):
            x0, x1 = min(xa, xb), max(xa, xb)
            quad = ((x0, -0.70, -0.04), (x1, -0.70, -0.04),
                    (x1, 0.70, -0.04), (x0, 0.70, -0.04))
            base = panel_colors[(side + segment) % len(panel_colors)]
            palette = (mix_color(base, (6, 32, 89), 0.12), base,
                       mix_color(base, (165, 255, 237), 0.25),
                       mix_color(base, (12, 67, 143), 0.18))
            for indices in ((0, 1, 2), (0, 2, 3)):
                add_model_triangle(tuple(quad[index] for index in indices), tuple(palette[index] for index in indices))  # type: ignore[arg-type]

    # A small two-triangle antenna catches the highlight above the main body.
    antenna = ((-0.16, 1.05, 0.02), (0.16, 1.05, 0.02), (0.0, 1.85, 0.02), (0.0, 1.45, 0.12))
    antenna_color = ((111, 239, 248), (40, 160, 235), (255, 198, 94), (255, 238, 170))
    for indices in ((0, 1, 3), (0, 3, 2)):
        add_model_triangle(tuple(antenna[index] for index in indices), tuple(antenna_color[index] for index in indices))  # type: ignore[arg-type]

    if len(points) != TRIANGLES_PER_FRAME:
        raise RuntimeError(f"Satellite scene generated {len(points)} triangles")
    return points


def sunset_scene(frame: int) -> list[Triangle]:
    triangles = background_triangles((7, 13, 43), (50, 19, 77))
    t = frame / (FRAMES_PER_SCENE - 1)
    sun_x, sun_y = 46.0 - 10.0 * t, 15.0 + 13.0 * t
    sun_radius = 6.1
    ring = [
        (sun_x + sun_radius * math.cos(2 * math.pi * index / 6),
         sun_y + sun_radius * math.sin(2 * math.pi * index / 6))
        for index in range(6)
    ]
    sun_palette = ((255, 235, 143), (255, 189, 73), (255, 124, 57),
                   (255, 158, 64), (255, 220, 117), (255, 243, 177))
    for index in range(6):
        triangles.append(screen_triangle(
            ((sun_x, sun_y), ring[index], ring[(index + 1) % 6]),
            (47000, 47000, 47000),
            ((255, 243, 174), sun_palette[index], sun_palette[(index + 1) % 6]),
        ))

    mountain_faces = (
        (((0, 45), (14, 26), (29, 47)), ((38, 62, 129), (126, 137, 210), (67, 74, 154))),
        (((13, 47), (31, 21), (49, 47)), ((53, 58, 132), (156, 130, 199), (93, 64, 153))),
        (((35, 47), (52, 28), (64, 46)), ((75, 55, 133), (182, 119, 190), (81, 57, 142))),
        (((0, 51), (11, 39), (21, 52)), ((36, 68, 116), (94, 118, 170), (47, 75, 128))),
    )
    for coords, colors in mountain_faces:
        triangles.append(screen_triangle(coords, (30000,) * 3, colors))

    foreground_quads = (
        (((0, 51), (28, 45), (30, 64), (0, 64)),
         ((19, 67, 102), (48, 107, 127), (20, 54, 102), (9, 35, 79))),
        (((22, 53), (48, 47), (64, 52), (64, 64)),
         ((19, 57, 100), (48, 91, 124), (20, 59, 101), (8, 31, 76))),
        (((0, 58), (26, 51), (40, 64), (0, 64)),
         ((14, 45, 91), (30, 77, 116), (7, 28, 70), (6, 23, 64))),
    )
    for coords, colors in foreground_quads:
        for indices in ((0, 1, 2), (0, 2, 3)):
            triangles.append(screen_triangle(
                tuple(coords[index] for index in indices), (18000,) * 3,
                tuple(colors[index] for index in indices),
            ))

    if len(triangles) != TRIANGLES_PER_FRAME:
        raise RuntimeError(f"Sunset scene generated {len(triangles)} triangles")
    return triangles


def orbit_scene(frame: int) -> list[Triangle]:
    triangles = background_triangles((4, 9, 28), (17, 13, 49))
    angle = 2.0 * math.pi * frame / FRAMES_PER_SCENE
    spin = angle * 0.72
    center = (32.0, 32.0)
    perimeter = []
    ring_colors: list[RGB] = []
    ring_depths: list[int] = []
    for index in range(8):
        a = spin + 2.0 * math.pi * index / 8
        radius = 17.0 if index % 2 == 0 else 11.5
        perimeter.append((center[0] + radius * math.cos(a), center[1] + radius * math.sin(a)))
        hue = index / 8
        if hue < 0.34:
            color = mix_color((29, 235, 234), (58, 114, 255), hue / 0.34)
        elif hue < 0.67:
            color = mix_color((58, 114, 255), (198, 75, 255), (hue - 0.34) / 0.33)
        else:
            color = mix_color((198, 75, 255), (255, 126, 83), (hue - 0.67) / 0.33)
        ring_colors.append(color)
        ring_depths.append(31800 + round(1400 * math.sin(a * 2.0)))

    for index in range(8):
        nxt = (index + 1) % 8
        center_color = mix_color(ring_colors[index], ring_colors[nxt], 0.52)
        triangles.append(screen_triangle(
            (center, perimeter[index], perimeter[nxt]),
            (31000, ring_depths[index], ring_depths[nxt]),
            (center_color, ring_colors[index], ring_colors[nxt]),
        ))

    def add_orbiting_gem(phase: float, orbit_radius: float, size: float,
                         palette: tuple[RGB, RGB, RGB, RGB], base_depth: int) -> None:
        cx = 32.0 + orbit_radius * math.cos(phase)
        cy = 32.0 + orbit_radius * 0.73 * math.sin(phase)
        rotation = -phase * 0.55
        corners = tuple(
            (cx + size * math.cos(rotation + math.pi / 4 + index * math.pi / 2),
             cy + size * math.sin(rotation + math.pi / 4 + index * math.pi / 2))
            for index in range(4)
        )
        hub_color = mix_color(palette[0], palette[2], 0.5)
        for index in range(4):
            triangles.append(screen_triangle(
                ((cx, cy), corners[index], corners[(index + 1) % 4]),
                (base_depth - 900, base_depth, base_depth + 400),
                (hub_color, palette[index], palette[(index + 1) % 4]),
            ))

    add_orbiting_gem(angle + 0.25, 22.0, 5.7,
                     ((69, 234, 255), (38, 126, 250), (61, 79, 220), (147, 91, 255)),
                     21000 + round(8000 * (0.5 + 0.5 * math.sin(angle))))
    add_orbiting_gem(-angle * 1.35 + 2.7, 20.0, 4.8,
                     ((255, 199, 90), (255, 105, 93), (223, 73, 176), (255, 145, 101)),
                     39000 - round(8000 * (0.5 + 0.5 * math.sin(angle + 1.2)))
    )

    if len(triangles) != TRIANGLES_PER_FRAME:
        raise RuntimeError(f"Orbit scene generated {len(triangles)} triangles")
    return triangles


SCENE_BUILDERS = (satellite_scene, sunset_scene, orbit_scene)


def write_triangle(scene_file, frame_index: int, primitive_id: int, triangle: Triangle) -> None:
    fields: list[str | int] = [frame_index, primitive_id]
    for x, y, _, _ in triangle:
        fields.extend((round(x * COORD_SCALE), round(y * COORD_SCALE)))
    fields.extend(vertex[2] for vertex in triangle)
    fields.extend(f"{rgba(vertex[3]):08x}" for vertex in triangle)
    scene_file.write(" ".join(map(str, fields)) + "\n")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with SCENE_FILE.open("w", encoding="ascii", newline="\n") as scene_file:
        for scene_index, build_scene in enumerate(SCENE_BUILDERS):
            for local_frame in range(FRAMES_PER_SCENE):
                global_frame = scene_index * FRAMES_PER_SCENE + local_frame
                for primitive_id, triangle in enumerate(build_scene(local_frame), start=1):
                    write_triangle(scene_file, global_frame, primitive_id, triangle)

    print(f"Wrote {SCENE_COUNT} scenes × {FRAMES_PER_SCENE} frames × "
          f"{TRIANGLES_PER_FRAME} triangles: {SCENE_FILE}")


if __name__ == "__main__":
    main()
