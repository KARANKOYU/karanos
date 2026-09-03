#!/usr/bin/env python3
"""Generate the Kavis system sounds (follow-up work 6b).

Pure-stdlib sine synthesis (wave + math — numpy would be a build
dependency for nothing): short notes from one timbre family, all
license-free by construction. Run by the kavis-theme package build;
output lands in /usr/share/sounds/kavis/stereo/ under freedesktop
sound-theme names so GTK apps pick them up automatically.

Usage: gen-system-sounds.py <output-dir>
"""

import math
import struct
import sys
import wave
from pathlib import Path

RATE = 44100


def tone(freq, dur, volume=0.5, attack=0.008, harmonics=(1.0, 0.35, 0.12)):
    """One soft sine note with a fast attack and exponential decay."""
    samples = []
    n = int(RATE * dur)
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-4.5 * t / dur)
        value = sum(
            amp * math.sin(2 * math.pi * freq * (k + 1) * t)
            for k, amp in enumerate(harmonics)
        )
        samples.append(volume * env * value / sum(harmonics))
    return samples


def silence(dur):
    return [0.0] * int(RATE * dur)


def write_wav(path, samples):
    with wave.open(str(path), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        frames = bytearray()
        for value in samples:
            clipped = max(-1.0, min(1.0, value))
            raw = struct.pack("<h", int(clipped * 32767))
            frames += raw + raw   # stereo: same sample on both channels
        out.writeframes(bytes(frames))


def main():
    if len(sys.argv) != 2:
        print("usage: gen-system-sounds.py <output-dir>",
              file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    A5, E5, D4, C3, G4 = 880.0, 659.25, 293.66, 130.81, 392.0

    sounds = {
        # device plugged in: two notes up (like the Windows USB sound)
        "device-added": tone(E5, 0.16) + tone(A5, 0.28),
        # device removed: two notes down
        "device-removed": tone(A5, 0.16) + tone(E5, 0.28),
        # notification: a single soft "ding"
        "message-new-instant": tone(A5, 0.5, volume=0.42),
        # warning: two quick low notes
        "dialog-warning": tone(D4, 0.12) + silence(0.05) + tone(D4, 0.2),
        # error: short, dull, low
        "dialog-error": tone(C3, 0.3, harmonics=(1.0, 0.5, 0.25)),
        # low battery: the warning sound, repeated
        "battery-low": (tone(G4, 0.14) + silence(0.08) + tone(D4, 0.22)
                        + silence(0.25)
                        + tone(G4, 0.14) + silence(0.08) + tone(D4, 0.22)),
    }
    for name, samples in sounds.items():
        write_wav(out / (name + ".wav"), samples)
        print(f"{name}.wav ({len(samples) / RATE:.2f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
