"""Read-only alpha analysis: index generated cells and foot anchors. No pixel edits."""
from PIL import Image
from pathlib import Path
import json, statistics
root=Path(__file__).resolve().parents[1]
image=Image.open(root/'assets/characters/dawen_walk_004_source.png')
alpha=image.getchannel('A')
w,h=image.size
rows=[]; heights=[]
for row in range(8):
    frames=[]
    for column in range(6):
        x0,y0=round(column*w/6),round(row*h/8)
        x1,y1=round((column+1)*w/6),round((row+1)*h/8)
        box=alpha.crop((x0,y0,x1,y1)).point(lambda value:255 if value>100 else 0).getbbox()
        if box is None: raise RuntimeError(f'Empty animation cell {row}/{column}')
        heights.append(box[3]-box[1])
        frames.append({'region':[x0,y0,x1-x0,y1-y0], 'anchor':[(box[0]+box[2])/2,box[3]]})
    rows.append(frames)
layout={'columns':6,'rows':8,'scale':50/statistics.median(heights),'frames':rows}
(root/'assets/characters/dawen_walk_004_layout.json').write_text(json.dumps(layout,indent=2),encoding='utf-8')
print('Indexed 48 frames with alpha-derived foot anchors. Scale:',layout['scale'])
