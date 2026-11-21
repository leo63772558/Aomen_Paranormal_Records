"""Inspect sprite alpha/LED landmarks and write layout metadata; does not edit pixels."""
from pathlib import Path
from PIL import Image
import json
import statistics

root = Path(__file__).resolve().parent.parent
image = Image.open(root / "assets/characters/ahhao_walk_043.png").convert("RGBA")
rows = []
heights = []
for row in range(8):
    poses = []
    for column in range(4):
        left, top = round(column * image.width / 4), round(row * image.height / 8)
        right, bottom = round((column + 1) * image.width / 4), round((row + 1) * image.height / 8)
        cell = image.crop((left, top, right, bottom))
        alpha = cell.getchannel("A")
        opaque = alpha.point(lambda value: 255 if value > 160 else 0)
        # Ignore isolated fringe pixels: body rows have a meaningful occupied width.
        scan = []
        for y in range(cell.height):
            xs = [x for x in range(cell.width) if opaque.getpixel((x, y))]
            if len(xs) >= 5: scan.append((y, xs))
        if not scan: raise ValueError((row, column, "empty cell"))
        min_y, max_y = scan[0][0], scan[-1][0]
        valid = [(y, xs) for y, xs in scan if min_y <= y <= max_y]
        min_x = min(min(xs) for _, xs in valid)
        max_x = max(max(xs) for _, xs in valid)
        foot_xs = [x for y, xs in valid if y >= max_y - 9 for x in xs]
        anchor_x = statistics.median(foot_xs)
        heights.append(max_y - min_y + 1)
        led = []
        for y in range(round(min_y + (max_y - min_y) * 0.14), round(min_y + (max_y - min_y) * 0.55)):
            for x in range(min_x, max_x + 1):
                r, g, b, a = cell.getpixel((x, y))
                if a > 170 and min(r, g, b) > 178 and max(r, g, b) - min(r, g, b) < 40:
                    led.append((x, y))
        if len(led) < 3: raise ValueError((row, column, "LED landmark needs review"))
        lens = (statistics.mean(x for x, _ in led), statistics.mean(y for _, y in led))
        region_left = max(0, min_x - 2)
        region_top = max(0, min_y - 2)
        pose = {"region":[left + region_left, top + region_top, min(cell.width, max_x + 3) - region_left, min(cell.height, max_y + 3) - region_top],
                "anchor":[round(anchor_x - region_left, 2), max_y + 1 - region_top],
                "torch_lens":[round(lens[0] - region_left, 2), round(lens[1] - region_top, 2)],
                "led_pixels":len(led)}
        poses.append(pose)
    rows.append([poses[index] for index in [0, 1, 2, 3, 2, 1]])
layout = {"source":"ahhao_walk_043.png", "scale":round(54.0 / statistics.median(heights), 6),
          "direction_order":["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"],
          "frames":rows, "verification":"Alpha/LED landmark extraction; requires hidden render review."}
path = root / "assets/characters/ahhao_walk_043_layout.json"
path.write_text(json.dumps(layout, ensure_ascii=False, indent=2), encoding="utf-8")
print(path)
print("scale", layout["scale"], "median_height", statistics.median(heights))
