#!/usr/bin/env python3
"""用 Breeze TTS 2 服务生成游戏角色语音（WAV，24kHz/mono/16bit）。

服务：http://s-20261112194623-sic5h.ak-cloudml.xiaomi.srv/v1/audio/speech
串行调用（上游一次只接一单）；单条文本 ≤50 字。
用法：python3 tools/gen_voices.py
"""
import json
import struct
import sys
import time
import urllib.request
import uuid

TTS_URL = "http://s-20261112194623-sic5h.ak-cloudml.xiaomi.srv/v1/audio/speech"
OUT = "assets/audio"
CFG = 4.0  # 语气贴合强度（质量优先；音效短句不追求速度）

# (输出名, 文本, 语气指令, seed)
VOICES = [
    ("voice_welcome", "欢迎光临，里边请！", "热情亲切的老板娘，声音明亮欢快", 3001),
    ("voice_laozhang", "老地方，照旧。", "低沉随和的老大爷，慢悠悠的", 4101),
    ("voice_xiaowang", "来杯咖啡，提提神！", "年轻男生，轻快活泼", 4201),
    ("voice_lijie", "给我来块蛋糕吧。", "温柔亲切的中年女性", 4301),
    ("voice_critic", "嗯，让我尝尝看。", "拿腔拿调的美食评论家，傲慢挑剔", 4401),
    ("voice_birthday", "生日快乐呀！", "开心祝贺的语气", 3001),
    ("voice_thanks", "太好吃了！", "满足又惊喜的食客", 4201),
    ("voice_angry", "哼！再也不来了。", "生气抱怨的语气", 4201),
]


def make_wav(pcm: bytes, rate: int = 24000) -> bytes:
    """裸 PCM(16bit LE mono) -> WAV 容器。"""
    data_size = len(pcm)
    hdr = b"RIFF" + struct.pack("<I", 36 + data_size) + b"WAVEfmt " \
        + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16) \
        + b"data" + struct.pack("<I", data_size)
    return hdr + pcm


def synth(text: str, instruction: str, seed: int) -> bytes:
    boundary = uuid.uuid4().hex
    parts = [
        ("text", text),
        ("instruction", instruction),
        ("cfg_scale", str(CFG)),
        ("seed", str(seed)),
    ]
    body = b""
    for name, value in parts:
        body += (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n"
        ).encode()
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        TTS_URL,
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    # 上游模型服务一次只接一单（小说流水线在跑时会 409），耐心抢空隙
    last_err = None
    for attempt in range(80):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            last_err = e
            if "409" in str(e):
                time.sleep(0.5)  # 服务被占，紧轮询抢请求间隙
            else:
                print(f"    retry {attempt + 1}: {e}")
                time.sleep(3)
    raise RuntimeError(f"TTS failed: {last_err}")


def main() -> int:
    import os
    os.makedirs(OUT, exist_ok=True)
    ok = 0
    for name, text, instruction, seed in VOICES:
        print(f"[gen] {name}: {text!r}")
        pcm = synth(text, instruction, seed)
        wav = make_wav(pcm)
        path = f"{OUT}/{name}.wav"
        with open(path, "wb") as f:
            f.write(wav)
        print(f"    -> {path} ({len(wav) / 1024:.0f}KB, {len(pcm) / 48000:.1f}s)")
        ok += 1
    print(f"done: {ok}/{len(VOICES)} voices generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
