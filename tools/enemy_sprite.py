"""Original Idle Dungeon bestiary. Rebuild: python3 tools/enemy_sprite.py.

Pillow only; no downloaded art and no hero assets are modified. Each monster has
three 48x64 frames: two idle poses and an attack pose, facing the party (left).
The registry covers every name currently present in data/dungeons.json.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/sprites/enemies'
DARK = '#141018'


def shade(color, amount=.7):
    color = color.lstrip('#')
    return tuple(int(int(color[i:i+2], 16) * amount) for i in (0, 2, 4)) + (255,)


class Art:
    def __init__(self, frame):
        self.image = Image.new('RGBA', (48, 64))
        self.d = ImageDraw.Draw(self.image)
        self.b = frame % 2
        self.attack = frame == 2

    def poly(self, points, col):
        self.d.polygon(points, fill=col)

    def rect(self, box, col):
        self.d.rectangle(box, fill=col)

    def line(self, points, col, width=1):
        self.d.line(points, fill=col, width=width)

    def eye(self, x, y, col='#ffbd69'):
        self.rect((x-1, y-1, x+1, y+1), DARK)
        self.rect((x-1, y, x, y), col)

    def outline(self):
        src = self.image.copy()
        src_px, dst = src.load(), self.image.load()
        for y in range(64):
            for x in range(48):
                if src_px[x, y][3]:
                    continue
                if any(0 <= x+dx < 48 and 0 <= y+dy < 64 and src_px[x+dx, y+dy][3] > 0
                       for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    dst[x, y] = (20, 16, 24, 255)
        return self.image


def legs(c, color, wide=False):
    a = 2 if wide else 0
    c.rect((18-a, 42, 22, 57), color)
    c.rect((28, 42, 32+a, 57), shade(color))
    c.rect((14-a, 56, 22, 60), '#45434c')
    c.rect((26, 56, 35+a, 60), '#33343e')


def robe(c, color, trim, wide=False):
    b = c.b
    c.poly([(18, 21+b), (32, 20+b), (39 if wide else 35, 58), (10 if wide else 14, 58)], color)
    c.poly([(28, 24+b), (32, 23+b), (39 if wide else 35, 58), (26, 58)], shade(color))
    c.rect((17, 56, 34, 58), trim)
    c.line([(23, 28+b), (22, 55)], trim, 2)


def skull(c, x=23, y=14, bone='#b6ae93'):
    c.poly([(x-6,y-5), (x+4,y-5), (x+7,y), (x+4,y+7), (x-4,y+8), (x-8,y+2)], bone)
    c.rect((x-6,y-4,x+2,y-2), '#ded1b0')
    c.eye(x-5,y+1,'#e4a26e')
    c.eye(x+2,y+1,'#e4a26e')
    c.rect((x-3,y+4,x-1,y+5), DARK)
    for dx in [-3,0,3]:
        c.line([(x+dx,y+7),(x+dx,y+9)], '#ded1b0')


def sword(c, x=8, y=20, col='#afb3bd'):
    if c.attack:
        c.poly([(2,34),(x+10,30),(x+11,33),(3,37)], col)
        c.line([(x+8,27),(x+10,37)], '#bda35c', 2)
    else:
        c.poly([(x-2,y),(x,y-5),(x+2,y),(x+2,y+19),(x-1,y+19)], col)
        c.line([(x-5,y+19),(x+5,y+19)], '#bda35c', 2)
        c.line([(x,y+20),(x+1,y+27)], '#6d4a32', 2)


def crown(c, color='#b69b58', y=8):
    c.poly([(16,y+3), (14,y-5), (21,y), (25,y-7), (29,y), (36,y-4), (33,y+5)], color)
    c.rect((18,y+2,32,y+5), shade(color))
    c.rect((24,y+1,26,y+3), '#f2c987')


def knight(c, variant):
    b = c.b
    bone = variant in ('skeleton', 'bone_guard', 'crypt_lord')
    ice = variant in ('ice_knight', 'ice_king')
    plague = variant == 'plague_knight'
    metal = '#92b8c8' if ice else ('#718074' if plague else '#787980')
    trim = '#d6e8e5' if ice else '#ad9c68'
    if variant in ('crypt_lord', 'ice_king'):
        c.poly([(16,20+b),(32,19+b),(42,57),(9,57)], '#4c3345' if not ice else '#304d77')
    legs(c, '#aea78e' if bone else '#51515b')
    c.poly([(14,24+b),(34,23+b),(32,43),(18,43)], '#443e40' if bone else metal)
    c.poly([(27,26+b),(34,24+b),(32,43),(27,43)], shade(metal))
    if bone:
        c.rect((23,25+b,25,42), '#b3ab91')
        for y in [28,33,38]:
            c.line([(18,y+b),(24,y+2+b),(31,y+b)], '#b3ab91', 2)
        skull(c, y=14+b)
    else:
        c.poly([(18,9+b),(29,8+b),(33,14+b),(30,23+b),(18,22+b),(15,15+b)], metal)
        c.rect((16,14+b,29,16+b), '#24272e')
        c.eye(18,15+b,'#98e3f5' if ice else '#a9dd71')
        c.line([(24,9+b),(24,22+b)], trim, 2)
    if variant != 'skeleton':
        c.poly([(12,22+b),(18,21+b),(21,28+b),(12,30+b)], metal)
        c.poly([(30,21+b),(37,24+b),(38,30+b),(30,28+b)], shade(metal))
        c.poly([(34,30+b),(43,32+b),(42,47+b),(37,51+b),(32,45+b)], '#486572' if ice else '#5e473b')
        c.line([(37,34+b),(37,46+b)], trim, 2)
        c.line([(34,40+b),(41,40+b)], trim, 2)
    else:
        c.line([(35,27+b),(39,37+b),(36,42+b)], '#b3ab91', 3)
    c.line([(14,29+b),(11,37+b),(8,39+b)], '#b3ab91' if bone else metal, 3)
    sword(c, col='#c5e9eb' if ice else '#b1afb6')
    if variant in ('crypt_lord','ice_king'):
        crown(c, '#90c1de' if ice else '#b69b58', 7+b)
    if plague:
        for x,y in [(31,28),(29,38),(19,23),(33,44)]:
            c.rect((x,y+b,x+2,y+2+b), '#a0b54b')
    if variant == 'bone_guard':
        c.poly([(13,20+b),(10,15+b),(18,20+b),(34,19+b),(38,14+b),(37,24+b)], '#929195')


def ghoul(c, variant):
    b = c.b
    col = {'scavenger':'#8b7e68', 'zombie':'#789063', 'frost_ghoul':'#8bafba', 'drowned':'#72968e'}[variant]
    if variant == 'zombie':
        legs(c, '#4e423e')
        c.poly([(17,25+b),(32,24+b),(35,43),(17,43)], '#6c4b41')
        c.line([(18,25+b),(16,39+b),(9,41+b)], col, 5)
        c.line([(33,25+b),(38,36+b),(35,42+b)], col, 4)
        c.poly([(19,9+b),(30,9+b),(32,22+b),(20,25+b),(16,18+b)], col)
        c.rect((18,11+b,27,13+b), '#9ba481')
        c.eye(19,17+b)
        c.rect((21,22+b,27,23+b), DARK)
        c.rect((20,29+b,25,36+b), '#807a58')
        c.line([(18,37),(26,41),(30,36)], '#3d332f', 2)
    elif variant == 'drowned':
        legs(c, '#4b685e', True)
        c.poly([(12,26+b),(16,19+b),(33,18+b),(38,31+b),(34,46),(14,46)], col)
        c.poly([(20,12+b),(30,11+b),(34,22+b),(22,27+b),(16,22+b)], '#8bada0')
        c.poly([(19,10+b),(30,10+b),(34,16+b),(17,15+b)], '#354b45')
        c.eye(21,19+b,'#b5d9de')
        c.line([(14,28+b),(10,42+b),(8,45+b)], col, 5)
        c.line([(36,28+b),(39,39+b)], col, 5)
        # Rusted anchor and links across the torso.
        c.line([(10,39),(7,54),(3,50),(3,56),(8,59),(13,55)], '#74604d', 3)
        for y in range(25,43,4):
            c.rect((23,y+b,25,y+2+b), '#a59a75')
        for x,y in [(15,35),(31,43),(32,12)]:
            c.line([(x,y+b),(x-1,y+6+b)], '#4c7554', 2)
    else:
        # The scavenger is low and long-armed; frost ghoul has a spined back.
        c.poly([(12,34+b),(20,25+b),(30,24+b),(36,33+b),(33,43+b),(20,43+b)], col)
        c.line([(20,40),(18,49),(13,56),(22,56)], col, 5)
        c.line([(30,40),(34,48),(35,57),(41,57)], shade(col), 4)
        c.poly([(13,25+b),(22,22+b),(26,29+b),(20,37+b),(10,34+b)], col)
        c.eye(13,29+b,'#a9e7f2' if variant == 'frost_ghoul' else '#e4bc69')
        c.rect((10,33+b,17,34+b), '#c6c1a2')
        reach = -3 if c.attack else 0
        c.line([(17,37+b),(8+reach,43+b),(6+reach,50+b)], col, 5)
        c.line([(31,34+b),(33,43+b),(28,50+b)], shade(col), 4)
        for dx in [0,3,6]:
            c.line([(5+reach+dx,49+b),(3+reach+dx,53+b)], '#c8bfa1', 1)
        if variant == 'frost_ghoul':
            for x,y in [(23,24),(28,24),(33,26)]:
                c.poly([(x-2,y+b),(x,y-8+b),(x+2,y+b)], '#c1e3e5')


def slime(c, variant):
    b = c.b
    if variant == 'slime':
        c.poly([(5,57),(4,49+b),(9,39+b),(15,35+b),(23,32+b),(34,38+b),(40,47+b),(43,57)], '#527f68')
        c.poly([(9,48+b),(13,40+b),(24,36+b),(29,38+b),(17,44+b),(14,51+b)], '#89ad80')
        c.poly([(24,39+b),(35,43+b),(40,55),(24,56)], '#3b5c54')
        c.eye(16,47+b,'#d9e2a0'); c.eye(25,48+b,'#d9e2a0')
        c.line([(17,53+b),(22,54+b),(26,52+b)], DARK, 2)
        c.rect((16,38+b,19,41+b), '#c1cba5')
        if c.attack:
            c.poly([(8,44),(0,40),(1,48),(9,51)], '#527f68')
    else:
        # Waterlogged bloater: tiny legs, huge torn belly and dripping jaw.
        legs(c, '#527065', True)
        c.poly([(9,24+b),(17,18+b),(31,18+b),(39,27+b),(41,44),(35,53),(14,53),(7,42)], '#75927b')
        c.poly([(17,31+b),(32,29+b),(37,40),(32,49),(18,48),(12,41)], '#a6a786')
        c.line([(21,35+b),(28,39),(24,45)], '#725c62', 2)
        c.poly([(17,10+b),(29,9+b),(33,20+b),(21,24+b),(15,20+b)], '#90a28d')
        c.eye(20,16+b); c.eye(28,16+b)
        c.rect((22,22+b,28,25+b), '#3a403c')
        c.line([(10,27+b),(6,41+b),(10,46)], '#66816d', 5)
        c.line([(37,27+b),(42,41+b),(39,47)], '#577060', 5)


def caster(c, variant):
    b = c.b
    palette = {'cultist':('#743e44','#c4a273'), 'fanatic':('#783630','#c59862'),
               'fire_priest':('#8d4934','#d0ab62'), 'monk':('#657048','#b3af71'),
               'abbot':('#4f593d','#c5b77b'), 'shade':('#383047','#696080')}
    col, trim = palette[variant]
    robe(c, col, trim, variant == 'abbot')
    c.poly([(15,24+b),(14,12+b),(23,5+b),(31,12+b),(33,25+b)], col)
    c.poly([(19,13+b),(25,11+b),(29,17+b),(28,23+b),(20,23+b)], '#211c22')
    c.eye(20,18+b,'#d9cb82' if variant in ('monk','abbot') else '#ed9a6e')
    c.line([(16,27+b),(10,35+b),(9,39+b)], col, 4)
    c.line([(32,26+b),(36,36+b)], shade(col), 4)
    if variant == 'cultist':
        sword(c, 8, 31+b, '#bdac91')
        c.rect((32,34+b,39,42+b), '#624d33')
        c.line([(34,35+b),(34,41+b)], '#c6b284')
    elif variant == 'fanatic':
        # A raised ritual mask and twin crescent axes.
        c.poly([(19,12+b),(27,12+b),(27,22+b),(23,25+b),(19,22+b)], '#d1ba90')
        c.eye(21,17+b); c.eye(26,17+b)
        for x in [7,38]:
            c.line([(x,25+b),(x,48+b)], '#8c6843', 2)
            c.poly([(x-5,24+b),(x+4,28+b),(x+4,35+b),(x-5,37+b),(x-1,31+b)], '#b9a79d')
    elif variant in ('monk','abbot'):
        c.line([(9,35+b),(6,45+b),(10,49+b)], '#a49160', 1)
        c.poly([(4,49+b),(11,47+b),(14,53+b),(10,58+b),(4,56+b)], '#8c8358')
        c.line([(6,45+b),(3,39+b),(6,33+b)], '#8ca569', 2)
        if variant == 'abbot':
            c.poly([(16,8+b),(16,2+b),(24,5+b),(31,2+b),(30,11+b)], '#b1a86f')
            c.line([(38,28+b),(38,56)], '#a2916a', 3)
            c.line([(34,30+b),(42,30+b)], '#c7b882', 2)
    elif variant == 'shade':
        # Split, faceless silhouette with mist instead of feet.
        c.poly([(14,52),(9,60),(18,57),(21,62),(26,57),(34,60),(31,50)], col)
        c.rect((20,18+b,27,19+b), '#a5a0cb')
    else:
        c.line([(8,23+b),(8,56)], '#875934', 3)
        c.poly([(8,12+b),(3,23+b),(8,29+b),(13,23+b)], '#e4a252')
        c.poly([(8,17+b),(6,23+b),(8,26+b),(10,23+b)], '#ffe3a0')


def imp(c, variant):
    b = c.b
    demon = variant in ('demon', 'gatekeeper', 'ash_lord')
    col = '#a14f3f' if demon else '#b77847'
    if demon:
        c.poly([(16,26+b),(6,13+b),(1,17+b),(3,39+b),(11,32+b)], '#61323a')
        c.poly([(31,25+b),(42,13+b),(46,18+b),(44,40+b),(36,33+b)], '#72343d')
        c.line([(5,18+b),(7,31+b),(13,29+b)], '#bd7957', 2)
        c.line([(42,18+b),(41,31+b),(35,30+b)], '#bd7957', 2)
    else:
        c.poly([(18,35+b),(9,25+b),(4,28+b),(8,43+b),(13,38+b)], '#7c483c')
        c.poly([(29,34+b),(39,25+b),(44,29+b),(39,43+b),(34,38+b)], '#8b4f3c')
    y = 15 if demon else 21
    c.poly([(19,y+10+b),(29,y+9+b),(34,y+25),(18,y+25)], col)
    c.poly([(19,y+24),(21,y+37),(16,y+40),(22,y+40),(25,y+30),(29,y+39),(35,y+39),(31,y+24)], col)
    c.poly([(18,y+b),(29,y-1+b),(32,y+5+b),(29,y+12+b),(20,y+13+b),(15,y+6+b)], col)
    c.poly([(19,y+1+b),(15,y-7+b),(23,y-1+b)], '#c6aa7b')
    c.poly([(27,y+b),(34,y-7+b),(32,y+4+b)], '#c6aa7b')
    c.eye(18,y+5+b,'#ffd076'); c.eye(26,y+5+b,'#ffd076')
    c.rect((20,y+10+b,26,y+11+b), '#e0cba6')
    c.line([(18,y+15+b),(11,y+23+b),(8,y+27+b)], col, 4)
    c.line([(31,y+15+b),(37,y+22+b),(38,y+28+b)], shade(col), 4)
    if variant in ('gatekeeper','ash_lord'):
        c.rect((18,30+b,32,33+b), '#5d4c46')
        c.line([(7,15+b),(8,54)], '#9b7b4e', 3)
        c.poly([(2,16+b),(13,13+b),(16,23+b),(3,27+b),(6,22+b)], '#b7a38d')
        if variant == 'ash_lord':
            crown(c, '#d5aa68', 9+b)
            c.poly([(18,3+b),(21,10+b),(24,0),(29,9+b),(34,4+b),(30,14+b)], '#eead57')
            c.rect((23,27+b,25,34+b), '#f6bf67')


def golem(c, variant):
    b = c.b
    frost = variant == 'frost_guardian'
    col = '#87b0bb' if frost else '#787783'
    light = '#bfdfe0' if frost else '#a0a1b2'
    legs(c, col, True)
    c.poly([(11,23+b),(19,18+b),(30,18+b),(38,24+b),(35,43),(15,43)], col)
    c.poly([(24,22+b),(35,24+b),(34,40),(26,42)], shade(col))
    c.poly([(18,8+b),(31,8+b),(35,15+b),(31,23+b),(20,24+b),(15,17+b)], col)
    c.rect((19,10+b,28,12+b), light)
    c.rect((16,16+b,30,18+b), DARK)
    c.rect((18,16+b,22,17+b), '#b9def0'); c.rect((26,16+b,29,17+b), '#b9def0')
    c.poly([(10,23+b),(4,28+b),(3,42+b),(10,44+b),(16,28+b)], col)
    c.poly([(37,23+b),(43,28+b),(45,43+b),(37,46+b),(31,28+b)], shade(col))
    c.line([(22,26+b),(27,31+b),(23,36+b),(27,39)], '#9fd6e7', 2)
    for x,y in [(13,24),(34,25),(22,42)]:
        c.line([(x,y+b),(x+3,y+4+b),(x,y+6+b)], DARK)
    if variant == 'storm_lord':
        c.poly([(12,20+b),(7,12+b),(20,20+b),(28,18+b),(38,10+b),(37,24+b)], '#b7b2d3')
        c.line([(6,7+b),(2,17+b),(8,16+b),(4,28+b)], '#c1c8fa', 2)
        c.line([(41,5+b),(38,15+b),(44,14+b),(40,24+b)], '#c1c8fa', 2)
        c.rect((20,28+b,29,37+b), '#6972ac')
        c.line([(24,28+b),(22,33+b),(26,33+b),(23,39+b)], '#d2e1ff', 2)
    elif frost:
        for x,y in [(13,23),(34,23),(21,8),(29,7)]:
            c.poly([(x-3,y+b),(x,y-7+b),(x+3,y+b)], light)


def kobold(c, variant):
    b = c.b
    foreman = variant == 'foreman'
    skin = '#ad885b' if foreman else '#977a57'
    c.line([(30,43),(39,47),(43,43)], skin, 3)
    legs(c, skin)
    c.poly([(18,29+b),(29,28+b),(33,45),(17,45)], '#725644' if foreman else '#5c5864')
    c.poly([(19,16+b),(28,15+b),(31,25+b),(22,30+b),(11,26+b),(10,22+b)], skin)
    c.poly([(19,18+b),(16,11+b),(23,17+b)], '#b69b76')
    c.eye(18,22+b,'#e5bb6a')
    c.rect((10,24+b,14,25+b), DARK)
    c.line([(17,33+b),(10,39+b),(6,39+b)], skin, 3)
    c.line([(30,32+b),(36,39+b)], skin, 3)
    # Pickaxe held to the front.
    c.line([(5,29+b),(11,53)], '#a67c4b', 2)
    c.poly([(0,29+b),(7,25+b),(16,28+b),(16,30+b),(7,29+b)], '#afb0b3')
    c.poly([(17,15+b),(19,11+b),(27,11+b),(31,16+b)], '#baa35f')
    c.rect((16,16+b,31,18+b), '#8c7850')
    c.rect((18,13+b,20,15+b), '#ece1af')
    if foreman:
        c.rect((22,34+b,29,40+b), '#8e3430')
        for x in [23,26,29]:
            c.line([(x,33+b),(x,40+b)], '#d18459')
        c.poly([(15,29+b),(19,29+b),(18,43),(15,41)], '#b69b68')


def harpy(c, variant):
    b = c.b
    c.poly([(21,30+b),(12,16+b),(2,11+b),(5,22+b),(0,22+b),(7,31+b),(3,33+b),(17,40+b)], '#9e937f')
    c.poly([(29,29+b),(36,15+b),(45,10+b),(43,22+b),(47,21+b),(41,32+b),(45,34+b),(33,39+b)], '#797d78')
    for x,y in [(7,19),(10,25),(37,22),(37,28)]:
        c.line([(x,y+b),(x+4,y+6+b)], '#c0b39b', 2)
    c.poly([(21,25+b),(29,25+b),(32,42+b),(20,43+b)], '#977a69')
    c.line([(23,41),(20,51),(16,56)], '#bb9a67', 3)
    c.line([(29,41),(31,51),(30,57)], '#a98c65', 3)
    c.line([(12,57),(20,57)], '#c5b188', 2)
    c.line([(27,58),(35,58)], '#c5b188', 2)
    c.poly([(21,13+b),(28,13+b),(31,20+b),(27,27+b),(20,24+b)], '#c0a080')
    c.poly([(19,15+b),(22,8+b),(27,11+b),(31,9+b),(31,18+b)], '#685466')
    c.poly([(20,20+b),(14,22+b),(20,24+b)], '#d6b26d')
    c.eye(21,19+b,'#eadba3')


def hound(c, variant):
    b = c.b
    c.poly([(11,32+b),(25,28+b),(37,32+b),(39,44+b),(17,47+b),(9,41+b)], '#65734c')
    c.poly([(23,32+b),(35,33+b),(36,41+b),(24,42+b)], '#8a9162')
    c.poly([(12,32+b),(15,20+b),(20,21+b),(18,28+b),(22,35+b),(15,40+b),(5,38+b),(3,34+b)], '#7f8a5c')
    c.eye(10,32+b,'#e5d390')
    c.rect((4,37+b,12,38+b), '#d4cca0')
    c.line([(15,43),(12,57),(8,57)], '#758151', 4)
    c.line([(24,44),(24,57),(20,57)], '#516341', 3)
    c.line([(34,43),(38,54),(36,57)], '#596a45', 4)
    c.line([(36,33+b),(43,25+b),(44,18+b)], '#65734c', 3)
    for x,y in [(21,29),(27,29),(31,31),(17,25)]:
        c.rect((x,y+b,x+3,y+2+b), '#b2ae61')
    c.line([(26,35+b),(29,38+b),(25,42+b)], '#9b5254', 2)


def troll(c, variant):
    b = c.b
    col = '#8aadb1'
    legs(c, '#829ba2', True)
    c.poly([(9,22+b),(20,15+b),(33,17+b),(40,27+b),(35,44),(14,43)], col)
    c.poly([(17,20+b),(28,22+b),(32,39),(20,41)], '#bdd1ca')
    c.line([(11,25+b),(6,38+b),(9,47)], col, 7)
    c.line([(37,26+b),(42,36+b),(39,44)], shade(col), 6)
    c.poly([(16,8+b),(29,7+b),(33,17+b),(27,27+b),(18,25+b),(12,17+b)], col)
    c.poly([(15,8+b),(17,4+b),(21,6+b),(25,3+b),(30,7+b),(31,12+b)], '#c6d5d1')
    c.eye(17,15+b,'#f7d69b'); c.eye(26,15+b,'#f7d69b')
    c.rect((17,22+b,27,24+b), DARK)
    c.poly([(17,22+b),(19,28+b),(21,22+b)], '#e8dac0')
    c.poly([(25,22+b),(27,28+b),(29,21+b)], '#e8dac0')
    c.line([(7,32+b),(6,55)], '#7c6658', 4)
    c.poly([(1,25+b),(9,24+b),(12,34+b),(2,38+b)], '#7e8b92')


def ghost(c, variant):
    b = c.b
    c.poly([(15,17+b),(25,10+b),(33,17+b),(34,32+b),(38,49+b),(33,46+b),(30,57+b),(25,52+b),(20,59+b),(18,48+b),(10,52+b),(13,35+b)], '#7893a1')
    c.poly([(20,17+b),(27,14+b),(31,20+b),(29,40+b),(25,51+b),(19,42+b)], '#b2c7c7')
    c.poly([(15,26+b),(9,29+b),(4,40+b),(12,35+b),(17,36+b)], '#96b5bd')
    c.poly([(32,27+b),(38,30+b),(43,42+b),(35,37+b),(29,35+b)], '#68899b')
    c.eye(21,24+b,'#eef2d2'); c.eye(28,24+b,'#eef2d2')
    c.rect((23,30+b,26,34+b), '#344958')


def worm(c, variant):
    b = c.b
    for x,y,r in [(38,51,6),(30,49,8),(22,43,9),(17,32,9),(15,22,10)]:
        c.d.ellipse((x-r,y-r+b,x+r,y+r+b), fill='#924c3f', outline=DARK, width=1)
        c.line([(x+3,y-r+2+b),(x+6,y+b),(x+3,y+r-2+b)], '#d58b57', 2)
    c.poly([(6,15+b),(17,13+b),(23,21+b),(18,29+b),(6,27+b)], '#c16b47')
    c.poly([(6,18+b),(17,18+b),(18,25+b),(5,25+b)], '#34232a')
    for x in [7,11,15]:
        c.poly([(x,18+b),(x+2,22+b),(x+3,18+b)], '#d9bb81')
        c.poly([(x,25+b),(x+2,22+b),(x+3,25+b)], '#d9bb81')
    c.eye(10,14+b,'#ffcd77')
    for x,y in [(26,35),(31,44),(40,49)]:
        c.poly([(x,y+b),(x+4,y-6+b),(x+4,y+b)], '#e3a565')


def tentacled(c, variant):
    b = c.b
    sea = variant == 'sea_queen'
    col = '#5f8d91' if sea else '#68547e'
    light = '#a1c5bf' if sea else '#b2a2c8'
    # Arms and several curled lower limbs, genuinely nonhumanoid silhouettes.
    for pts in [[(20,38+b),(12,48),(8,56),(3,54)], [(26,38+b),(28,51),(24,60),(18,58)],
                [(30,38+b),(38,48),(42,56),(45,51)], [(24,43+b),(18,53),(16,60)]]:
        c.line(pts, col, 5)
        c.line(pts, shade(col), 1)
    if variant == 'abyss_spawn':
        c.poly([(13,30+b),(16,22+b),(29,20+b),(36,27+b),(34,41+b),(21,47+b),(12,39+b)], '#7b5878')
        for x,y in [(18,28),(28,27),(23,36),(31,37)]:
            c.eye(x,y+b,'#f1cf8e')
        c.line([(15,33+b),(7,29+b),(3,33+b)], '#8b697b', 3)
        c.line([(34,31+b),(40,25+b),(44,29+b)], '#8b697b', 3)
    elif variant == 'void_voice':
        c.poly([(11,24+b),(22,14+b),(35,21+b),(38,34+b),(29,45+b),(14,42+b),(8,33+b)], '#6d567e')
        c.poly([(12,29+b),(22,22+b),(34,27+b),(34,35+b),(22,40+b)], '#bdadb9')
        c.d.ellipse((17,24+b,30,38+b), fill='#4c395d')
        c.rect((22,26+b,24,36+b), '#e8c688')
        c.poly([(16,22+b),(12,12+b),(20,19+b),(28,18+b),(34,8+b),(34,23+b)], '#8e7b9c')
    else:
        c.poly([(19,23+b),(29,22+b),(34,39+b),(17,42+b)], '#426f7d')
        c.poly([(20,10+b),(29,10+b),(33,18+b),(28,27+b),(20,24+b),(16,16+b)], light)
        c.poly([(18,10+b),(18,5+b),(24,8+b),(29,3+b),(31,12+b)], '#acbdab')
        c.eye(20,18+b,'#eddea0'); c.eye(27,18+b,'#eddea0')
        c.line([(18,27+b),(11,34+b),(8,27+b)], light, 3)
        c.line([(31,26+b),(36,35+b),(40,31+b)], light, 3)
        c.line([(8,18+b),(8,52)], '#92b2b1', 2)
        c.line([(3,17+b),(3,23+b),(13,23+b),(13,17+b)], '#bed1bf', 2)


def flame_mother(c, variant):
    b = c.b
    for x,y in [(12,10),(19,7),(27,5),(35,10),(39,20),(8,22)]:
        c.poly([(x-3,y+9+b),(x,y+b),(x+3,y+9+b)], '#d58a47')
        c.poly([(x-1,y+8+b),(x,y+4+b),(x+1,y+8+b)], '#f4cd80')
    robe(c, '#8f493f', '#d0a067', True)
    c.poly([(18,12+b),(28,12+b),(31,18+b),(27,25+b),(20,24+b),(16,18+b)], '#bf9b7c')
    c.poly([(16,14+b),(17,8+b),(26,9+b),(31,13+b),(31,21+b),(28,15+b)], '#5a3540')
    c.eye(19,18+b,'#ffe2a0'); c.eye(26,18+b,'#ffe2a0')
    c.line([(17,27+b),(11,33+b),(6,29+b)], '#bd8a66', 3)
    c.line([(31,27+b),(37,33+b),(42,28+b)], '#bd8a66', 3)
    c.poly([(3,26+b),(6,17+b),(9,27+b)], '#efaf59')
    c.poly([(39,25+b),(42,16+b),(45,26+b)], '#efaf59')
    c.poly([(14,52),(8,59),(20,55),(24,61),(28,55),(39,59),(33,51)], '#b46640')


def plague_lord(c, variant):
    b = c.b
    legs(c, '#626e4e', True)
    c.poly([(10,22+b),(17,16+b),(32,17+b),(40,26+b),(41,43),(34,53),(15,53),(7,40)], '#6a7b50')
    c.poly([(16,28+b),(31,26+b),(37,35),(34,46),(20,49),(12,39)], '#a2a16c')
    c.line([(21,30+b),(25,36),(21,43),(28,45)], '#6c4650', 2)
    c.poly([(17,8+b),(29,8+b),(33,17+b),(28,24+b),(19,22+b),(14,15+b)], '#96a270')
    c.eye(19,15+b); c.eye(27,15+b)
    c.rect((21,20+b,29,22+b), '#464637')
    c.line([(11,26+b),(5,38+b),(9,45)], '#76844f', 5)
    c.line([(38,27+b),(43,38+b),(39,47)], '#5c6c46', 5)
    # Distinct fungus crest and shoulder caps.
    for x,y in [(16,6),(25,4),(33,15),(11,25),(36,29)]:
        c.rect((x,y+b,x+1,y+6+b), '#a5a86b')
        c.poly([(x-3,y+b),(x,y-3+b),(x+4,y+b)], '#b6ac6c')
        c.rect((x-1,y-1+b,x,y+b), '#e2ce91')


def spire_guard(c, variant):
    b = c.b
    # Floating iron construct: huge shoulders, hanging chains, no human legs.
    c.poly([(13,22+b),(19,17+b),(31,17+b),(37,24+b),(34,39+b),(24,47+b),(15,38+b)], '#665b77')
    c.poly([(23,23+b),(31,23+b),(31,36+b),(24,40+b)], '#9585a8')
    c.poly([(17,12+b),(24,4+b),(31,12+b),(31,21+b),(18,21+b)], '#91839e')
    c.rect((19,16+b,29,18+b), '#2e283b')
    c.rect((21,16+b,27,17+b), '#c7a1ea')
    c.poly([(4,20+b),(14,19+b),(20,27+b),(15,34+b),(5,30+b)], '#82738e')
    c.poly([(32,22+b),(42,19+b),(44,30+b),(35,35+b),(30,28+b)], '#6c617d')
    c.line([(9,32+b),(7,44+b),(4,47+b)], '#746783', 4)
    c.line([(38,33+b),(40,43+b),(37,48+b)], '#746783', 4)
    for x in [18,25,31]:
        for y in range(42,57,4):
            c.rect((x,y+b,x+2,y+2+b), '#978a9c')
    c.poly([(24,47+b),(19,53+b),(25,60+b),(29,53+b)], '#b19ac7')
    c.line([(3,38+b),(4,56)], '#b0a0b6', 2)


def void_herald(c, variant):
    b = c.b
    # Winged hovering eye, unlike any humanoid boss.
    c.poly([(17,27+b),(9,12+b),(1,7+b),(4,26+b),(0,33+b),(12,41+b),(17,36+b)], '#5b456e')
    c.poly([(29,27+b),(38,12+b),(46,7+b),(43,26+b),(47,33+b),(36,41+b),(31,36+b)], '#715581')
    c.line([(4,13+b),(8,28+b),(14,34+b)], '#a688af', 2)
    c.line([(43,13+b),(39,28+b),(33,34+b)], '#a688af', 2)
    c.poly([(14,23+b),(23,16+b),(33,22+b),(37,32+b),(29,43+b),(18,43+b),(10,33+b)], '#857093')
    c.poly([(13,30+b),(23,23+b),(33,30+b),(23,37+b)], '#d2b8c3')
    c.d.ellipse((18,25+b,28,36+b), fill='#513e68')
    c.rect((22,26+b,24,34+b), '#f3d5a3')
    c.poly([(18,16+b),(16,5+b),(22,12+b),(26,1+b),(29,13+b),(35,5+b),(32,20+b)], '#9b8aa6')
    for x in [17,24,31]:
        c.line([(x,41+b),(x-3,50+b),(x+1,57+b)], '#9576ab', 3)
    c.poly([(24,46+b),(21,53+b),(24,60+b),(27,53+b)], '#c9b6d4')


# One registry entry per in-game name, including floor guardians and final bosses.
# kind identifies a meaningful body plan, variant adds its own equipment/anatomy.
MONSTERS = [
    ('Падальщик', 'scavenger', 'ghoul'), ('Скелет','skeleton','knight'), ('Зомби','zombie','ghoul'),
    ('Костяной страж','bone_guard','knight'), ('Хозяин склепа','crypt_lord','knight'),
    ('Утопленник','drowned','ghoul'), ('Ледяной упырь','frost_ghoul','ghoul'), ('Слизень','slime','slime'),
    ('Раздутый','bloater','slime'), ('Владычица глубин','sea_queen','tentacled'),
    ('Культист','cultist','caster'), ('Огненный бес','imp','imp'), ('Фанатик','fanatic','caster'),
    ('Жрец пламени','fire_priest','caster'), ('Пламенная мать','flame_mother','flame_mother'),
    ('Грозовой голем','golem','golem'), ('Кобольд','kobold','kobold'), ('Гарпия','harpy','harpy'),
    ('Бригадир','foreman','kobold'), ('Владыка грома','storm_lord','golem'),
    ('Чумной монах','monk','caster'), ('Гнилой пёс','hound','hound'), ('Порченый рыцарь','plague_knight','knight'),
    ('Настоятель','abbot','caster'), ('Чумной лорд','plague_lord','plague_lord'),
    ('Снежный тролль','troll','troll'), ('Призрак','ghost','ghost'), ('Ледяной рыцарь','ice_knight','knight'),
    ('Хранитель стужи','frost_guardian','golem'), ('Король стужи','ice_king','knight'),
    ('Отродье бездны','abyss_spawn','tentacled'), ('Лавовый червь','worm','worm'), ('Демон','demon','imp'),
    ('Привратник','gatekeeper','imp'), ('Повелитель пепла','ash_lord','imp'),
    ('Глас пустоты','void_voice','tentacled'), ('Тень','shade','caster'),
    ('Страж шпиля','spire_guard','spire_guard'), ('Глашатай пустоты','void_herald','void_herald')
]
DRAWERS = {name: value for name, value in globals().copy().items() if callable(value)}


def generate():
    OUT.mkdir(parents=True, exist_ok=True)
    registry = {}
    for name, key, body in MONSTERS:
        sheet = Image.new('RGBA', (144, 64))
        for frame in range(3):
            c = Art(frame)
            DRAWERS[body](c, key)
            sheet.alpha_composite(c.outline(), (frame*48, 0))
        sheet.save(OUT / (key + '.png'))
        registry[name] = {'sprite': key, 'archetype': body}
    (ROOT / 'data/enemy_visuals.json').write_text(json.dumps(registry, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    names = json.loads((ROOT / 'data/dungeons.json').read_text(encoding='utf-8'))['dungeons']
    for dungeon in names:
        for name in dungeon['names'] + [dungeon['floor_boss'], dungeon['boss']]:
            assert name in registry, f'No sprite for {name}'
    # Review-only contact sheet goes outside the source art folder by default.
    review = ROOT.parent / 'changes/v04'
    review.mkdir(parents=True, exist_ok=True)
    preview = Image.new('RGB', (5*192, 8*212), '#1c1c23')
    d = ImageDraw.Draw(preview)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13)
    except OSError:
        font = ImageFont.load_default()
    for n, (name,key,body) in enumerate(MONSTERS):
        x,y=(n%5)*192,(n//5)*212
        sprite=Image.open(OUT/(key+'.png')).crop((0,0,48,64)).resize((120,160),Image.Resampling.NEAREST)
        preview.paste(sprite,(x+36,y+8),sprite)
        d.text((x+5,y+173), name, fill='#d3c6ae', font=font)
    preview.save(review/'bestiary.png')
    print(f'Generated {len(registry)} original three-frame monster sheets; {len(set(v[2] for v in MONSTERS))} body-plan drawers; all dungeon names covered.')


if __name__ == '__main__':
    generate()
