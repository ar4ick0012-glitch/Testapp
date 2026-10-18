"""Пиксельные модельки героев (заглушки в стиле D2 до настоящего арта).
Запуск: python3 tools/sprites.py  ->  assets/sprites/*.png и assets/sprites/_preview.png
Каждый герой: кадры idle0, idle1, attack. Холст 32x48, смотрит вправо.
"""
import os
from PIL import Image, ImageDraw, ImageFont

W, H = 32, 48
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
OUTLINE = (14, 10, 8, 255)


def rgb(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3],)


class C:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.img.load()

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = c

    def rect(self, x0, y0, x1, y1, c, shaded=True):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                col = c
                if shaded:
                    if y == y0 or x == x0:
                        col = shade(c, 1.25)
                    elif x == x1 or y == y1:
                        col = shade(c, 0.7)
                self.px(x, y, col)

    def line(self, pts, c, w=1):
        d = ImageDraw.Draw(self.img)
        d.line(pts, fill=c, width=w)

    def poly(self, pts, c):
        ImageDraw.Draw(self.img).polygon(pts, fill=c)

    def disc(self, x, y, r, c):
        ImageDraw.Draw(self.img).ellipse((x - r, y - r, x + r, y + r), fill=c)

    def outline(self):
        src = self.img.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] > 200 and src[nx, ny] != OUTLINE:
                            self.p[x, y] = OUTLINE
                            break
        return self.img


SKIN = rgb("#c89a74")


# ---------- части тела ----------
def legs(c, pants, boots, bob):
    c.rect(12, 32 + bob, 14, 42, pants)
    c.rect(17, 32 + bob, 19, 42, shade(pants, 0.85))
    c.rect(11, 42, 15, 45, boots)
    c.rect(16, 42, 21, 45, boots)


def robe(c, col, trim, bob):
    c.poly([(11, 19 + bob), (21, 19 + bob), (23, 45), (9, 45)], col)
    c.poly([(16, 19 + bob), (21, 19 + bob), (23, 45), (17, 45)], shade(col, 0.78))
    c.rect(9, 44, 23, 45, trim, False)
    c.rect(15, 21 + bob, 16, 44, shade(trim, 0.9), False)


def torso(c, col, belt, bob, wide=False):
    x0, x1 = (9, 22) if wide else (10, 21)
    c.rect(x0, 18 + bob, x1, 31 + bob, col)
    c.rect(x0, 29 + bob, x1, 30 + bob, belt, False)
    c.px(16, 29 + bob, rgb("#d8b25a"))


def cape(c, col, bob):
    c.poly([(10, 18 + bob), (14, 18 + bob), (11, 44), (6, 43)], shade(col, 0.75))


def pauldron(c, col, bob):
    c.rect(8, 17 + bob, 12, 21 + bob, col)
    c.rect(19, 17 + bob, 23, 21 + bob, col)


def head(c, bob, skin=SKIN):
    c.rect(13, 9 + bob, 19, 16 + bob, skin)
    c.px(18, 12 + bob, rgb("#1a1010"))


def helm_full(c, metal, plume, bob):
    c.rect(12, 7 + bob, 20, 16 + bob, metal)
    c.rect(16, 11 + bob, 20, 12 + bob, rgb("#0c0a0a"), False)
    c.rect(15, 5 + bob, 17, 7 + bob, plume)
    c.px(14, 4 + bob, plume)


def hood(c, col, bob, eyes=None):
    c.poly([(12, 17 + bob), (13, 8 + bob), (16, 5 + bob), (20, 8 + bob), (21, 17 + bob)], col)
    c.rect(15, 10 + bob, 20, 16 + bob, rgb("#1c1416"), False)
    if eyes:
        c.px(18, 12 + bob, eyes)
        c.px(20, 12 + bob, eyes)
    else:
        c.rect(16, 11 + bob, 20, 15 + bob, shade(SKIN, 0.55), False)
        c.px(19, 12 + bob, rgb("#0c0808"))


def arm(c, x, y, col, hand=SKIN, down=True):
    if down:
        c.rect(x, y, x + 2, y + 9, col)
        c.rect(x, y + 10, x + 2, y + 11, hand, False)
        return (x + 1, y + 11)
    c.rect(x, y, x + 7, y + 2, col)
    c.rect(x + 8, y, x + 9, y + 2, hand, False)
    return (x + 9, y + 1)


# ---------- оружие ----------
def sword(c, hx, hy, attack, blade=rgb("#c8ccd4"), length=10):
    if attack:
        c.line([(hx, hy), (hx + length, hy - length + 3)], blade, 2)
        c.line([(hx - 1, hy - 2), (hx + 1, hy + 2)], rgb("#b08a3a"), 1)
    else:
        c.line([(hx, hy), (hx, hy - length)], blade, 2)
        c.line([(hx - 2, hy - 1), (hx + 2, hy - 1)], rgb("#b08a3a"), 1)


def greatsword(c, hx, hy, attack):
    if attack:
        c.line([(hx, hy), (hx + 14, hy - 12)], rgb("#b8bcc6"), 3)
        c.line([(hx - 2, hy - 2), (hx + 2, hy + 2)], rgb("#8a2a20"), 2)
    else:
        c.line([(hx, hy + 2), (hx - 2, hy - 18)], rgb("#b8bcc6"), 3)
        c.line([(hx - 4, hy - 1), (hx + 3, hy - 2)], rgb("#8a2a20"), 2)


def shield(c, bob, col, emblem):
    c.poly([(19, 21 + bob), (26, 21 + bob), (26, 31 + bob), (22, 35 + bob), (19, 31 + bob)], col)
    c.rect(22, 25 + bob, 23, 29 + bob, emblem, False)
    c.px(21, 27 + bob, emblem)
    c.px(24, 27 + bob, emblem)


def staff(c, hx, hy, orb, wood=rgb("#5a3d22"), attack=False):
    top = (hx + 2, hy - 18) if not attack else (hx + 8, hy - 14)
    c.line([(hx, hy + 6), top], wood, 2)
    if orb:
        c.disc(top[0], top[1], 2, orb)
        c.px(top[0] - 1, top[1] - 1, rgb("#ffffff"))


def bow(c, hx, hy, attack):
    wood = rgb("#6b4a2a")
    x = hx + (2 if attack else 0)
    c.line([(x, hy - 9), (x + 3, hy - 4), (x + 3, hy + 4), (x, hy + 9)], wood, 1)
    string = rgb("#d8d0b8")
    if attack:
        c.line([(x, hy - 9), (hx - 4, hy), (x, hy + 9)], string, 1)
        c.line([(hx - 4, hy), (x + 9, hy)], rgb("#a07a50"), 1)
        c.px(x + 10, hy, rgb("#c8ccd4"))
    else:
        c.line([(x, hy - 9), (x, hy + 9)], string, 1)


def mace(c, hx, hy, attack, head_col):
    end = (hx + 7, hy - 7) if attack else (hx, hy - 9)
    c.line([(hx, hy), end], rgb("#6b4a2a"), 2)
    c.disc(end[0], end[1], 2, head_col)


def glow(c, x, y, col, r=3):
    c.disc(x, y, r, col[:3] + (110,))
    c.disc(x, y, max(1, r - 2), col)


# ---------- классы ----------
def warrior_tank(c, bob, attack):
    metal = rgb("#7c808a")
    cape(c, rgb("#7a1c1c"), bob)
    legs(c, rgb("#4a4d55"), rgb("#3a2a1e"), bob)
    arm(c, 9, 19 + bob, shade(metal, 0.8))
    torso(c, metal, rgb("#3a2a1e"), bob, wide=True)
    pauldron(c, rgb("#9a9ea8"), bob)
    head(c, bob)
    helm_full(c, metal, rgb("#9a2222"), bob)
    if attack:
        h = arm(c, 18, 21 + bob, metal, down=False)
        sword(c, h[0], h[1], True)
    else:
        h = arm(c, 20, 20 + bob, metal)
        sword(c, h[0] + 1, h[1], False)
    shield(c, bob, rgb("#6e1a1a"), rgb("#d8b25a"))


def warrior_2h(c, bob, attack):
    metal = rgb("#6c6a6a")
    legs(c, rgb("#4a3a2c"), rgb("#2e2218"), bob)
    arm(c, 9, 19 + bob, SKIN)
    torso(c, rgb("#5a4632"), rgb("#2a1c12"), bob, wide=True)
    pauldron(c, metal, bob)
    head(c, bob)
    c.rect(12, 7 + bob, 20, 10 + bob, metal)  # открытый шлем
    c.px(12, 6 + bob, rgb("#d8d0b8"))
    c.px(20, 6 + bob, rgb("#d8d0b8"))
    c.rect(17, 14 + bob, 19, 16 + bob, rgb("#6b4422"), False)  # борода
    if attack:
        h = arm(c, 18, 20 + bob, SKIN, down=False)
        greatsword(c, h[0], h[1], True)
    else:
        h = arm(c, 19, 20 + bob, SKIN)
        greatsword(c, h[0], h[1], False)


def mage_elem(c, bob, attack):
    col = rgb("#24407a")
    robe(c, col, rgb("#c46a2a"), bob)
    arm(c, 9, 19 + bob, shade(col, 0.8))
    hood(c, col, bob)
    if attack:
        h = arm(c, 18, 21 + bob, col, down=False)
        glow(c, h[0] + 2, h[1] - 1, rgb("#ff7a2a"), 4)
        glow(c, h[0] + 1, h[1] + 4, rgb("#8ad8ff"), 2)
    else:
        h = arm(c, 20, 20 + bob, col)
        staff(c, h[0], h[1], rgb("#ff7a2a"))


def mage_arcane(c, bob, attack):
    col = rgb("#4a2a6e")
    robe(c, col, rgb("#c8a0ff"), bob)
    arm(c, 9, 19 + bob, shade(col, 0.8))
    hood(c, col, bob)
    for i, (x, y) in enumerate(((7, 10), (24, 8), (25, 16))):
        c.px(x, y + (bob if i % 2 else -bob), rgb("#e0c8ff"))
    if attack:
        h = arm(c, 18, 21 + bob, col, down=False)
        glow(c, h[0] + 2, h[1], rgb("#d080ff"), 4)
    else:
        h = arm(c, 20, 20 + bob, col)
        staff(c, h[0], h[1], rgb("#d080ff"))


def priest_light(c, bob, attack):
    col = rgb("#d8d2c0")
    robe(c, col, rgb("#c8a040"), bob)
    arm(c, 9, 19 + bob, shade(col, 0.8))
    head(c, bob)
    c.rect(12, 8 + bob, 16, 16 + bob, rgb("#e0dccc"))  # капюшон откинут
    c.rect(13, 8 + bob, 19, 9 + bob, rgb("#8a6a40"), False)  # волосы
    glow(c, 16, 4 + bob, rgb("#ffe890"), 2) if attack else c.px(16, 5 + bob, rgb("#ffe890"))
    if attack:
        h = arm(c, 18, 21 + bob, col, down=False)
        glow(c, h[0] + 2, h[1], rgb("#fff0a0"), 4)
    else:
        h = arm(c, 20, 20 + bob, col)
        mace(c, h[0], h[1], False, rgb("#d8b25a"))


def priest_shadow(c, bob, attack):
    col = rgb("#2a2232")
    robe(c, col, rgb("#6a3a9a"), bob)
    arm(c, 9, 19 + bob, shade(col, 0.8))
    hood(c, col, bob, eyes=rgb("#c070ff"))
    c.disc(6, 30 + bob, 2, rgb("#5a2a8a", 140))
    if attack:
        h = arm(c, 18, 21 + bob, col, down=False)
        glow(c, h[0] + 2, h[1], rgb("#8a3ad0"), 4)
    else:
        h = arm(c, 20, 20 + bob, col)
        glow(c, h[0] + 1, h[1] + 1, rgb("#8a3ad0"), 2)


def paladin_holy(c, bob, attack):
    metal = rgb("#b8a46a")
    cape(c, rgb("#e0dccc"), bob)
    legs(c, rgb("#8a7a4a"), rgb("#4a3a22"), bob)
    arm(c, 9, 19 + bob, shade(metal, 0.8))
    torso(c, metal, rgb("#4a3a22"), bob, wide=True)
    c.rect(15, 21 + bob, 16, 27 + bob, rgb("#f0e8c0"), False)
    c.rect(13, 23 + bob, 18, 24 + bob, rgb("#f0e8c0"), False)
    pauldron(c, rgb("#d0bc80"), bob)
    head(c, bob)
    c.rect(12, 8 + bob, 20, 11 + bob, metal)
    c.rect(13, 14 + bob, 19, 16 + bob, rgb("#a08860"), False)
    if attack:
        h = arm(c, 18, 21 + bob, metal, down=False)
        glow(c, h[0] + 2, h[1], rgb("#fff0a0"), 4)
    else:
        h = arm(c, 20, 20 + bob, metal)
        mace(c, h[0], h[1], False, rgb("#e0d090"))
    c.disc(16, 6 + bob, 0, rgb("#fff0a0"))


def paladin_ret(c, bob, attack):
    metal = rgb("#a0884a")
    cape(c, rgb("#8a1c1c"), bob)
    legs(c, rgb("#6a5a3a"), rgb("#3a2a1a"), bob)
    arm(c, 9, 19 + bob, shade(metal, 0.8))
    torso(c, metal, rgb("#3a2a1a"), bob, wide=True)
    pauldron(c, rgb("#c8a85a"), bob)
    c.px(9, 16 + bob, rgb("#c8a85a"))
    c.px(22, 16 + bob, rgb("#c8a85a"))
    head(c, bob)
    helm_full(c, metal, rgb("#e0c060"), bob)
    if attack:
        h = arm(c, 18, 20 + bob, metal, down=False)
        mace(c, h[0], h[1], True, rgb("#d8c070"))
        glow(c, h[0] + 7, h[1] - 7, rgb("#fff0a0"), 2)
    else:
        h = arm(c, 19, 20 + bob, metal)
        greatsword(c, h[0], h[1], False)


def warlock(c, bob, attack):
    col = rgb("#3a1a22")
    robe(c, col, rgb("#4ac040"), bob)
    arm(c, 9, 19 + bob, shade(col, 0.8))
    hood(c, col, bob, eyes=rgb("#7aff5a"))
    c.px(13, 6 + bob, rgb("#d8d0b8"))  # рожки на капюшоне
    c.px(12, 5 + bob, rgb("#d8d0b8"))
    c.px(20, 6 + bob, rgb("#d8d0b8"))
    c.px(21, 5 + bob, rgb("#d8d0b8"))
    if attack:
        h = arm(c, 18, 21 + bob, col, down=False)
        glow(c, h[0] + 2, h[1], rgb("#5aff3a"), 4)
    else:
        h = arm(c, 20, 20 + bob, col)
        staff(c, h[0], h[1], rgb("#d8d0b8"), wood=rgb("#2a1a14"))
        c.px(h[0] + 2, h[1] - 18, rgb("#5aff3a"))


def shaman(c, bob, attack):
    col = rgb("#3a5a4a")
    legs(c, rgb("#4a3a2a"), rgb("#2a1e14"), bob)
    arm(c, 9, 19 + bob, rgb("#6a5038"))
    torso(c, col, rgb("#6a4a2a"), bob)
    c.rect(9, 17 + bob, 22, 20 + bob, rgb("#8a7a60"))  # меховой воротник
    head(c, bob)
    c.rect(12, 7 + bob, 20, 11 + bob, rgb("#7a6a50"))  # шкура на голове
    c.px(11, 6 + bob, rgb("#d8d0b8"))
    c.px(10, 5 + bob, rgb("#d8d0b8"))
    c.px(21, 6 + bob, rgb("#d8d0b8"))
    c.px(22, 5 + bob, rgb("#d8d0b8"))
    c.px(12, 13 + bob, rgb("#3aa0d0"))  # перо
    c.px(12, 14 + bob, rgb("#3aa0d0"))
    if attack:
        h = arm(c, 18, 21 + bob, rgb("#6a5038"), down=False)
        glow(c, h[0] + 2, h[1], rgb("#6ad0ff"), 4)
        c.line([(h[0] + 3, h[1] - 5), (h[0] + 5, h[1] - 2), (h[0] + 4, h[1])], rgb("#e0f4ff"), 1)
    else:
        h = arm(c, 20, 20 + bob, rgb("#6a5038"))
        staff(c, h[0], h[1], rgb("#3aa0d0"), wood=rgb("#6a4a2a"))


def hunter(c, bob, attack):
    col = rgb("#3e4a2a")
    cape(c, rgb("#2a3420"), bob)
    legs(c, rgb("#4a3a26"), rgb("#2a1e14"), bob)
    c.rect(7, 18 + bob, 9, 30 + bob, rgb("#5a3a22"))  # колчан
    c.px(7, 16 + bob, rgb("#c8ccd4"))
    c.px(9, 15 + bob, rgb("#c8ccd4"))
    arm(c, 9, 19 + bob, shade(col, 0.8))
    torso(c, col, rgb("#5a3a22"), bob)
    head(c, bob)
    c.poly([(12, 16 + bob), (13, 8 + bob), (17, 6 + bob), (20, 9 + bob), (16, 10 + bob), (14, 16 + bob)], col)
    c.rect(15, 14 + bob, 20, 16 + bob, rgb("#5a3a22"), False)  # шарф на лицо
    if attack:
        h = arm(c, 18, 21 + bob, col, down=False)
        bow(c, h[0], h[1], True)
    else:
        h = arm(c, 20, 20 + bob, col)
        bow(c, h[0] + 1, h[1] - 3, False)


def wolf(bob, attack):
    c = C(32, 24)
    fur = rgb("#5a5048")
    dark = shade(fur, 0.7)
    off = 3 if attack else 0
    c.rect(5, 9 + bob, 22, 16 + bob, fur)  # тело
    c.rect(5, 14 + bob, 22, 16 + bob, dark, False)
    c.line([(5, 10 + bob), (1, 7 + bob)], fur, 2)  # хвост
    for x in (6, 10, 17, 21):
        c.rect(x, 16 + bob, x + 1, 21, dark if x in (10, 21) else fur, False)
    c.rect(20 + off, 6 + bob, 27 + off, 12 + bob, fur)  # голова
    c.rect(27 + off, 9 + bob, 30 + off, 12 + bob, fur)  # морда
    c.px(21 + off, 4 + bob, fur)
    c.px(21 + off, 5 + bob, fur)
    c.px(24 + off, 8 + bob, rgb("#e0b030"))
    if attack:
        c.rect(27 + off, 12 + bob, 30 + off, 13 + bob, rgb("#7a1a1a"), False)
        c.px(29 + off, 12 + bob, rgb("#ffffff"))
    return c.outline()


HEROES = [
    ("warrior_tank", "Воин: танк", warrior_tank),
    ("warrior_2h", "Воин: двуручник", warrior_2h),
    ("mage_elem", "Маг: стихии", mage_elem),
    ("mage_arcane", "Маг: аркан", mage_arcane),
    ("priest_light", "Жрец: свет", priest_light),
    ("priest_shadow", "Жрец: тьма", priest_shadow),
    ("paladin_holy", "Паладин: свет", paladin_holy),
    ("paladin_ret", "Паладин: воздаяние", paladin_ret),
    ("warlock", "Чернокнижник", warlock),
    ("shaman", "Шаман", shaman),
    ("hunter", "Охотник", hunter),
]


def frames(fn):
    out = []
    for bob, attack in ((0, False), (1, False), (0, True)):
        c = C()
        fn(c, bob, attack)
        out.append(c.outline())
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    all_frames = []
    for hid, name, fn in HEROES:
        fr = frames(fn)
        sheet = Image.new("RGBA", (W * 3, H), (0, 0, 0, 0))
        for i, f in enumerate(fr):
            sheet.paste(f, (i * W, 0))
        sheet.save(os.path.join(OUT, hid + ".png"))
        all_frames.append((name, fr))
    wf = [wolf(0, False), wolf(1, False), wolf(0, True)]
    ws = Image.new("RGBA", (32 * 3, 24), (0, 0, 0, 0))
    for i, f in enumerate(wf):
        ws.paste(f, (i * 32, 0))
    ws.save(os.path.join(OUT, "hunter_pet_wolf.png"))
    preview(all_frames, wf)


def preview(all_frames, wf):
    S = 4
    cols = 4
    cw, ch = W * S * 2 + 24, H * S + 40
    rows = (len(all_frames) + 1 + cols - 1) // cols
    img = Image.new("RGBA", (cols * cw + 16, rows * ch + 16), rgb("#141010"))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for y in range(0, img.height, 24):  # кладка
        for x in range(-(y // 24 % 2) * 24, img.width, 48):
            d.rectangle((x + 1, y + 1, x + 46, y + 22), fill=rgb("#1e1814"))
    items = list(all_frames) + [("Пет охотника: волк", None)]
    for i, (name, fr) in enumerate(items):
        ox = 8 + (i % cols) * cw
        oy = 8 + (i // cols) * ch
        d.rectangle((ox, oy, ox + cw - 8, oy + ch - 8), outline=rgb("#6a5230"), width=2)
        d.text((ox + 10, oy + 6), name, fill=rgb("#d8b25a"), font=font)
        if fr:
            img.alpha_composite(fr[0].resize((W * S, H * S), Image.NEAREST), (ox + 4, oy + 28))
            img.alpha_composite(fr[2].resize((W * S, H * S), Image.NEAREST), (ox + 4 + W * S + 8, oy + 28))
        else:
            img.alpha_composite(wf[0].resize((32 * S, 24 * S), Image.NEAREST), (ox + 4, oy + 28 + 80))
            img.alpha_composite(wf[2].resize((32 * S, 24 * S), Image.NEAREST), (ox + 4 + 32 * S + 8, oy + 28 + 80))
    img.save(os.path.join(OUT, "_preview.png"))


if __name__ == "__main__":
    main()
