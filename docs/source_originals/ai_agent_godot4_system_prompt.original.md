# 《澳诡实录》(Aomen Paranormal Records) — AI Agent 后台开发最高法则与统一架构规范 (System Prompt V3.0 · 锁定定稿版)

> **使用说明**：请将本文件直接放入 Godot 4 项目根目录（命名为 `CLAUDE.md`、`CURSOR_RULES.md` 或 `AGENT_SYSTEM_PROMPT.md`）。每次调用 AI Agent（结合 Godot MCP）编写代码、搭建场景或修复 Bug 时，强制要求 AI Agent 先读取并严格遵守本规范。所有模块必须遵循同一套底层逻辑，严禁各自造轮子或破坏全局状态树。

---

## 零、 制作人拍板锁定的全局固定参数（Locked Constants）

所有 AI Agent 在编写脚本、UI、对话 JSON 与关卡逻辑时，**必须无条件使用以下已锁定的唯一设定**：

1. **项目名称**：中文《澳诡实录》｜英文副标题：`Aomen Paranormal Records`
2. **固定主角人设与命名**：
   - **男主角（Player）**：`陈大文`（昵称：`阿文` / `大文`），24岁香港工程系毕业，理性毒舌但极护短，初始自带关键工具道具 `multitool_pliers`（多功能工具钳）。
   - **女主角（Missing GF）**：`黄嘉敏`（昵称：`嘉敏` / `阿敏`），23岁香港民俗专栏作者，为考证外婆遗留的大三巴旁福荣里唐楼旧照赴澳，遗留核心终端 `jiamin_phone`（嘉敏的智能手机）与《怪谈手札》。
3. **手电筒与移动控制（D4 锁定）**：
   - `W/A/S/D` 控制四方向网格平滑移动；
   - **鼠标 360° 自由指向**：主角的手电筒光锥（`PointLight2D`，张角 `60°`，照射半径 `256px` / 8格）实时朝向鼠标光标坐标 `get_global_mouse_position()`。
4. **轻量级野比大雄风 HUD（D5 锁定）**：
   - 屏幕左上角**仅显示** `StaminaBar`（冲刺体力条）与 `BatteryGrid`（手电筒电量格）；
   - **严禁**在屏幕上显示数字化的“恐惧值/理智值条”——恐惧感全部通过 `AudioManager` 的动态心跳声加速与 `CanvasLayer` 后处理 Shader（屏幕边缘暗角 Vignette + 色差抖动 Chromatic Aberration）表现。
5. **手机强光闪光灯防身机制（D6 锁定）**：
   - 打开手机相机按 `R` 键触发强光闪光灯：每次消耗 `25%` 手机电量（每章最多可用 1~2 次），除了能拍下隐藏灵异线索外，若距离怪物 `< 120px` 且无墙体遮挡，可強制使怪物进入 `STUNNED`（眩晕驻足）状态 **2.5 秒**。
6. **七大章节标准结构（D7 锁定）**：
   - `ch0_tanglau`：序章·福荣旧影（大三巴前地旅拍吃葡挞 + 福荣里唐楼失踪）
   - `ch1_stpaul_crypt`：第一章·牌坊地宫（大三巴地下秘道与黑衣传教士）
   - `ch2_guia_tunnel`：第二章·松山断香（东望洋山99级楼梯 + 松山防空洞流浪汉垃圾尿渍噪音陷阱 + 中央坍塌垂直【无底洞】）
   - `ch3_amparo_alley`：第三章·骨肉长楼（大关斜巷十六两八卦秤 + 长楼斜巷猪仔馆哭声）
   - `ch4_bus33_loop`：第四章·诡夜末班（午夜新福利33号巴士车厢异常筛查）
   - `ch5_hacsa_beach`：第五章·黑沙溯潮（路环黑沙海滩动态涨潮 + 脚印追踪 + 车灯驱鬼）
   - `ch6_abandoned_vip`：最终章·石屎筹局（黑沙环百利新邨石屎封墙 + 废弃酒店赌场VIP后勤区，**零赌博玩法**）
7. **实景原型 1:1 像素还原准则（D8 锁定）**：
   - 严禁生成脱离澳门现实的通用西式地牢或现代样板间！所有地图瓦片与场景物件必须严格对照各章真实澳门原型照片/视频关键帧（如松山军用隧道的弧形水泥拱顶、墙面黄色电缆管、防爆铁门、新福利33号巴士的黄色扶手与蓝底碎花座椅、大三巴墓室的花岗岩基座）进行像素化还原。

---

## 一、 核心架构铁律（The Golden Rules for AI Agent）

1. **禁止硬编码与跨节点乱引用（Signal Up, Call Down）**：
   - 子节点向父节点通信**必须使用 Signal（信号）**或通过全局事件总线 `EventBus`；父节点控制子节点可直接调用方法。
   - **严禁**在脚本中使用深层级的相对路径 `get_node("../../../Player")`。所有跨系统通信统一走四大 Autoload 单例。
   - **严禁**随意修改其他已稳定系统的脚本或重复创建功能相同的脚本；每次修改必须说明影响范围并运行测试。
2. **四大全局单例（Autoload Singletons）唯一真理源**：
   所有 AI Agent 编写的功能必须挂载并服从以下四个全局单例（位于 `res://core/autoload/`），**严禁新建多余的全局管理器**：
   - `GameState.gd`：统合管理章节进度（`current_chapter: int`）、全局剧情布尔开关（`flags: Dictionary`）、证据图鉴 ID 列表（`clues: Array[String]`）、轻量道具背包（`inventory: Array[String]`，初始含 `multitool_pliers`）、陈大文耐力/手电电量/手机电量/隐藏恐惧值（`stamina: float`, `flashlight_battery: float`, `phone_battery: float`, `fear: float`）以及本地检查点/手动存档（JSON 序列化至 `user://savegame.json`）。
   - `EventBus.gd`：纯信号中心（Signal Hub），包含交互提示、证据获取、手机 UI 弹窗、闪光灯释放、动态恐怖事件触发、怪物状态切换、屏息 QTE、空间循环计数等标准信号。
   - `AudioManager.gd`：统一控制 5 条 AudioBus（`Master`, `Music`, `Ambience`, `SFX`, `Voice`），支持粤语配音触发时自动对背景音乐施加 `-6dB` 闪避（Sidechain Ducking），以及随怪物距离动态调节心跳声频率。
   - `AutoBot.gd`：内置自动化巡航与 8 维遥测机器人（支持 `--headless --autobot` 无头模式与 `F9` 热键切换），用于连续数小时无人值守挂机测试、统计卡关热力图与自动捕获软锁（Softlock）。
3. **2D 俯视角瓦片与像素渲染规范（《野比大雄的生化危机》标准）**：
   - 基准视口分辨率：`640 × 360`（16:9 整数倍缩放至 1920×1080，`stretch/mode = "viewport"`，`stretch/aspect = "keep"`）。
   - 纹理过滤：全局设置 `default_texture_filter = "Nearest"`（保持像素锐利，严禁线性模糊）。
   - 瓦片规格：统一采用 `32 × 32 px` 正交 `TileMapLayer`（Godot 4.3+ 标准节点，严禁使用旧版已废弃的 `TileMap`）。
   - 碰撞层（Collision Layers）严格锁定，**任何 AI Agent 不得私自篡改**：
     - `Layer 1 (Bit 0)`: `World_Wall`（墙壁、不可跨越家具、松山防空洞无底洞铁链护栏）
     - `Layer 2 (Bit 1)`: `Player`（男主角陈大文）
     - `Layer 3 (Bit 2)`: `Enemy`（黑衣传教士、防空洞无脸巡山人、33号巴士校服女鬼、无头西装客）
     - `Layer 4 (Bit 3)`: `Interactable`（调查点、门锁、拍立得照片、可躲藏衣柜/桌底）
     - `Layer 5 (Bit 4)`: `Hazard_Trigger`（防空洞垂直无底洞即死区、易拉罐/尿渍水洼发声陷阱、黑沙海滩涨潮淹没区、松山烧香回头判定区）

---

## 二、 核心代码接口规范（AI Agent 必须直接复用）

### 1. 主角陈大文移动与鼠标 360° 手电筒控制器 (`res://entities/player/player_controller.gd`)
```gdscript
class_name PlayerController
extends CharacterBody2D

const WALK_SPEED: float = 96.0
const SPRINT_SPEED: float = 160.0
const CROUCH_SPEED: float = 56.0
const FLASHLIGHT_ROTATION_SPEED: float = 18.0

@onready var flashlight_pivot: Node2D = $FlashlightPivot
@onready var flashlight_light: PointLight2D = $FlashlightPivot/PointLight2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_crouching: bool = false
var is_hidden: bool = false

func _physics_process(delta: float) -> void:
	if is_hidden:
		return
	
	# 1. 鼠标 360° 自由控制 60° 手电筒光锥朝向 (D4 锁定设定)
	var mouse_pos: Vector2 = get_global_mouse_position()
	var target_angle: float = global_position.angle_to_point(mouse_pos)
	flashlight_pivot.rotation = lerp_angle(flashlight_pivot.rotation, target_angle, FLASHLIGHT_ROTATION_SPEED * delta)
	
	# 2. WASD 四方向移动与 Shift 冲刺 / Ctrl 蹲下
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("crouch"):
		is_crouching = !is_crouching
	
	var current_speed: float = WALK_SPEED
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint") and GameState.stamina > 0.0 and input_dir != Vector2.ZERO:
		current_speed = SPRINT_SPEED
		GameState.consume_stamina(20.0 * delta)
		EventBus.noise_emitted.emit(global_position, 140.0) # 奔跑发出脚步噪音
	else:
		GameState.recover_stamina(15.0 * delta)
	
	velocity = input_dir * current_speed
	move_and_slide()
```

### 2. 怪物 6+1 态状态机标准枚举 (`res://entities/enemies/enemy_fsm.gd`)
```gdscript
class_name EnemyFSM
extends Node

enum State {
	IDLE,        # 待机或隐藏在暗处
	PATROL,      # 沿巡逻点移动
	INVESTIGATE, # 听到陈大文奔跑/踩碎防空洞易拉罐或尿渍水洼/砸石屎墙噪音，前往声源坐标查看
	CHASE,       # RayCast2D 无墙体遮挡发现玩家或手电筒漏光，高速追击并触发追逐音乐
	STUNNED,     # 被陈大文使用黄嘉敏手机强光闪光灯(R键，消耗25%电量)正面致盲眩晕 2.5 秒 (D6 锁定)
	SEARCH,      # 玩家拐弯脱离视线或躲入柜子，在最后已知位置附近徘徊搜寻 5 秒
	RETURN       # 搜寻超时未果，沿 NavigationAgent2D 返回初始巡逻路线
}
```

### 3. AutoBot 8 维遥测数据结构 (`user://telemetry_report.json`)
`AutoBot.gd` 与 `GameState.gd` 必须在后台实时统计并输出以下 8 项指标，供人工与 AI 调优关卡：
```json
{
  "protagonist": "陈大文",
  "heroine": "黄嘉敏",
  "chapter_id": "ch2_guia_tunnel",
  "completion_time_sec": 842.5,
  "death_count": 3,
  "death_causes": {"guia_abyss_fall": 2, "stalker_caught": 1},
  "stuck_time_sec": 12.4,
  "stuck_positions": [[320, 480]],
  "puzzle_fail_counts": {"guia_99_stairs": 2},
  "clue_miss_rate": 0.15,
  "chase_fail_rate": 0.25,
  "route_repeat_count": 4,
  "save_load_success_rate": 1.0
}
```