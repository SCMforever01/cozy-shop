#!/usr/bin/env python3
"""角色语音响度归一化：把 assets/audio/voice_*.wav 统一到目标 RMS。

Breeze TTS 各条输出响度不一（峰值 -2 ~ -12dBFS），归一后 AudioController
再用统一音量偏移与音效配比。纯标准库（wave + struct + math）。
用法：python3 tools/normalize_audio.py [--target 0.08]
"""
import math
import struct
import sys
import wave
import glob

TARGET_RMS = 0.08  # 约 -22dBFS，给 BGM/音效留空间


def analyze(path: str):
    w = wave.open(path, "rb")
    frames = w.readframes(w.getnframes())
    w.close()
    samples = struct.unpack("<%dh" % (len(frames) // 2), frames)
    return samples


def rms_of(samples) -> float:
    if not samples:
        return 0.0
    acc = sum(s * s for s in samples)
    return math.sqrt(acc / len(samples)) / 32768.0


def write_wav(path: str, samples, rate: int = 24000) -> None:
    frames = struct.pack("<%dh" % len(samples), *[max(-32768, min(32767, int(s))) for s in samples])
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(rate)
    w.writeframes(frames)
    w.close()


def main() -> int:
    target = float(sys.argv[sys.argv.index("--target") + 1]) if "--target" in sys.argv else TARGET_RMS
    files = sorted(glob.glob("assets/audio/voice_*.wav"))
    if not files:
        print("no voice files")
        return 1
    for path in files:
        samples = analyze(path)
        rms = rms_of(samples)
        if rms <= 0:
            print(f"{path}: silent, skip")
            continue
        gain = target / rms
        gain = min(gain, 4.0)  # 不过度放大噪音
        new_samples = [s * gain for s in samples]
        write_wav(path, new_samples)
        peak = max(abs(s) for s in new_samples) / 32768.0
        print(f"{path}: rms {rms:.3f} -> {rms_of(new_samples):.3f} (gain x{gain:.2f}, peak {peak:.2f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
