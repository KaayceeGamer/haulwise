# Draws the project avatar (400x400) with plain shapes. No game art is used.
from PIL import Image, ImageDraw, ImageFilter
S = 1600
img = Image.new("RGBA", (S, S))
d = ImageDraw.Draw(img)
# background: radial gradient, deep teal to near-black
for r in range(S, 0, -8):
    t = r / S
    c = (int(12 + 30 * (1 - t)), int(28 + 60 * (1 - t)), int(40 + 70 * (1 - t)), 255)
    d.ellipse([S/2 - r, S/2 - r * 0.95, S/2 + r, S/2 + r * 1.05], fill=c)
# glow behind the chest
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([330, 330, 1270, 1150], fill=(255, 200, 80, 150))
img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(140)))
d = ImageDraw.Draw(img)
GOLD, GOLD_D, GOLD_L = (236, 178, 58), (170, 112, 28), (255, 222, 120)
WOOD, WOOD_D = (110, 62, 34), (70, 38, 22)
# coins spilling out of the top
for x, y, r in [(800, 560, 120), (640, 610, 105), (960, 610, 105), (720, 470, 95), (880, 470, 95), (800, 390, 85)]:
    d.ellipse([x - r, y - r * 0.62, x + r, y + r * 0.62], fill=GOLD_D)
    d.ellipse([x - r, y - r * 0.62 - 22, x + r, y + r * 0.62 - 22], fill=GOLD)
    d.ellipse([x - r * 0.6, y - r * 0.37 - 22, x + r * 0.6, y + r * 0.37 - 22], outline=GOLD_L, width=10)
# chest body
d.rounded_rectangle([380, 700, 1220, 1260], 60, fill=WOOD_D)
d.rounded_rectangle([400, 715, 1200, 1240], 50, fill=WOOD)
for y in (860, 1010, 1160):
    d.line([430, y, 1170, y], fill=WOOD_D, width=12)
# gold bands and rim
d.rounded_rectangle([380, 680, 1220, 770], 30, fill=GOLD)
d.rectangle([380, 740, 1220, 770], fill=GOLD_D)
for x in (470, 1050):
    d.rectangle([x, 700, x + 80, 1260], fill=GOLD_D)
    d.rectangle([x + 10, 700, x + 70, 1250], fill=GOLD)
# lock plate with an upward arrow
d.rounded_rectangle([690, 820, 910, 1080], 40, fill=GOLD_D)
d.rounded_rectangle([705, 832, 895, 1066], 32, fill=GOLD)
d.polygon([(800, 870), (860, 950), (825, 950), (825, 1030), (775, 1030), (775, 950), (740, 950)], fill=WOOD_D)
# rounded-square mask
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], 260, fill=255)
img.putalpha(mask)
img.resize((400, 400), Image.LANCZOS).save("docs/assets/logo-400.png")
img.resize((64, 64), Image.LANCZOS).save("docs/assets/logo-64.png")
