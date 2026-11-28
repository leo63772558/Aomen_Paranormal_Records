from pathlib import Path
import subprocess
import sys

RAW_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_raw")
OUT_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition")
CLEAN_DIR = OUT_ROOT / "raw_clean"
MASTER_DIR = OUT_ROOT / "mastered"
BUS_DIR = OUT_ROOT / "bus_fx"

RAW_FILES = {
    "dawen_01_daily": RAW_ROOT / "陈大文" / "dawen_1_daily.m4a",
    "dawen_02_tense": RAW_ROOT / "陈大文" / "dawen-2-tense.m4a",
    "dawen_03_urgent": RAW_ROOT / "陈大文" / "dawen-3-urgent.m4a",
    "jiamin_01": RAW_ROOT / "黄嘉敏" / "jiamin1.m4a",
    "jiamin_02": RAW_ROOT / "黄嘉敏" / "jiamin2.m4a",
    "jiamin_03": RAW_ROOT / "黄嘉敏" / "jiamin3.m4a",
    "granny": RAW_ROOT / "阿婆" / "granny.m4a",
    "zhihao_01": RAW_ROOT / "黄梓豪" / "zhihao_01.m4a",
    "zhihao_02": RAW_ROOT / "黄梓豪" / "zhihao_02.m4a",
    "zhihao_03": RAW_ROOT / "黄梓豪" / "zhihao_03.m4a",
    "zhihao_04": RAW_ROOT / "黄梓豪" / "zhihao_4.m4a",
    "uncle_liang_01": RAW_ROOT / "梁伯" / "uncle_liang_01.m4a",
    "uncle_liang_02": RAW_ROOT / "梁伯" / "uncle_liang_02.m4a",
    "uncle_liang_03_driver": RAW_ROOT / "梁伯" / "uncle_liang_03.m4a",
    "bus_normal": RAW_ROOT / "巴士" / "busnormal.m4a",
    "bus_anomaly": RAW_ROOT / "巴士" / "busanomaly.m4a",
    "bus_handrail_4lang": RAW_ROOT / "巴士" / "澳门巴士紧握扶手.m4a",
}


def run_ffmpeg(inp: Path, out: Path, af: str, sr: int = 24000) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(inp),
        "-ac", "1", "-ar", str(sr),
        "-af", af,
        "-c:a", "pcm_s16le",
        str(out),
    ]
    subprocess.run(cmd, check=True)


def main() -> None:
    for d in (CLEAN_DIR, MASTER_DIR, BUS_DIR):
        d.mkdir(parents=True, exist_ok=True)

    # 1. Base clean 24kHz mono WAVs for all 17 clips (gentle denoise + loudness norm + trim leading/trailing excess silence)
    base_clean_af = (
        "highpass=f=75,"
        "afftdn=nf=-28,"
        "acompressor=threshold=-22dB:ratio=2.5:attack=15:release=180,"
        "loudnorm=I=-18:TP=-1.5:LRA=11,"
        "silenceremove=start_periods=1:start_duration=0.12:start_threshold=-45dB,"
        "areverse,"
        "silenceremove=start_periods=1:start_duration=0.12:start_threshold=-45dB,"
        "areverse,"
        "apad=pad_dur=0.15"
    )
    for key, src in RAW_FILES.items():
        if not src.exists():
            raise FileNotFoundError(f"Missing raw file: {src}")
        run_ffmpeg(src, CLEAN_DIR / f"{key}.wav", base_clean_af)
        print(f"[raw_clean] {key}.wav")

    # 2. Mastered Da Wen (clean studio polish)
    for key in ("dawen_01_daily", "dawen_02_tense", "dawen_03_urgent"):
        run_ffmpeg(
            CLEAN_DIR / f"{key}.wav",
            MASTER_DIR / f"{key}.wav",
            "equalizer=f=220:t=q:w=1.2:g=1.2,equalizer=f=3200:t=q:w=1.3:g=1.5,loudnorm=I=-16:TP=-1.5:LRA=9",
        )
        print(f"[mastered] {key}.wav")

    # 3. Mastered Ah Hao (youth clarity, panic boost, cold stairwell reverb on 03, dying fragility on 04)
    run_ffmpeg(
        CLEAN_DIR / "zhihao_01.wav",
        MASTER_DIR / "zhihao_01_daily.wav",
        "equalizer=f=3000:t=q:w=1.2:g=1.8,loudnorm=I=-16:TP=-1.5:LRA=9",
    )
    run_ffmpeg(
        CLEAN_DIR / "zhihao_02.wav",
        MASTER_DIR / "zhihao_02_chase.wav",
        "highpass=f=90,acompressor=threshold=-20dB:ratio=3:attack=10:release=120,loudnorm=I=-15.5:TP=-1.5:LRA=8",
    )
    run_ffmpeg(
        CLEAN_DIR / "zhihao_03.wav",
        MASTER_DIR / "zhihao_03_ghost_clean.wav",
        "highpass=f=110,loudnorm=I=-16.5:TP=-1.5:LRA=10",
    )
    run_ffmpeg(
        CLEAN_DIR / "zhihao_03.wav",
        MASTER_DIR / "zhihao_03_ghost_reverb.wav",
        "highpass=f=130,equalizer=f=2400:t=q:w=1.1:g=2.0,aecho=0.82:0.74:42|88:0.28|0.15,loudnorm=I=-16.5:TP=-1.5:LRA=10",
    )
    run_ffmpeg(
        CLEAN_DIR / "zhihao_04.wav",
        MASTER_DIR / "zhihao_04_dying.wav",
        "highpass=f=100,equalizer=f=2600:t=q:w=1.2:g=1.5,loudnorm=I=-17:TP=-1.5:LRA=10",
    )
    print("[mastered] zhihao_01..04 done")

    # 4. Mastered Uncle Liang (close-mic breath inhale suppression + warm elder low-mid body + gentle de-ess)
    liang_af = (
        "highpass=f=85,"
        "agate=threshold=-33dB:range=0.22:attack=8:release=160,"
        "equalizer=f=180:t=q:w=1.2:g=2.5,"
        "equalizer=f=5500:t=q:w=1.5:g=-3.0,"
        "acompressor=threshold=-20dB:ratio=2.5:attack=15:release=160,"
        "loudnorm=I=-16.5:TP=-1.5:LRA=10"
    )
    run_ffmpeg(CLEAN_DIR / "uncle_liang_01.wav", MASTER_DIR / "uncle_liang_01_clean.wav", liang_af)
    run_ffmpeg(CLEAN_DIR / "uncle_liang_02.wav", MASTER_DIR / "uncle_liang_02_clean.wav", liang_af)
    run_ffmpeg(
        CLEAN_DIR / "uncle_liang_03_driver.wav",
        MASTER_DIR / "bus_driver_pa.wav",
        "highpass=f=300,lowpass=f=3600,acompressor=threshold=-22dB:ratio=3:attack=10:release=140,aecho=0.8:0.8:18:0.15,loudnorm=I=-16.5:TP=-1.5:LRA=9",
    )
    print("[mastered] uncle_liang & bus_driver_pa done")

    # 5. Bus PA versions of user's original announcer clips
    bus_pa_af = (
        "highpass=f=300,lowpass=f=4200,"
        "equalizer=f=1800:t=q:w=1.0:g=3.0,"
        "acompressor=threshold=-21dB:ratio=3:attack=10:release=120,"
        "aecho=0.8:0.85:22:0.12,"
        "loudnorm=I=-16:TP=-1.5:LRA=9"
    )
    run_ffmpeg(CLEAN_DIR / "bus_normal.wav", BUS_DIR / "bus_normal_pa_orig.wav", bus_pa_af)
    run_ffmpeg(CLEAN_DIR / "bus_handrail_4lang.wav", BUS_DIR / "bus_handrail_4lang_pa_orig.wav", bus_pa_af)

    # Anomaly PA: eerie cold metallic echo + subtle slow pitch sag (-8% pitch/formant drop via asetrate+atempo) on the haunted warning
    bus_anom_af = (
        "highpass=f=240,lowpass=f=3800,"
        "asetrate=24000*0.92,aresample=24000,atempo=1/0.92,"
        "aecho=0.78:0.75:38|78|135:0.30|0.18|0.10,"
        "tremolo=f=4.2:d=0.18,"
        "loudnorm=I=-16:TP=-1.5:LRA=10"
    )
    run_ffmpeg(CLEAN_DIR / "bus_anomaly.wav", BUS_DIR / "bus_anomaly_pa_orig.wav", bus_anom_af)
    print("[bus_fx] orig PA versions done")


if __name__ == "__main__":
    main()
