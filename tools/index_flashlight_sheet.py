"""Index the held-flashlight sheet, with feet and authored lens attachment tracks.

Reads source pixels only; the image itself is not edited.
"""
from pathlib import Path
from PIL import Image
import statistics, json

root=Path(__file__).resolve().parents[1]
image=Image.open(root/'assets/characters/dawen_flashlight_005_source.png')
alpha=image.getchannel('A')
w,h=image.size
rows=[]; heights=[]
# Lens landmarks in the first source cell of each facing. Subsequent frames
# retain the same chest-height hold with a small positional correction.
first_lenses=[(111,64),(75,68),(57,67),(34,72),(35,68),(42,51),(91,58),(104,57)]
for row in range(8):
    frames=[]; bounds=[]; foot_centers=[]
    for col in range(6):
        x0,y0=round(col*w/6),round(row*h/8)
        x1,y1=round((col+1)*w/6),round((row+1)*h/8)
        mask=alpha.crop((x0,y0,x1,y1)).point(lambda v:255 if v>100 else 0)
        box=mask.getbbox()
        if not box: raise ValueError(f'Empty frame {row}/{col}')
        band_start=round(box[1]+(box[3]-box[1])*.80)
        feet=mask.crop((0,band_start,x1-x0,box[3])).getbbox()
        center=(feet[0]+feet[2])/2
        foot_centers.append(center)
        bounds.append(box)
        heights.append(box[3]-box[1])
        frames.append({'region':[x0,y0,x1-x0,y1-y0],'anchor':[center,box[3]]})
    # Feet rather than silhouette determine origin: the outstretched torch must
    # never shift the whole man's centering in the animation cell.
    first_center=foot_centers[0]
    first_height=bounds[0][3]-bounds[0][1]
    for col,frame in enumerate(frames):
        box=bounds[col]
        height=box[3]-box[1]
        lens=first_lenses[row]
        frame['torch_lens']=[lens[0]+foot_centers[col]-first_center,
                             box[3]-(bounds[0][3]-lens[1])*height/first_height]
    rows.append(frames)
layout={'columns':6,'rows':8,'scale':50/statistics.median(heights),'frames':rows}
(root/'assets/characters/dawen_flashlight_005_layout.json').write_text(json.dumps(layout,indent=2),encoding='utf-8')
print('Indexed 48 held-torch frames and lens tracks:',image.size,'scale=',layout['scale'])
