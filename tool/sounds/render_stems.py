#!/usr/bin/env python3
"""Renders Aura's recorded Sounds stems (F15) from scratch: no third-party audio.

Every stem is synthesised with numpy/scipy, seeded and deterministic, as ONE seamless
loop. Seamless by construction, not by crossfade: every random signal and every filter
is circular (filters run on a tiled copy and keep the middle), and every tone is a whole
number of cycles per loop, so the last sample flows into the first with no seam.

Spec (docs/sounds/licence-log.md "Rules for a recorded stem"): AAC-LC .m4a, 44.1 kHz,
stereo, 128 kbps, a 120 s loop, about -23 LUFS integrated, no fade at either end.

    python3 tool/sounds/render_stems.py --out /tmp/aura-stems            # render + measure
    python3 tool/sounds/render_stems.py --out ... --publish               # + site folder, manifest, bundle

Needs ffmpeg (loudness measurement and AAC encoding). The licence for every stem is
"Aura-original": the code in this file is the only source.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
LOOP_S = 120
N = SR * LOOP_S
TARGET_LUFS = -23.0
# Deep rumble reads quiet on a loudness meter (K-weighting discounts bass), so forcing -23 LUFS would drive its
# peaks into the limiter and splash harmonics up to 5 kHz. Thunder is "distant": a lower target keeps it clean.
TARGET_OVERRIDE = {"distant_thunder": -27.5}
PEAK_CEILING = 0.89  # about -1 dBFS
BITRATE = "128k"

REPO = Path(__file__).resolve().parents[2]
MANIFEST = REPO / "contracts/sounds/stems.v1.json"
BUNDLED = REPO / "apps/mobile/lib/src/features/sanctuary/sounds/stem_manifest_bundled.dart"
SITE_SOUNDS = REPO / "apps/site/public/sounds"
LICENCE_LOG = REPO / "docs/sounds/licence-log.md"
SOURCE_URL = "https://github.com/kalyan1421/aura/blob/main/tool/sounds/render_stems.py"
LICENCE = "Aura-original: synthesised by tool/sounds/render_stems.py"


# ---- circular DSP helpers ---------------------------------------------------------------


def cf(sos: np.ndarray, x: np.ndarray) -> np.ndarray:
    """Circular filter: run on three copies, keep the middle, so the loop wraps cleanly."""
    n = len(x)
    return signal.sosfilt(sos, np.concatenate([x, x, x]))[n : 2 * n]


def band(lo: float, hi: float, order: int = 2) -> np.ndarray:
    return signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")


def low(f: float, order: int = 2) -> np.ndarray:
    return signal.butter(order, f, btype="lowpass", fs=SR, output="sos")


def peak(f: float, q: float) -> np.ndarray:
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.tf2sos(b, a)


def noise(r: np.random.Generator, n: int = N) -> np.ndarray:
    return r.standard_normal(n)


def unit(x: np.ndarray) -> np.ndarray:
    """Zero-mean, unit-RMS."""
    x = x - x.mean()
    return x / (np.sqrt(np.mean(x**2)) + 1e-12)


def slow(r: np.random.Generator, hz: float, order: int = 2) -> np.ndarray:
    """Circular slow random curve, zero-mean unit-RMS (gusts, swells, flutter)."""
    return unit(cf(low(hz, order), noise(r)))


def lift(x: np.ndarray, depth: float) -> np.ndarray:
    """A slow curve as a positive gain around 1: 1 + depth * x, never below 0.05."""
    return np.maximum(1.0 + depth * x, 0.05)


def pan_gains(p: float) -> tuple[float, float]:
    """Equal-power pan, p in [-1, 1]."""
    th = (p + 1.0) * np.pi / 4.0
    return float(np.cos(th)), float(np.sin(th))


def stereo(l: np.ndarray, r_: np.ndarray) -> np.ndarray:
    return np.stack([l, r_])


def add_wrap(buf: np.ndarray, start: int, wave: np.ndarray, gain: float = 1.0) -> None:
    """Adds [wave] into [buf] at [start], wrapping around the end (circular loop)."""
    n = len(buf)
    start %= n
    end = start + len(wave)
    if end <= n:
        buf[start:end] += gain * wave
    else:
        k = n - start
        buf[start:] += gain * wave[:k]
        buf[: len(wave) - k] += gain * wave[k:]


def poisson_times(r: np.random.Generator, rate: float) -> np.ndarray:
    """Event start samples for a Poisson process of [rate] per second over the loop."""
    count = r.poisson(rate * LOOP_S)
    return r.integers(0, N, size=count)


def sparse_impulses(r: np.random.Generator, rate: float, sigma: float = 0.9) -> np.ndarray:
    """A circular impulse train, log-normal amplitudes with random sign."""
    x = np.zeros(N)
    t = poisson_times(r, rate)
    amp = np.minimum(r.lognormal(0.0, sigma, len(t)), 2.2)  # no single drop dominates the peak
    np.add.at(x, t, amp * r.choice([-1.0, 1.0], len(t)))
    return x


def tone_hz(f: float) -> float:
    """Nearest frequency with a whole number of cycles per loop (so the loop is seamless)."""
    return round(f * LOOP_S) / LOOP_S


def master(x: np.ndarray, soften_hz: float = 12000.0) -> np.ndarray:
    """Gentle top-end softening and DC removal for comfort at bedtime volumes."""
    sos = low(soften_hz, 2)
    out = np.stack([cf(sos, c - c.mean()) for c in x])
    return out


# ---- the stems --------------------------------------------------------------------------


def rain(seed: int, heavy: bool = False) -> np.ndarray:
    """Soft broadband hiss with layered drops; [heavy] is denser, with more low body."""
    r = np.random.default_rng(seed)
    swell = lift(slow(r, 0.08), 0.10)
    hiss_gain, drop_rate, big_rate = (1.0, 900.0, 7.0) if not heavy else (1.25, 2200.0, 22.0)
    chans = []
    for _ in range(2):
        body = unit(cf(band(700, 9000), noise(r))) * hiss_gain * swell
        soft = unit(cf(band(120, 500), noise(r))) * (0.18 if not heavy else 0.34)
        drops = np.zeros(N)
        for (lo, hi, g) in ((1500, 3000, 0.9), (2800, 5200, 0.7), (4500, 8500, 0.45)):
            drops += g * unit(cf(band(lo, hi), sparse_impulses(r, drop_rate / 3.0)))
        big = unit(cf(band(600, 1900), sparse_impulses(r, big_rate, sigma=1.1)))
        chans.append(body + soft + 0.22 * drops + 0.16 * big)
    return master(stereo(*chans))


def ocean(seed: int) -> np.ndarray:
    """Waves of 8-14 s: a slow swell, a crest that brightens, then fizz that drains away."""
    r = np.random.default_rng(seed)
    periods = []
    while sum(periods) < LOOP_S:
        periods.append(r.uniform(8.0, 14.0))
    scale = LOOP_S / sum(periods)  # fit a whole number of waves into the loop
    periods = [p * scale for p in periods]
    starts = np.cumsum([0.0] + periods[:-1])
    t = np.arange(N) / SR
    env_l = np.zeros(N)
    env_r = np.zeros(N)
    for t0, p in zip(starts, periods):
        s = ((t - t0) / p) % 1.0  # wraps, so a wave can straddle the loop point
        wave = (s**1.25) * np.exp(-3.4 * s)
        wave /= (1.25 / 3.4) ** 1.25 * np.exp(-1.25)
        gl, gr = pan_gains(r.uniform(-0.35, 0.35))
        # keep each wave from restarting twice: only the cycle that begins at t0
        mask = (((t - t0) % LOOP_S) < p).astype(float)
        env_l += wave * mask * (0.6 + 0.4 * gl * 1.4)
        env_r += wave * mask * (0.6 + 0.4 * gr * 1.4)
    chans = []
    for env in (env_l, env_r):
        e = np.clip(env, 0, None)
        e = cf(low(2.5), e)  # smooth the corners
        rumble = unit(cf(band(35, 200), noise(r))) * (0.35 + 0.5 * e)
        low_b = unit(cf(band(120, 700), noise(r))) * (0.15 + 0.9 * e**0.8)
        mid_b = unit(cf(band(700, 2600), noise(r))) * (0.05 + 0.8 * e**1.5)
        fizz = unit(cf(band(2600, 8000), noise(r))) * (0.02 + 0.5 * e**2.6)
        chans.append(0.9 * rumble + low_b + 0.8 * mid_b + 0.45 * fizz)
    return master(stereo(*chans), soften_hz=9000.0)


def wind(seed: int) -> np.ndarray:
    """Gusts that rise and fall over many seconds, with a faint drifting whistle."""
    r = np.random.default_rng(seed)
    gust = np.clip(0.55 + 0.45 * slow(r, 0.11, 2), 0.05, None)
    gust2 = np.clip(0.4 + 0.6 * slow(r, 0.17, 2), 0.0, None)
    chans = []
    for _ in range(2):
        main = unit(cf(band(120, 950), noise(r))) * gust
        air = unit(cf(band(900, 3200), noise(r))) * (gust2**2) * 0.55
        wh = np.zeros(N)
        for f in (430, 640, 880):
            wh += unit(cf(peak(tone_hz(f), 28), noise(r))) * np.clip(0.2 + 0.8 * slow(r, 0.2), 0, None) * 0.5
        chans.append(main + air + 0.12 * wh * gust)
    return master(stereo(*chans), soften_hz=8000.0)


def night_insects(seed: int) -> np.ndarray:
    """A hedge of crickets: chirps of short pulses on 3.4-5.3 kHz carriers, each placed apart."""
    r = np.random.default_rng(seed)
    t = np.arange(N) / SR
    mix_l = np.zeros(N)
    mix_r = np.zeros(N)
    pulse_len = int(0.012 * SR)
    pulse = np.hanning(pulse_len)
    for k in range(15):
        f = tone_hz(r.uniform(3400, 5300))
        vib = tone_hz(r.uniform(2.0, 5.0))
        carrier = np.sin(2 * np.pi * f * t + 0.6 * np.sin(2 * np.pi * vib * t))
        env = np.zeros(N)
        chirp_gap = r.uniform(0.35, 1.0)  # seconds between chirps
        n_pulses = int(r.integers(3, 6))
        pulse_rate = r.uniform(26.0, 40.0)  # pulses per second inside a chirp
        base_amp = r.uniform(0.25, 1.0)  # near vs far
        tt = r.uniform(0, chirp_gap)
        while tt < LOOP_S:
            for i in range(n_pulses):
                add_wrap(env, int((tt + i / pulse_rate) * SR), pulse, base_amp * (0.65 + 0.35 * (1 - i / n_pulses)))
            tt += chirp_gap * r.uniform(0.7, 1.4)
        voice = env * carrier
        gl, gr = pan_gains(r.uniform(-0.9, 0.9))
        mix_l += gl * voice
        mix_r += gr * voice
    chans = []
    for m in (mix_l, mix_r):
        air = unit(cf(band(1800, 9000), noise(r))) * 0.05
        hum = unit(cf(band(60, 260), noise(r))) * 0.05
        chans.append(unit(m) * 0.9 + air + hum)
    return master(stereo(*chans), soften_hz=11000.0)


def monsoon_roof(seed: int) -> np.ndarray:
    """Heavy rain on a tin roof: dense drops, resonant pings and a low drumming."""
    r = np.random.default_rng(seed)
    base = rain(seed + 1, heavy=True)
    swell = lift(slow(r, 0.06), 0.12)
    chans = []
    for c in range(2):
        pings = np.zeros(N)
        for f, q, rate in ((880, 22, 28), (1420, 30, 34), (2300, 36, 40), (3100, 40, 30)):
            pings += unit(cf(peak(f, q), sparse_impulses(r, rate, 1.0))) * 0.6
        drum = unit(cf(band(70, 260), sparse_impulses(r, 55, 1.0))) * 0.45
        chans.append(unit(base[c]) * 1.0 + 0.30 * pings + 0.35 * drum)
    return master(stereo(*[c * swell for c in chans]))


def stream(seed: int) -> np.ndarray:
    """A shallow stream: broadband flow with a constant spray of rising bubbles."""
    r = np.random.default_rng(seed)
    chans = []
    for _ in range(2):
        flow = unit(cf(band(350, 5200), noise(r)))
        flow *= lift(unit(cf(band(4, 16), noise(r))), 0.35)
        bub = np.zeros(N)
        for t0 in poisson_times(r, 110):
            dur = r.uniform(0.014, 0.045)
            m = int(dur * SR)
            tt = np.arange(m) / SR
            f0 = r.uniform(550, 2300)
            f1 = f0 * r.uniform(1.3, 1.9)
            ph = 2 * np.pi * (f0 * tt + 0.5 * (f1 - f0) * tt**2 / dur)
            wave = np.sin(ph) * np.exp(-tt / (dur * 0.45))
            add_wrap(bub, int(t0), wave, r.lognormal(-0.2, 0.55))
        hiss = unit(cf(band(2500, 9000), noise(r))) * 0.18
        chans.append(flow * 0.9 + 0.55 * unit(bub) + hiss)
    return master(stereo(*chans), soften_hz=9500.0)


def fireplace(seed: int) -> np.ndarray:
    """A low hearth rumble with flame flutter, small crackles and the odd pop."""
    r = np.random.default_rng(seed)
    chans = []
    for _ in range(2):
        rumble = unit(cf(band(35, 190), noise(r))) * 0.55
        flutter = unit(cf(band(300, 1900), noise(r))) * lift(slow(r, 5.0), 0.7) * 0.35
        crack = np.zeros(N)
        for t0 in poisson_times(r, 9):
            m = int(r.uniform(0.001, 0.006) * SR)
            burst = r.standard_normal(m) * np.hanning(m)
            amp = r.lognormal(-0.3, 1.0)
            add_wrap(crack, int(t0), burst, amp)
            if r.random() < 0.35:
                for j in range(int(r.integers(2, 5))):  # a little cascade of smaller pops
                    mm = int(r.uniform(0.0008, 0.003) * SR)
                    add_wrap(crack, int(t0 + (j + 1) * r.uniform(0.004, 0.02) * SR), r.standard_normal(mm) * np.hanning(mm), amp * r.uniform(0.2, 0.6))
        crack = cf(band(1400, 7500), crack)
        pops = np.zeros(N)
        for t0 in poisson_times(r, 0.45):
            m = int(0.045 * SR)
            tt = np.arange(m) / SR
            f = r.uniform(180, 520)
            add_wrap(pops, int(t0), np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.012), r.uniform(0.6, 1.6))
        crackle = 3.0 * np.tanh(unit(crack) / 3.0)  # a few loud ones must not set the level
        popping = 3.0 * np.tanh(unit(pops) / 3.0)
        chans.append(rumble + flutter + 0.30 * crackle + 0.16 * popping)
    return master(stereo(*chans), soften_hz=9000.0)


def distant_thunder(seed: int) -> np.ndarray:
    """A low bed with slow, rolling rumbles that fall in pitch and fade over several seconds."""
    r = np.random.default_rng(seed)
    n_events = 5
    gap = LOOP_S / n_events
    starts = (np.arange(n_events) * gap + r.uniform(0.0, gap * 0.5, n_events)) % LOOP_S
    chans = []
    for _ in range(2):
        bed = unit(cf(band(28, 110), noise(r))) * 0.12
        env = np.zeros(N)
        pitch = np.zeros(N)
        for s in starts:
            dur = r.uniform(8.0, 14.0)
            m = int(dur * SR)
            tt = np.arange(m) / SR
            attack = 1 - np.exp(-tt / r.uniform(0.9, 2.2))
            taper = np.cos(0.5 * np.pi * tt / dur) ** 2  # reaches exactly 0 at the end: no step
            decay = np.exp(-tt / r.uniform(3.5, 6.5)) * taper
            roll = np.clip(0.55 + 0.45 * unit(signal.sosfilt(low(2.2), r.standard_normal(m))), 0.1, None)
            add_wrap(env, int(s * SR), attack * decay * roll, r.uniform(0.7, 1.0))
            add_wrap(pitch, int(s * SR), np.exp(-tt / (dur * 0.5)) * taper)
        rough_hi = unit(cf(low(230), noise(r)))
        rough_lo = unit(cf(low(70), noise(r)))
        w = np.clip(pitch, 0, 1)
        thunder = (w * rough_hi + (1 - w) * rough_lo) * env
        chans.append(bed + thunder * 1.6)
    return master(stereo(*chans), soften_hz=2500.0)


STEMS = {
    "rain": (rain, 11),
    "ocean": (ocean, 12),
    "wind": (wind, 13),
    "night_insects": (night_insects, 14),
    "monsoon_roof": (monsoon_roof, 15),
    "stream": (stream, 16),
    "fireplace": (fireplace, 17),
    "distant_thunder": (distant_thunder, 18),
}


# ---- measuring, normalising, encoding ----------------------------------------------------


def lufs_of(wav: Path) -> float:
    out = subprocess.run(
        ["ffmpeg", "-nostats", "-hide_banner", "-i", str(wav), "-af", "ebur128=peak=true", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    m = re.findall(r"I:\s+(-?\d+\.\d+)\s+LUFS", out)
    if not m:
        sys.exit("could not measure loudness:\n" + out[-600:])
    return float(m[-1])


def limit(x: np.ndarray, knee: float = 0.6, ceiling: float = PEAK_CEILING) -> np.ndarray:
    """Transparent below [knee]; above it a smooth tanh curve that never passes [ceiling]."""
    a = np.abs(x)
    y = x.copy()
    over = a > knee
    y[over] = np.sign(x[over]) * (knee + (ceiling - knee) * np.tanh((a[over] - knee) / (ceiling - knee)))
    return y


def normalise(x: np.ndarray, tmp: Path, target: float = TARGET_LUFS) -> tuple[np.ndarray, float, float]:
    """Finds the gain that puts the *limited* signal at TARGET_LUFS (loud peaks are tamed, not clipped)."""
    base = x / (np.abs(x).max() + 1e-12) * 0.5
    gain = 1.0
    cur = base
    for _ in range(5):
        cur = limit(base * gain)
        wavfile.write(tmp, SR, cur.T.astype(np.float32))
        err = target - lufs_of(tmp)
        if abs(err) < 0.05:
            break
        gain *= 10 ** (err / 20.0)
    return cur, lufs_of(tmp), float(np.abs(cur).max())


def encode(wav: Path, m4a: Path) -> None:
    """AAC-LC with ffmpeg's own encoder: it writes an MP4 edit list, so players trim the encoder's
    priming and padding and the loop stays gapless. (Apple's aac_at and afconvert leave ~22 ms of
    trailing silence when decoded, which would click on every loop.)"""
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "aac", "-b:a", BITRATE,
         "-ar", str(SR), "-ac", "2", "-movflags", "+faststart", str(m4a)],
        check=True,
    )


def raw_seam_ratio(x: np.ndarray) -> float:
    """Loop-point jump relative to a typical sample step, on the *unencoded* loop (1.0 = as smooth as anywhere)."""
    step = float(np.mean(np.abs(np.diff(x, axis=1))))
    return float(np.mean(np.abs(x[:, 0] - x[:, -1])) / (step + 1e-12))


def encoded_report(m4a: Path) -> dict:
    """Decodes the .m4a: exact length, and no digital silence at either end (that would click on a loop)."""
    with tempfile.TemporaryDirectory() as d:
        w = Path(d) / "x.wav"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(m4a), "-f", "wav", "-c:a", "pcm_f32le", str(w)], check=True)
        _, x = wavfile.read(w)
    x = x.T
    return {"seconds": round(x.shape[1] / SR, 4), "extra_samples": int(x.shape[1] - N),
            "head_zeros": int(np.sum(x[0, :3000] == 0)), "tail_zeros": int(np.sum(x[0, -3000:] == 0))}


# ---- publishing --------------------------------------------------------------------------


def publish(results: dict[str, dict], out: Path) -> None:
    manifest_text = MANIFEST.read_text()
    doc = json.loads(manifest_text)
    SITE_SOUNDS.mkdir(parents=True, exist_ok=True)
    for stem in doc["stems"]:
        res = results.get(stem["id"])
        if not res:
            continue
        dest = SITE_SOUNDS / stem["file"]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(Path(res["m4a"]).read_bytes())
        stem.update({"bytes": res["bytes"], "sha256": res["sha256"], "licence": LICENCE,
                     "source_url": SOURCE_URL, "status": "available"})
    new = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    MANIFEST.write_text(new)
    b = BUNDLED.read_text()
    start = b.index("r'''\n") + len("r'''\n")
    end = b.index("'''", start)
    BUNDLED.write_text(b[:start] + new + b[end:])
    log = LICENCE_LOG.read_text()
    today = "2026-10-02"
    for sid, res in results.items():
        pat = re.compile(r"^\| " + re.escape(sid) + r" \|.*$", re.M)
        row = pat.search(log)
        if not row:
            continue
        tier = row.group(0).split("|")[2].strip()
        new_row = (f"| {sid} | {tier} | file | Synthesised by `tool/sounds/render_stems.py` (seeded; no third-party audio) "
                   f"| Aura-original | {today} | sha256 `{res['sha256'][:16]}…`, {res['bytes']:,} bytes, "
                   f"{res['lufs']:.1f} LUFS. Regenerating re-encodes, so the manifest hash is the one that counts. |")
        log = log.replace(row.group(0), new_row)
    LICENCE_LOG.write_text(log)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--only", nargs="*", help="stem ids (default: all)")
    ap.add_argument("--publish", action="store_true", help="copy to apps/site, update manifest, bundle and licence log")
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    results: dict[str, dict] = {}
    for sid, (fn, seed) in STEMS.items():
        if a.only and sid not in a.only:
            continue
        x = fn(seed)
        assert x.shape == (2, N), x.shape
        tmp = a.out / f"{sid}.wav"
        x, lufs, pk = normalise(x, tmp, TARGET_OVERRIDE.get(sid, TARGET_LUFS))
        m4a = a.out / f"{sid}.m4a"
        encode(tmp, m4a)
        data = m4a.read_bytes()
        rep = encoded_report(m4a)
        seam = round(raw_seam_ratio(x), 2)
        results[sid] = {"m4a": str(m4a), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                        "lufs": lufs, "peak_dbfs": round(20 * np.log10(pk), 1), "raw_seam": seam, **rep}
        print(f"{sid:16s} {len(data)/1e6:5.2f} MB  {lufs:6.1f} LUFS  peak {results[sid]['peak_dbfs']:5.1f} dBFS  "
              f"{rep['seconds']}s ({rep['extra_samples']:+d} samples)  loop seam x{seam}  silence head/tail {rep['head_zeros']}/{rep['tail_zeros']}")
    (a.out / "report.json").write_text(json.dumps(results, indent=2))
    if a.publish:
        publish(results, a.out)
        print("published: apps/site/public/sounds, contracts/sounds/stems.v1.json, bundled manifest, licence log")


if __name__ == "__main__":
    main()
