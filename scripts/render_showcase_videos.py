"""Turn accepted RTL pixel records into per-scene frames and preview GIFs."""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "results" / "demo" / "generated" / "showcase"
TRACE = OUT_DIR / "video_pixel_trace.csv"
FRAMES_PER_SCENE = 24
SCENES = ("satellite", "sunset", "orbit")
WIDTH = HEIGHT = 64
SCALE = 12
DURATION_MS = 100
BACKGROUND = (5, 8, 21)


def main() -> None:
    events_by_frame: dict[int, list[dict[str, str]]] = defaultdict(list)
    with TRACE.open(newline="", encoding="utf-8") as trace_file:
        for row in csv.DictReader(trace_file):
            events_by_frame[int(row["frame"])].append(row)
    if not events_by_frame:
        raise RuntimeError(f"No accepted RTL pixels found in {TRACE}")

    frame_dirs = {name: OUT_DIR / "frames" / name for name in SCENES}
    for directory in frame_dirs.values():
        directory.mkdir(parents=True, exist_ok=True)

    scene_frames: dict[str, list[Image.Image]] = {name: [] for name in SCENES}
    for scene_index, scene_name in enumerate(SCENES):
        for local_frame in range(FRAMES_PER_SCENE):
            global_frame = scene_index * FRAMES_PER_SCENE + local_frame
            image = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
            for row in events_by_frame.get(global_frame, []):
                x, y = int(row["x"]), int(row["y"])
                color = int(row["rgba"], 16)
                if not (0 <= x < WIDTH and 0 <= y < HEIGHT):
                    raise ValueError(f"RTL emitted an out-of-range pixel ({x}, {y})")
                image.putpixel((x, y), ((color >> 24) & 255,
                                        (color >> 16) & 255,
                                        (color >> 8) & 255))
            enlarged = image.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.Resampling.NEAREST)
            enlarged.save(frame_dirs[scene_name] / f"frame_{local_frame:03d}.png")
            scene_frames[scene_name].append(enlarged)

        first, *rest = scene_frames[scene_name]
        first.save(OUT_DIR / f"{scene_name}_preview.gif", save_all=True,
                   append_images=rest, duration=DURATION_MS, loop=0, optimize=False)

    reel = [frame for scene in SCENES for frame in scene_frames[scene]]
    reel[0].save(OUT_DIR / "rtl_showcase_reel.gif", save_all=True,
                 append_images=reel[1:], duration=DURATION_MS, loop=0, optimize=False)

    sheet = Image.new("RGB", (3 * 320, 360), (7, 10, 23))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, scene_name in enumerate(SCENES):
        sample = scene_frames[scene_name][12].resize((320, 320), Image.Resampling.NEAREST)
        x = index * 320
        sheet.paste(sample, (x, 0))
        draw.text((x + 12, 332), scene_name.upper(), fill=(223, 232, 255), font=font)
    sheet.save(OUT_DIR / "showcase_contact_sheet.png")

    pixels = sum(len(events_by_frame.get(i, [])) for i in range(len(SCENES) * FRAMES_PER_SCENE))
    print(f"Rendered {len(SCENES) * FRAMES_PER_SCENE} RTL frames; "
          f"{pixels} accepted output pixels across {len(SCENES)} clips.")
    print(f"GIF reel: {OUT_DIR / 'rtl_showcase_reel.gif'}")
    print(f"Contact sheet: {OUT_DIR / 'showcase_contact_sheet.png'}")


if __name__ == "__main__":
    main()
