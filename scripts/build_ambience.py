"""Synthesise the app's ambient loops and sound cues (no recordings, nothing to license). Everything here is
presentation: dramatic rather than realistic, in the spirit of a documentary soundtrack (ASSUMPTIONS A-G23).

Loops (seamless, -18 dBFS RMS), godot/assets/ambience/<name>.ogg:
  brook     band-passed noise with slow swell and a low gurgle           chapters 7, W
  rumble    brown noise below ~70 Hz with a slow heave                   molten lava (chapters 3, 5)
  pressure  deep beating drone with occasional creaks                    chapter W: burial at depth
  grind     tectonic grinding: low heave, grinding band, crackle         chapter 6 tilt, chapter W tilt
  weather   wind and root creaks                                        chapter W: the outcrop weathers
  rush      flood roar: broadband turbulence with a low swell            chapter 7 flood, chapter W flood
  shimmer   glassy partials with slow tremolo                            chapter W: the nodule grows
  bubble    viscous bubbling: slow low plops over a simmer               the botryoidal domes grow (chapters 4, W)
One-shots (peak -6 dBFS):
  whoosh_short, whoosh_long   the camera swooping                        tour flights
  vast                        an airy echoing swell                      tour zooms out to landscape scale
  dive                        a quick rising sweep                       tour dives into a small scale
  thud                        a deep impact                              tilt begins, the crust breaks
  settle                      a stone clink over a soft thud             the piece comes to rest
  glint                       a soft bell                                the nodule begins to grow
  .venv/Scripts/python.exe scripts/build_ambience.py
"""
import os
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "assets", "ambience")
SR = 24000


def bp(x, lo, hi, order=4):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def lp(x, f, order=4):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def loopify(x, fade_s=1.0):
    n = int(fade_s * SR)
    w = np.linspace(0.0, 1.0, n)
    head = x[:n] * w + x[-n:] * (1.0 - w)
    return np.concatenate([head, x[n:-n]])


def normalise(x, rms_db=-18.0):
    rms = np.sqrt(np.mean(x ** 2)) or 1.0
    x = x * (10 ** (rms_db / 20.0) / rms)
    return np.clip(x, -0.98, 0.98).astype(np.float32)


def peak(x, db=-6.0):
    m = np.max(np.abs(x)) or 1.0
    return np.clip(x * (10 ** (db / 20.0) / m), -0.98, 0.98).astype(np.float32)


def brown(n, rng):
    b = np.cumsum(rng.standard_normal(n))
    return b - np.linspace(b[0], b[-1], n)


def env(n, attack, decay, hold=0.0, shape=1.0):
    """attack / hold / exponential decay envelope (seconds)."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1) ** shape
    d = np.exp(-np.clip(t - attack - hold, 0, None) / max(decay, 1e-4))
    return a * d


def write_ogg(path, clip):
    with sf.SoundFile(path, "w", samplerate=SR, channels=1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, clip.size, 8192):
            f.write(clip[i:i + 8192])


def reverb(x, taps=((0.031, 0.5), (0.067, 0.4), (0.113, 0.33), (0.191, 0.25), (0.293, 0.18), (0.431, 0.12)), tail=1.0):
    """a cheap echoing space: a few feedback delays summed"""
    n = x.size + int(tail * SR)
    y = np.zeros(n)
    y[:x.size] += x
    for d, g in taps:
        k = int(d * SR)
        acc = np.zeros(n)
        acc[:x.size] = x
        for _ in range(6):
            acc = np.roll(acc, k) * g
            acc[:k] = 0.0
            y += acc
    return y


# ---------------------------------------------------------------- loops
def brook(seconds=12.0, seed=3):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    hiss = bp(rng.standard_normal(n), 600, 5000)
    gurgle = bp(rng.standard_normal(n), 120, 700)
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * 0.23 * t) * np.sin(2 * np.pi * 0.071 * t + 1.0)
    burble = 0.5 + 0.5 * np.clip(np.sin(2 * np.pi * 1.7 * t) * np.sin(2 * np.pi * 0.37 * t + 0.4), 0, 1) ** 2
    return normalise(loopify(hiss * swell + 0.6 * gurgle * burble * swell))


def rumble(seconds=16.0, seed=5):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    low = lp(brown(n, rng), 70)
    heave = 0.7 + 0.3 * np.sin(2 * np.pi * 0.11 * t) * np.sin(2 * np.pi * 0.043 * t + 2.0)
    crackle = bp(rng.standard_normal(n), 200, 1200, 2) * (rng.random(n) < 0.0008) * 3.0
    return normalise(loopify(low * heave + 0.08 * crackle, 2.0))


def pressure(seconds=16.0, seed=11):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    drone = np.sin(2 * np.pi * 38.0 * t) + 0.6 * np.sin(2 * np.pi * 57.2 * t + 0.3) + 0.35 * np.sin(2 * np.pi * 76.5 * t)
    beat = 0.8 + 0.2 * np.sin(2 * np.pi * 0.15 * t)
    sub = lp(brown(n, rng), 50) * 0.5
    creaks = np.zeros(n)
    for s in rng.uniform(0.5, seconds - 1.5, 5):
        i = int(s * SR)
        m = int(0.6 * SR)
        creaks[i:i + m] += bp(rng.standard_normal(m), 250, 900) * env(m, 0.05, 0.18) * 0.6
    x = drone * beat * 0.35 + sub + creaks
    return normalise(loopify(x, 2.0))


def grind(seconds=14.0, seed=13):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    low = lp(brown(n, rng), 110) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.2 * t))
    band = bp(rng.standard_normal(n), 150, 500)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * (7.0 + 2.0 * np.sin(2 * np.pi * 0.17 * t)) * t)
    crackle = bp(rng.standard_normal(n), 700, 3000, 2) * (rng.random(n) < 0.004) * 2.5
    x = low + 0.35 * band * am + 0.12 * crackle
    return normalise(loopify(x, 2.0))


def weather(seconds=16.0, seed=17):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    wind = bp(rng.standard_normal(n), 300, 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.09 * t) ** 2) * 0.25
    x = wind.copy()
    for s in rng.uniform(0.3, seconds - 1.0, 4):    # root creaks
        i = int(s * SR)
        m = int(0.7 * SR)
        x[i:i + m] += bp(rng.standard_normal(m), 180, 600) * env(m, 0.1, 0.25) * 0.4
    return normalise(loopify(x, 1.5))


def rush(seconds=14.0, seed=23):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    roar = lp(brown(n, rng), 200) * 0.9
    body = bp(rng.standard_normal(n), 100, 6000)
    swell = 0.7 + 0.3 * np.sin(2 * np.pi * 0.19 * t) * np.sin(2 * np.pi * 0.053 * t + 0.7)
    return normalise(loopify(roar + 0.8 * body * swell, 2.0))


def bubble(seconds=13.0, seed=71):
    """magma-like bubbling: low, slow plops with a pitch drop, over a faint simmer"""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    simmer = lp(rng.standard_normal(n), 160) * 0.18 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.13 * t) ** 2)
    x = simmer.copy()
    for s_ in rng.uniform(0.1, seconds - 0.6, int(seconds * 2.2)):
        i = int(s_ * SR)
        dur = rng.uniform(0.18, 0.45)
        m = int(dur * SR)
        tt = np.arange(m) / SR
        f0 = rng.uniform(70, 170)
        f = f0 * (1.0 - 0.55 * tt / dur)          # the bubble swells and bursts: pitch sliding down
        ph = 2 * np.pi * np.cumsum(f) / SR
        amp = rng.uniform(0.4, 1.0)
        x[i:i + m] += np.sin(ph) * env(m, 0.04, dur * 0.35, 0.0, 2.0) * amp
        x[i:i + m] += bp(rng.standard_normal(m), 300, 1200, 2) * env(m, 0.002, 0.02) * amp * 0.25   # the burst
    return normalise(loopify(x, 1.5))


def shimmer(seconds=16.0, seed=29):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, a, r in [(1320, 1.0, 0.31), (1760, 0.7, 0.47), (2640, 0.5, 0.63), (3520, 0.35, 0.83), (880, 0.6, 0.23)]:
        trem = 0.5 + 0.5 * np.sin(2 * np.pi * r * t + rng.uniform(0, 6.28))
        x += a * np.sin(2 * np.pi * (f * (1 + 0.0007 * np.sin(2 * np.pi * 0.11 * t))) * t) * trem
    for s in rng.uniform(0.2, seconds - 0.3, 14):   # sparkles
        i = int(s * SR)
        m = int(0.25 * SR)
        tt = np.arange(m) / SR
        x[i:i + m] += np.sin(2 * np.pi * rng.uniform(3000, 6000) * tt) * env(m, 0.003, 0.06) * 0.5
    return normalise(loopify(x, 2.0))


# ---------------------------------------------------------------- one-shots
def whoosh(seconds, f_lo, f_peak, seed):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    u = t / seconds
    centre = f_lo + (f_peak - f_lo) * np.sin(np.pi * np.clip(u * 1.1, 0, 1)) ** 1.5
    white = rng.standard_normal(n)
    # a sweeping band: blend three fixed bands by where the centre is
    bands = [bp(white, 250, 700), bp(white, 700, 1800), bp(white, 1800, 4500)]
    centres = np.array([420.0, 1120.0, 2800.0])
    x = np.zeros(n)
    for b, c in zip(bands, centres):
        w = np.exp(-((np.log(centre) - np.log(c)) ** 2) / 0.35)
        x += b * w
    e = np.sin(np.pi * u) ** 1.6
    return peak(x * e)


def vast(seconds=3.6, seed=31):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    pad = bp(rng.standard_normal(n), 200, 2000) * env(n, 0.9, 1.1, 0.3) * 0.5
    tone = (np.sin(2 * np.pi * 55.0 * t) + 0.5 * np.sin(2 * np.pi * 110.5 * t)) * env(n, 0.4, 1.4, 0.2) * 0.6
    x = reverb(pad + tone, tail=1.2)
    return peak(x, -7.0)


def dive(seconds=1.6, seed=37):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    f = 180.0 * (1400.0 / 180.0) ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) * env(n, 0.05, 0.4, 0.6) * 0.6 + bp(rng.standard_normal(n), 800, 4000) * env(n, 0.3, 0.3, 0.4) * 0.35
    return peak(x)


def thud(seconds=1.4, seed=41):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * (46.0 - 12.0 * np.clip(t / 0.5, 0, 1)) * t) * env(n, 0.008, 0.45) + lp(rng.standard_normal(n), 300) * env(n, 0.003, 0.12) * 0.8
    return peak(reverb(x, tail=0.5), -4.0)


def settle(seconds=1.1, seed=53):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    clink = bp(rng.standard_normal(n), 1500, 3500) * env(n, 0.001, 0.05) + np.sin(2 * np.pi * 2200.0 * t) * env(n, 0.002, 0.09) * 0.4
    low = np.sin(2 * np.pi * 70.0 * t) * env(n, 0.005, 0.25) * 0.8
    return peak(clink + low, -7.0)


def glint(seconds=1.6, seed=59):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, a, d in [(2093, 1.0, 0.5), (3322, 0.6, 0.35), (5020, 0.35, 0.25), (1046, 0.4, 0.7)]:
        x += a * np.sin(2 * np.pi * f * (1 + 0.0015 * np.sin(2 * np.pi * 5.0 * t)) * t) * env(n, 0.004, d)
    return peak(reverb(x, tail=0.4), -9.0)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    clips = {
        "brook": brook(), "rumble": rumble(), "pressure": pressure(), "grind": grind(), "weather": weather(),
        "rush": rush(), "shimmer": shimmer(), "bubble": bubble(),
        "whoosh_short": whoosh(0.9, 350.0, 2600.0, 61), "whoosh_long": whoosh(2.4, 250.0, 1500.0, 67),
        "vast": vast(), "dive": dive(), "thud": thud(), "settle": settle(), "glint": glint(),
    }
    for name, clip in clips.items():
        write_ogg(os.path.join(OUT, name + ".ogg"), clip)
        print("%-13s %5.1f s" % (name, clip.size / SR))
    print("wrote", OUT)
