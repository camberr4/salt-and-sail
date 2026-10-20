#!/usr/bin/env python3
"""Draws the launcher icon set (legacy, adaptive foreground/background, monochrome)."""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sea_background(size):
    n = size * S
    img = Image.new("RGB", (n, n))
    px = img.load()
    top, bot = (22, 112, 150), (6, 40, 82)
    for y in range(n):
        c = lerp(top, bot, y / n)
        for x in range(n):
            px[x, y] = c
    d = ImageDraw.Draw(img, "RGBA")
    # soft wave bands
    for i in range(7):
        y0 = n * (0.12 + i * 0.14)
        pts = []
        for x in range(0, n + 1, 8):
            pts.append((x, y0 + math.sin(x / n * 6.0 + i * 1.3) * n * 0.025))
        d.line(pts, fill=(255, 255, 255, 26 + i * 4), width=int(n * 0.012))
    # vignette
    mask = Image.new("L", (n, n), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([-n * 0.15, -n * 0.15, n * 1.15, n * 1.15], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(n * 0.12))
    dark = Image.new("RGB", (n, n), (3, 18, 40))
    img = Image.composite(img, dark, mask)
    return img.resize((size, size), Image.LANCZOS)


def ship_layer(size, mono=False):
    """Ship seen at a three-quarter angle, centred inside the adaptive safe zone."""
    n = size * S
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = n * 0.5, n * 0.54
    u = n / 100.0

    def P(x, y):
        return (cx + x * u, cy + y * u)

    cream, shade = ((255, 255, 255) if mono else (246, 236, 208)), ((200, 200, 200) if mono else (206, 188, 150))
    wood, dark = ((255, 255, 255) if mono else (122, 74, 36)), ((255, 255, 255) if mono else (58, 33, 18))
    red = (255, 255, 255) if mono else (178, 58, 43)
    gold = (255, 255, 255) if mono else (232, 182, 74)

    # hull
    hull = [P(-27, 10), P(27, 10), P(21, 22), P(-21, 22)]
    d.polygon([P(-30, 8), P(30, 8), P(22, 24), P(-22, 24)], fill=dark)
    d.polygon(hull, fill=wood)
    d.line([P(-27, 13), P(27, 13)], fill=red, width=int(1.6 * u))
    d.line([P(-24, 18), P(24, 18)], fill=dark, width=int(0.8 * u))

    def sail(mx, top, bottom, half, bulge):
        pts = [P(mx - half, top)]
        for i in range(0, 11):
            t = i / 10
            pts.append(P(mx - half + 2 * half * t, top + 2.5 * math.sin(math.pi * t)))
        pts.append(P(mx + half, bottom))
        for i in range(10, -1, -1):
            t = i / 10
            pts.append(P(mx - half + 2 * half * t, bottom + bulge * math.sin(math.pi * t)))
        d.polygon(pts, fill=cream)
        # shading toward the foot
        for k in range(1, 6):
            t = k / 6
            y = top + (bottom - top) * t
            d.line([P(mx - half + 1, y), P(mx + half - 1, y + bulge * 0.3)], fill=shade, width=max(1, int(0.5 * u)))
        d.line([P(mx - half - 1.5, top), P(mx + half + 1.5, top)], fill=dark, width=int(1.3 * u))

    d.line([P(0, -36), P(0, 10)], fill=dark, width=int(2.0 * u))
    d.line([P(-17, -2), P(-17, 10)], fill=dark, width=int(1.4 * u))
    d.line([P(17, 2), P(17, 10)], fill=dark, width=int(1.4 * u))
    sail(0, -32, -6, 15, 5)
    sail(0, -4, 9, 20, 3)
    sail(-18, 0, 8, 9, 2)
    sail(18, 4, 9, 8, 2)

    # flag
    d.polygon([P(0, -36), P(11, -33.5), P(0, -31)], fill=(255, 255, 255) if mono else (24, 22, 30))
    # compass ring
    ring = [cx - 41 * u, cy - 46 * u, cx + 41 * u, cy + 36 * u]
    d.ellipse(ring, outline=gold, width=int(1.1 * u))
    img = img.resize((size, size), Image.LANCZOS)
    return img


def main():
    out = "assets/icons/"
    bg = sea_background(432)
    fg = ship_layer(432)
    bg.save(out + "adaptive_bg.png")
    fg.save(out + "adaptive_fg.png")
    ship_layer(432, mono=True).save(out + "adaptive_mono.png")
    full = sea_background(512).convert("RGBA")
    full.alpha_composite(ship_layer(512).resize((int(512 * 0.9), int(512 * 0.9)), Image.LANCZOS), (int(512 * 0.05), int(512 * 0.05)))
    full.save("icon.png")
    full.resize((192, 192), Image.LANCZOS).save(out + "icon_192.png")
    # Play Store hi-res icon
    full.save("store/play_icon_512.png")
    print("ok")


if __name__ == "__main__":
    main()
