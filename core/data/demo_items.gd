extends RefCounted
class_name DemoItems

# IDs are stable in the checkpoint. Scene-specific descriptions live with the interactions.
const ENTRIES := {
	"multitool_pliers": ["多功能工具钳", "大文的随身工具。可拆检修盖、剪细铁丝。", "multitool_pliers_251"],
	"trip_map": ["澳门手绘路线图", "嘉敏手绘的澳门寻踪路线图，标注了福荣里、大三巴、松山、大关斜巷、33路与黑沙各站。", "travel_map_026"],
	"old_304_photo": ["福荣旧酒店 304 旧照", "嘉敏带来的事故房旧照。右后墙有一扇半开的百叶木门，床脚旁是缺了一角的四瓣花砖。", "room304_old_photo_026"],
	"jiamin_phone": ["嘉敏的手机", "在 304 门边找到。按 Q 或 Tab 查看她保存的聊天、旧图和行程。", "jiamin_phone_011"],
	"ceramic_fuse": ["备用陶瓷芯", "值班台下的维修备件，用于更换模拟装置里的烧蚀芯。", "fuse_026"],
	"insulated_bridge": ["绝缘桥片", "街口电工留下的备件。安装后可让中断的接触片合拢。", "bridge_026"],
	"power_record": ["一楼值班工单", "水泵舱进水，保留隔离。三楼楼梯灯与门扣两路均须通过试运行。", "work_order_026"],
	"wet_tag": ["湿漉漉的检修签", "门外刚出现的工牌。背面写着：门舌吃力，先往框里顶，再转偏心轮。", "wet_tag_026"],
	"service_grip": ["检修握柄", "旧铁门的可拆手柄。柄端是一个空的方形接头。", "service_grip_026"],
	"service_spindle": ["方轴", "可插进握柄的接头。背面有与门锁偏心轮相同的磨痕。", "service_spindle_026"],
	"service_handle": ["装好的检修手柄", "方轴已装进握柄。可用在通道铁门的偏心轮上。", "service_handle_026"],
	"crypt_old_photo": ["地宫巡查照片", "拍摄的是地宫石壁。能看到三斜痕、排水口和后来立起的石像。", "crypt_photo_013"],
	"crypt_survey": ["石壁测绘描图", "查阅处保留的描图。纸上记录了改造前的壁龛和墙脚记号。", "crypt_plan_013"],
	"crypt_doodle": ["石缝旁的访客涂鸦", "孩子画出了位于中间壁龛底下的金属扣，旁边是三斜痕。", "crypt_doodle_013"],
	"interview_index": ["松山地籍旧档案", "当年防空洞施工留下的地籍旧档案。记录着贯通大三巴的地下暗道、红影与不能数完的梯级。", "interview_index_macau_025"],
	"gate_work_order": ["松山换锁工单", "铁门换过锁芯。当前铁门使用方肩钥匙，圆肩那把是旧储物柜的。", "work_order_026"],
	"oil": ["小油壶", "从洞口维修角找到。壶嘴细长，适合处理锈涩的锁。", "bunker_tools_025"],
	"gate_key_1": ["单槽方肩钥匙", "方肩，匙身有一处窄槽。", "bunker_keys_025"],
	"gate_key_2": ["双槽方肩钥匙", "方肩，匙身有两处窄槽。", "bunker_keys_025"],
	"gate_key_3": ["双槽圆肩钥匙", "圆肩，匙身有两处窄槽。", "bunker_keys_025"],
	"loose_stone": ["碎石", "一枚从护栏内侧捡起的碎石，可以用来试探深坑。", "stone_026"],
	"stair_rubbing": ["机房墙面拓记", "白线停在八十九，缺角和墙钉成对出现。三道人影的脚印朝相反方向。", "stair_rubbing_026"],
	"bunker_recording": ["嘉敏的防空洞录音机", "嘉敏在防空洞绝境中录下的求救录音，背景带着隐约的哭声与求救暗号，附签写着大关斜巷。", "recorder_026"],
	"archive_spare_key": ["方牌备用钥匙", "从大关斜巷肉铺后间的暗柜取出。钥匙系着一枚方铜牌，与合照中屠夫围裙旁挂着的铜牌一致。", "bunker_key_025"],
	"w17_bus_ticket": ["33 路时刻表撕页", "嘉敏躲进冷库时从旧时刻表撕下的一页，标出亚马喇前地。它说明她准备去哪里求援，不是她已经上车的车票。", "jiamin_trail_props_044"],
	"laochen_handoff_note": ["时刻表背面的求生留言", "嘉敏的字迹：全城无信号，街上有东西追我。我去亚马喇前地，找亮灯的 33 路，往路环报警。\n她是在躲避追逐时留下这页纸，不知道阿豪已经遇害。", "jiamin_trail_props_044"],
	"jiamin_lens_cap": ["嘉敏的镜头盖", "肉铺冷柜下找到的镜头盖。内侧那条磨白的胶带，与她出发前用的相机一致。", "jiamin_trail_props_044"],
	"jiamin_severed_finger": ["嘉敏带尾戒的断指", "大关斜巷旧肉铺血盆旁找到的断指——左手尾指戴着嘉敏的细银尾戒，指节旁沾着半片米色创可贴。她曾在这里撞破屠夫惨案并拼死逃脱。", "jiamin_severed_finger_v6"],
	"ahhao_camera": ["阿豪的相机", "大文在楼梯口蹲下扶阿豪时取回的相机，摄影补光灯仍装在机顶。不是失踪后的新消息；卡里的旅行影像尚待后续场景整理。", "ahhao_camera_051"],
	"shoe_repair_photo": ["网购户外靴订单与鞋底实拍图", "大文手机里保存着以前帮嘉敏网购这双 37 码户外靴的订单与鞋底实拍图：斜人字纹底，右后跟边缘留着一处三角缺角。", "footprint_evidence_039"],
	"beach_cabinet_key": ["救生站资料柜钥匙", "高地保管箱内的黄铜钥匙，对应蓝门旁资料柜的锁芯。", "beach_mechanism_parts_040"],
	"hotel_maintenance_plan": ["沿海工事维护图", "救生站保留的旧工事维护档案。下排水口位于潮线内，侧向维护井通往上层夹道；需要到现场核对嘉敏留下的红布与鞋印。", "coastal_plan_047"]
}
const PROP_CELLS := {
	"ceramic_fuse": 0, "insulated_bridge": 1, "wet_tag": 2, "service_spindle": 3,
	"service_grip": 4, "service_handle": 5, "loose_stone": 6, "bunker_recording": 7,
	"power_record": 8, "gate_work_order": 8, "stair_rubbing": 9
}

static func prop_cell(index: int) -> Texture2D:
	var path := "res://assets/props/demo_props_026.png"
	if not ResourceLoader.exists(path):
		return null
	var source := load(path) as Texture2D
	var cell := source.get_size() / Vector2(4, 3)
	var crop := AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2(Vector2(index % 4, floori(index / 4.0)) * cell, cell)
	crop.filter_clip = true
	return crop

static func title(item_id: String) -> String:
	return String(ENTRIES[item_id][0])

static func description(item_id: String) -> String:
	return String(ENTRIES[item_id][1])

static func texture(item_id: String) -> Texture2D:
	if item_id in ["w17_bus_ticket", "laochen_handoff_note", "jiamin_lens_cap", "shoe_repair_photo"]:
		var sheet := load("res://assets/props/%s.png" % ENTRIES[item_id][2]) as Texture2D
		var cell := sheet.get_size() / Vector2(2, 2)
		var index: int = {"w17_bus_ticket":1, "laochen_handoff_note":2, "jiamin_lens_cap":0, "shoe_repair_photo":0}[item_id]
		var crop := AtlasTexture.new()
		crop.atlas = sheet
		crop.region = Rect2(Vector2(index % 2, index / 2) * cell, cell)
		crop.filter_clip = true
		return crop
	if PROP_CELLS.has(item_id):
		return prop_cell(PROP_CELLS[item_id])
	var name := String(ENTRIES[item_id][2])
	if name.is_empty():
		return null
	var path := "res://assets/props/%s.png" % name
	if item_id == "old_304_photo" and not ResourceLoader.exists(path):
		path = "res://assets/props/room304_old_photo_011.png"
	if not ResourceLoader.exists(path):
		return null
	var source := load(path) as Texture2D
	if item_id == "beach_cabinet_key":
		var crop := AtlasTexture.new()
		crop.atlas = source
		var cell := source.get_size() / Vector2(2, 2)
		crop.region = Rect2(Vector2(0, cell.y) if item_id == "beach_cabinet_key" else Vector2.ZERO, cell)
		crop.filter_clip = true
		return crop
	if item_id == "w17_bus_ticket":
		var ticket := AtlasTexture.new()
		ticket.atlas = source
		ticket.region = Rect2(760, 130, 270, 120)
		ticket.filter_clip = true
		return ticket
	if item_id.begins_with("gate_key_") or item_id == "oil":
		var crop := AtlasTexture.new()
		crop.atlas = source
		if item_id == "oil":
			crop.region = Rect2(1086, 0, 1086, 724)
		else:
			var key_number := int(item_id.get_slice("_", 2))
			crop.region = Rect2((key_number - 1) * 724, 180, 724, 320)
		return crop
	return source
