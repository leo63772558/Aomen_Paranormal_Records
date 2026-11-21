"""Clean and balance assets/props/room304_old_photo_026.png.

Removes the fake yellowish AI simulated border edges and dark bottom smudge artifacts,
cropping to a clean 3:2 vintage archival ratio (1416x944) and applying subtle
contrast and sharpness balancing for authentic photographic clarity.
"""
from PIL import Image, ImageEnhance
import os
import shutil

def process_photo():
    photo_path = os.path.join("assets", "props", "room304_old_photo_026.png")
    backup_dir = os.path.join("tools", "backup")
    os.makedirs(backup_dir, exist_ok=True)
    backup_path = os.path.join(backup_dir, "room304_old_photo_026.orig.png")
    
    source_path = backup_path if os.path.exists(backup_path) else photo_path
    if not os.path.exists(backup_path):
        shutil.copy2(photo_path, backup_path)
        print(f"Backed up original photo to {backup_path}")

    img = Image.open(source_path)
    w, h = img.size
    print(f"Source size: {w}x{h}")

    # Crop out the ~18-35px border on all 4 sides, exactly 3:2 aspect ratio (1416x944)
    # Box: left=50, top=36, right=1466, bottom=980
    crop_box = (50, 36, 1466, 980)
    cropped = img.crop(crop_box)
    cw, ch = cropped.size
    print(f"Cropped size: {cw}x{ch}, aspect ratio: {cw/ch:.4f}")

    # Apply subtle contrast and sharpness enhancement for authentic archival clarity
    c = ImageEnhance.Contrast(cropped).enhance(1.06)
    s = ImageEnhance.Sharpness(c).enhance(1.08)

    s.save(photo_path, format="PNG", optimize=True)
    print(f"Updated {photo_path} cleanly.")

if __name__ == "__main__":
    process_photo()
