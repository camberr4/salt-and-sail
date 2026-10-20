#!/usr/bin/env python3
"""Generates the tileable noise atlas used by the sea shaders.

Channels (all 0..1, seamlessly tileable, 512x512):
  R  soft fbm            (waves, cloud shadows, coast roughness)
  G  medium fbm          (second octave set, different seed)
  B  worley edge lines   (caustics, net-like patterns)
  A  fine grain          (sparkles, tree canopy, foam breakup)
"""
import numpy as np
from PIL import Image

N = 512


def fft_noise(seed, slope, lo=0.0):
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((N, N))
    f = np.fft.fftfreq(N)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    amp = r ** (-slope)
    amp[0, 0] = 0.0
    if lo:
        amp *= np.exp(-((lo / np.maximum(r, 1e-6)) ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    return out


def norm(a):
    lo, hi = np.percentile(a, [1, 99])
    return np.clip((a - lo) / (hi - lo), 0, 1)


def worley_edges(seed, cells):
    rng = np.random.default_rng(seed)
    pts = (np.stack(np.meshgrid(np.arange(cells), np.arange(cells)), -1) + rng.random((cells, cells, 2))) / cells
    pts = pts.reshape(-1, 2)
    ys, xs = np.mgrid[0:N, 0:N]
    p = np.stack([xs, ys], -1).reshape(-1, 2) / N
    f1 = np.full(len(p), 9.0)
    f2 = np.full(len(p), 9.0)
    for q in pts:
        d = p - q
        d -= np.round(d)
        dist = np.sqrt((d * d).sum(1))
        m = dist < f1
        f2 = np.where(m, f1, np.minimum(f2, dist))
        f1 = np.where(m, dist, f1)
    e = (f2 - f1).reshape(N, N)
    e = norm(e)
    return 1.0 - e  # bright lines on cell borders


def main():
    r = norm(fft_noise(11, 1.6))
    g = norm(fft_noise(23, 1.15))
    b = worley_edges(5, 9)
    a = norm(fft_noise(41, 0.15))
    img = np.stack([r, g, b, a], -1)
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save("assets/textures/noise_atlas.png", optimize=True)
    print("ok")


if __name__ == "__main__":
    main()
