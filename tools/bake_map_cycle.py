"""Bake a replaceable full sky-cycle reference without changing the live generator.

Requires Python + numpy and ffmpeg on PATH. Replays the map's existing OGG beds,
sky weights and seeded random calls into a seamless stereo 160-second OGG.
Writes the Windows workspace's editable copy (custom/music/) and the copy the
Web build plays in place of the live mix (default/music/ambience/).
Run from any directory: python tools/bake_map_cycle.py
"""
from pathlib import Path
import json
import re
import shutil
import subprocess
import tempfile
import wave

import numpy as np

GAME = Path(__file__).resolve().parents[1] / 'prototypes/prototype_02'
RATE = 22050


def decode(path):
    raw = subprocess.check_output([
        'ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le',
        '-ac', '1', '-ar', str(RATE), '-'])
    return np.frombuffer(raw, dtype='<f4')


def bake():
    sky = (GAME / 'scripts/ui/day_night_sky.gd').read_text()
    seconds = float(re.search(r'var cycle_seconds := ([\d.]+)', sky)[1])
    count = round(seconds * RATE)
    phase = np.arange(count, dtype=np.float64) / count * 4
    index = phase.astype(int) % 4
    blend = np.clip((phase % 1 - .18) / (.88 - .18), 0, 1)
    blend = blend * blend * (3 - 2 * blend)

    def by_time(values):
        values = np.asarray(values)
        return values[index] * (1 - blend) + values[(index + 1) % 4] * blend

    rng = np.random.default_rng(20261121)
    mix = np.zeros((count, 2), dtype=np.float64)
    source = GAME / 'default/music/ambience'
    for name, levels in {
        'wind_day': [1, .75, .35, 0],
        'wind_night': [0, .25, .6, 1],
        'crickets': [0, 0, .45, .8],
    }.items():
        audio = decode(source / f'{name}.ogg')
        # Circular crossfade at each source wrap (a short equal-amplitude splice).
        edge = min(round(.03 * RATE), len(audio) // 4)
        ramp = np.linspace(0, 1, edge)
        audio = audio.copy()
        audio[:edge] = audio[-edge:] * (1 - ramp) + audio[:edge] * ramp
        offset = int(rng.integers(0, len(audio)))
        bed = audio[(np.arange(count) + offset) % len(audio)] * by_time(levels)
        mix += bed[:, None]
    for kind, variants, rates, gap, level in [
        ('bird', 6, [14, 8, 3, 0], 1.2, -3),
        ('chime', 3, [0, 3, 1, 0], 6, -9),
        ('owl', 2, [0, 0, 1, 3], 9, -5),
    ]:
        chance = by_time(rates) / 60
        wait, last = float(rng.uniform(.5, 3)), -1
        for t in np.arange(0, seconds, 1 / 60):
            wait -= 1 / 60
            start = round(t * RATE)
            if wait > 0 or rng.random() >= chance[start] / 60:
                continue
            variant = int(rng.integers(1, variants + 1))
            if variant == last:
                variant = variant % variants + 1
            last = variant
            audio = decode(source / f'{kind}_{variant}.ogg')
            pitch = rng.uniform(.95, 1.05)
            audio = np.interp(np.arange(0, len(audio), pitch), np.arange(len(audio)), audio)
            gain = 10 ** ((level + rng.uniform(-2, 2)) / 20)
            pan = rng.uniform(-.4, .4) if kind != 'chime' else 0
            stereo = audio[:, None] * gain * np.array([1 - max(pan, 0), 1 + min(pan, 0)])
            # Calls crossing the cycle's end wrap into its beginning.
            np.add.at(mix, (start + np.arange(len(audio))) % count, stereo)
            wait = gap
    # Blend the boundary toward a common waveform without shortening the cycle.
    edge = round(.05 * RATE)
    common = (mix[-edge:] + mix[:edge]) / 2
    ramp = np.linspace(0, 1, edge)[:, None]
    mix[-edge:] = mix[-edge:] * (1 - ramp) + common * ramp
    mix[:edge] = common * (1 - ramp) + mix[:edge] * ramp
    mix[0] = mix[-1] = (mix[0] + mix[-1]) / 2
    # Fixed 6 dB storage headroom, compensated by the sidecar's -8 dB level:
    # together these preserve the live ambience's -14 dB mix.
    mix *= 10 ** (-6 / 20)
    peak = float(np.max(np.abs(mix)))
    if peak > .98:
        raise RuntimeError(f'Reference clips ({peak}); adjust the source mix, not normalization')
    output = GAME / 'custom/music/world_map_cycle.ogg'
    with tempfile.TemporaryDirectory(prefix='gameoff-ambience-') as temporary:
        wav = Path(temporary) / 'cycle.wav'
        with wave.open(str(wav), 'wb') as stream:
            stream.setnchannels(2)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes((mix * 32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(wav),
                        '-c:a', 'libvorbis', '-q:a', '5', str(output)], check=True)
    web_copy = GAME / 'default/music/ambience/world_map_cycle.ogg'
    shutil.copyfile(output, web_copy)
    print(json.dumps({'output': str(output), 'web_copy': str(web_copy), 'seconds': seconds, 'peak': peak}))


if __name__ == '__main__':
    bake()
