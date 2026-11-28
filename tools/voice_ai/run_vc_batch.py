import asyncio
import os
import sys
import subprocess
from pathlib import Path

for _proxy_key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
    os.environ.pop(_proxy_key, None)

os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"
os.environ["HF_HOME"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"
os.environ["HF_HUB_CACHE"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"

SEED_VC_DIR = Path(r"d:\Aomen_Paranormal_Records\tools\voice_ai\seed-vc")
sys.path.insert(0, str(SEED_VC_DIR))
os.chdir(SEED_VC_DIR)

import numpy as np
import torch
import torchaudio
import librosa
import edge_tts

# Load Seed-VC inference helpers once and reuse loaded models across all jobs
import inference as seed_inf  # noqa: E402

AUD_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition")
RAW_CLEAN = AUD_ROOT / "raw_clean"
REFS_DIR = AUD_ROOT / "refs"
JIAMIN_OUT = AUD_ROOT / "jiamin_vc"
GRANNY_OUT = AUD_ROOT / "granny_vc"
BUS_OUT = AUD_ROOT / "bus_fx"
CLONE_OUT = AUD_ROOT / "cloned_demos"


class ModelArgs:
    def __init__(self, f0_condition=False, fp16=True):
        self.checkpoint = None
        self.config = None
        self.f0_condition = f0_condition
        self.fp16 = fp16


def convert_one(
    models_bundle,
    source_path: Path,
    target_path: Path,
    out_wav_path: Path,
    diffusion_steps: int = 40,
    length_adjust: float = 1.0,
    inference_cfg_rate: float = 0.72,
    f0_condition: bool = False,
    auto_f0_adjust: bool = False,
    pitch_shift: int = 0,
    post_af: str | None = None,
) -> None:
    model, semantic_fn, f0_fn, vocoder_fn, campplus_model, mel_fn, mel_fn_args = models_bundle
    device = seed_inf.device
    sr = 22050 if not f0_condition else 44100
    hop_length = 256 if not f0_condition else 512
    max_context_window = sr // hop_length * 30
    overlap_frame_len = 16
    overlap_wave_len = overlap_frame_len * hop_length

    source_audio = librosa.load(str(source_path), sr=sr)[0]
    ref_audio = librosa.load(str(target_path), sr=sr)[0]

    source_t = torch.tensor(source_audio).unsqueeze(0).float().to(device)
    ref_t = torch.tensor(ref_audio[: sr * 25]).unsqueeze(0).float().to(device)

    converted_waves_16k = torchaudio.functional.resample(source_t, sr, 16000)
    if converted_waves_16k.size(-1) <= 16000 * 30:
        S_alt = semantic_fn(converted_waves_16k)
    else:
        overlapping_time = 5
        S_alt_list = []
        buffer = None
        traversed_time = 0
        while traversed_time < converted_waves_16k.size(-1):
            if buffer is None:
                chunk = converted_waves_16k[:, traversed_time : traversed_time + 16000 * 30]
            else:
                chunk = torch.cat(
                    [buffer, converted_waves_16k[:, traversed_time : traversed_time + 16000 * (30 - overlapping_time)]],
                    dim=-1,
                )
            S_alt = semantic_fn(chunk)
            if traversed_time == 0:
                S_alt_list.append(S_alt)
            else:
                S_alt_list.append(S_alt[:, 50 * overlapping_time :])
            buffer = chunk[:, -16000 * overlapping_time :]
            traversed_time += 30 * 16000 if traversed_time == 0 else chunk.size(-1) - 16000 * overlapping_time
        S_alt = torch.cat(S_alt_list, dim=1)

    ori_waves_16k = torchaudio.functional.resample(ref_t, sr, 16000)
    S_ori = semantic_fn(ori_waves_16k)

    mel = mel_fn(source_t.to(device).float())
    mel2 = mel_fn(ref_t.to(device).float())

    target_lengths = torch.LongTensor([int(mel.size(2) * length_adjust)]).to(mel.device)
    target2_lengths = torch.LongTensor([mel2.size(2)]).to(mel2.device)

    feat2 = torchaudio.compliance.kaldi.fbank(ori_waves_16k, num_mel_bins=80, dither=0, sample_frequency=16000)
    feat2 = feat2 - feat2.mean(dim=0, keepdim=True)
    style2 = campplus_model(feat2.unsqueeze(0))

    if f0_condition:
        F0_ori = f0_fn(ori_waves_16k[0], thred=0.03)
        F0_alt = f0_fn(converted_waves_16k[0], thred=0.03)
        F0_ori = torch.from_numpy(F0_ori).to(device)[None]
        F0_alt = torch.from_numpy(F0_alt).to(device)[None]
        voiced_F0_ori = F0_ori[F0_ori > 1]
        voiced_F0_alt = F0_alt[F0_alt > 1]
        log_f0_alt = torch.log(F0_alt + 1e-5)
        voiced_log_f0_ori = torch.log(voiced_F0_ori + 1e-5)
        voiced_log_f0_alt = torch.log(voiced_F0_alt + 1e-5)
        median_log_f0_ori = torch.median(voiced_log_f0_ori)
        median_log_f0_alt = torch.median(voiced_log_f0_alt)
        shifted_log_f0_alt = log_f0_alt.clone()
        if auto_f0_adjust:
            shifted_log_f0_alt[F0_alt > 1] = log_f0_alt[F0_alt > 1] - median_log_f0_alt + median_log_f0_ori
        shifted_f0_alt = torch.exp(shifted_log_f0_alt)
        if pitch_shift != 0:
            shifted_f0_alt[F0_alt > 1] = seed_inf.adjust_f0_semitones(shifted_f0_alt[F0_alt > 1], pitch_shift)
    else:
        F0_ori = None
        shifted_f0_alt = None

    cond, _, _, _, _ = model.length_regulator(S_alt, ylens=target_lengths, n_quantizers=3, f0=shifted_f0_alt)
    prompt_condition, _, _, _, _ = model.length_regulator(S_ori, ylens=target2_lengths, n_quantizers=3, f0=F0_ori)

    max_source_window = max_context_window - mel2.size(2)
    processed_frames = 0
    generated_wave_chunks = []
    previous_chunk = None
    while processed_frames < cond.size(1):
        chunk_cond = cond[:, processed_frames : processed_frames + max_source_window]
        is_last_chunk = processed_frames + max_source_window >= cond.size(1)
        cat_condition = torch.cat([prompt_condition, chunk_cond], dim=1)
        with torch.autocast(device_type=device.type, dtype=torch.float16):
            vc_target = model.cfm.inference(
                cat_condition,
                torch.LongTensor([cat_condition.size(1)]).to(mel2.device),
                mel2,
                style2,
                None,
                diffusion_steps,
                inference_cfg_rate=inference_cfg_rate,
            )
            vc_target = vc_target[:, :, mel2.size(-1) :]
        vc_wave = vocoder_fn(vc_target.float()).squeeze()[None, :]
        if processed_frames == 0:
            if is_last_chunk:
                generated_wave_chunks.append(vc_wave[0].cpu().numpy())
                break
            generated_wave_chunks.append(vc_wave[0, :-overlap_wave_len].cpu().numpy())
            previous_chunk = vc_wave[0, -overlap_wave_len:]
            processed_frames += vc_target.size(2) - overlap_frame_len
        elif is_last_chunk:
            generated_wave_chunks.append(seed_inf.crossfade(previous_chunk.cpu().numpy(), vc_wave[0].cpu().numpy(), overlap_wave_len))
            break
        else:
            generated_wave_chunks.append(seed_inf.crossfade(previous_chunk.cpu().numpy(), vc_wave[0, :-overlap_wave_len].cpu().numpy(), overlap_wave_len))
            previous_chunk = vc_wave[0, -overlap_wave_len:]
            processed_frames += vc_target.size(2) - overlap_frame_len

    vc_wave = torch.tensor(np.concatenate(generated_wave_chunks))[None, :].float()
    out_wav_path.parent.mkdir(parents=True, exist_ok=True)
    raw_tmp = out_wav_path.with_suffix(".rawvc.wav")
    torchaudio.save(str(raw_tmp), vc_wave.cpu(), sr)

    af = post_af if post_af else "highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=9"
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(raw_tmp), "-ac", "1", "-ar", "24000", "-af", af, "-c:a", "pcm_s16le", str(out_wav_path)],
        check=True,
    )
    raw_tmp.unlink(missing_ok=True)
    print(f"[vc] {out_wav_path.relative_to(AUD_ROOT)}")


async def make_tts_sources() -> dict[str, Path]:
    tmp = CLONE_OUT / "_tts_src"
    tmp.mkdir(parents=True, exist_ok=True)
    scripts = {
        "dawen_foyer": ("zh-HK-WanLungNeural", "+0%", "-4Hz", "楼梯全黑晒……先用工具钳拆开墙边个电表箱睇睇先。"),
        "dawen_meter": ("zh-HK-WanLungNeural", "+2%", "-2Hz", "三楼支路断咗电。先拆盖检查测试表同值班台备件。"),
        "dawen_stairs": ("zh-HK-WanLungNeural", "+5%", "+0Hz", "嘉敏仲喺三楼等紧我，先把楼梯灯整着先再上去！"),
        "zhihao_enter": ("zh-HK-WanLungNeural", "+8%", "+8Hz", "姐夫，我去二楼半后廊合备用闸。好快搞掂，楼梯口见！"),
        "jiamin_bunker": ("zh-HK-HiuMaanNeural", "+6%", "+2Hz", "大文、阿豪！千祈唔好由正门落嚟！后面有三道红衣人影堵死咗楼梯口，我而家经排风竖井走出去！"),
    }
    out = {}
    for k, (voice, rate, pitch, txt) in scripts.items():
        mp3 = tmp / f"{k}.mp3"
        wav = tmp / f"{k}.wav"
        await edge_tts.Communicate(txt, voice=voice, rate=rate, pitch=pitch).save(str(mp3))
        subprocess.run(
            ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(mp3), "-ac", "1", "-ar", "24000", "-c:a", "pcm_s16le", str(wav)],
            check=True,
        )
        out[k] = wav
    return out


def main() -> None:
    for d in (JIAMIN_OUT, GRANNY_OUT, BUS_OUT, CLONE_OUT):
        d.mkdir(parents=True, exist_ok=True)

    print("1) Generating Cantonese TTS carrier scripts for AI cloning...")
    tts_src = asyncio.run(make_tts_sources())

    print("2) Loading Seed-VC model on CUDA:", seed_inf.device)
    with torch.no_grad():
        bundle = seed_inf.load_models(ModelArgs(f0_condition=False, fp16=True))

        # A. Jiamin: User's male reading -> Female HK Cantonese (Option A HiuMaan, Option B HiuGaai)
        for i in ("01", "02", "03"):
            src = RAW_CLEAN / f"jiamin_{i}.wav"
            convert_one(bundle, src, REFS_DIR / "ref_jiamin_hiumaan.wav", JIAMIN_OUT / f"jiamin_{i}_hiumaan.wav", diffusion_steps=42, inference_cfg_rate=0.75)
            convert_one(bundle, src, REFS_DIR / "ref_jiamin_hiugaai.wav", JIAMIN_OUT / f"jiamin_{i}_hiugaai.wav", diffusion_steps=42, inference_cfg_rate=0.75)

        # B. Granny Chen: User's lowered male voice -> Elderly woman variants
        g_src = RAW_CLEAN / "granny.wav"
        convert_one(bundle, g_src, REFS_DIR / "ref_granny_real_judy_cc0.wav", GRANNY_OUT / "granny_A_real_judy.wav", diffusion_steps=48, inference_cfg_rate=0.78)
        convert_one(bundle, g_src, REFS_DIR / "ref_granny_real_rama_ccbysa.wav", GRANNY_OUT / "granny_B_real_rama.wav", diffusion_steps=48, inference_cfg_rate=0.78)
        convert_one(
            bundle, g_src, REFS_DIR / "ref_granny_crafted_warm.wav", GRANNY_OUT / "granny_C_warm_hk.wav",
            diffusion_steps=45, inference_cfg_rate=0.75,
            post_af="highpass=f=90,lowpass=f=4800,equalizer=f=240:t=q:w=1.2:g=2.5,atempo=0.96,loudnorm=I=-16:TP=-1.5:LRA=9",
        )

        # C. Female Bus PA variants (converting user's 3 bus announcements -> crisp HK female PA)
        bus_pa_af = "highpass=f=300,lowpass=f=4200,equalizer=f=1800:t=q:w=1.0:g=3.0,acompressor=threshold=-21dB:ratio=3:attack=10:release=120,aecho=0.8:0.85:22:0.12,loudnorm=I=-16:TP=-1.5:LRA=9"
        bus_anom_pa_af = "highpass=f=240,lowpass=f=3800,asetrate=24000*0.92,aresample=24000,atempo=1/0.92,aecho=0.78:0.75:38|78|135:0.30|0.18|0.10,tremolo=f=4.2:d=0.18,loudnorm=I=-16:TP=-1.5:LRA=10"
        convert_one(bundle, RAW_CLEAN / "bus_normal.wav", REFS_DIR / "ref_jiamin_hiugaai.wav", BUS_OUT / "bus_normal_pa_female.wav", diffusion_steps=40, inference_cfg_rate=0.75, post_af=bus_pa_af)
        convert_one(bundle, RAW_CLEAN / "bus_handrail_4lang.wav", REFS_DIR / "ref_jiamin_hiugaai.wav", BUS_OUT / "bus_handrail_4lang_pa_female.wav", diffusion_steps=40, inference_cfg_rate=0.75, post_af=bus_pa_af)
        convert_one(bundle, RAW_CLEAN / "bus_anomaly.wav", REFS_DIR / "ref_jiamin_hiugaai.wav", BUS_OUT / "bus_anomaly_pa_female.wav", diffusion_steps=40, inference_cfg_rate=0.75, post_af=bus_anom_pa_af)

        # D. Zero-shot Voice Cloning Demos in User's / Teammate's voices
        convert_one(bundle, tts_src["dawen_foyer"], RAW_CLEAN / "dawen_01_daily.wav", CLONE_OUT / "dawen_clone_01_foyer.wav", diffusion_steps=45, inference_cfg_rate=0.75)
        convert_one(bundle, tts_src["dawen_meter"], RAW_CLEAN / "dawen_02_tense.wav", CLONE_OUT / "dawen_clone_02_meter.wav", diffusion_steps=45, inference_cfg_rate=0.75)
        convert_one(bundle, tts_src["dawen_stairs"], RAW_CLEAN / "dawen_03_urgent.wav", CLONE_OUT / "dawen_clone_03_stairs.wav", diffusion_steps=45, inference_cfg_rate=0.75)
        convert_one(bundle, tts_src["zhihao_enter"], RAW_CLEAN / "zhihao_01.wav", CLONE_OUT / "zhihao_clone_01_enter.wav", diffusion_steps=45, inference_cfg_rate=0.75)
        convert_one(bundle, tts_src["jiamin_bunker"], JIAMIN_OUT / "jiamin_03_hiumaan.wav", CLONE_OUT / "jiamin_clone_01_bunker.wav", diffusion_steps=45, inference_cfg_rate=0.75)

    print("ALL_VC_JOBS_COMPLETE")


if __name__ == "__main__":
    main()
