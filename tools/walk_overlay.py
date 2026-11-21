"""Composite walk_audit.json reachable cells over each room's background art."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
out = root / "docs/build_reports/walk_audit"
data = json.loads((out / "walk_audit.json").read_text(encoding="utf-8"))
for room, r in data.items():
    if "cells" not in r:
        print(room, r.get("error")); continue
    bx, by, bw, bh = r["bounds"]
    canvas = Image.new("RGBA", (int(bw), int(bh)), (20, 20, 20, 255))
    if "background" in r:
        src = Image.open(root / r["background"].replace("res://", "")).convert("RGBA")
        if "bg_region" in r:
            x, y, w, h = r["bg_region"]; src = src.crop((int(x), int(y), int(x + w), int(y + h)))
        sw, sh = src.size
        w, h = int(sw * r["bg_scale"][0]), int(sh * r["bg_scale"][1])
        src = src.resize((max(1, w), max(1, h)))
        ox, oy = r["bg_origin"]
        if r.get("bg_centered"):
            ox -= w / 2; oy -= h / 2
        canvas.alpha_composite(src, (int(ox - bx), int(oy - by)))
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    s = r["step"]
    for cx, cy in r["cells"]:
        d.rectangle([cx * s, cy * s, cx * s + s - 1, cy * s + s - 1], fill=(0, 255, 90, 70))
    sx, sy = r["start"]
    d.ellipse([sx - bx - 6, sy - by - 6, sx - bx + 6, sy - by + 6], fill=(255, 40, 40, 255))
    canvas.alpha_composite(overlay)
    canvas.convert("RGB").save(out / f"{room}.png")
    print(room, len(r["cells"]))
