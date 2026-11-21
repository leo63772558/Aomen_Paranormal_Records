"""Index alpha bounds/foot anchors of opening action poses. No image edits."""
from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]

def pose(im,rect):
    x,y,w,h=rect
    mask=im.getchannel('A').crop((x,y,x+w,y+h)).point(lambda v:255 if v>100 else 0)
    b=mask.getbbox()
    if b is None: raise RuntimeError('Empty pose')
    band=round(b[1]+(b[3]-b[1])*.8)
    feet=mask.crop((0,band,w,b[3])).getbbox()
    return {'region':rect,'anchor':[(feet[0]+feet[2])/2,b[3]],'scale':50/(b[3]-b[1]),'bounds':list(b)}

data={}
for name in ['camera','pastry','pliers']:
    im=Image.open(root/f'assets/characters/dawen_{name}_006.png')
    data[name]=pose(im,[0,0,*im.size])
    if name=='pliers':
        data[name]['scale']*=.88
        data[name]['torch_lens']=[638,390]
im=Image.open(root/'assets/characters/jiamin_006.png')
w,h=im.size
data['girl']=[]
for i in range(3):
    x0,x1=round(i*w/3),round((i+1)*w/3)
    data['girl'].append(pose(im,[x0,0,x1-x0,h]))
b=data['girl'][0]['bounds']
portrait_h=round((b[3]-b[1])*.44)
portrait_w=round(portrait_h*.8)
data['girl_portrait']=[round((b[0]+b[2]-portrait_w)/2),b[1],portrait_w,portrait_h]
cover=Image.open(root/'assets/props/vent_006.png')
box=cover.getchannel('A').point(lambda v:255 if v>100 else 0).getbbox()
data['cover_region']=[box[0],box[1],box[2]-box[0],box[3]-box[1]]
(root/'core/data/opening_art.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print('Indexed girl poses, hero phone/pastry poses and metal cover.')
