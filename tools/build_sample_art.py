"""Reproducible original pixel assets. Pillow only; no downloaded game art."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
random.seed(304)

def save(im, folder, name):
    im.save(ROOT / 'assets' / folder / (name + '.png'))

floor = Image.new('RGBA', (640, 360), '#17252a')
d = ImageDraw.Draw(floor)
d.rectangle((60, 59, 580, 319), fill='#697966')
for y in range(64, 320, 32):
    for x in range(64, 576, 32):
        green = (x // 32 + y // 32) % 2 == 0
        base = random.choice(['#718575', '#788a78', '#7d8e7b']) if green else '#b4b39a'
        d.rectangle((x, y, x+30, y+30), fill=base)
        ink = '#4d7264' if not green else '#9ba78a'
        d.polygon([(x+15,y+3),(x+27,y+15),(x+15,y+27),(x+3,y+15)], outline=ink)
        for dx, dy in [(7,7),(23,7),(7,23),(23,23)]:
            d.rectangle((x+dx-1,y+dy-1,x+dx+1,y+dy+1), fill=ink)
        d.rectangle((x+13,y+13,x+17,y+17), fill=ink)
        for _ in range(4):
            px, py = x+random.randrange(30), y+random.randrange(30)
            d.point((px,py), fill='#929a80')
# Wall face, timber skirting and worn plaster.
d.rectangle((48,40,592,63), fill='#4c665e')
d.rectangle((48,42,592,45), fill='#8b9a7e')
d.rectangle((48,54,592,61), fill='#384e48')
d.rectangle((48,62,592,65), fill='#b4a37a')
for x in range(52,590,32):
    d.line((x,47,x+20,47), fill='#66796a')
d.rectangle((48,64,63,320), fill='#354c48')
d.rectangle((576,64,591,320), fill='#354c48')
d.rectangle((48,310,591,325), fill='#293e3b')
d.line((64,309,575,309), fill='#8b8669', width=2)
# Window, courtyard glimpse and shutter slats.
d.rectangle((212,38,326,64), fill='#1b3036')
d.rectangle((218,40,320,57), fill='#647f7d')
for x in range(220,320,12):
    d.line((x,40,x,59), fill='#2e4948', width=2)
d.line((217,58,322,58), fill='#aaad8d', width=2)
# Preserve clean historical floor before the new drag marks.
historical_floor = floor.copy()
# Drag marks beside original bed, imperfect long scrape over tile.
for x in [407, 411, 459, 463]:
    d.line((x,184,x-22,212), fill='#536b5b', width=1)
    d.line((x+1,184,x-21,212), fill='#c1baa0')
# Damp stain, threshold runner, overhead pipe.
for _ in range(50):
    x,y = random.randrange(70,105),random.randrange(67,130)
    d.rectangle((x,y,x+random.randrange(1,5),y+1),fill='#4f6559')
d.rectangle((67,242,104,285),fill='#715c47')
for y in range(244,284,4):
    d.line((68,y,102,y),fill='#968261')
d.line((72,69,565,69),fill='#283f3c',width=3)
save(floor,'tilesets','tanglau_room')

def prop(name, size, painter):
    im=Image.new('RGBA',size)
    painter(ImageDraw.Draw(im))
    save(im,'props',name)

def bed(d):
    d.rectangle((0,8,65,86),fill='#263536')
    d.rectangle((3,5,62,78),fill='#76786b')
    d.rectangle((6,10,59,73),fill='#b3b39a')
    d.rectangle((9,13,55,29),fill='#d1c7a6')
    d.rectangle((9,13,55,15),fill='#e0d4b1')
    d.rectangle((7,34,59,72),fill='#566f6a')
    for y in range(37,72,7):
        d.line((8,y,58,y),fill='#7b9181')
    for x in range(9,60,9):
        d.line((x,34,x,72),fill='#3d5a58')
    for y in [5,78]:
        d.rectangle((0,y,65,y+3),fill='#9a9f88')
    for x in [1,62]:
        d.rectangle((x,1,x+2,88),fill='#b3b29b')
        d.rectangle((x,1,x+2,3),fill='#d2c6a1')
prop('iron_bed',(66,90),bed)

def wardrobe(d):
    d.rectangle((1,7,69,82),fill='#202d2c')
    d.rectangle((3,0,66,75),fill='#493d32')
    d.rectangle((0,1,69,7),fill='#7b664d')
    for left in [7,36]:
        d.rectangle((left,11,left+24,69),fill='#68563f',outline='#988060')
        d.rectangle((left+4,16,left+20,39),outline='#493f33')
        d.rectangle((left+4,45,left+20,64),outline='#493f33')
    d.rectangle((29,40,31,44),fill='#c6ad77')
    d.rectangle((38,40,40,44),fill='#c6ad77')
    d.line((5,74,65,74),fill='#b0956a')
prop('wardrobe',(72,84),wardrobe)

def desk(d):
    d.rectangle((3,9,83,51),fill='#303b32')
    d.rectangle((2,2,81,31),fill='#775d43',outline='#ac8e62',width=2)
    for y in [6,16,25]: d.line((5,y,79,y),fill='#876d4b')
    d.rectangle((8,32,12,49),fill='#5e4836')
    d.rectangle((73,32,77,49),fill='#5e4836')
    d.polygon([(12,8),(37,5),(40,24),(14,27)],fill='#d2c4a0',outline='#ede0b8')
    d.rectangle((17,11,32,21),fill='#647668')
    d.ellipse((51,8,75,25),fill='#293a37',outline='#65726a')
    d.ellipse((58,12,68,22),outline='#b2a787')
    d.rounded_rectangle((49,5,77,12),radius=3,fill='#192b2b')
prop('photo_desk',(86,52),desk)

def gate(d):
    d.rectangle((0,0,18,77),fill='#203632',outline='#b49c70',width=2)
    for y in range(4,76,7):
        d.line((3,y,15,y),fill='#7c8270',width=2)
    d.rectangle((4,29,7,48),fill='#403d32')
prop('gate',(20,78),gate)

def shrine(d):
    d.rectangle((2,5,36,39),fill='#5f3d31')
    d.polygon([(0,7),(19,0),(39,7)],fill='#9b5e42')
    d.rectangle((8,9,30,31),fill='#372e29',outline='#ac7951')
    d.rectangle((17,12,21,25),fill='#b08a52')
    d.rectangle((2,32,37,36),fill='#b48256')
    for x in [11,26]:
        d.rectangle((x,26,x+2,32),fill='#b7a47b')
        d.point((x+1,25),fill='#ffcd78')
prop('shrine',(40,40),shrine)

def partition(d):
    d.rectangle((0,0,15,113),fill='#344c47')
    d.rectangle((1,1,13,9),fill='#7c8a71')
    for y in range(15,112,16):
        d.line((1,y,12,y),fill='#526b5d')
    d.line((14,1,14,111),fill='#9b9876')
prop('partition',(16,114),partition)

def vent(d):
    d.rectangle((0,0,41,27),fill='#1a2c2c',outline='#9e9e80',width=2)
    for y in range(5,25,4): d.line((5,y,36,y),fill='#60746b',width=2)
    for x in [3,38]:
        for y in [3,24]: d.point((x,y),fill='#d0c6a1')
prop('vent',(42,28),vent)

def letterbox(d):
    d.rectangle((1,1,24,28),fill='#883f32',outline='#b27350')
    d.rectangle((4,6,21,8),fill='#2c3430')
    d.rectangle((8,14,19,20),fill='#c4bb99')
prop('letterbox',(26,30),letterbox)

# Four facing directions, four frames per direction. Foot position at (16,35).
sheet=Image.new('RGBA',(128,144))
for direction in range(4):
    for frame in range(4):
        sprite=Image.new('RGBA',(32,36)); p=ImageDraw.Draw(sprite)
        bob = 1 if frame in [1,3] else 0
        step = [0,-2,0,2][frame]
        p.ellipse((7,29,25,34),fill=(12,25,26,100))
        if direction < 2:  # down/up
            p.rectangle((10,23+bob,14,30+step//2),fill='#293f46')
            p.rectangle((18,23+bob,22,30-step//2),fill='#293f46')
            p.rectangle((9,30+step//2,14,32+step//2),fill='#1e3037')
            p.rectangle((18,30-step//2,23,32-step//2),fill='#1e3037')
            p.rectangle((8,13+bob,24,24+bob),fill='#948b6a',outline='#c6b68b')
            p.rectangle((6,15+bob,9,24+bob),fill='#ab9d77')
            p.rectangle((23,15+bob,26,24+bob),fill='#ab9d77')
            p.rectangle((6,24+bob,9,26+bob),fill='#c0a07c')
            p.rectangle((23,24+bob,26,26+bob),fill='#c0a07c')
            p.rectangle((11,4+bob,22,13+bob),fill='#b99570')
            p.rectangle((10,2+bob,22,7+bob),fill='#263735')
            p.rectangle((12,1+bob,20,3+bob),fill='#3a4740')
            if direction == 0:
                p.point((13,9+bob),fill='#293632'); p.point((20,9+bob),fill='#293632')
                p.line((15,12+bob,18,12+bob),fill='#8b6954')
                p.line((15,15+bob,18,15+bob),fill='#ded0a4')
            else:
                p.rectangle((10,3+bob,22,10+bob),fill='#293a36')
                p.rectangle((12,15+bob,21,25+bob),fill='#526a63',outline='#73857a')
        else:
            flip = direction == 2
            p.rectangle((12+step//2,23+bob,16+step//2,31),fill='#293f46')
            p.rectangle((17-step//2,23+bob,21-step//2,31),fill='#364c50')
            p.rectangle((11+step//2,30,17+step//2,32),fill='#1e3037')
            p.rectangle((16-step//2,30,22-step//2,32),fill='#1e3037')
            p.rectangle((10,13+bob,22,24+bob),fill='#b3a27b',outline='#c6b68b')
            p.rectangle((14,16+bob,18,26+bob),fill='#948b6a')
            p.rectangle((14,25+bob,18,27+bob),fill='#c0a07c')
            p.rectangle((12,4+bob,23,12+bob),fill='#b99570')
            p.rectangle((10,2+bob,21,7+bob),fill='#293a36')
            p.rectangle((10,6+bob,13,11+bob),fill='#293a36')
            p.point((22,8+bob),fill='#293632')
            p.rectangle((8,15+bob,11,24+bob),fill='#526a63')
            if flip: sprite=sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        sheet.alpha_composite(sprite,(frame*32,direction*36))
save(sheet,'characters','dawen_walk')

# Texture is centered; source is left edge of the cone via PointLight2D.offset.
cone=Image.new('RGBA',(512,512))
pix=cone.load()
for y in range(512):
    for x in range(256,512):
        dx,dy=x-256,y-256
        r=math.hypot(dx,dy)
        a=abs(math.atan2(dy,dx)) if r else 0
        if r < 256 and a <= math.pi/6:
            angular=min(1,(math.pi/6-a)/0.07)
            fade=min(1,(256-r)/42)
            strength=int(255*angular*fade*(0.9-0.5*r/256))
            pix[x,y]=(255,255,255,strength)
save(cone,'lighting','flashlight_cone')
radial=Image.new('RGBA',(256,256)); pix=radial.load()
for y in range(256):
    for x in range(256):
        r=math.hypot(x-128,y-128)/128
        pix[x,y]=(255,255,255,int(255*max(0,1-r)**1.5))
save(radial,'lighting','soft_light')

# In-world old photo has the same tile/bed geometry, bed at the original wall.
photo=historical_floor.crop((368,64,568,224)).convert('RGB')
bedim=Image.open(ROOT/'assets/props/iron_bed.png')
photo.paste(bedim,(44,0),bedim)
photo=photo.convert('L').convert('RGB')
pixels=photo.load()
for y in range(photo.height):
    for x in range(photo.width):
        v=pixels[x,y][0]
        pixels[x,y]=(min(255,int(v*1.09)),min(255,int(v*.99)),int(v*.76))
pd=ImageDraw.Draw(photo)
pd.rectangle((0,0,199,159),outline='#d1bd8e',width=5)
save(photo,'props','old_photo')

for name,freq,duration in [('click',420,.08),('step',135,.055),('scrape',95,.35),('latch',700,.12)]:
    samples=[]
    for i in range(int(22050*duration)):
        t=i/22050
        noise=random.uniform(-1,1)
        value=(math.sin(2*math.pi*freq*t)*.4+noise*.3)*math.exp(-t*18)*.35
        samples.append(struct.pack('<h',int(value*32767)))
    with wave.open(str(ROOT/'assets/audio'/f'{name}.wav'),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(22050); f.writeframes(b''.join(samples))
print('Original sample-room assets generated.')
