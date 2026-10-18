"""Собственный пиксельный костяной страж; два кадра стойки. Только Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw


def frame(bob):
    im = Image.new('RGBA', (48, 64))
    d = ImageDraw.Draw(im)
    dark, bone, light = '#211e23', '#a89b81', '#d3c7a9'
    # Плащ, ноги и кованые сапоги.
    d.polygon([(14, 19+bob), (34, 20+bob), (40, 57), (9, 58)], fill='#493239', outline=dark)
    d.rectangle((18, 41, 22, 57), fill=bone)
    d.rectangle((28, 41, 32, 57), fill='#807462')
    d.rectangle((15, 55, 23, 60), fill='#45424a', outline=dark)
    d.rectangle((28, 55, 36, 60), fill='#45424a', outline=dark)
    # Рёбра и наплечники.
    d.polygon([(15, 24+bob), (34, 24+bob), (31, 44), (19, 44)], fill='#30292e', outline=dark)
    d.rectangle((23, 25+bob, 26, 43), fill=bone)
    for y in [28, 33, 38]:
        d.line([(18, y+bob), (24, y+2+bob), (31, y+bob)], fill=bone, width=2)
    d.polygon([(11, 22+bob), (18, 20+bob), (22, 27+bob), (11, 29+bob)], fill='#67616a', outline=dark)
    d.polygon([(30, 21+bob), (37, 24+bob), (38, 30+bob), (29, 27+bob)], fill='#514b55', outline=dark)
    d.line([(12, 29+bob), (10, 39+bob), (8, 43+bob)], fill=bone, width=4)
    d.line([(35, 29+bob), (38, 36+bob), (42, 38+bob)], fill=bone, width=4)
    # Череп, глаза и корона.
    d.polygon([(18, 8+bob), (29, 7+bob), (34, 12+bob), (31, 21+bob), (26, 25+bob), (18, 21+bob), (15, 14+bob)], fill=bone, outline=dark)
    d.rectangle((18, 10+bob, 28, 13+bob), fill=light)
    d.rectangle((17, 15+bob, 21, 18+bob), fill='#8a342e')
    d.rectangle((27, 14+bob, 31, 17+bob), fill='#8a342e')
    d.point((18, 16+bob), fill='#ffb16b')
    d.point((28, 15+bob), fill='#ffb16b')
    d.line([(21, 22+bob), (21, 24+bob), (28, 24+bob), (29, 21+bob)], fill=light)
    d.polygon([(17, 10+bob), (15, 2+bob), (22, 7+bob), (25, 1+bob), (28, 7+bob), (35, 3+bob), (31, 11+bob)], fill='#887044', outline=dark)
    # Оружие смотрит в сторону героев.
    d.line([(7, 29+bob), (9, 53+bob)], fill='#5e4233', width=3)
    d.polygon([(6, 30+bob), (3, 12+bob), (7, 9+bob), (10, 29+bob)], fill='#a3a3a7', outline=dark)
    d.line([(2, 30+bob), (12, 29+bob)], fill='#ac8d51', width=2)
    return im


if __name__ == '__main__':
    sheet = Image.new('RGBA', (96, 64))
    for i in range(2):
        sheet.alpha_composite(frame(i), (i*48, 0))
    sheet.save(Path(__file__).resolve().parents[1]/'assets/sprites/enemy_guard.png')
