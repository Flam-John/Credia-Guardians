"""Generate placeholder audio: retro SFX + simple chiptune music loops.

Deterministic, pure-stdlib (wave/struct/math). Swap for final audio later —
filenames match docs/AUDIO_LIST.md and every AudioManager.play_sfx call.
Usage: python tools/audiogen/generate_audio.py
"""
import math
import os
import struct
import wave

RATE = 22050


def _write(path, samples):
    clamped = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s))
        clamped += struct.pack("<h", int(v * 32000))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(clamped))


def square(freq, t):
    return 0.6 if math.sin(2 * math.pi * freq * t) >= 0 else -0.6


def tri(freq, t):
    return 2.0 * abs(2.0 * ((freq * t) % 1.0) - 1.0) - 1.0


def noise(t):  # deterministic pseudo-noise
    return (math.sin(t * 12345.678) * 43758.5453) % 2.0 - 1.0


def env(i, n, attack=0.01, release=0.3):
    t = i / n
    a = min(1.0, t / max(attack, 1e-6))
    r = max(0.0, (1.0 - t) / release) if t > 1.0 - release else 1.0
    return a * min(1.0, r)


def sweep(f0, f1, dur, wave_fn=square, vol=0.5, rel=0.4):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        phase += f / RATE
        out.append(wave_fn(1.0, phase) * vol * env(i, n, release=rel))
    return out


def blip(freqs, dur_each=0.06, wave_fn=square, vol=0.5):
    out = []
    for f in freqs:
        n = int(RATE * dur_each)
        out += [wave_fn(f, i / RATE) * vol * env(i, n, release=0.5) for i in range(n)]
    return out


def hiss(dur, vol=0.4, lowpass=1.0):
    n = int(RATE * dur)
    out = []
    prev = 0.0
    for i in range(n):
        raw = noise(i) * vol * env(i, n, release=0.6)
        prev = prev + (raw - prev) * lowpass
        out.append(prev)
    return out


SFX = {
    "jump": lambda: sweep(300, 700, 0.12),
    "double_jump": lambda: sweep(400, 950, 0.12),
    "land": lambda: hiss(0.08, 0.25, 0.4),
    "dash": lambda: hiss(0.15, 0.35, 0.7),
    "attack_1": lambda: sweep(600, 300, 0.07, vol=0.35),
    "attack_2": lambda: sweep(700, 350, 0.07, vol=0.35),
    "attack_3": lambda: sweep(800, 250, 0.1, vol=0.4),
    "hit_connect": lambda: hiss(0.06, 0.5, 0.9),
    "hurt": lambda: sweep(500, 150, 0.2, tri, 0.5),
    "death": lambda: sweep(600, 80, 0.6, tri, 0.5),
    "heal": lambda: blip([400, 500, 650], 0.07, tri),
    "powerup": lambda: blip([330, 415, 494, 660], 0.07),
    "coin": lambda: blip([988, 1319], 0.06, vol=0.4),
    "pickup": lambda: blip([660, 880], 0.06),
    "checkpoint": lambda: blip([523, 659, 784], 0.07),
    "node_hold_loop": lambda: sweep(200, 400, 0.4, tri, 0.3),
    "node_activate": lambda: blip([523, 659, 784, 1047], 0.09),
    "gate_open": lambda: sweep(120, 350, 0.5, tri, 0.5),
    "platform_crumble": lambda: hiss(0.3, 0.4, 0.3),
    "hidden_room": lambda: blip([784, 988, 1175, 1568], 0.1, tri),
    "enemy_hurt": lambda: sweep(350, 200, 0.08, vol=0.35),
    "enemy_death": lambda: sweep(400, 100, 0.25, vol=0.45),
    "banker_panic": lambda: blip([600, 800, 600, 800], 0.05, tri),
    "manager_charge": lambda: sweep(150, 350, 0.3, tri, 0.5),
    "ledger_throw": lambda: hiss(0.1, 0.3, 0.8),
    "shark_lunge": lambda: sweep(200, 600, 0.2, tri, 0.5),
    "ai_teleport": lambda: sweep(1200, 300, 0.18, vol=0.35),
    "projectile": lambda: sweep(900, 500, 0.08, vol=0.3),
    "stomp": lambda: sweep(250, 600, 0.15, tri, 0.5),
    "shield_on": lambda: sweep(300, 500, 0.15, tri, 0.35),
    "shield_break": lambda: hiss(0.25, 0.5, 0.6),
    "shield_parry": lambda: blip([900, 1400], 0.04, vol=0.35) + hiss(0.04, 0.3, 0.8),
    "weapon_fire_chris": lambda: sweep(1500, 2400, 0.05, vol=0.3),
    "weapon_fire_flam": lambda: sweep(220, 90, 0.12, tri, 0.45) + hiss(0.05, 0.25, 0.5),
    "menu_move": lambda: blip([700], 0.04, vol=0.25),
    "menu_select": lambda: blip([700, 1050], 0.05, vol=0.3),
    "menu_back": lambda: blip([500, 350], 0.05, vol=0.3),
    "pause_in": lambda: blip([600, 450], 0.06, tri),
    "pause_out": lambda: blip([450, 600], 0.06, tri),
    "tally_tick": lambda: blip([1200], 0.03, vol=0.2),
    "rank_stamp": lambda: sweep(200, 100, 0.2, tri, 0.6) + blip([784, 1047], 0.1),
}

# Music: simple square-lead arps over triangle bass. (key offsets, tempo, feel)
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]


def note_hz(semitone):
    return 220.0 * (2.0 ** (semitone / 12.0))


def track(root, scale, bpm, bars, progression, lead_pattern, vol=0.35):
    beat = 60.0 / bpm
    out = []
    for bar in range(bars):
        chord_deg = progression[bar % len(progression)]
        for step in range(8):  # 8th notes, 4/4
            deg = chord_deg + lead_pattern[step % len(lead_pattern)]
            semis = scale[deg % 7] + 12 * (deg // 7)
            lead = note_hz(root + semis + 12)
            bass = note_hz(root + scale[chord_deg % 7] - 12)
            n = int(RATE * beat / 2)
            for i in range(n):
                t = i / RATE
                s = square(lead, t) * 0.5 * env(i, n, release=0.25)
                s += tri(bass, t) * 0.5
                # kick-ish thump on beat 1
                if step == 0 and i < RATE * 0.05:
                    s += tri(60, t) * (1.0 - i / (RATE * 0.05))
                out.append(s * vol)
    return out


MUSIC = {
    "menu": lambda: track(0, MINOR, 100, 8, [0, 5, 3, 4], [0, 2, 4, 2, 0, 2, 4, 7]),
    "stage_1": lambda: track(3, MAJOR, 128, 8, [0, 3, 4, 0], [0, 4, 2, 4, 7, 4, 2, 4]),
    "stage_2": lambda: track(-2, MINOR, 140, 8, [0, 0, 5, 4], [0, 7, 4, 7, 0, 7, 4, 9]),
    "stage_3": lambda: track(5, MAJOR, 116, 8, [0, 4, 5, 3], [0, 2, 4, 5, 4, 2, 0, 4]),
    "stage_4": lambda: track(-4, MINOR, 108, 8, [0, 3, 4, 4], [0, 4, 7, 4, 2, 5, 7, 5]),
    "boss_mid": lambda: track(-5, MINOR, 160, 8, [0, 0, 4, 5], [0, 7, 0, 7, 4, 7, 0, 10]),
    "stage_5": lambda: track(-7, MINOR, 150, 8, [0, 1, 0, 4], [0, 7, 10, 7, 0, 7, 12, 7]),
    "boss_final": lambda: track(-9, MINOR, 170, 8, [0, 0, 3, 4], [0, 12, 7, 12, 0, 10, 7, 10]),
    "victory": lambda: track(5, MAJOR, 120, 8, [0, 3, 4, 4], [0, 4, 7, 9, 7, 4, 7, 11]),
}


def main():
    os.makedirs("assets/audio/sfx", exist_ok=True)
    os.makedirs("assets/audio/music", exist_ok=True)
    for name, fn in SFX.items():
        _write(f"assets/audio/sfx/{name}.wav", fn())
    for name, fn in MUSIC.items():
        _write(f"assets/audio/music/{name}.wav", fn())
    print(f"audio generated: {len(SFX)} sfx, {len(MUSIC)} music loops")


if __name__ == "__main__":
    main()
