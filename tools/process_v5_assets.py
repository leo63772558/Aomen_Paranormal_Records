"""Process v5 realistic horror art assets with zero white halos / clean alpha cutouts."""
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path("d:/Aomen_Paranormal_Records")

def flood_cut_white_quads(src_path: Path, dst_path: Path, flip_h: bool = False) -> None:
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    hw, hh = w // 2, h // 2
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for qy in range(2):
        for qx in range(2):
            sub = im.crop((qx * hw, qy * hh, (qx + 1) * hw, (qy + 1) * hh))
            sw, sh = sub.size
            px = sub.load()
            vis = bytearray(sw * sh)
            q = deque()
            def seed(x, y):
                r, g, b, a = px[x, y]
                if r > 225 and g > 225 and b > 225:
                    idx = y * sw + x
                    if not vis[idx]:
                        vis[idx] = 1
                        q.append((x, y))
            for x in range(sw):
                seed(x, 0); seed(x, sh - 1)
            for y in range(sh):
                seed(0, y); seed(sw - 1, y)
            while q:
                cx, cy = q.popleft()
                px[cx, cy] = (0, 0, 0, 0)
                for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
                    if 0 <= nx < sw and 0 <= ny < sh:
                        idx = ny * sw + nx
                        if not vis[idx]:
                            r, g, b, a = px[nx, ny]
                            if r > 214 and g > 214 and b > 214 and max(r, g, b) - min(r, g, b) < 22:
                                vis[idx] = 1
                                q.append((nx, ny))
            # 1px defringe pass against transparent background
            for y in range(1, sh - 1):
                for x in range(1, sw - 1):
                    r, g, b, a = px[x, y]
                    if a > 0 and r > 192 and g > 192 and b > 192 and max(r, g, b) - min(r, g, b) < 25:
                        if any(px[x + dx, y + dy][3] == 0 for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                            px[x, y] = (0, 0, 0, 0)
            if flip_h:
                sub = sub.transpose(Image.FLIP_LEFT_RIGHT)
            out.paste(sub, (qx * hw, qy * hh))
    out.save(dst_path)
    print("CUT", dst_path, out.size)

def defringe_sprite(path: Path, lum_thresh: int = 185) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    removed = 0
    for _pass in range(2):
        to_clear = []
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                if any(px[x + dx, y + dy][3] == 0 for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    if r > lum_thresh and g > lum_thresh and b > lum_thresh and (max(r, g, b) - min(r, g, b) < 34):
                        to_clear.append((x, y))
                    elif a < 90:
                        to_clear.append((x, y))
        for x, y in to_clear:
            px[x, y] = (0, 0, 0, 0)
            removed += 1
    im.save(path)
    print(f"DEFRINGED {path.name}: cleared {removed} edge pixels")

def clean_beach_ghost_hair() -> None:
    # Clean stray stray semi-dark/light halo specks around upper head/hair of drowned_ghost_v3.png
    p = ROOT / "assets/characters/drowned_ghost_v3.png"
    im = Image.open(p).convert("RGBA")
    w, h = im.size
    px = im.load()
    cleaned = 0
    for y in range(1, int(h * 0.42)):
        for x in range(1, w - 1):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            trans_nb = sum(1 for dx, dy in ((-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)) if px[x+dx, y+dy][3] == 0)
            # Remove isolated 1-2px detached hair artifacts or bright fringe specks on hair
            if trans_nb >= 6:
                px[x, y] = (0, 0, 0, 0)
                cleaned += 1
            elif trans_nb >= 2 and r > 155 and g > 155 and b > 155:
                px[x, y] = (int(r*0.35), int(g*0.38), int(b*0.42), int(a*0.55))
                cleaned += 1
    im.save(p)
    print(f"CLEANED HAIR on {p.name}: refined {cleaned} pixels")

def extract_tall_coinbox() -> None:
    # Extract realistic tall stainless-steel Macau bus coinbox from macau_transmac_bus_v4.png
    src = Image.open(ROOT / "assets/tilesets/macau_transmac_bus_v4.png").convert("RGBA")
    w, h = src.size
    # Coinbox sits around x=56.2%..70.2%, y=51.5%..77.2%
    crop = src.crop((int(w * 0.562), int(h * 0.515), int(w * 0.702), int(h * 0.772)))
    cw, ch = crop.size
    # Stretch vertically slightly into an authentic tall waist-height stainless fare pillar
    tall = crop.resize((128, 220), Image.Resampling.LANCZOS)
    # Clean outer corners softly
    mask = Image.new("L", (128, 220), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((6, 4, 122, 218), radius=8, fill=255)
    tall.putalpha(mask)
    tall.save(ROOT / "assets/props/bus_coinbox_tall_v5.png")

    # Realistic blood-seeping coinbox variant: dark glossy crimson rivulets seeping from slot & pooling down metal
    blood = tall.copy()
    bd = ImageDraw.Draw(blood, "RGBA")
    # Dark crimson seepage from the top coin slot running organically down the stainless front
    rivulets = [
        [(62, 34), (60, 58), (63, 88), (58, 126), (61, 170), (57, 214)],
        [(70, 36), (73, 66), (70, 96), (74, 140), (72, 182), (76, 216)],
        [(54, 42), (51, 78), (54, 118), (49, 165)],
        [(82, 46), (86, 84), (83, 124), (88, 168), (85, 206)],
    ]
    for pts in rivulets:
        bd.line(pts, fill=(88, 8, 12, 225), width=5)
        bd.line([(x-1, y) for x, y in pts], fill=(138, 18, 22, 165), width=2)
    # Dark pooling stains around coin slot & lower plate
    bd.ellipse((44, 24, 92, 42), fill=(72, 6, 10, 210))
    bd.ellipse((32, 192, 102, 218), fill=(68, 5, 8, 220))
    blood.save(ROOT / "assets/props/bus_coinbox_blood_v5.png")
    print("EXTRACTED tall coinboxes:", tall.size)

def upgrade_bus_crash_art() -> None:
    # Composite a high-res moody 16:9 midnight crash scene from the real Transmac bus & Hac Sa black sand beach
    beach = Image.open(ROOT / "assets/tilesets/hacsa_beach_040.png").convert("RGBA").resize((960, 540), Image.Resampling.LANCZOS)
    bus = Image.open(ROOT / "assets/tilesets/macau_transmac_bus_v4.png").convert("RGBA")
    # Crop the exterior green-and-cream Transmac bus through the windshield & make it wrecked/tilted on midnight black sand
    ext_bus = bus.crop((int(bus.width * 0.51), int(bus.height * 0.23), int(bus.width * 0.91), int(bus.height * 0.50))).convert("RGBA")
    ext_bus = ImageEnhance.Brightness(ext_bus).enhance(0.45)
    ext_bus = ImageEnhance.Contrast(ext_bus).enhance(1.3)
    ext_bus = ext_bus.resize((520, 235), Image.Resampling.LANCZOS).rotate(-9.5, resample=Image.Resampling.BICUBIC, expand=True)
    # Soft vignette mask on bus wreck so it blends seamlessly into dark midnight fog
    bw, bh = ext_bus.size
    bmask = Image.new("L", (bw, bh), 0)
    md = ImageDraw.Draw(bmask)
    md.rounded_rectangle((28, 22, bw - 28, bh - 24), radius=34, fill=235)
    bmask = bmask.filter(ImageFilter.GaussianBlur(14))
    ext_bus.putalpha(bmask)

    scene = ImageEnhance.Brightness(beach).enhance(0.52)
    scene = ImageEnhance.Color(scene).enhance(0.75)
    scene.alpha_composite(ext_bus, (190, 145))

    # Add flickering amber headlight cone, shattered glass cracks, midnight mist & sea spray
    ov = Image.new("RGBA", (960, 540), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov, "RGBA")
    # Warm broken headlight beam cutting left across dark black sand
    od.polygon([(235, 312), (20, 240), (20, 440), (235, 338)], fill=(255, 226, 145, 58))
    od.ellipse((212, 300, 256, 344), fill=(255, 238, 175, 190))
    # Dark coastal sea fog band
    od.rectangle((0, 0, 960, 170), fill=(8, 14, 18, 125))
    od.rectangle((0, 420, 960, 540), fill=(6, 10, 12, 135))
    # Cracked glass web lines on upper-right frame edge
    cx, cy = 760, 135
    for dx, dy in [(-120, 45), (-90, -60), (80, 95), (140, -30), (-45, 130), (35, -90)]:
        od.line([(cx, cy), (cx + dx, cy + dy)], fill=(215, 228, 232, 85), width=2)
    ov = ov.filter(ImageFilter.GaussianBlur(1.2))
    scene.alpha_composite(ov)
    scene.convert("RGB").save(ROOT / "assets/props/bus_crash_beach.png")
    print("UPGRADED bus_crash_beach.png to 960x540")

if __name__ == "__main__":
    flood_cut_white_quads(
        Path("C:/Users/tffnf/.gemini/antigravity/brain/f816a13f-0eae-4b23-bebe-b2ea42bf44ae/wardrobe_stalker_v5_1795266097352.jpg"),
        ROOT / "assets/characters/wardrobe_stalker_v5.png",
        flip_h=True
    )
    defringe_sprite(ROOT / "assets/characters/ahhao_walk_043.png", 185)
    clean_beach_ghost_hair()
    extract_tall_coinbox()
    upgrade_bus_crash_art()
