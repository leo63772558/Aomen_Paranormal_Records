from pathlib import Path
import html
import sys

DOCS_DIR = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6")
AUD_DIR = DOCS_DIR / "voice_audition"
OUT_HTML = DOCS_DIR / "voice_audition_board.html"


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

    # 1. Huang Jiamin (Male -> Realistic Young HK Female)
    s1_cards = "".join([
        card("sec1_jiamin_voice", "44k_F0_HiuGaai (44kHz 高清少女音高引导 · 推荐)", "方案 A · 嘉敏① 44kHz 高清转换（少女声纹＋自然女声起伏）", "F0 音高引导 + 44kHz BigVGAN，自然且「趁热食」收尾完整", "jiamin_vc/jiamin_01_f0_44k.wav", "radio", True),
        card("sec1_jiamin_voice", "HiuMaan (22kHz 温和知性港女)", "方案 B · 嘉敏① 日常葡挞（温和知性港女声线）", "保留你的粤语语调，偏温柔成熟女声", "jiamin_vc/jiamin_01_hiumaan.wav", "radio", False),
        card("sec1_jiamin_voice", "HiuGaai (22kHz 清亮港女)", "方案 C · 嘉敏① 日常葡挞（清亮港女声线）", "明快清晰的年轻港女声线", "jiamin_vc/jiamin_01_hiugaai.wav", "radio", False),
        card("sec1_jiamin_extra", "jiamin_02_hiumaan", "对比对照 · 嘉敏② 304 发现旧门（温和港女）", "压低声音调查感", "jiamin_vc/jiamin_02_hiumaan.wav", "checkbox", False),
        card("sec1_jiamin_extra", "jiamin_02_hiugaai", "对比对照 · 嘉敏② 304 发现旧门（清亮少女）", "调查对话清晰咬字", "jiamin_vc/jiamin_02_hiugaai.wav", "checkbox", False),
        card("sec1_jiamin_extra", "jiamin_03_hiumaan", "对比对照 · 嘉敏③ 门外异变惊逃（温和港女）", "紧张急促求生感", "jiamin_vc/jiamin_03_hiumaan.wav", "checkbox", False),
        card("sec1_jiamin_extra", "jiamin_03_hiugaai", "对比对照 · 嘉敏③ 门外异变惊逃（清亮少女）", "急促偏高紧张感", "jiamin_vc/jiamin_03_hiugaai.wav", "checkbox", False),
        card("sec1_jiamin_extra", "raw_jiamin_01", "【原声参照】你的原始录音 jiamin1（降噪归一化）", "用于对比 AI 女声转换前后差别", "raw_clean/jiamin_01.wav", "checkbox", False),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="1. 黄嘉敏 · 男声转真实女声方案" data-group="sec1_jiamin_voice">
      <h2>1. 黄嘉敏（女主）· AI 男声转真实港女声对比</h2>
      <p class="cat-desc">完整保留你自己的港澳粤语断句、停顿和表演张力，由 RTX 4060 本地 Seed-VC 换成自然年轻女声（先单选喜欢的整体声线方案 A/B/C，其余卡片可点播对比）。</p>
      <div class="samples-grid">{s1_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：如想更年轻一点 / 某一句咬字再调..." /></div>
    </section>""")

    # 2. Granny Chen (Male lowered -> Authentic Elderly Female)
    s2_cards = "".join([
        card("sec2_granny_voice", "granny_D_f0_judy (44kHz 音高引导 · 真老阿婆声纹 · 推荐)", "方案 A（推荐）· 真·75岁老奶奶声纹 + 44kHz 音高引导", "自动将男声压低音域转进真实老太太女声，带自然老人气声微颤", "granny_vc/granny_D_f0_judy.wav", "radio", True),
        card("sec2_granny_voice", "granny_C_lifted_judy (提音前置+真老阿婆声纹)", "方案 B · 预提半音后再转真老奶奶声纹", "保留更重沧桑沙哑与略慢老街坊语速", "granny_vc/granny_C_lifted_judy.wav", "radio", False),
        card("sec2_granny_voice", "granny_E_f0_hk_elder (44kHz 港式暖声阿婆)", "方案 C · 港式柔和陈阿婆（偏慈祥少沙哑）", "港音更重、柔和慈祥老人女声", "granny_vc/granny_E_f0_hk_elder.wav", "radio", False),
        card("sec2_granny_voice", "granny_B_real_rama (72岁亚洲老阿婆)", "方案 D · 真·72岁亚洲老阿婆声纹直转", "厚实醇和，带轻微市井阿婆韵味", "granny_vc/granny_B_real_rama.wav", "radio", False),
        card("sec2_granny_extra", "raw_granny", "【原声参照】你的原始录音 granny（压低男声）", "对比前后变声效果", "raw_clean/granny.wav", "checkbox", False),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="2. 葡挞档陈阿婆 · 男声转老人女声方案" data-group="sec2_granny_voice">
      <h2>2. 葡挞档陈阿婆 · AI 男声转真实老人女声</h2>
      <p class="cat-desc">实测常规转换还会偏男声/年轻女声，所以我加跑了 <strong>44kHz 音高引导 + 真实老奶奶声纹</strong> 版本（保留你念的港式粤语「新鲜出炉拿稳呀……」），请四选一。</p>
      <div class="samples-grid">{s2_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：如喜欢方案A的老太太音色 / 希望再老或再沙哑一点..." /></div>
    </section>""")

    # 3. Macau Bus PA (including 4-language handrail)
    s3_cards = "".join([
        card("sec3_bus_voice", "female_pa (AI女声巴士车厢喇叭)", "女声广播版 ① · 下一站：黑沙海滩（正常）", "Seed-VC 转清晰女声 + 巴士广播频段 EQ", "bus_fx/bus_normal_pa_female.wav", "radio", True),
        card("sec3_bus_voice", "orig_pa (保留原声巴士车厢喇叭)", "原声广播版 ① · 下一站：黑沙海滩（正常）", "保留你的配音 + 巴士广播喇叭音染", "bus_fx/bus_normal_pa_orig.wav", "radio", False),
        card("sec3_bus_extra", "handrail_female", "女声广播版 ② · 四语循环「请紧握扶手」（粤/葡/普/英）", "葡语 Segure o corrimão 等四语完整女声广播", "bus_fx/bus_handrail_4lang_pa_female.wav", "checkbox", True),
        card("sec3_bus_extra", "handrail_orig", "原声广播版 ② · 四语循环「请紧握扶手」（粤/葡/普/英）", "你的四语原声 + 真实巴士车厢喇叭混响", "bus_fx/bus_handrail_4lang_pa_orig.wav", "checkbox", False),
        card("sec3_bus_extra", "anom_female", "女声异象版 ③ · 下一站枉死坡，千祈唔好落车（阴冷慢变调）", "女声后段低沉拉长+冷车厢金属回声", "bus_fx/bus_anomaly_pa_female.wav", "checkbox", True),
        card("sec3_bus_extra", "anom_orig", "原声异象版 ③ · 下一站枉死坡，千祈唔好落车（阴冷慢变调）", "原声加诡异降调与金属车厢回声", "bus_fx/bus_anomaly_pa_orig.wav", "checkbox", False),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="3. 澳门 33 路巴士报站 & 四语安全广播" data-group="sec3_bus_voice">
      <h2>3. 澳门巴士三条报站（含粤/葡/普/英「紧握扶手」神细节！）</h2>
      <p class="cat-desc">你加的那条四语「紧握扶手」太地道了！这里做了「保留你的原声加车厢喇叭」和「AI 转为女声巴士报站」两套，请选一套为主。</p>
      <div class="samples-grid">{s3_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：如四语播报希望循环间距多长、异象要不要更吓人..." /></div>
    </section>""")

    # 4. Teammate (Ah Hao & Uncle Liang & Bus Driver) + Da Wen Mastered
    s4_cards = "".join([
        card("sec4_teammate", "dawen_mastered", "陈大文①（你的原声母带 · 清理平衡版）", "保留你自然松弛吐槽，后续作大文克隆声纹", "mastered/dawen_01_daily.wav", "checkbox", True),
        card("sec4_teammate", "zhihao_01", "黄梓豪① · 序章大三巴拍照（队员原声精修）", "阳光少年感，已去底噪并对齐音量", "mastered/zhihao_01_daily.wav", "checkbox", True),
        card("sec4_teammate", "zhihao_02", "黄梓豪② · 二楼半灯闪被追（队员原声精修）", "喘气慌张感极好！", "mastered/zhihao_02_chase.wav", "checkbox", True),
        card("sec4_teammate", "zhihao_03_reverb", "黄梓豪③ · 99 级石阶怨魂（石梯冷混响版）", "在队员颤抖哭腔上叠加阴冷湿石阶混响", "mastered/zhihao_03_ghost_reverb.wav", "checkbox", True),
        card("sec4_teammate", "zhihao_04", "黄梓豪④ · 楼梯口临终遗言（队员原声精修）", "「唔好理我，快啲去救我姐」情绪非常真实", "mastered/zhihao_04_dying.wav", "checkbox", True),
        card("sec4_teammate", "liang_01", "梁伯① · 凉茶档劝告（已弱化重呼吸+暖老声EQ）", "保留苍老感，压低原录换气鼻息声", "mastered/uncle_liang_01_clean.wav", "checkbox", True),
        card("sec4_teammate", "driver_pa", "33 路司机 · 投六蚊唔设找赎（驾驶室广播质感）", "低沉冷淡，已调出夜班巴士驾驶室质感", "mastered/bus_driver_pa.wav", "checkbox", True),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="4. 陈大文、黄梓豪、梁伯与司机精修验收" data-group="sec4_teammate">
      <h2>4. 你的大文母带 + 队员「阿豪 / 梁伯 / 司机」精修验收</h2>
      <p class="cat-desc">你队员的阿豪和梁伯声线区分度非常高！梁伯前两段我们已做了近麦呼吸声抑制和厚实老声均衡，阿豪③加了 99 级石阶冷混响。</p>
      <div class="samples-grid">{s4_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：如阿豪③喜欢干声还是石阶混响、梁伯呼吸还要不要再削..." /></div>
    </section>""")

    # 5. Zero-shot AI Voice Cloning Demos
    s5_cards = "".join([
        card("sec5_cloning", "dawen_clone_01", "AI 克隆陈大文 · 新台词①「楼梯全黑晒，拆开电表箱睇睇」", "未录过这句！用你的 dawen_1 声纹 + RTX 4060 生成", "cloned_demos/dawen_clone_01_foyer.wav", "checkbox", True),
        card("sec5_cloning", "dawen_clone_02", "AI 克隆陈大文 · 新台词②「三楼支路断咗电，检查备件」", "用你的 dawen-2-tense 声纹生成", "cloned_demos/dawen_clone_02_meter.wav", "checkbox", True),
        card("sec5_cloning", "dawen_clone_03", "AI 克隆陈大文 · 新台词③「嘉敏仲喺三楼等紧我！」", "用你的 dawen-3-urgent 声纹生成", "cloned_demos/dawen_clone_03_stairs.wav", "checkbox", True),
        card("sec5_cloning", "zhihao_clone_01", "AI 克隆黄梓豪 · 新台词「我去二楼半合备用闸，楼梯口见」", "用你队员 zhihao_01 声纹生成新台词", "cloned_demos/zhihao_clone_01_enter.wav", "checkbox", True),
        card("sec5_cloning", "jiamin_clone_01", "AI 克隆黄嘉敏 · 新台词「千祈唔好由正门落嚟！走去大关斜巷！」", "用你转换后的嘉敏女声声纹继续扩展全篇台词", "cloned_demos/jiamin_clone_01_bunker.wav", "checkbox", True),
    ])
    sections.append(f"""
    <section class="cat-box" data-cat="5. 全新台词 AI 声音克隆实测（可放心批产全篇）" data-group="sec5_cloning">
      <h2>5. RTX 4060 本地 AI 声音克隆实测（用你和队员声纹说“没录过的新台词”）</h2>
      <p class="cat-desc">下面这 5 句你们完全没录过，全部是用你和队员的声纹在本地零样本生成。请听听像不像你本人和队员！</p>
      <div class="samples-grid">{s5_cards}</div>
      <div class="note-row"><input class="cat-note" type="text" placeholder="选填备注：觉得 AI 克隆像度够不够，哪些句想微调语速或情绪..." /></div>
    </section>""")

    page_html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>《澳诡实录》V6 团队粤语配音改造 & AI 声音克隆试听验收板</title>
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
  .wrap {{ max-width: 1060px; margin: 0 auto; }}
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
  .samples-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(440px, 1fr)); gap: 12px; }}
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
    <h1>《澳诡实录》V6 团队粤语配音改造 &amp; AI 声音克隆试听验收板</h1>
    <p class="lead">
      已对你们的 17 条原始录音完成母带降噪、电平统一，并在本地 <strong>RTX 4060</strong> 上跑通 <strong>Seed-VC</strong>：
      把你的黄嘉敏（男→年轻港女）、陈阿婆（男→真实老阿婆）、巴士报站（含超地道的粤/葡/普/英四语扶手广播）全部重塑，并实测用你与队员声纹克隆了 5 句全新台词。
    </p>
    <span class="badge">点播试听后，点击底部按钮复制选择结果发给我；确认即可全量批量克隆并开始 Batch 3B</span>
  </header>

  {''.join(sections)}

  <section class="cat-box">
    <h2>生成配音审批文本（复制直接发给 AI）</h2>
    <textarea id="resultOut" readonly></textarea>
  </section>
</div>

<div class="sticky-bar">
  <span class="status-txt" id="summaryBadge">请点播试听各组方案并选择</span>
  <button class="btn" id="copyBtn" type="button">一键复制配音审批结果</button>
</div>

<script>
  function collect() {{
    const lines = ['【《澳诡实录》V6 团队粤语配音审批结果】'];
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
