extends RefCounted
class_name MacauGuide

const CARD_ORDER := [
	"transmac_bus",
	"azulejo_street",
	"egg_tart",
	"herbal_tea",
	"tanglau_foyer",
	"red_payphone",
	"room304_secret",
	"st_pauls",
	"guia_lighthouse",
	"ninety_nine_steps",
	"amparo_alley",
	"archive_ledger",
	"macau_cantonese_opera",
	"hacsa_beach",
	"coastal_pressure_room",
	"bleeding_wall_vip",
]

const CARDS := {
	"transmac_bus": {
		"title": "6 元投币 · 四语报站",
		"location": "口岸 / 33 路巴士",
		"tag": "城市日常",
		"image": "res://assets/ui/map_landmarks/stop_6_bridge_bus33.png",
		"fact": "新福利与澳巴现金均一票价 6 澳门元不设找赎，粤/葡/普/英四语报站。",
		"adaptation": "第四章 33 路末班车以此为日常声景参照；诡异轮回与异象站牌为虚构。",
	},
	"azulejo_street": {
		"title": "蓝白葡式街砖牌",
		"location": "福荣里旧街口",
		"tag": "世遗风貌",
		"image": "res://assets/ui/map_landmarks/stop_1_tanglau.png",
		"fact": "历史城区沿用白底蓝花瓷砖中葡双语路牌，搭配黑白碎石波浪路面。",
		"adaptation": "「福荣里 304 旧楼」系本作虚构门牌，不对应现实私人住宅。",
	},
	"egg_tart": {
		"title": "安德鲁葡挞外卖档",
		"location": "大三巴手信街",
		"tag": "市井美食",
		"image": "res://assets/props/macau_tart_stand_v10.png",
		"fact": "焦糖脆皮蛋挞与猪扒包是过关打卡必吃烟火风味。",
		"adaptation": "序章吃葡挞递食时露出的小指尾戒，伏笔第三章最揪心的认物瞬间。",
	},
	"herbal_tea": {
		"title": "廿四味大铜壶凉茶",
		"location": "旧区骑楼街角",
		"tag": "街坊民俗",
		"image": "res://assets/props/macau_herbal_cart_v10.png",
		"fact": "广式凉茶铺常悬擦亮的黄铜大壶与土地龛，为老街夜归人消暑驱湿。",
		"adaptation": "梁伯凉茶档在此借民间忌讳点破「夜入旧楼莫乱应声」的前路预警。",
	},
	"tanglau_foyer": {
		"title": "福荣里骑楼旧唐楼",
		"location": "旧区无电梯唐楼",
		"tag": "老城建筑",
		"image": "res://assets/tilesets/opening_006.png",
		"fact": "上世纪澳门中低层唐楼多见绿漆铁闸、水磨石梯间与壁挂裸线电表箱。",
		"adaptation": "序章停电查表、合后廊备闸与阿豪遇害均为本作惊悚改编桥段。",
	},
	"red_payphone": {
		"title": "CTM 红色投币电话亭",
		"location": "大三巴旁旧巷口",
		"tag": "怀旧设施",
		"image": "res://assets/props/payphone_booth_v9.png",
		"fact": "街头仍偶见保留澳门电讯 CTM 标志的老式投币公用电话亭（MOP$1 起）。",
		"adaptation": "本作中 999 忙音接不通，强化孤立无援与夜间通讯中断感。",
	},
	"room304_secret": {
		"title": "304 铁床后封死暗门",
		"location": "福荣里 304 室",
		"tag": "都市奇谈",
		"image": "res://assets/tilesets/room304_011.png",
		"fact": "旧城唐楼翻修或并户时常留下封堵门框，成为坊间穿凿灵异传说的温床。",
		"adaptation": "床后直通大三巴地下与渗暗血迹属剧情机关需要，非现实市政结构。",
	},
	"st_pauls": {
		"title": "大三巴牌坊与墓室",
		"location": "耶稣会纪念广场",
		"tag": "世界遗产",
		"image": "res://assets/ui/map_landmarks/stop_2_stpaul_crypt.png",
		"fact": "1835 年大火后仅存花岗岩前壁，其后设天主教艺术博物馆与古墓室。",
		"adaptation": "第一章虚构侧阶暗道与地宫档案室为民间怪谈取材，非真实通道。",
	},
	"guia_lighthouse": {
		"title": "东望洋灯塔与防空洞",
		"location": "东望洋山（松山）",
		"tag": "军事遗址",
		"image": "res://assets/ui/map_landmarks/stop_3_guia_bunker.png",
		"fact": "山顶设 1865 年启用的百年灯塔，山体周边留存近代防空与军事隧洞。",
		"adaptation": "洞内失控潜伏、油壶开锁与红衣幻影为本作第二章恐怖演绎。",
	},
	"ninety_nine_steps": {
		"title": "九十九级鬼打墙石阶",
		"location": "松山防空洞深处",
		"tag": "传说改编",
		"image": "res://assets/props/hill_stele_014.png",
		"fact": "坊间流传松山夜间石阶「白天八十余、夜里数到九十九却走不出」。",
		"adaptation": "本作将此传闻落于防空洞内，需 89 级留记号、99 级倒退不回头脱险。",
	},
	"amparo_alley": {
		"title": "大关斜巷手写老招牌",
		"location": "内港旧街巷",
		"tag": "历史街区",
		"image": "res://assets/ui/map_landmarks/stop_4_amparo_alley.png",
		"fact": "大关斜巷紧邻关前正街、烂鬼楼，至今保有陡斜麻石路面与老字号铺位。",
		"adaptation": "第三章虚构涉案老肉铺改写自港澳奇谈意象，不消费真实受害者。",
	},
	"archive_ledger": {
		"title": "1985 泛黄账册剪报",
		"location": "肉铺里间资料台",
		"tag": "虚构卷宗",
		"image": "res://assets/ui/map_landmarks/stop_5_archive_1985.png",
		"fact": "上世纪八十年代澳门旧铺多用直排繁体复写单与账簿记录寄递往来。",
		"adaptation": "房客登记与失踪邮差档案专为本作推理谜题编撰，属虚构物证。",
	},
	"macau_cantonese_opera": {
		"title": "深夜收音机粤剧声",
		"location": "老巷后厨工作台",
		"tag": "岭南声景",
		"image": "res://assets/props/butcher_radio_v10.png",
		"fact": "港澳老式茶居、肉铺常整夜开着 AM 晶体管收音机播传统广东大戏。",
		"adaptation": "高亢梆簧曲调在第三章掩盖剁骨动静，营造岭南独有阴森反差。",
	},
	"hacsa_beach": {
		"title": "路环黑沙海滩暗潮",
		"location": "路环岛东岸",
		"tag": "自然奇观",
		"image": "res://assets/ui/map_landmarks/stop_7_hacsa_beach.png",
		"fact": "海沙因富含海绿石呈青黑色，1985 年传闻曾言海浪将残肢冲上岸边。",
		"adaptation": "第五章借用「浪卷残肢」都市传说由虚构屠夫抛尸与邮差线展开追逐。",
	},
	"coastal_pressure_room": {
		"title": "沿海防洪调压廊",
		"location": "黑沙近岸地下工事",
		"tag": "工业设施",
		"image": "res://assets/props/coastal_console_plate_v10.png",
		"fact": "澳门半岛及路环低洼带筑有防洪闸门与暗渠分流阀以抗台风风暴潮。",
		"adaptation": "第五章末段需按进水→旁通→泄压顺序操纵铸铁手轮退水过关。",
	},
	"bleeding_wall_vip": {
		"title": "百利新邨渗血夹层",
		"location": "终章地下混凝土间",
		"tag": "终章档案",
		"image": "res://assets/ui/map_landmarks/stop_8_bleeding_wall.png",
		"fact": "老旧商住屋苑连夜违建或封堵设备夹层，曾衍生诸多港澳都市怪谈。",
		"adaptation": "终章声呐引怪落闸与「嘉敏逃生汇合」为全篇完全虚构收束舞台。",
	},
}

static func ordered_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in CARD_ORDER:
		ids.append(k)
	return ids

static func get_card(card_id: String) -> Dictionary:
	return CARDS.get(card_id, {})

static func has_card(card_id: String) -> bool:
	return CARDS.has(card_id)

static func total_count() -> int:
	return CARD_ORDER.size()
