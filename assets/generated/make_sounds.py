"""Gera os sons ambientes que não existem nos pacotes da Kenney.

Rode com:  python assets/generated/make_sounds.py
Cria, nesta mesma pasta:
  - wind_loop.wav      vento (8 s, emenda sem "pulo" quando repete)
  - bird_chirp_1..4    piados curtos de passarinho
  - metro_ride.wav     viagem de metrô (3 s): ronco grave + "tac-tac" dos trilhos

Só usa a biblioteca padrão do Python (wave, math, random).
Estes sons foram feitos para o Game Hub e são CC0 (domínio público).
"""

import math
import os
import random
import struct
import wave

RATE = 22050
HERE = os.path.dirname(os.path.abspath(__file__))


def save_wav(name, samples):
    """Salva uma lista de números entre -1 e 1 como WAV mono de 16 bits."""
    path = os.path.join(HERE, name)
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print("gerado:", name)


def wind(seconds=8.0):
    """Ruído "marrom" (grave, como vento) com rajadas lentas."""
    random.seed(7)
    count = int(seconds * RATE)
    samples = []
    value = 0.0
    smooth = 0.0
    for i in range(count):
        value = (value + random.uniform(-0.02, 0.02)) * 0.998  # ruído marrom
        smooth += (value - smooth) * 0.08                      # tira o chiado agudo
        t = i / RATE
        # rajadas: soma de ondas lentas, que fecham um ciclo inteiro em 8 s
        gust = 0.55 + 0.25 * math.sin(2 * math.pi * t / seconds) \
            + 0.2 * math.sin(2 * math.pi * 3 * t / seconds + 1.3)
        samples.append(smooth * gust * 6.0)
    # Emenda: mistura o fim com o começo para o loop não dar "clique".
    fade = int(0.5 * RATE)
    for i in range(fade):
        w = i / fade
        samples[i] = samples[i] * w + samples[count - fade + i] * (1 - w)
    samples = samples[: count - fade]
    # Ajusta o volume: o pico fica em 70% (sem distorcer).
    peak = max(abs(s) for s in samples)
    return [s * 0.7 / peak for s in samples]


def chirp(seed):
    """Um piado: 2 a 4 notas curtas que sobem e descem de tom."""
    rng = random.Random(seed)
    samples = []
    for _ in range(rng.randint(2, 4)):
        start = rng.uniform(2500, 3500)
        end = start + rng.uniform(-1200, 1800)
        length = rng.uniform(0.05, 0.12)
        count = int(length * RATE)
        phase = 0.0
        for i in range(count):
            k = i / count
            frequency = start + (end - start) * k
            phase += 2 * math.pi * frequency / RATE
            envelope = math.sin(math.pi * k) ** 2
            samples.append(0.5 * envelope * (math.sin(phase) + 0.25 * math.sin(2 * phase)))
        samples.extend([0.0] * int(rng.uniform(0.03, 0.08) * RATE))
    return samples


def metro_ride(seconds=3.0):
    """Viagem de metrô: ronco grave que cresce e some, com o "tac-tac" das
    rodas passando nas emendas dos trilhos (dois toques a cada 0,45 s)."""
    random.seed(11)
    count = int(seconds * RATE)
    samples = []
    value = 0.0
    smooth = 0.0
    hum_phase = 0.0
    for i in range(count):
        t = i / RATE
        value = (value + random.uniform(-0.03, 0.03)) * 0.997  # ruído grave (motor e ar)
        smooth += (value - smooth) * 0.05
        hum_phase += 2 * math.pi * (55 + 8 * math.sin(t * 1.3)) / RATE  # zumbido do motor
        envelope = min(1.0, t / 0.5) * min(1.0, (seconds - t) / 0.8)  # cresce e some
        rumble = smooth * 5.0 + 0.18 * math.sin(hum_phase)
        # "Tac-tac": dois estalos curtos e graves a cada 0,45 s.
        click = 0.0
        for start in (0.0, 0.11):
            k = (t - start) % 0.45
            if k < 0.03:
                click += math.exp(-k * 160) * math.sin(2 * math.pi * 140 * k) * 0.9
        samples.append((rumble + click) * envelope)
    peak = max(abs(s) for s in samples)
    return [s * 0.7 / peak for s in samples]


if __name__ == "__main__":
    save_wav("wind_loop.wav", wind())
    for n in range(1, 5):
        save_wav("bird_chirp_%d.wav" % n, chirp(n))
    save_wav("metro_ride.wav", metro_ride())
