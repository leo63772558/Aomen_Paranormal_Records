import json
from pathlib import Path
from PIL import Image

sheet_path = Path("assets/characters/jiamin_walk_061.png")
layout_path = Path("assets/characters/jiamin_walk_061_layout.json")
image = Image.open(sheet_path).convert("RGBA")
width, height = image.size
columns, rows = 6, 8
frames = []
for row in range(rows):
    row_frames = []
    y0 = round(row * height / rows)
    y1 = round((row + 1) * height / rows)
    for column in range(columns):
        x0 = round(column * width / columns)
        x1 = round((column + 1) * width / columns)
        cell = image.crop((x0, y0, x1, y1))
        visible = cell.getchannel("A").point(lambda value: 255 if value > 128 else 0).getbbox()
        if visible is None:
            raise SystemExit(f"empty animation frame: row={row}, column={column}")
        if visible[1] < 0 or visible[3] > y1 - y0:
            raise SystemExit(f"frame escapes atlas cell: row={row}, column={column}")
        row_frames.append({
            "region": [x0, y0, x1 - x0, y1 - y0],
            "anchor": [round((x1 - x0) / 2.0, 2), 184.0],
        })
    frames.append(row_frames)

layout = {
    "columns": columns,
    "rows": rows,
    "scale": 0.30,
    "frames": frames,
    "verification": "48 transparent full-body frames; 8 directions by 6 loopable walk poses; baseline fixed at y=184.",
}
layout_path.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"wrote {layout_path} for {width}x{height} atlas")
