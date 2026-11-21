"""Original retro RPG horror art pass. Reuses sample audio/light generators."""
from build_sample_art import save, prop, ROOT
from PIL import Image, ImageDraw, ImageEnhance
import random
random.seed(3049)

room=Image.new('RGBA',(640,360),'#080b10')
d=ImageDraw.Draw(room)
# A plaster wall with height and skirting, rather than a floor-height border.
d.rectangle((58,42,581,313),fill='#101318')
d.rectangle((64,48,575,310),fill='#41454b')
for y in range(96,310,32):
    for x in range(64,576,32):
        c=random.choice(['#56544e','#5b5851','#52514d','#5a5750'])
        d.rectangle((x,y,x+31,min(y+31,309)),fill=c)
        d.line((x,y,x+31,y),fill='#737064')
        d.line((x,y,x,min(y+30,309)),fill='#69685e')
        d.line((x+31,y,x+31,min(y+31,309)),fill='#303431')
        d.line((x,min(y+31,309),x+31,min(y+31,309)),fill='#323532')
        if x < 192 and y > 223:
            d.polygon([(x+15,y+8),(x+22,y+15),(x+15,y+22),(x+8,y+15)],outline='#788477')
            d.rectangle((x+13,y+13,x+16,y+16),fill='#424b44')
        for i in range(40):
            px,py=x+random.randrange(1,30),y+random.randrange(1,30)
            if py < 309: d.point((px,py),fill=random.choice(['#626258','#4c4e48','#656458']))
        if random.random()<.12:
            d.line((x+4,y+12,x+11,y+18,x+14,y+28),fill='#383d39')
# Stained green-grey wall above dark wood panelling.
d.rectangle((64,48,575,85),fill='#657069')
d.rectangle((64,48,575,51),fill='#333f3e')
d.line((64,53,575,53),fill='#879187')
for _ in range(950):
    x,y=random.randrange(65,575),random.randrange(55,85)
    d.point((x,y),fill=random.choice(['#5b675f','#6b756b','#747b6e','#505d57']))
for x in [68,181,335,558]:
    for y in range(54,84):
        if random.random() < .6:
            d.line((x,y,x+random.randrange(2,9),y),fill='#48594f')
d.rectangle((64,86,575,94),fill='#303b37')
d.line((64,86,575,86),fill='#87907b')
d.line((64,94,575,94),fill='#171f20',width=2)
d.rectangle((57,48,63,315),fill='#1c2726')
d.line((63,94,63,312),fill='#5d695c')
d.rectangle((576,48,582,315),fill='#1c2726')
d.line((576,94,576,312),fill='#5d695c')
d.rectangle((58,310,581,320),fill='#151e1f')
d.line((64,310,575,310),fill='#677363')
# Old louvred window: outside is opaque blue, a diagonal plank interrupts it.
d.rectangle((217,49,318,85),fill='#222c31',outline='#92917b',width=2)
d.rectangle((222,53,313,79),fill='#344854')
for x in range(226,314,9):
    d.line((x,53,x,80),fill='#151f27',width=2)
    d.line((x+2,54,x+2,78),fill='#50616a')
d.line((220,77,315,58),fill='#605c4b',width=4)
d.line((220,75,315,56),fill='#89816a')
d.rectangle((212,85,323,91),fill='#343c35')
d.line((213,85,323,85),fill='#9b9d80')
# Cracked wall plaster and surface wiring.
for x,y in [(196,56),(394,53),(548,60)]:
    d.line((x,y,x-3,y+7,x+1,y+13,x-4,y+22),fill='#34423d')
    d.line((x-2,y+9,x+8,y+12,x+12,y+18),fill='#424f47')
d.line((76,48,76,78,115,78),fill='#292f2d',width=2)
d.line((77,48,77,77,115,77),fill='#989780')
# Wall calendar and a dark portrait, no borrowed images.
d.rectangle((178,58,194,79),fill='#d0c8a8',outline='#3b433d')
d.rectangle((179,59,193,62),fill='#684339')
for y in range(65,77,4):
    for x in range(181,193,3): d.point((x,y),fill='#717466')
d.rectangle((383,57,401,79),fill='#34332d',outline='#938169')
d.rectangle((386,60,398,76),fill='#1b262b')
d.ellipse((389,62,395,68),fill='#657066')
d.rectangle((388,68,396,75),fill='#35413e')
# Dirt accumulates by edges; isolated scuffs do not cover every tile.
for _ in range(350):
    x=random.choice([random.randrange(66,88),random.randrange(551,575)])
    y=random.randrange(98,309)
    d.point((x,y),fill='#363d37')
# A folded newspaper and fallen bowl off the walking route.
d.polygon([(177,283),(193,279),(198,292),(181,296)],fill='#9c9a81',outline='#3c433d')
for y in range(284,292,3): d.line((183,y,192,y-2),fill='#565e53')
d.ellipse((531,267,546,273),fill='#b5b39b',outline='#3d4943')
d.arc((533,267,544,272),0,180,fill='#6d7c70')
# Low doorway mat and legible local drag marks.
d.rectangle((69,247,103,285),fill='#3b3931',outline='#77705c')
for y in range(249,284,3): d.line((71,y,101,y),fill='#625c49')
historical=room.copy()
for x in [407,411,459,463]:
    d.line((x,183,x-22,213),fill='#282f2b')
    d.line((x+1,183,x-21,213),fill='#aaa18a')
save(room,'tilesets','tanglau_room')

def bed(p):
    p.rectangle((2,6,64,87),fill='#111a1d')
    p.rectangle((4,7,61,79),fill='#68716b',outline='#303e3d')
    p.rectangle((7,10,59,74),fill='#969783')
    for y in range(11,73,3):
        p.line((8,y,58,y),fill=random.choice(['#8b8f7b','#9a9b86','#a2a18b']))
    p.rectangle((11,13,54,29),fill='#b7b5a0',outline='#767f71')
    p.line((14,15,51,15),fill='#d2cbb1')
    p.line((13,27,50,27),fill='#969c88')
    p.rectangle((8,36,58,73),fill='#4c625e',outline='#334b49')
    for x in range(10,58,6):
        p.line((x,37,x,71),fill='#60766b')
        p.line((x+2,38,x+2,71),fill='#455c57')
    for y in range(39,72,8): p.line((9,y,57,y),fill='#6f7e6e')
    p.polygon([(8,36),(31,39),(58,34),(58,42),(32,44),(8,40)],fill='#84917e')
    p.line((8,39,30,43,58,38),fill='#acb19a')
    for x in [1,62]:
        p.rectangle((x,2,x+2,88),fill='#4b605f')
        p.line((x,3,x,86),fill='#bac0a8')
        p.rectangle((x,2,x+3,5),fill='#bfc1ab')
        for y in [18,49,77]: p.point((x+1,y),fill='#9c7354')
    for y in [7,78]:
        p.line((2,y,63,y),fill='#b2b8a2',width=2)
        p.line((3,y+2,62,y+2),fill='#3f5655')
    for x in range(12,59,12):
        p.line((x,3,x,10),fill='#80978c')
        p.line((x,77,x,84),fill='#80978c')
prop('iron_bed',(66,90),bed)

def wardrobe(p):
    p.rectangle((1,7,70,82),fill='#111b1c')
    p.rectangle((4,3,66,76),fill='#554638',outline='#272f2c',width=2)
    p.rectangle((2,0,68,7),fill='#82725b',outline='#303b34')
    p.line((5,2,65,2),fill='#b39b73')
    for left in [8,37]:
        p.rectangle((left,11,left+23,70),fill='#685743',outline='#9d8765')
        p.rectangle((left+3,14,left+20,39),fill='#4e4538',outline='#403c32')
        p.line((left+4,15,left+19,15),fill='#887453')
        p.rectangle((left+3,45,left+20,65),fill='#4a4236',outline='#3b3a30')
        for y in [17,22,30,47,56,60]:
            p.line((left+5,y,left+random.randrange(8,18),y),fill='#64553f')
    p.rectangle((30,39,32,44),fill='#1b2827')
    p.rectangle((37,39,39,44),fill='#1b2827')
    p.point((31,40),fill='#c6b68a'); p.point((38,40),fill='#c6b68a')
    p.rectangle((4,72,65,76),fill='#786346')
    p.line((7,73,63,73),fill='#a58a5f')
    p.rectangle((8,77,13,80),fill='#3c3a2f')
    p.rectangle((57,77,62,80),fill='#3c3a2f')
prop('wardrobe',(72,84),wardrobe)

def desk(p):
    p.rectangle((3,8,83,51),fill='#10191b')
    p.rectangle((3,3,81,31),fill='#514637',outline='#8b7959')
    p.line((4,4,79,4),fill='#afa082')
    for y in range(7,30,3):
        p.line((5,y,79,y),fill=random.choice(['#65553e','#706047','#5e503b']))
    p.rectangle((5,32,80,37),fill='#3d382d',outline='#756448')
    for x in [8,73]:
        p.rectangle((x,37,x+4,49),fill='#4d4231')
        p.line((x,38,x,47),fill='#887357')
    p.polygon([(11,9),(34,6),(38,24),(14,28)],fill='#bcb89a',outline='#e0d1a6')
    p.polygon([(15,12),(31,10),(34,22),(17,24)],fill='#526356')
    p.line((17,21,21,15,29,20),fill='#7e8570')
    p.ellipse((48,13,77,27),fill='#111d20',outline='#5f6b60')
    p.ellipse((56,14,68,25),fill='#54615b',outline='#939886')
    p.ellipse((59,17,65,22),fill='#1c2b2c')
    for x,y in [(59,15),(64,16),(66,21),(60,24),(56,20)]: p.point((x,y),fill='#d0c5a2')
    p.rounded_rectangle((46,6,78,15),radius=4,fill='#162528',outline='#78877b')
    p.line((51,7,72,7),fill='#a2a58b')
    p.line((76,22,80,26,76,29,81,31),fill='#2b3935')
prop('photo_desk',(86,52),desk)

def partition(p):
    p.rectangle((0,0,15,113),fill='#1a2525')
    p.rectangle((1,0,12,109),fill='#515f55')
    for y in range(2,110,3): p.line((2,y,11,y),fill=random.choice(['#59675a','#485a51','#697460']))
    p.line((13,0,13,111),fill='#92957a')
    p.line((1,109,12,109),fill='#a39b7b',width=2)
prop('partition',(16,114),partition)

def gate(p):
    p.rectangle((0,0,18,77),fill='#142022',outline='#6d7d71')
    for y in range(4,75,7):
        p.line((3,y,15,y),fill='#8c9782',width=2)
        p.line((3,y+2,15,y+2),fill='#3b5350')
    for x in [4,13]: p.line((x,1,x,76),fill='#536f64')
    p.rectangle((7,31,10,46),fill='#a59e7e',outline='#273936')
prop('gate',(20,78),gate)

# Repaint character with small shaded forms and dark silhouette outlines.
sheet=Image.new('RGBA',(128,144))
for row in range(4):
    for frame in range(4):
        im=Image.new('RGBA',(32,36)); p=ImageDraw.Draw(im)
        bob=1 if frame in [1,3] else 0
        step=[0,-1,0,1][frame]
        p.ellipse((7,29,25,34),fill=(0,8,14,130))
        if row < 2:
            p.rectangle((11,24,15,31+step),fill='#132631')
            p.rectangle((18,24,22,31-step),fill='#172d39')
            p.line((12,25,12,29+step),fill='#3d5360')
            p.line((19,25,19,29-step),fill='#405663')
            p.rectangle((10,31+step,15,33+step),fill='#101c25')
            p.rectangle((18,31-step,23,33-step),fill='#101c25')
            p.line((11,32+step,14,32+step),fill='#68716b')
            p.line((19,32-step,22,32-step),fill='#68716b')
            p.polygon([(10,13+bob),(14,11+bob),(20,11+bob),(24,14+bob),(24,25+bob),(9,25+bob)],fill='#19292f')
            p.rectangle((11,14+bob,22,24+bob),fill='#667468')
            p.rectangle((11,15+bob,13,23+bob),fill='#87917b')
            p.rectangle((20,14+bob,22,24+bob),fill='#4a5f57')
            p.rectangle((15,14+bob,18,21+bob),fill='#b3b29a' if row==0 else '#586e60')
            p.line((16,16+bob,16,24+bob),fill='#333f3b')
            p.rectangle((8,15+bob,10,24+step+bob),fill='#586b60')
            p.rectangle((24,15+bob,26,24-step+bob),fill='#3d534d')
            p.rectangle((8,23+step+bob,10,26+step+bob),fill='#b59779')
            p.rectangle((24,23-step+bob,26,26-step+bob),fill='#a48a71')
            p.rectangle((11,4+bob,23,12+bob),fill='#172429')
            p.rectangle((12,5+bob,22,11+bob),fill='#bda080')
            p.rectangle((14,12+bob,20,13+bob),fill='#9c8068')
            p.polygon([(10,4+bob),(12,2+bob),(21,1+bob),(24,4+bob),(23,7+bob),(20,6+bob),(18,5+bob),(12,7+bob),(10,6+bob)],fill='#152228')
            p.line((12,3+bob,20,2+bob,22,3+bob),fill='#3d4d4d')
            if row == 0:
                p.point((14,8+bob),fill='#18252a'); p.point((21,8+bob),fill='#18252a')
                p.line((16,11+bob,19,11+bob),fill='#896e5c')
                p.point((17,9+bob),fill='#d8ba92')
            else:
                p.rectangle((11,4+bob,23,10+bob),fill='#1b292e')
                p.line((13,4+bob,20,3+bob),fill='#3a4c4c')
                p.rectangle((13,15+bob,22,24+bob),fill='#374f4b',outline='#768375')
                p.line((14,17+bob,21,17+bob),fill='#536d5e')
        else:
            p.rectangle((12+step,24,16+step,31),fill='#19303d')
            p.rectangle((17-step,23,21-step,31),fill='#253e49')
            p.rectangle((11+step,31,17+step,33),fill='#101e27')
            p.rectangle((17-step,31,23-step,33),fill='#101e27')
            p.line((12+step,32,16+step,32),fill='#67766f')
            p.polygon([(11,14+bob),(15,12+bob),(21,13+bob),(24,16+bob),(23,25+bob),(11,25+bob)],fill='#192a30')
            p.rectangle((12,15+bob,22,24+bob),fill='#657669')
            p.rectangle((13,16+bob,17,24+bob),fill='#85927b')
            p.rectangle((14,24+bob,17,27+bob),fill='#b99d7e')
            p.rectangle((9,15+bob,12,24+bob),fill='#374e49',outline='#788674')
            p.rectangle((12,4+bob,23,12+bob),fill='#17262c')
            p.rectangle((15,5+bob,23,11+bob),fill='#bda080')
            p.rectangle((23,8+bob,24,10+bob),fill='#b79a7a')
            p.point((22,7+bob),fill='#15272d')
            p.polygon([(10,4+bob),(13,1+bob),(20,1+bob),(23,4+bob),(21,6+bob),(16,5+bob),(14,10+bob),(11,9+bob)],fill='#18282d')
            p.line((12,3+bob,19,2+bob,21,3+bob),fill='#405250')
            if row==2: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        sheet.alpha_composite(im,(frame*32,row*36))
save(sheet,'characters','dawen_walk')

# An unlit reflection becomes visible only in the danger preview.
reflection=Image.new('RGBA',(48,36)); p=ImageDraw.Draw(reflection)
p.ellipse((19,2,28,13),fill=(13,20,26,235))
p.polygon([(18,12),(29,12),(33,33),(13,33)],fill=(12,18,25,230))
p.line((21,7,22,7),fill=(140,150,137,150))
save(reflection,'props','window_reflection')

photo=historical.crop((368,64,568,224)).convert('RGB')
bed_image=Image.open(ROOT/'assets/props/iron_bed.png')
photo.paste(bed_image,(44,0),bed_image)
photo=ImageEnhance.Color(photo).enhance(.2)
p=ImageDraw.Draw(photo)
p.rectangle((0,0,199,159),outline='#b2a98e',width=4)
save(photo,'props','old_photo')
print('Retro RPG horror pass generated.')
