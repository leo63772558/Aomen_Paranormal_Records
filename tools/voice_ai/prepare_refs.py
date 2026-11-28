import asyncio
from pathlib import Path
import subprocess
import edge_tts

REFS_DIR = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition\refs")

JIaMIN_TEXT = (
    "你睇下前面，呢条街啲葡式碎石路好靓呀。"
    "喂，阵间影完相记得去买盒新鲜出炉嘅葡挞同猪扒包，唔好行太快呀，等等我嘛。"
)

GRANNY_TEXT = (
    "后生仔，新鲜出炉嘅葡挞拿稳呀，挞皮一掂就碎㗎。"
    "呢条旧街夜晚行路小心啲，听到有声唔好乱回头，快啲返屋企唞啦。"
)


async def synth_refs() -> None:
    REFS_DIR.mkdir(parents=True, exist_ok=True)
    tmp_dir = REFS_DIR / "_tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    jobs = [
        ("zh-HK-HiuMaanNeural", "+0%", "+0Hz", JIaMIN_TEXT, tmp_dir / "hiumaan.mp3", REFS_DIR / "ref_jiamin_hiumaan.wav",
         "highpass=f=85,loudnorm=I=-16:TP=-1.5:LRA=9"),
        ("zh-HK-HiuGaaiNeural", "+3%", "+6Hz", JIaMIN_TEXT, tmp_dir / "hiugaai.mp3", REFS_DIR / "ref_jiamin_hiugaai.wav",
         "highpass=f=90,loudnorm=I=-16:TP=-1.5:LRA=9"),
        ("zh-HK-HiuGaaiNeural", "-18%", "-18Hz", GRANNY_TEXT, tmp_dir / "granny_a.mp3", REFS_DIR / "ref_granny_crafted_warm.wav",
         "highpass=f=95,lowpass=f=4800,equalizer=f=240:t=q:w=1.2:g=2.5,vibrato=f=5.4:d=0.10,loudnorm=I=-16:TP=-1.5:LRA=9"),
        ("zh-CN-XiaoxiaoNeural", "-22%", "-24Hz", "小伙子，刚出炉的蛋挞拿稳喽，天黑了路不好走，听到背后有声音千万别随便回头，早点回家歇着吧。",
         tmp_dir / "granny_b.mp3", REFS_DIR / "ref_granny_crafted_raspy.wav",
         "highpass=f=110,lowpass=f=4400,equalizer=f=220:t=q:w=1.1:g=3.0,equalizer=f=2600:t=q:w=1.4:g=-2.0,vibrato=f=5.8:d=0.13,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ]
    for voice, rate, pitch, text, mp3_path, wav_path, af in jobs:
        comm = edge_tts.Communicate(text, voice=voice, rate=rate, pitch=pitch)
        await comm.save(str(mp3_path))
        subprocess.run(
            ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(mp3_path), "-ac", "1", "-ar", "24000", "-af", af, "-c:a", "pcm_s16le", str(wav_path)],
            check=True,
        )
        print(f"[ref] {wav_path.name}")


if __name__ == "__main__":
    asyncio.run(synth_refs())
