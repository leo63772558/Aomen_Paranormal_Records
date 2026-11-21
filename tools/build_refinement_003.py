"""Native authored typography, classic window skin, 8-direction character and dry footsteps."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math, random, struct, wave
ROOT = Path(__file__).resolve().parents[1]
random.seed(30403)
(ROOT/'assets/ui').mkdir(exist_ok=True)

# Text is rasterized for this original title treatment; font files are not bundled.
logo=Image.new('RGBA',(448,152))
font=ImageFont.truetype('C:/Windows/Fonts/simkai.ttf',100)
p=ImageDraw.Draw(logo)
for i,ch in enumerate('澳诡实录'):
    x=8+i*108
    y=[8,0,10,3][i]
    p.text((x+2,y+3),ch,font=font,fill='#662e26',stroke_width=1)
    p.text((x,y),ch,font=font,fill='#dedbc9')
# Fine wear inside letter strokes, not a blanket noisy overlay.
for i in range(160):
    x,y=random.randrange(448),random.randrange(118)
    if logo.getpixel((x,y))[3]>0:
        p.line((x,y,x+random.randrange(2,7),y),fill=(23,30,28,200))
p.line((30,133,410,133),fill='#5d2825',width=2)
logo.save(ROOT/'assets/ui/title_mark.png')

window=Image.new('RGBA',(96,96)); p=ImageDraw.Draw(window)
for y in range(96):
    t=y/95
    p.line((0,y,95,y),fill=(int(49-40*t),int(85-49*t),int(65-41*t),250))
for inset,color in [(0,'#111a1b'),(1,'#81999a'),(2,'#e1e9df'),(3,'#405e60'),(4,'#142f29'),(5,'#558276')]:
    p.rectangle((inset,inset,95-inset,95-inset),outline=color)
window.save(ROOT/'assets/ui/dialogue_window.png')

# Original portrait, ordinary adult protagonist with a guarded expression.
portrait=Image.new('RGBA',(86,112)); p=ImageDraw.Draw(portrait)
p.polygon([(3,111),(6,83),(26,73),(61,72),(78,82),(85,111)],fill='#172a2c',outline='#080f17')
p.polygon([(7,111),(10,86),(30,76),(53,80),(63,91),(70,111)],fill='#607d69')
p.polygon([(47,79),(62,75),(78,84),(83,111),(63,111)],fill='#354f49')
p.polygon([(29,70),(31,83),(43,95),(56,79),(54,65)],fill='#b49270',outline='#5f6959')
p.polygon([(27,76),(40,85),(34,94),(22,81)],fill='#a5b49a')
p.polygon([(54,75),(43,85),(50,95),(63,81)],fill='#819c85')
p.polygon([(34,94),(43,87),(50,95),(54,111),(31,111)],fill='#c9c8af')
p.polygon([(22,23),(34,13),(56,15),(68,30),(64,56),(55,72),(43,77),(30,67),(23,48)],fill='#bb9e7c',outline='#13232a')
p.polygon([(56,24),(67,30),(63,57),(54,71),(44,76),(47,67),(56,55)],fill='#90765e')
p.polygon([(24,29),(29,23),(31,51),(37,66),(30,63),(24,47)],fill='#d4b18a')
p.polygon([(17,28),(23,12),(36,5),(58,8),(70,20),(70,34),(64,30),(57,21),(48,26),(42,19),(35,28),(29,29),(25,43),(20,39)],fill='#14242a',outline='#080f17')
p.line((24,18,36,11,53,12,64,20),fill='#405958',width=2)
p.line((28,37,37,36),fill='#243334',width=2)
p.line((50,35,60,37),fill='#243334',width=2)
p.line((28,40,36,40),fill='#e1c09a');p.rectangle((32,39,34,42),fill='#14262a')
p.line((50,40,58,40),fill='#c8b18f');p.rectangle((51,39,53,42),fill='#14262a')
p.line((43,40,41,51,46,52),fill='#947659')
p.line((37,60,49,61),fill='#624f43');p.line((40,64,47,64),fill='#c2a17d')
p.line((14,88,11,109),fill='#a6b096');p.line((66,88,72,108),fill='#557868')
portrait.save(ROOT/'assets/ui/dawen_portrait.png')

sheet=Image.new('RGBA',(192,320))
for direction in range(8):
    angle=direction*math.pi/4
    dx,dy=math.cos(angle),math.sin(angle)
    back=dy<-.4
    side=abs(dx)>.4
    for frame in range(6):
        im=Image.new('RGBA',(32,40)); p=ImageDraw.Draw(im)
        phase=frame*math.pi/3
        stride=round(math.sin(phase)*2)
        bob=1 if frame in (1,2,4,5) else 0
        p.ellipse((7,32,25,37),fill=(2,10,16,100))
        sx=1 if side else 0
        p.rectangle((11+sx,25,15+sx,34+stride),fill='#182c39')
        p.rectangle((18,25,22,34-stride),fill='#263e4b')
        p.line((12+sx,26,12+sx,32+stride),fill='#476273')
        p.line((19,26,19,32-stride),fill='#456372')
        p.rectangle((10+sx,34+stride,15+sx,36+stride),fill='#101b24')
        p.rectangle((18,34-stride,23,36-stride),fill='#101b24')
        p.line((11+sx,35+stride,15+sx,35+stride),fill='#667b77')
        p.line((19,35-stride,22,35-stride),fill='#667b77')
        p.polygon([(10+sx,15+bob),(14,13+bob),(21,14+bob),(25,17+bob),(24,27+bob),(9+sx,27+bob)],fill='#14272d')
        p.rectangle((11+sx,16+bob,22,26+bob),fill='#617f68')
        p.line((12+sx,17+bob,12+sx,24+bob),fill='#9ba78a')
        p.rectangle((20,17+bob,23,26+bob),fill='#365b50')
        if not back:
            p.rectangle((16+sx,16+bob,18+sx,24+bob),fill='#c6c5a5')
            p.line((16+sx,18+bob,16+sx,25+bob),fill='#394c43')
        else:
            p.rectangle((13,17+bob,21,26+bob),fill='#35584b',outline='#879b7c')
        p.rectangle((8+sx,17+bob,10+sx,25+stride//2+bob),fill='#6c856d')
        p.rectangle((24,17+bob,26,25-stride//2+bob),fill='#3e6252')
        p.rectangle((8+sx,25+stride//2+bob,10+sx,28+stride//2+bob),fill='#c1a17a')
        p.rectangle((24,25-stride//2+bob,26,28-stride//2+bob),fill='#af8f6c')
        p.rectangle((12+sx,5+bob,23+sx,13+bob),fill='#15262b')
        p.rectangle((13+sx,6+bob,22+sx,12+bob),fill='#c4a27a')
        p.rectangle((15,13+bob,20,14+bob),fill='#997e60')
        p.polygon([(11+sx,5+bob),(13+sx,3+bob),(21,2+bob),(24+sx,5+bob),(24+sx,8+bob),(20,6+bob),(17,7+bob),(13+sx,9+bob),(11+sx,8+bob)],fill='#14272d')
        p.line((13+sx,4+bob,20,3+bob,23,5+bob),fill='#3c5956')
        if back:
            p.rectangle((12+sx,6+bob,23+sx,12+bob),fill='#1a3034')
            if side:
                p.rectangle((22+sx,10+bob,24+sx,12+bob),fill='#ba9874')
                p.point((23+sx,9+bob),fill='#13272c')
        elif side:
            p.rectangle((23,9+bob,25,11+bob),fill='#b89974')
            p.point((22,9+bob),fill='#172b30')
            if dy>.4: p.point((17,10+bob),fill='#26352e')
            p.line((19,13+bob,22,13+bob),fill='#85664f')
        else:
            p.point((15,10+bob),fill='#15262c');p.point((21,10+bob),fill='#15262c')
            p.line((17,13+bob,19,13+bob),fill='#87684e')
        if dx<-.4: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        sheet.alpha_composite(im,(frame*32,direction*40))
sheet.save(ROOT/'assets/characters/dawen_walk_8dir.png')

# Dry heel/toe noise; no pitched oscillators or chirps. Four nonidentical takes.
for variant in range(4):
    rng=random.Random(900+variant)
    rate=24000; length=int(rate*.30)
    values=[]; low=0.; mid=0.
    for i in range(length):
        t=i/rate
        noise=rng.uniform(-1,1)
        low=.96*low+.04*noise
        mid=.65*mid+.35*noise
        heel=math.exp(-t*(47+variant*2))*min(1,t/.002)
        toe=math.exp(-max(0,t-.065)*38)*min(1,max(0,t-.065)/.003) if t>.065 else 0
        scrape=math.exp(-t*17)*min(1,t/.012)
        value=low*(heel*2.4+toe*1.2)+mid*(heel*.16+toe*.12)+noise*scrape*.012
        values.append(value)
    for i in range(length-1,int(.028*rate),-1):
        values[i]+=values[i-int(.028*rate)]*.15
    with wave.open(str(ROOT/f'assets/audio/step_stone_{variant}.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        f.writeframes(b''.join(struct.pack('<h',int(max(-.95,min(.95,v))*.8*32767)) for v in values))
print('Pass003: title, RPG window skin, portrait, 48 animation cells, 4 dry stone footsteps.')
