# Audio replacement 122

The former `chase_urgent_026.wav` and `jumpscare_shriek_026.wav` assets had no recoverable source or license record. Their bytes are retained only in `tools/recovery/audio_provenance_unverified_20261117.zip`; the game asset tree now uses two original, reproducible cues from `tools/build_audio_replacements_122.py`.

- `chase_urgent_122.wav` is an eight-second loop built from generated low-frequency tones, deterministic noise, and double pulse accents. `AudioManager.start_chase_music()` still controls its loop playback.
- `jumpscare_shriek_122.wav` is a 2.2-second harmonic sweep with shaped noise. It contains no human voice or third-party sample and is loaded through the existing `jumpscare_shriek` world-effect key.
- Both are 24 kHz mono 16-bit PCM WAV. Per-file source records sit beside each asset; the directory manifest links these replacements to this note.
- Background checks can establish decoding, resource resolution, trigger behavior, and pause behavior. Listening quality, loudness balance, artistic fit, and fear response still require listening review.
