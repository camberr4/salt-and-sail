#!/usr/bin/env python3
"""Prepares painted art for the game: normalises names, crops transparent
sprites to their content, resizes to practical sizes and makes terrain and
water textures tile seamlessly. Safe to re-run (idempotent on its own output).

usage: python3 tools/prep_art.py
Originals stay available in git history.
"""
import os
import numpy as np
from PIL import Image

ROOT = "assets/art"


def path(*p):
    return os.path.join(ROOT, *p)


def fit(im, longest):
    w, h = im.size
    k = longest / max(w, h)
    if k >= 1.0:
        return im
    return im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)


def crop_alpha(im, pad=4, thr=8):
    a = np.array(im.getchannel("A"))
    ys, xs = np.where(a > thr)
    if len(xs) == 0:
        return im
    x0, x1, y0, y1 = max(xs.min() - pad, 0), min(xs.max() + pad, im.width - 1), max(ys.min() - pad, 0), min(ys.max() + pad, im.height - 1)
    return im.crop((x0, y0, x1 + 1, y1 + 1))


def seamless(im, normal=False):
    a = np.array(im.convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    b = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    wx = 0.5 - 0.5 * np.cos(2 * np.pi * (np.arange(w) + 0.5) / w)
    wy = 0.5 - 0.5 * np.cos(2 * np.pi * (np.arange(h) + 0.5) / h)
    m = (wy[:, None] * wx[None, :])[:, :, None]
    m = np.clip(m * 1.0, 0, 1)
    # a is correct at the centre (m=1), b is correct at the borders (m=0)
    out = a * m + b * (1.0 - m)
    if normal:
        v = out / 255.0 * 2.0 - 1.0
        v[:, :, 2] = np.maximum(v[:, :, 2], 0.2)
        v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-6
        out = (v * 0.5 + 0.5) * 255.0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def save(im, *p):
    out = path(*p)
    im.save(out, optimize=True)
    return out


def main():
    # names
    bad = path("ship", "saIL_FORE.png")
    if os.path.exists(bad):
        os.rename(bad, path("ship", "sail_fore.png"))

    for f in sorted(os.listdir(path("terrain"))):
        if f.endswith(".png"):
            im = Image.open(path("terrain", f)).convert("RGB")
            im = im.resize((1024, 1024), Image.LANCZOS) if im.width > 1024 else im
            save(seamless(im), "terrain", f)
    for f in sorted(os.listdir(path("water"))):
        if f.endswith(".png"):
            im = Image.open(path("water", f)).convert("RGB")
            im = im.resize((1024, 1024), Image.LANCZOS) if im.width > 1024 else im
            save(seamless(im, normal=(f == "wave_normal.png")), "water", f)

    sizes = {"props": 640, "poi": 896}
    for d, longest in sizes.items():
        for f in sorted(os.listdir(path(d))):
            if f.endswith(".png"):
                im = Image.open(path(d, f)).convert("RGBA")
                save(fit(crop_alpha(im), longest), d, f)

    # ship: tight crops; the jib arrives lying on its side, stand it up so its
    # tip points to the bow (top of the image).
    for f in sorted(os.listdir(path("ship"))):
        if not f.endswith(".png"):
            continue
        im = Image.open(path("ship", f)).convert("RGBA")
        if f == "sail_jib.png" and im.width > im.height:
            im = im.rotate(-90, expand=True)
        im = crop_alpha(im)
        longest = {"hull.png": 1280, "hull_dark.png": 1280, "sail_main.png": 1024, "sail_fore.png": 1024, "sail_jib.png": 768}.get(f, 512)
        save(fit(im, longest), "ship", f)

    # ui
    ui_sizes = {"button_primary.png": 1100, "button_wood.png": 1100, "chip_glass.png": 1050, "panel_parchment.png": 1024, "compass_rose.png": 768, "icon_set.png": 1774}
    for f, s in ui_sizes.items():
        p = path("ui", f)
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            if f in ("button_primary.png", "button_wood.png", "chip_glass.png"):
                im = crop_alpha(im, pad=2)
            save(fit(im, s), "ui", f)

    # events: 1080 wide is plenty
    for f in sorted(os.listdir(path("events"))):
        if f.endswith(".png"):
            im = Image.open(path("events", f)).convert("RGB")
            if im.width > 1080:
                im = im.resize((1080, round(im.height * 1080 / im.width)), Image.LANCZOS)
            save(im, "events", f)
    print("done")


if __name__ == "__main__":
    main()
