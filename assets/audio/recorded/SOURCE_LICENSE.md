# Opening and metal interaction audio

Retrieved / source licence checked: 2026-11-09. No original audio was re-encoded.

## Camera shutter

- Active file: `camera_shutter.wav`.
- Author: ristooooo1.
- Original recording: [DSLR Shutter fast 006.wav](https://freesound.org/people/ristooooo1/sounds/539136/).
- Original page explicitly lists Creative Commons 0.
- Downloaded mirror: https://remotion.media/shutter-modern.wav
- The [Remotion source documentation](https://www.remotion.dev/docs/sfx/shutter-modern) names the original recording, author, CC0 licence and mirror. This recording is used as the phone camera's shutter cue; it is not a newly recorded phone sound.

## Metal cover and entrance door

- Author: rubberduck.
- Source: [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx).
- Downloaded source archive: https://opengameart.org/sites/default/files/100-CC0-wood-metal-SFX.zip
- Licence link on original author page: https://creativecommons.org/publicdomain/zero/1.0/
- `metal_cover.ogg`: original `metal_sheet_01.ogg`, used when removing the metal maintenance cover.
- `entrance_door.ogg`: original `door_open_01.ogg`, used entering the tenement.
- Source HTML retained at `docs/review_sources/wood_metal_source.html`; complete source archive is in ignored `tools/audio_sources/`.

## Power switch

- Active file: `power_switch.wav`, downloaded from https://remotion.media/switch.wav .
- Author: Kenney, UI Audio / Switch 35, CC0, identified by [Remotion source documentation](https://www.remotion.dev/docs/sfx/ui-switch).
- Used for the in-game floor branch switch, distinct from cover removal and wood door cues.

## Bed scrape

- Active file: `bed_scrape.ogg`, original `scrape-2.ogg` from [Scrapes](https://opengameart.org/content/scrapes) by AntumDeluge, CC0.
- Recording source: an object dragged across a cinder block; used for the iron bed moving across flooring, not represented as a recording of this particular bed.
- Source archive: `tools/audio_sources/scrapes.zip`. Listening quality has not yet been reviewed in a live session.

## Rotary phone ring

- `rotary_ring.ogg`: [Fixed Telephone Ring #4](https://bigsoundbank.com/fixed-telephone-ring-4-s0253.html), Denis Chardonnet, CC0; downloaded Ogg stream from the source page. Listening quality remains to be reviewed.

## Shadow footsteps

- `shadow_step.ogg`: original `02-footstep.ogg` from [Footsteps](https://opengameart.org/content/footsteps-0), GboxMikeFozzy, CC0; a real subway walking recording, played in the shadow encounter. Listening quality still needs review.

## Mechanical lock

- `lock_mechanism.wav`: original `mechanical1.wav` from [Mechanical Sounds](https://opengameart.org/content/mechanical-sounds), Brian MacIntosh (BMacZero), CC0; used for the unlocking mechanism.

## Phone busy tone

- `phone_busy.ogg`: [Tone, busy #1](https://bigsoundbank.com/tone-busy-1-s1610.html), BigSoundBank, CC0. This is a French busy signal used as a game cue, not a claim of authentic Macau telephone signalling.

Camera, cover removal, entrance transition and power switch cues finish under the reading panel opened by the action. Wardrobe sounds keep the world-pause behaviour documented in their own folder. Background testing is silent and does not prove listening quality.

## Bunker ambience

- `bunker_ambience.ogg`: [Loopable Dungeon Ambience](https://opengameart.org/content/loopable-dungeon-ambience), JaggedStone, CC0. The track is used as a low-volume loop in the bunker and staircase. Its mix and atmosphere still require a listening review.
- `crypt_ambience.ogg`: [Dungeon Ambience](https://opengameart.org/content/dungeon-ambience), yd, CC0. Used in the maintenance passage and crypt; the mix still requires a listening review.

## Story and gate effects

- `door_knocks_025.ogg`: [Door](https://bigsoundbank.com/door-s0015.html), Joseph Sardin, CC0; used as a sudden knock while examining the old photograph.
- `gate_chain_025.wav`: `rattle1.wav` from [Mechanical Sounds](https://opengameart.org/content/mechanical-sounds), Brian MacIntosh, CC0; used for the chain.
- `gate_iron_025.ogg`: [Iron Door](https://opengameart.org/content/iron-door), themightyglider, CC0; used for the iron gate. Listening quality still requires review.

## Third-chapter balance mechanism

- `ch3_balance_weight.wav` and `ch3_balance_settle.wav`: original procedural synthesis written for this project in `tools/build_ch3_balance_sounds.py` on 2026-11-11. The sounds use synthesized inharmonic partials and short impact envelopes; no third-party recording or sample is included. The first cue is for brass/iron weights contacting the pan; the second is for the balance linkage and cabinet catch settling. Files are PCM WAV at 44.1 kHz mono. Background tests use Dummy audio and do not verify listening quality.

## Third-chapter archive pickups

- `archive_key_pickup.wav` and `archive_ticket_pickup.wav`: original procedural synthesis written for this project in `tools/build_ch3_archive_pickup_sounds.py` on 2026-11-11. The key cue uses short inharmonic metal strikes; the ticket cue uses shaped deterministic noise for a brief paper shuffle. No third-party recording or sample is included. Files are PCM WAV at 44.1 kHz mono. Background tests use Dummy audio and do not verify listening quality.

## Demo 026

- `../click.wav` is the project’s original short interface cue from `tools/build_sample_art.py`, used when advancing dialogue and confirming choices.
- `../demo/recording_fragment_026.wav` and `../demo/hall_wail_026.wav` use an excerpt of [Female high-pitched scream SFX](https://opengameart.org/content/female-high-pitched-scream-sfx), WuxiaScrub, CC0. The tape combines a filtered nonverbal cry with the rubberduck wood-hit recording listed above. V5: the 304 telephone uses hall_wail_026.wav; the bunker recorder uses recording_fragment_026.wav, avoiding a literal future-recording replay.
- `../demo/pit_drop_026.wav` uses [Fall of Stone](https://bigsoundbank.com/fall-of-stone-s1022.html), Joseph Sardin, CC0, with separated, filtered echoes.
- `../demo/door_approach_026.wav` adapts the credited footsteps above. `../demo/power_failure_026.wav`, `../demo/capture_hit_026.wav` and `../demo/capture_rush_026.wav` combine original synthesis with excerpts of the credited switch, cry and footsteps. `../demo/oil_drops_026.wav` is original synthesis. Source selection and mixing are recorded in `tools/build_demo_sounds.py`.
- `chase_urgent_122.wav` and `jumpscare_shriek_122.wav` in the demo folder are original procedural replacements created by `tools/build_audio_replacements_122.py`; see their adjacent `.source.md` files and `docs/audio_generation_122.md`. The legacy `_026.wav` files have unknown provenance and are excluded from game assets; byte-preserved copies and hashes are in `tools/recovery/audio_provenance_unverified_20261117.zip` for audit only.

## Bus pneumatic door mechanism (036)

- `bus_door_open_036.wav` and `bus_door_close_036.wav`: original procedural synthesis by the project, generated with `tools/build_bus_mechanism_sounds.py` on 2026-11-11. Shaped filtered noise, low-frequency actuator hum and a short latch impact; no third-party samples. PCM WAV, 24 kHz mono.
- `bus_replayed_fragment_037.wav` is generated by `tools/build_bus_mechanism_sounds.py` from `../demo/recording_fragment_026.wav`, preceded by a 0.22-second silent lead-in; it adds no recording or sample. It is the comparison track in the independent fixed bus mechanism sample. The UI trace is derived from decoded PCM samples.
- Tests use Dummy audio. Decoding, playback and pause checks do not constitute listening acceptance or authentication of a particular Macau bus sound.
