# 《澳诡实录》V6 已实装正式音频来源与许可台账

以下 6 类音频已由用户试听并正式审批通过，转码至 `assets/audio/v6/`（16-bit PCM WAV）：

| 游戏内资产路径 | 原始素材 / 作者 | 来源 | 许可协议 | 游戏内用途 |
| --- | --- | --- | --- | --- |
| `bgm_main_menu_v6.wav` | Rafael Krux — *Lights (Creepy Ambient Suspense)* | Wikimedia Commons (`File:Rafael Krux - Lights - Creepy Ambient Suspense (cc-by) (filmmusic).mp3`) | CC-BY 4.0 (Filmmusic) | 主界面恐怖低沉氛围 BGM（已移除旧街道杂音） |
| `menu_footsteps_v6.wav` | *Pasos en escalera de caracol* | Wikimedia Commons (`File:Pasos en escalera de caracol.ogg`) | CC / Wikimedia Commons | 主界面偶发石阶轻脚步氛围音效 |
| `menu_door_knock_v6.wav` | *Knocking on wood or door* | Wikimedia Commons (`File:Knocking on wood or door.ogg`) | CC0 / Wikimedia Commons | 主界面偶发轻敲木门两下氛围音效 |
| `chase_stalker_v6.wav` | Rafael Krux — *Horror Suspense* | Wikimedia Commons (`File:Rafael Krux - Horror Suspense.ogg`) | CC-BY 4.0 (Filmmusic) | 序章 / 长发鬼追逐 BGM |
| `chase_family_v6.wav` | Kevin MacLeod — *Controlled Chaos* | Wikimedia Commons (`File:Controlled Chaos (ISRC USUAN1200059).mp3`) | CC-BY 3.0 / 4.0 | 第二章防空洞红衣鬼与 99 级鬼阶追逐 BGM |
| `cantonese_opera_butterfly_v6.wav` | 78 转粤剧唱片《蝴蝶梦》选段 (`GSC 521 A.0`) | Internet Archive (`gsc-521-a.-0`) | Public Domain（历史 78 转唱片） | 第三章大关斜巷肉铺老收音机真实粤剧背景声 |
| `jiamin_scream_phone_v6.wav` | *Scream-c* | Wikimedia Commons (`File:Scream-c.wav`) | CC0 / Wikimedia Commons | 304 嘉敏手机回拨听筒惊恐尖叫（电话听筒带通处理） |
| `recording_fragment_v6.wav` | *Scream-c* | Wikimedia Commons (`File:Scream-c.wav`) | CC0 / Wikimedia Commons | 第二章防空洞采访录音机与巴士录音对照（微型录音机滤波处理） |
| `chase_butcher_v6.wav` | Kevin MacLeod — *Volatile Reaction* | Internet Archive (`Kevin-Macleod_Action-Cuts_2014_FullAlbum`) | CC-BY 3.0 / 4.0 | 第三章肉铺屠夫 & 第五章黑沙海滩屠夫追逐 BGM |
| `jumpscare_wraith_v6.wav` | *Half grown monster screaming* (Craig Smith / USC SSE) | Internet Archive (`SSE_Library_CREATURES`) | Public Domain / Educational Archive | 长发鬼与怨灵扑脸狂暴尖啸（`jumpscare_wraith` / `jumpscare_shriek`） |
| `jumpscare_butcher_v6.wav` | *Werewolf growls; grunts* (Craig Smith / USC SSE) | Internet Archive (`SSE_Library_CREATURES`) | Public Domain / Educational Archive | 屠夫与终章恶灵扑咬低吼（`jumpscare_butcher` / `boss_roar_impact`） |
| `jumpscare_family_v6.wav` | *Horror Scream With Echo* | Internet Archive (`horror-scream-with-echo-sound-effect_202507`) | Public Domain / Archive.org | 防空洞与阶梯突袭回声惊吓尖叫（`jumpscare_family` / `hall_wail`） |
| `peephole_grudge_croak_v6.wav` | *The Grudge Sound* | Internet Archive (`thegrudgesoundringtonesforandroidscaryringtones`) | Archive.org Free SFX | 304 猫眼贴眼与贴近低语喉音鬼叫（`peephole_grudge_croak` / `ghost_taunt_whisper`） |

## V6 终版纯正港澳粤语配音包台账（`assets/audio/v6/voice/`，共 29 条）

> 按 2026-11-26 用户终版试玩要求：**删除全部团队普通台词真人录音**，仅保留用户指定的 **四语巴士扶手广播** `bus_handrail_4lang_v6.wav`；其余 28 条采用纯港澳粤语专训管线生成并经逐条实际试听校验——10 条嘉敏＋2 条报站使用 `hk-cantonese-female (hk_voice_343)`，2 条陈阿婆使用 `hk_voice_343 → Seed-VC`（同性别音色转换），14 条男声（黄梓豪/陈大文/梁伯/巴士司机）改用原生粤语克隆模型 `hk-cantonese-base` 对齐洁净 V2 参考声纹直出，消除男女跨声源 Seed-VC 产生的金属 AI 感与误读。

| 游戏内资产路径 | 角色 / 用途 | 生成与声纹定型管线 | 许可 / 归属 | 触发场景 |
| --- | --- | --- | --- | --- |
| `bus_handrail_4lang_v6.wav` | 新福利四语扶手广播 | 团队指定保留真人原声（粤/葡/普/英，车厢广播均衡） | 团队自有版权 | 过场投币上车 & 第四章 33 路末班车周期广播 |
| `bus_normal_pa_v6.wav` | 33 路正常报站（纯港粤女声） | `hk-cantonese-female (hk_voice_343)` + 车厢广播均衡 | Apache-2.0 模型生成 | 第四章 33 路末班车正常电子报站屏 |
| `bus_anomaly_pa_v6.wav` | 33 路异象报站（枉死坡） | `hk-cantonese-female (hk_voice_343)` + 车厢异象降调混响 | Apache-2.0 模型生成 | 第四章 33 路异象报站屏（枉死坡） |
| `bus_driver_pa_v6.wav` | 新福利巴士司机 | `hk-cantonese-base` 直出克隆（洁净司机 V2 固定声纹） | 项目生成 | 序章过场换乘新福利巴士提示 |
| `uncle_liang_01_v6.wav` | 凉茶档梁伯（初见） | `hk-cantonese-base` 直出克隆（梁伯 V2 固定声纹） | 项目生成 | 序章大三巴街凉茶档初遇嘱咐 |
| `uncle_liang_02_v6.wav` | 凉茶档梁伯（再访） | `hk-cantonese-base` 直出克隆（梁伯 V2 固定声纹） | 项目生成 | 序章大三巴街凉茶档重复对话 |
| `ahhao_street_01_v6.wav` | 黄梓豪（大三巴开场） | `hk-cantonese-base` 直出克隆（洁净阿豪 V2 固定声纹） | 项目生成 | 序章初抵大三巴街试灯开拍 |
| `ahhao_enter_v6.wav` | 黄梓豪（入楼分工） | `hk-cantonese-base` 直出克隆（洁净阿豪 V2 固定声纹） | 项目生成 | 序章进唐楼前合闸分工 |
| `ahhao_chase_panic_v6.wav` | 黄梓豪（后廊遇袭） | `hk-cantonese-base` 直出克隆（洁净阿豪 V2 固定声纹） | 项目生成 | 序章二楼半后廊遭遇怨灵追逐 |
| `ahhao_dying_v6.wav` | 黄梓豪临终遗言 | `hk-cantonese-base` 直出克隆（洁净阿豪 V2 固定声纹） | 项目生成 | 序章唐楼楼梯口挡怪临终台词 |
| `ahhao_ghost_99_v6.wav` | 黄梓豪幻听（99 级石阶） | `hk-cantonese-base` 直出克隆（洁净阿豪 V2 + 石阶混响） | 项目生成 | 第二章 99 级石阶下行第 24 级幻听诱骗 |
| `dawen_pastry_reply_v6.wav` | 陈大文（聊葡挞猪扒包） | `hk-cantonese-base` 直出克隆（大文 V2 固定声纹） | 项目生成 | 序章大三巴街接过葡挞调侃 |
| `dawen_knock_reply_v6.wav` | 陈大文（复述敲门暗号） | `hk-cantonese-base` 直出克隆（大文 V2 固定声纹） | 项目生成 | 序章与嘉敏确认两下再一下暗号 |
| `dawen_foyer_v6.wav` | 陈大文（一楼玄关） | `hk-cantonese-base` 直出克隆（大文 V2 固定声纹） | 项目生成 | 序章一楼玄关停电调查电表 |
| `dawen_meter_v6.wav` | 陈大文（检查电表） | `hk-cantonese-base` 直出克隆（大文 V2 固定声纹） | 项目生成 | 序章拆开一楼检修箱 |
| `dawen_stairs_v6.wav` | 陈大文（楼梯修灯） | `hk-cantonese-base` 直出克隆（大文 V2 固定声纹） | 项目生成 | 序章修好三楼照明准备上楼 |
| `dawen_ch6_answer_ahhao_v6.wav` | 陈大文（终章答阿豪下落） | `hk-cantonese-base` 直出克隆（大文 V2 固定声纹） | 项目生成 | 终章救出嘉敏后交代阿豪牺牲 |
| `jiamin_photo_invite_v6.wav` | 黄嘉敏（大三巴合照邀请） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 序章邀请大文退后拍进大三巴牌坊 |
| `jiamin_photo_done_v6.wav` | 黄嘉敏（拍照完成打趣） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 序章大三巴拍完合照评价构图 |
| `jiamin_pastry_offer_v6.wav` | 黄嘉敏（递安德鲁葡挞） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 序章递出刚出炉葡挞 |
| `jiamin_pastry_plan_v6.wav` | 黄嘉敏（提议探 304 暗门） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 序章说明看半小时与请吃水蟹粥 |
| `jiamin_knock_v6.wav` | 黄嘉敏（约定敲门暗号） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 序章约定两下一停再一下暗号 |
| `jiamin_enter_v6.wav` | 黄嘉敏（先行上 304） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 序章入唐楼分头行动 |
| `jiamin_304_scared_v6.wav` | 黄嘉敏（304 手机求救） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 序章 304 房接通嘉敏来电惊呼 |
| `jiamin_bunker_tape_v6.wav` | 黄嘉敏（防空洞录音带留言） | `hk-cantonese-female (hk_voice_343)` + 录音带带通滤波 | Apache-2.0 模型生成 | 第二章拾取录音机 & 背包双轨播放 |
| `jiamin_ch6_wall_v6.wav` | 黄嘉敏（终章隔墙弱声） | `hk-cantonese-female (hk_voice_343)` + 隔墙低通滤波 | Apache-2.0 模型生成 | 终章管道敲击确认嘉敏仍在隔离舱 |
| `jiamin_ch6_where_ahhao_v6.wav` | 黄嘉敏（终章追问阿豪） | `hk-cantonese-female (hk_voice_343)` 纯港粤固定女声 | Apache-2.0 模型生成 | 终章获救后追问「阿豪呢？」 |
| `granny_chen_01_v6.wav` | 葡挞档陈阿婆（初见传闻） | `hk_voice_343` 纯港粤母带 + `Seed-VC`（阿婆 A 固定声纹） | 项目生成 | 序章葡挞档讲述福荣里黑袍传闻（改纯粤用词修复「樓梯/聲」误读） |
| `granny_chen_02_v6.wav` | 葡挞档陈阿婆（再访） | `hk_voice_343` 纯港粤母带 + `Seed-VC`（阿婆 A 固定声纹） | 项目生成 | 序章葡挞档重复对话提醒趁热吃 |
