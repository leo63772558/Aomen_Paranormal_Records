from pathlib import Path
import html
import sys

DOCS_DIR = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6")
AUD_DIR = DOCS_DIR / "voice_audition"
OUT_HTML = DOCS_DIR / "voice_audition_board_v2.html"


def audio_rel(rel_path: str) -> str:
    full = AUD_DIR / rel_path
    if not full.exists():
        raise FileNotFoundError(f"Missing audition wav: {full}")
    return f"voice_audition/{rel_path.replace(chr(92), '/')}"


def card(group: str, value: str, title: str, subtitle: str, rel_wav: str, input_type: str = "radio", checked: bool = False) -> str:
    src = audio_rel(rel_wav)
    chk = " checked" if checked else ""
    return f"""
      <label class="sample-card">
        <div class="sample-top">
          <input type="{input_type}" name="{html.escape(group)}" value="{html.escape(value)}"{chk} />
          <div>
            <div class="sample-title">{html.escape(title)}</div>
            <div class="sample-sub">{html.escape(subtitle)} · <code>{html.escape(rel_wav)}</code></div>
          </div>
        </div>
        <audio controls preload="metadata" src="{html.escape(src)}"></audio>
      </label>"""


def main() -> int:
    sections = []

    # 1. Core Decision: Route A (Ready-made human-like LLM voices) vs Route B (Qwen3-TTS LLM direct clone of user/teammate) vs V1 Old EdgeTTS+SeedVC
    s1_cards = "".join([
        card("sec1_route_choice", "RouteA_ReadyMade_LLM (方案一：全现成自然港男/女语音大模型，零克隆)",
             "【方案一 · 现成男主】陈大文① 日常吐槽（Qwen3-VoiceDesign 直出）",
             "带叹气停顿、松弛地道港音，无需你们自己继续录音或克隆",
             "qwen3_v2/routeA_dawen_vd_01_daily.wav", "radio", True),
        card("sec1_route_choice", "RouteB_Direct_LLM_Clone (方案二：用你与队员原声喂 Qwen3-Base 端到端克隆)",
             "【方案二 · 你的声纹 LLM 直克】陈大文① 一楼电表箱",
             "不用 edge-tts 播音腔！由大模型按你的声纹直接吐出自然叹气与停顿",
             "qwen3_v2/routeB_dawen_clone_01_foyer.wav", "radio", False),
        card("sec1_extra", "routeA_dawen_vd_02",
             "【方案一 · 现成男主】陈大文② 楼梯全黑警觉自言自语",
             "压低声线+真实呼吸感，对比下面同句的方案二与旧版",
             "qwen3_v2/routeA_dawen_vd_02_foyer.wav", "checkbox", False),
        card("sec1_extra", "routeB_dawen_02_meter",
             "【方案二 · 你的声纹 LLM 直克】陈大文② 三楼支路断电检查",
             "用你 dawen-2 紧张干声直接克隆的真实对话感",
             "qwen3_v2/routeB_dawen_clone_02_meter.wav", "checkbox", False),
        card("sec1_extra", "routeB_dawen_03_stairs",
             "【方案二 · 你的声纹 LLM 直克】陈大文③ 急切救嘉敏",
             "情绪急促、不僵硬的真实语气起伏",
             "qwen3_v2/routeB_dawen_clone_03_stairs.wav", "checkbox", False),
        card("sec1_extra", "old_v1_dawen",
             "【反面参照 · 旧版 V1 播音腔】EdgeTTS + Seed-VC 旧克隆",
             "这就是刚才你听出很AI、像机械播音员的旧版流程，放旁边一眼/一耳听出区别",
             "cloned_demos/dawen_clone_01_foyer.wav", "checkbox", False),
        card("sec1_extra", "routeA_zhihao_vd",
             "【方案一 · 现成阿豪】19岁阳光香港后生仔（现成 VoiceDesign 直出）",
             "纯正港式后生仔语气「喂，姐夫！我而家上去二楼半…」",
             "qwen3_v2/routeA_zhihao_vd_01_daily.wav", "checkbox", False),
        card("sec1_extra", "routeB_zhihao_clone",
             "【方案二 · 队员声纹 LLM 直克】用你队员 zhihao_01 克隆新台词",
             "保留你队员自己的音色 + LLM 自然流利口语",
             "qwen3_v2/routeB_zhihao_clone_01_enter.wav", "checkbox", False),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="1. 总体配音路线二选一（现成大模型人声 vs 端到端LLM克隆你们声音）" data-group="sec1_route_choice">
      <h2>1. 核心路线对比：方案一（全现成零克隆人声）vs 方案二（LLM 直接克隆你们声纹）</h2>
      <p class="cat-desc">
        彻底扔掉旧版僵硬的 <code>edge-tts</code> 机械播音底座！改用对标 GPT-4o 实时对话架构的 <strong>端到端语音大模型 Qwen3-TTS-1.7B</strong>。
        请点开<strong>旧版参照</strong>再听<strong>方案一 / 方案二</strong>，选出你更想要的全篇配音路线！
      </p>
      <div class="samples-grid">{s1_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：如喜欢方案一的大文/方案二的阿豪，或者两套混搭..." /></div>
    </section>""")

    # 2. Huang Jiamin (Drop male-to-female conversion completely! Pure HK Cantonese Female options)
    s2_cards = "".join([
        card("sec2_jiamin_v2", "hk_cantonese_343 (专训香港女声 hk_voice_343 · 推荐主声线)",
             "【推荐 · 现成港女 A】黄嘉敏 · 专训香港粤语女声（日常+大三巴）",
             "真人语调微升、自然播客级香港女生口音，彻底告别男转女",
             "qwen3_v2/routeA_jiamin_hk_01_daily.wav", "radio", True),
        card("sec2_jiamin_v2", "hk_cantonese_777 (专训香港女声 hk_voice_777 · 温柔姐姐)",
             "【现成港女 B】另一位专训香港粤语女声（更温和稳重）",
             "同一香港模型自带第二位自然港女声，适合温柔理性版本",
             "qwen3_v2/routeA_hk777_sample.wav", "radio", False),
        card("sec2_jiamin_v2", "vd_jiamin_daily (Qwen3-VoiceDesign 情景港女)",
             "【现成港女 C】VoiceDesign 情景演绎日常港女",
             "活泼带笑意，适合日常轻喜剧开场",
             "qwen3_v2/routeA_jiamin_vd_01_daily.wav", "radio", False),
        card("sec2_jiamin_extra", "hk_jiamin_304",
             "专训港女 A · 304 发现旧门与约定暗号（敲两下停一停）",
             "实测冷静调查段落的自然停顿与咬字",
             "qwen3_v2/routeA_jiamin_hk_02_304.wav", "checkbox", True),
        card("sec2_jiamin_extra", "hk_jiamin_bunker",
             "专训港女 A · 防空洞求生留言（大文阿豪千祈唔好落嚟！）",
             "紧迫感下依然咬字清晰地道",
             "qwen3_v2/routeA_jiamin_hk_03_bunker.wav", "checkbox", True),
        card("sec2_jiamin_extra", "vd_jiamin_scared",
             "VoiceDesign 情景港女 · 304 惊恐喘气催逃（情绪拉满！）",
             "强推试听！险境急促喘气极其像真人女演员配音",
             "qwen3_v2/routeA_jiamin_vd_02_scared.wav", "checkbox", True),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="2. 黄嘉敏（已弃用男转女 · 全新现成地道港女声）" data-group="sec2_jiamin_v2">
      <h2>2. 黄嘉敏（女主）· 已彻底取消男转女，改用现成地道港女声</h2>
      <p class="cat-desc">不再用你的声音转换。这里提供两位纯正香港粤语专训女声 + 可带强烈情绪演出的 VoiceDesign 港女声，实机可按剧情（日常 vs 惊恐求生）匹配。</p>
      <div class="samples-grid">{s2_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：如喜欢女声A平时对话 + 女声C做惊恐片段..." /></div>
    </section>""")

    # 3. Granny Chen (Ready-made authentic Cantonese Grandma)
    s3_cards = "".join([
        card("sec3_granny_v2", "granny_vd_02_female (慈祥地道香港阿婆 · 推荐)",
             "【现成阿婆 A · 推荐】75 岁慈祥澳门/香港老婆婆",
             "一听就是慈祥真实老太太粤语，带自然慢速长辈叮嘱感",
             "qwen3_v2/routeA_granny_vd_02_female.wav", "radio", True),
        card("sec3_granny_v2", "granny_vd_01_warm (讲旧楼鬼故事阴森阿婆)",
             "【现成阿婆 B】72 岁街头讲福荣里怪谈阿婆（含压低神秘感）",
             "后半句讲黑袍老人压低嗓音很有街坊讲鬼故氛围",
             "qwen3_v2/routeA_granny_vd_01_warm.wav", "radio", False),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="3. 葡挞档陈阿婆（现成真实老阿婆粤语）" data-group="sec3_granny_v2">
      <h2>3. 葡挞档陈阿婆 · 全新现成老太太粤语（告别男声硬转）</h2>
      <p class="cat-desc">直接由语音大模型生成高龄女性自然粤语腔调，无需男声拟合。</p>
      <div class="samples-grid">{s3_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注..." /></div>
    </section>""")

    # 4. Kept Team Highlights (Bus 4-lang + Teammate Raw Ah Hao / Liang)
    s4_cards = "".join([
        card("sec4_keep_team", "keep_bus_4lang_orig",
             "【强烈建议保留真人原声】你录的四语澳门巴士「请紧握扶手」（车厢喇叭版）",
             "粤/葡/普/英四语循环太地道，已调好巴士车厢喇叭质感",
             "bus_fx/bus_handrail_4lang_pa_orig.wav", "checkbox", True),
        card("sec4_keep_team", "keep_bus_anom_orig",
             "【原声车厢特调】33 路异象报站「下一站枉死坡，千祈唔好落车」",
             "后段阴冷慢变调+金属回声，极有恐怖代入感",
             "bus_fx/bus_anomaly_pa_orig.wav", "checkbox", True),
        card("sec4_keep_team", "keep_zhihao_03_reverb",
             "【保留队员原声名场面】黄梓豪 99 级石阶断臂哭腔（石阶混响精修版）",
             "队员真人哭腔喘息+临终遗言（zhihao_04）比任何AI都更有感染力",
             "mastered/zhihao_03_ghost_reverb.wav", "checkbox", True),
        card("sec4_keep_team", "keep_zhihao_04",
             "【保留队员原声名场面】黄梓豪楼梯口临终遗言",
             "真情实感断气「唔好理我，快啲去救我姐」",
             "mastered/zhihao_04_dying.wav", "checkbox", True),
        card("sec4_keep_team", "keep_liang_01",
             "【保留队员原声配角】凉茶档梁伯（已压低换气声+暖声均衡）",
             "原声本就苍老自然，完全不用重生成",
             "mastered/uncle_liang_01_clean.wav", "checkbox", True),
        card("sec4_keep_team", "keep_driver_pa",
             "【保留队员原声配角】33 路夜班巴士司机「投六蚊唔设找赎」",
             "车厢驾驶室对讲感十足",
             "mastered/bus_driver_pa.wav", "checkbox", True),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="4. 建议直接保留的你们真人亮点录音" data-group="sec4_keep_team">
      <h2>4. 你们录得非常好的真人片段（建议直接保留进游戏，完全不经 AI）</h2>
      <p class="cat-desc">以下几段你们本人与队员演得极其到位，尤其 4 语扶手广播、阿豪哭腔与梁伯，真人表演比任何模型都自然。</p>
      <div class="samples-grid">{s4_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：如巴士报站要不要改用纯女声等..." /></div>
    </section>""")

    page_html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>《澳诡实录》V6 配音 V2 对比试听：现成无 AI 感人声 vs 端到端 LLM 克隆</title>
<style>
  :root {{
    --bg: #0c1310;
    --panel: #131e19;
    --card: #192821;
    --border: #435749;
    --gold: #ebd494;
    --text: #e2e5d5;
    --muted: #98aa9d;
    --accent: #a64b3f;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 24px 18px 96px;
    background: radial-gradient(circle at top, #16231d 0%, var(--bg) 65%);
    color: var(--text);
    font-family: "Microsoft YaHei", "SimSun", system-ui, sans-serif;
    line-height: 1.55;
  }}
  .wrap {{ max-width: 1080px; margin: 0 auto; }}
  header {{
    border: 1px solid var(--gold);
    background: linear-gradient(135deg, rgba(25,40,33,0.95), rgba(14,22,18,0.98));
    padding: 20px 24px;
    border-radius: 6px;
    margin-bottom: 22px;
  }}
  h1 {{ margin: 0 0 8px; color: var(--gold); font-size: 22px; letter-spacing: 1px; }}
  .lead {{ margin: 0; color: var(--muted); font-size: 14px; }}
  .badge {{
    display: inline-block; margin-top: 10px; padding: 3px 10px;
    background: rgba(166,75,63,0.22); border: 1px solid var(--accent);
    color: #f3c4bc; font-size: 12px; border-radius: 3px;
  }}
  .cat-box {{
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 18px 20px;
    margin-bottom: 18px;
  }}
  .cat-box h2 {{ margin: 0 0 4px; color: var(--gold); font-size: 17px; }}
  .cat-desc {{ margin: 0 0 12px; color: var(--muted); font-size: 13px; }}
  .samples-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(450px, 1fr)); gap: 12px; }}
  .sample-card {{
    display: flex; flex-direction: column; gap: 8px;
    background: var(--card); border: 1px solid #2c3d32;
    border-radius: 5px; padding: 12px 14px; cursor: pointer;
    transition: border-color .15s, background .15s;
  }}
  .sample-card:hover {{ border-color: var(--gold); }}
  .sample-card:has(input:checked) {{
    border-color: var(--gold);
    background: #203429;
    box-shadow: 0 0 0 1px rgba(235,212,148,0.35);
  }}
  .sample-top {{ display: flex; align-items: flex-start; gap: 10px; }}
  .sample-top input {{ margin-top: 4px; transform: scale(1.2); accent-color: var(--gold); }}
  .sample-title {{ font-weight: 600; font-size: 14px; color: #f2f1e4; }}
  .sample-sub {{ font-size: 11px; color: var(--muted); margin-top: 2px; word-break: break-all; }}
  code {{ color: #c7d9b8; font-size: 11px; }}
  audio {{ width: 100%; height: 34px; }}
  .note-row {{ margin-top: 10px; }}
  .cat-note {{
    width: 100%; padding: 8px 10px; border-radius: 4px;
    border: 1px solid #384a3e; background: #0f1713; color: var(--text);
    font-size: 13px;
  }}
  .sticky-bar {{
    position: fixed; left: 0; right: 0; bottom: 0;
    background: rgba(10,16,13,0.96); border-top: 1px solid var(--gold);
    padding: 12px 24px; display: flex; align-items: center; justify-content: center; gap: 16px;
    z-index: 99;
  }}
  .btn {{
    background: var(--gold); color: #101712; border: 0; border-radius: 4px;
    padding: 10px 22px; font-weight: 700; font-size: 14px; cursor: pointer;
  }}
  .btn:hover {{ filter: brightness(1.08); }}
  .status-txt {{ color: var(--muted); font-size: 13px; }}
  #resultOut {{
    width: 100%; min-height: 150px; background: #0b110e; color: #dce8cf;
    border: 1px solid var(--border); border-radius: 4px; padding: 12px;
    font-family: Consolas, monospace; font-size: 12px; margin-top: 10px;
  }}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>《澳诡实录》V6 配音 V2 对比试听：现成无 AI 感人声 vs 端到端 LLM 克隆</h1>
    <p class="lead">
      已彻底淘汰 V1 僵硬的 <code>edge-tts + Seed-VC</code> 播音腔流程，全部改由本地 <strong>RTX 4060 · Qwen3-TTS-1.7B 端到端语音大模型</strong>生成（对标 GPT-4o 实时对话语音的自然呼吸、停顿与地道港澳粤语口吻）。女生也已完全改用现成地道港女声与老阿婆，不再强行男转女。
    </p>
    <span class="badge">先对比第 1 组「旧版参照」和「方案一 / 方案二」，点播选定后复制发给我即可定稿</span>
  </header>

  {''.join(sections)}

  <section class="cat-box">
    <h2>生成配音路线审批文本（复制直接发给 AI）</h2>
    <textarea id="resultOut" readonly></textarea>
  </section>
</div>

<div class="sticky-bar">
  <span class="status-txt" id="summaryBadge">请点播对比方案一与方案二并选择</span>
  <button class="btn" id="copyBtn" type="button">一键复制 V2 路线拍板结果</button>
</div>

<script>
  function collect() {{
    const lines = ['【《澳诡实录》V6 配音 V2 路线审批结果】'];
    document.querySelectorAll('section.cat-box[data-cat]').forEach(sec => {{
      const cat = sec.dataset.cat;
      const checked = Array.from(sec.querySelectorAll('input[type="radio"]:checked, input[type="checkbox"]:checked'))
        .map(el => el.closest('label').querySelector('.sample-title').textContent.trim() + ' (' + el.value + ')');
      const note = (sec.querySelector('.cat-note')?.value || '').trim();
      lines.push('');
      lines.push('■ ' + cat);
      lines.push('  选中：' + (checked.length ? checked.join('；') : '（暂未勾选）'));
      if (note) lines.push('  备注：' + note);
    }});
    const out = lines.join('\\n');
    document.getElementById('resultOut').value = out;
    return out;
  }}
  document.addEventListener('change', collect);
  document.addEventListener('input', collect);
  document.getElementById('copyBtn').addEventListener('click', async () => {{
    const txt = collect();
    try {{
      await navigator.clipboard.writeText(txt);
      document.getElementById('summaryBadge').textContent = '已复制到剪贴板，直接粘贴发给我即可！';
    }} catch {{
      document.getElementById('resultOut').select();
      document.execCommand('copy');
      document.getElementById('summaryBadge').textContent = '已选中下方文本，按 Ctrl+C 复制发给我！';
    }}
  }});
  collect();
</script>
</body>
</html>
"""
    OUT_HTML.write_text(page_html, encoding="utf-8")
    print(f"WROTE {OUT_HTML} ({OUT_HTML.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
