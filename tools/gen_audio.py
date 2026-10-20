#!/usr/bin/env python3
"""Generates the placeholder audio set (sound effects, ambience loops, music).

Everything is synthesised with numpy so the repository needs no licensed audio
to run. Real recordings or Suno tracks can replace any file one-to-one: keep
the same file name in assets/audio/sfx or assets/audio/music (see
assets/audio/README.md).

usage: python3 tools/gen_audio.py   (needs numpy and ffmpeg)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RNG = np.random.default_rng(1234)


# ----------------------------------------------------------------- helpers

def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def fft_filter(x, lo=None, hi=None, slope=0.0, order=2):
    """Zero-phase spectral filter. Circular, so loops stay seamless."""
    n = len(x)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    if hi:
        g *= 1.0 / (1.0 + (f / hi) ** (2 * order))
    if slope:
        g *= (np.maximum(f, 20.0) / 1000.0) ** slope
    return np.fft.irfft(spec * g, n)


def noise(seconds, **kw):
    x = RNG.standard_normal(int(seconds * SR))
    return fft_filter(x, **kw) if kw else x


def norm(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay_tau)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def write_ogg(name, x, subdir, quality=4):
    x = np.atleast_2d(x)
    if x.shape[0] > x.shape[1]:
        x = x.T
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    out_dir = os.path.join(ROOT, subdir)
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav_path = os.path.join(td, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(pcm.shape[0])
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.T.tobytes())
        ogg = os.path.join(out_dir, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", str(quality), ogg], check=True)
    print("wrote", os.path.relpath(ogg))


# ------------------------------------------------------------ instruments

def pluck(freq, dur, vel=1.0, bright=1.0):
    t = t_axis(dur)
    y = np.zeros_like(t)
    for h in range(1, 8):
        a = (1.0 / h ** 1.15) * (0.55 + 0.45 * np.cos(h * 1.3))
        y += a * np.sin(2 * np.pi * freq * h * t + h) * np.exp(-t * (3.0 + 2.2 * h / bright))
    y *= np.minimum(t / 0.004, 1.0)
    return y * vel


def bell(freq, dur, vel=1.0):
    t = t_axis(dur)
    y = np.zeros_like(t)
    for ratio, a, d in [(1, 1.0, 1.4), (2.76, 0.5, 2.2), (5.4, 0.28, 3.4), (8.93, 0.14, 5.0), (0.5, 0.35, 1.0)]:
        y += a * np.sin(2 * np.pi * freq * ratio * t + ratio) * np.exp(-t * d)
    y *= np.minimum(t / 0.002, 1.0)
    return y * vel


def pad(freqs, dur, vel=1.0, attack=1.2, release=1.5):
    t = t_axis(dur)
    y = np.zeros_like(t)
    for f in freqs:
        for det, ph in [(-0.0035, 0.0), (0.0035, 1.7)]:
            ff = f * (1 + det)
            for h, a in [(1, 1.0), (2, 0.4), (3, 0.22), (4, 0.1)]:
                y += a * np.sin(2 * np.pi * ff * h * t + ph * h)
    env = np.minimum(t / attack, 1.0) * np.minimum((dur - t) / release, 1.0)
    return y * env * vel / (len(freqs) * 1.8)


def drum(dur=0.6, f0=95.0, vel=1.0):
    t = t_axis(dur)
    f = f0 * (1 + 1.6 * np.exp(-t * 28))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) * np.exp(-t * 9.0) + 0.2 * RNG.standard_normal(len(t)) * np.exp(-t * 60)) * vel


def tick(dur=0.12, vel=1.0):
    t = t_axis(dur)
    return (np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 90) + 0.4 * RNG.standard_normal(len(t)) * np.exp(-t * 120)) * vel


def add(buf, sig, at, pan=0.0):
    i = int(at * SR)
    n = min(len(sig), buf.shape[1] - i)
    if n <= 0:
        return
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    buf[0, i:i + n] += sig[:n] * l
    buf[1, i:i + n] += sig[:n] * r


def reverb(buf, seconds=2.4, wet=0.3, damp=3500):
    n = buf.shape[1]
    out = np.zeros_like(buf)
    for c in range(2):
        ir = RNG.standard_normal(int(seconds * SR)) * np.exp(-np.arange(int(seconds * SR)) / SR * (6.9 / seconds))
        ir = fft_filter(ir, hi=damp, order=1)
        ir /= np.sqrt(np.sum(ir ** 2))
        irp = np.zeros(n)
        irp[: len(ir)] = ir
        out[c] = np.fft.irfft(np.fft.rfft(buf[c]) * np.fft.rfft(irp), n)  # circular: tails wrap, loop stays seamless
    return buf * (1 - wet) + out * wet * 2.2


# ----------------------------------------------------------------- sfx

def sfx():
    # click: wooden tick
    write_ogg("click", norm(tick(0.09) * 0.9) * 0.8, "sfx")

    # discovery chime: rising three-note bell
    n = int(2.2 * SR)
    y = np.zeros(n)
    for i, (m, at) in enumerate([(81, 0.0), (88, 0.11), (93, 0.24)]):
        b = bell(midi(m), 2.0, 0.8 / (1 + i * 0.2))
        y[int(at * SR): int(at * SR) + len(b)] += b[: n - int(at * SR)]
    write_ogg("discover", norm(y), "sfx")

    # coin: two bright pings
    n = int(0.9 * SR)
    y = np.zeros(n)
    for at, f in [(0.0, 1568.0), (0.075, 2093.0)]:
        t = t_axis(0.8)
        p = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t)) * np.exp(-t * 7.5)
        p[:300] += RNG.standard_normal(300) * 0.4 * np.exp(-np.arange(300) / 60.0)
        i = int(at * SR)
        y[i: i + len(p)] += p[: n - i]
    write_ogg("coin", norm(y, 0.8), "sfx")

    # arrival: ship's bell
    write_ogg("arrive", norm(bell(262.0, 2.6, 1.0) + 0.5 * bell(392.0, 2.6, 0.6)) * 0.9, "sfx")

    # horn: low brass-like blast
    t = t_axis(2.0)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    saw = sum(np.sin(2 * np.pi * 110.0 * h * vib * t) / h for h in range(1, 14))
    y = fft_filter(saw, hi=900, order=2) * np.minimum(t / 0.18, 1) * np.minimum((2.0 - t) / 0.5, 1)
    write_ogg("horn", norm(y), "sfx")

    # scrape: hull on rock, grinding wood
    t = t_axis(0.8)
    base = noise(0.8, lo=140, hi=1600)
    grit = noise(0.8, lo=900, hi=5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t + 6 * RNG.standard_normal(len(t)).cumsum() / SR * 40))
    rough = np.clip(noise(0.8, hi=40) * 6, 0, 1.5)
    y = (base * 0.8 + grit * 0.5) * rough * np.minimum(t / 0.02, 1) * np.exp(-t * 3.0)
    y += drum(0.8, 70.0, 0.9)[: len(y)] * 0.7
    write_ogg("scrape", norm(y), "sfx")

    # splash
    t = t_axis(0.9)
    y = noise(0.9, lo=300, hi=7000) * np.exp(-t * 6.5) * np.minimum(t / 0.01, 1)
    y += 0.5 * noise(0.9, lo=60, hi=500) * np.exp(-t * 9)
    write_ogg("splash", norm(y), "sfx")

    # creak: slow stick-slip wooden groan
    t = t_axis(1.1)
    f = 170 + 70 * np.sin(2 * np.pi * 1.7 * t) + 40 * fft_filter(RNG.standard_normal(len(t)), hi=12) * 12
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = sum(np.sin(ph * h + h) / h for h in range(1, 9))
    am = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 14 * t + 2 * np.sin(2 * np.pi * 2.3 * t)))
    y = fft_filter(y * am, lo=120, hi=2400) * np.sin(np.pi * t / 1.1) ** 1.5
    write_ogg("creak", norm(y, 0.7), "sfx")

    # thunder: crack, then a long rolling rumble
    n = 5.5
    t = t_axis(n)
    crack = noise(n, lo=200, hi=6000) * np.exp(-t * 22) * 1.2
    roll = noise(n, lo=25, hi=190, order=2) * np.exp(-t * 0.75) * (1 + 0.6 * np.sin(2 * np.pi * 2.1 * t + 3 * np.sin(2 * np.pi * 0.37 * t)))
    roll *= np.minimum(t / 0.25, 1)
    write_ogg("thunder", norm(crack + roll * 2.4), "sfx")


# ------------------------------------------------------------ ambience

def periodic_lfo(seconds, freqs_weights, seed_phase=0.0):
    t = t_axis(seconds)
    y = np.zeros_like(t)
    for k, (cycles, w) in enumerate(freqs_weights):
        y += w * np.sin(2 * np.pi * cycles * t / seconds + seed_phase + k * 2.1)
    return y


def ambience():
    # Sea: swells of filtered noise, a loop of exactly 14 seconds.
    L = 14.0
    base = noise(L, lo=60, hi=700)
    hiss = noise(L, lo=1500, hi=5500) * 0.35
    swell = 0.55 + 0.45 * (periodic_lfo(L, [(2, 0.6), (3, 0.5), (5, 0.25)]) / 1.2)
    swell2 = 0.5 + 0.5 * (periodic_lfo(L, [(4, 0.7), (7, 0.3)], 1.3) / 1.0)
    y = base * swell + hiss * np.clip(swell2, 0, 1) ** 2
    write_ogg("amb_sea", norm(y, 0.7), "sfx", quality=3)

    # Wind: breathy, wandering band.
    L = 12.0
    t = t_axis(L)
    w1 = noise(L, lo=140, hi=700, order=2)
    w2 = noise(L, lo=500, hi=1800, order=2) * 0.5
    gust = np.clip(0.5 + 0.5 * periodic_lfo(L, [(2, 0.7), (3, 0.45), (6, 0.2)]) / 1.1, 0.1, 1)
    y = (w1 + w2 * gust) * gust
    write_ogg("amb_wind", norm(y, 0.7), "sfx", quality=3)

    # Rain: dense hiss plus drops on the deck.
    L = 8.0
    y = noise(L, lo=1800, hi=9000) * 0.6 + noise(L, lo=400, hi=1800) * 0.25
    drops = np.zeros(int(L * SR))
    for _ in range(int(L * 38)):
        i = RNG.integers(0, len(drops) - 600)
        d = np.sin(2 * np.pi * RNG.uniform(1800, 4200) * np.arange(500) / SR) * np.exp(-np.arange(500) / 70.0)
        drops[i: i + 500] += d * RNG.uniform(0.1, 0.5)
    write_ogg("amb_rain", norm(y + drops * 0.8, 0.7), "sfx", quality=3)

    # Night: crickets and a low drone.
    L = 12.0
    t = t_axis(L)
    y = np.zeros_like(t)
    for c in range(4):
        f = 4200 + c * 230
        phase = RNG.uniform(0, 1.0)
        # chirp groups at 1.5 Hz, 5 pulses each at ~32 Hz
        group = (np.sin(2 * np.pi * (1.5 * t + phase) * 1.0) > 0.35).astype(float)
        pulses = (np.sin(2 * np.pi * 32 * t + c) > 0.2).astype(float)
        y += np.sin(2 * np.pi * f * t) * group * pulses * 0.12
    drone = np.sin(2 * np.pi * 55 * t) * 0.18 + np.sin(2 * np.pi * 82.5 * t + 1) * 0.1
    y += drone * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * t / L))
    y += noise(L, lo=80, hi=500) * 0.08
    write_ogg("amb_night", norm(y, 0.6), "sfx", quality=3)


# --------------------------------------------------------------- music

def track(name, bars, bpm, beats_per_bar, chords, arp, melody, perc, wet=0.32, level=0.85, pad_oct=0):
    """Renders a looping track. Each section's callback adds events to `buf`."""
    spb = 60.0 / bpm
    total = bars * beats_per_bar * spb
    buf = np.zeros((2, int(total * SR)))
    for b in range(bars):
        chord = chords[b % len(chords)]
        t0 = b * beats_per_bar * spb
        add(buf, pad([midi(m + 12 * pad_oct) for m in chord], beats_per_bar * spb * 1.05, 0.9, attack=0.9, release=1.4), t0 - 0.0, -0.2)
        add(buf, pad([midi(chord[0] - 12)], beats_per_bar * spb * 1.05, 0.55, attack=0.5, release=1.2), t0, 0.2)
        arp(buf, b, t0, spb, chord)
        melody(buf, b, t0, spb, chord)
        perc(buf, b, t0, spb)
    buf = reverb(buf, wet=wet)
    buf = buf / np.max(np.abs(buf)) * level
    write_ogg(name, buf, "music", quality=4)


def music():
    # Scale helpers (D dorian / pentatonic bases).
    d_pent = [62, 64, 66, 69, 71, 74, 76, 78, 81]
    rng = np.random.default_rng(7)

    # --- calm: 6/8 sea shanty feel ----------------------------------------
    chords = [[50, 57, 62, 66], [48, 55, 60, 64], [43, 55, 59, 62], [50, 57, 62, 66]] * 2
    chords[7] = [45, 57, 61, 64]

    def arp(buf, b, t0, spb, chord):
        pat = [0, 2, 1, 3, 2, 1]
        for i in range(6):
            n = chord[pat[i] % len(chord)] + 12
            add(buf, pluck(midi(n), 1.4, 0.45), t0 + i * spb / 3.0, -0.35 + 0.14 * i)

    mel = [[74, 0, 76, 78, 0, 76], [74, 0, 71, 74, 0, 0], [71, 0, 74, 76, 0, 74], [78, 0, 76, 74, 0, 0],
           [74, 0, 76, 78, 0, 81], [79, 0, 78, 76, 0, 74], [71, 0, 74, 76, 78, 76], [74, 0, 0, 0, 0, 0]]

    def melody(buf, b, t0, spb, chord):
        for i, n in enumerate(mel[b % len(mel)]):
            if n:
                add(buf, pluck(midi(n), 1.2, 0.7, 1.4), t0 + i * spb / 3.0, 0.25)

    def perc(buf, b, t0, spb):
        add(buf, drum(0.6, 90, 0.7), t0, 0.0)
        add(buf, drum(0.5, 110, 0.4), t0 + spb, 0.0)
        for i in range(6):
            add(buf, tick(0.1, 0.12 if i % 3 else 0.22), t0 + i * spb / 3.0, 0.5)

    track("calm", 16, 78, 2, chords, arp, melody, perc, wet=0.3, level=0.8)

    # --- title: slower, grander ------------------------------------------
    chords_t = [[50, 57, 62, 65], [46, 53, 58, 62], [48, 55, 60, 64], [45, 52, 57, 61]] * 2

    def arp_t(buf, b, t0, spb, chord):
        for i in range(8):
            n = chord[[0, 2, 1, 3, 2, 3, 1, 2][i]] + 12
            add(buf, pluck(midi(n), 1.8, 0.4), t0 + i * spb / 2.0, -0.4 + 0.1 * i)

    mel_t = [[74, 0, 0, 77, 0, 0, 76, 0], [74, 0, 0, 72, 0, 0, 70, 0], [72, 0, 0, 76, 0, 0, 79, 0], [77, 0, 76, 0, 74, 0, 0, 0]] * 2

    def melody_t(buf, b, t0, spb, chord):
        for i, n in enumerate(mel_t[b % len(mel_t)]):
            if n:
                add(buf, bell(midi(n + 12), 2.6, 0.22), t0 + i * spb / 2.0, 0.3)

    def perc_t(buf, b, t0, spb):
        add(buf, drum(0.9, 70, 0.7), t0, 0.0)
        if b % 2:
            add(buf, drum(0.9, 80, 0.4), t0 + 2 * spb, 0.0)

    track("title", 16, 66, 4, chords_t, arp_t, melody_t, perc_t, wet=0.4, level=0.85)

    # --- fog: sparse, cold --------------------------------------------------
    chords_f = [[50, 56, 62, 68], [47, 53, 59, 65], [48, 54, 60, 66], [45, 51, 57, 63]]

    def arp_f(buf, b, t0, spb, chord):
        if b % 2 == 0:
            for i in range(3):
                add(buf, bell(midi(chord[i + 1] + 24), 3.5, 0.18), t0 + i * spb * 1.3 + 0.3, -0.5 + i * 0.5)

    def melody_f(buf, b, t0, spb, chord):
        if b % 4 == 1:
            add(buf, bell(midi(chord[2] + 12), 4.0, 0.3), t0 + spb, 0.0)

    def perc_f(buf, b, t0, spb):
        if b % 4 == 0:
            add(buf, drum(1.2, 50, 0.5), t0, 0.0)

    track("fog", 8, 48, 4, chords_f, arp_f, melody_f, perc_f, wet=0.5, level=0.7)

    # --- rain: soft piano-ish pulses ---------------------------------------
    chords_r = [[50, 57, 62, 65], [46, 53, 58, 62], [43, 50, 55, 58], [45, 52, 57, 60]] * 2

    def arp_r(buf, b, t0, spb, chord):
        for i in range(8):
            add(buf, pluck(midi(chord[[0, 1, 2, 3, 2, 1, 2, 3][i]] + 12), 1.6, 0.34, 0.9), t0 + i * spb / 2.0, -0.3 + 0.08 * i)

    mel_r = [[0, 0, 0, 0, 77, 0, 76, 0], [0, 0, 74, 0, 0, 0, 70, 0], [0, 0, 0, 0, 74, 0, 72, 0], [0, 0, 69, 0, 0, 0, 0, 0]] * 2

    def melody_r(buf, b, t0, spb, chord):
        for i, n in enumerate(mel_r[b % len(mel_r)]):
            if n:
                add(buf, pluck(midi(n + 12), 1.8, 0.5, 1.0), t0 + i * spb / 2.0, 0.3)

    def perc_r(buf, b, t0, spb):
        add(buf, drum(0.7, 75, 0.45), t0, 0.0)

    track("rain", 16, 70, 4, chords_r, arp_r, melody_r, perc_r, wet=0.4, level=0.75)

    # --- storm: tension and timpani ---------------------------------------
    chords_s = [[38, 45, 50, 53], [38, 45, 50, 54], [36, 43, 48, 51], [37, 44, 49, 52]] * 2

    def arp_s(buf, b, t0, spb, chord):
        for i in range(8):
            if i % 2 == 0 or rng.random() < 0.3:
                add(buf, pluck(midi(chord[i % 4] + 24), 0.8, 0.3, 1.2), t0 + i * spb / 2.0, rng.uniform(-0.6, 0.6))

    def melody_s(buf, b, t0, spb, chord):
        if b % 2 == 0:
            add(buf, pad([midi(chord[3] + 24), midi(chord[3] + 25)], 3 * spb, 0.35, attack=1.4, release=1.0), t0, 0.0)

    def perc_s(buf, b, t0, spb):
        for i in range(4):
            add(buf, drum(0.9, 62 + 4 * (i % 2), 0.9 if i == 0 else 0.55), t0 + i * spb, 0.0)
        add(buf, drum(0.5, 80, 0.35), t0 + 3.5 * spb, 0.0)

    track("storm", 16, 104, 4, chords_s, arp_s, melody_s, perc_s, wet=0.35, level=0.85)

    # --- night: music-box lullaby ------------------------------------------
    chords_n = [[43, 50, 55, 59], [40, 47, 52, 55], [48, 55, 60, 64], [50, 57, 62, 66]] * 2

    def arp_n(buf, b, t0, spb, chord):
        for i in range(4):
            add(buf, bell(midi(chord[[0, 2, 1, 3][i]] + 24), 2.2, 0.14), t0 + i * spb, -0.3 + 0.2 * i)

    mel_n = [[79, 76, 74, 76], [76, 74, 71, 0], [76, 79, 81, 79], [78, 74, 0, 0]] * 2

    def melody_n(buf, b, t0, spb, chord):
        for i, n in enumerate(mel_n[b % len(mel_n)]):
            if n:
                add(buf, bell(midi(n + 12), 2.8, 0.22), t0 + i * spb, 0.2)

    def perc_n(buf, b, t0, spb):
        pass

    track("night", 16, 60, 4, chords_n, arp_n, melody_n, perc_n, wet=0.5, level=0.7)


if __name__ == "__main__":
    sfx()
    ambience()
    music()
