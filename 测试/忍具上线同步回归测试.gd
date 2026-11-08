extends SceneTree

## 离线门：`WARP_CHAR_INFO` 文本帧第 **40** 截是忍具、第 **41** 截是忍术。
##
## 2026-11-04 用户报「穿上八咫镜就不能卸装备了 / 每次上线八咫镜都在背包、未装备」。
## 根因的第一环在**解析下标**：原版 `CharacterWarpInfo.decode:76-81` 的顺序是
## shenqi / ring / lingQi / **renJu** / skillInfoList，而夹具与客户端两边都把忍具那一段
## 漏了 —— 客户端只读 `[37,38,39]`、忍术还占着 `[40]`。
## 补上忍具后忍术顺移到 `[41]`，**两个下标必须一起改**：只加不挪 ⇒ 忍具串被当忍术解
## （`2&65000002&-24…` → 技能 2、层 65000002），忍术表里就多一条假技能、真技能消失。
##
## 本门自己造一帧：三段内容**互不相同**（神器 `-100`、灵器 `-23`、忍具 `-24`，
## 忍术 9029），错位一格立刻能指出来是哪一段串了。
##
## 运行：`"<Godot console>" --headless --path . --script res://测试/忍具上线同步回归测试.gd`

const 门存档快照 := preload("res://测试/门存档快照.gd")
const 门名 := "忍具上线同步回归测试"
const 忍具号 := "65000002"
const 忍具名 := "八咫镜(已开光)"		# `数据/忍具文案.json → 忍具/65000002/name`
const 灵器号 := "20200001"
const 技能号 := 9029

var _后端: Node
var _会话: Node
var _红数 := 0
var _旧: Dictionary = {}
var _档前: Dictionary = {}


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _后端 == null or _会话 == null:
		_红("缺单例：BackendConnection=%s GameSession=%s" % [_后端, _会话])
		return
	_档前 = 门存档快照.全快照()
	_旧 = {
		"inventory": (_后端.authoritative_inventory as Array).duplicate(true),
		"equipment": (_后端.authoritative_equipment as Dictionary).duplicate(true),
		"special": (_后端.authoritative_special_equipment as Dictionary).duplicate(true),
		"skills": (_后端.authoritative_skills as Dictionary).duplicate(true),
		"bag": int(_后端.authoritative_bag_capacity),
		"in_game": bool(_后端.in_game),
	}
	# 清空，免得预存状态把"没解析到"盖过去（假绿）。
	_后端.authoritative_special_equipment.clear()
	_后端.authoritative_equipment.clear()
	_后端.authoritative_skills.clear()

	_后端.call("_handle_warp_character_text", PackedStringArray(_造帧()))

	# ── ① 忍具段（第 40 截）落进负槽 -24，且它是**忍具**不是灵器 ──
	var 特: Dictionary = _后端.authoritative_special_equipment
	_查(特.has(-24), "第 40 截（忍具段）该落进 -24；实得键 %s（忍具整段没读？）" % str(特.keys()))
	if 特.has(-24):
		var 镜: Dictionary = 特[-24]
		_查(int(str(镜.get("id", "0"))) == 65000002,
				"第 40 截的件应是 %s；实得 %s" % [忍具号, str(镜.get("id"))])
		_查(int(镜.get("quantity", 0)) == 1, "-24 那枚镜的数量应是 1；实得 %s" % str(镜.get("quantity")))
		_查(String(镜.get("name", "")) == 忍具名,
				"-24 那枚镜的名字应是「%s」（`数据/忍具文案.json` 回退）；实得「%s」" % [忍具名, String(镜.get("name", ""))])
	_查(bool(_后端.authoritative_equipment.has(-24)),
			"忍具段没有并进 `authoritative_equipment` ⇒ 人物窗忍具格还是空")
	# ── ② 灵器段（第 39 截）仍在 -23，没被忍具挤走 ──
	_查(特.has(-23) and int(str((特[-23] as Dictionary).get("id", "0"))) == 20200001,
			"第 39 截（灵器段）该仍在 -23 且件号 %s；实得 %s" % [灵器号, str(特.get(-23, "无"))])

	# ── ③ 忍术段（第 41 截）解析到 9029；忍具串**不许**被当忍术 ──
	var 技: Dictionary = _后端.authoritative_skills
	_查(技.has(技能号), "第 41 截（忍术段）该解出技能 %d；实得键 %s" % [技能号, str(技.keys())])
	if 技.has(技能号):
		var 条: Dictionary = 技[技能号]
		_查(int(条.get("level", -1)) == 3 and int(条.get("master_level", -1)) == 17,
				"技能 %d 该是 3 层 / 熟练 17；实得 %s" % [技能号, str(条)])
	_查(not 技.has(2), "忍具串被当忍术解了（`2&65000002…` → 技能 2）⇒ 第 40/41 两截错位")
	_查(not 技.has(65000002), "忍具 id 被当技能号解进忍术表（下标仍指在 40 上）")

	# ── ④ 背包格数（第 36 截）没跟着挪 ──
	_查(int(_后端.authoritative_bag_capacity) == 360,
			"第 36 截背包格数该是 360；实得 %s" % str(_后端.authoritative_bag_capacity))

	_查(_档未脏(), "本门脏了 `user://` 那两份档（本门只喂内存帧，不该落盘）")
	_还原()
	_收尾()


## 47 段：0..46。只填 `_handle_warp_character_text` 真读的那几格 + 三个特殊装备段 + 忍术段。
func _造帧() -> Array[String]:
	var 帧: Array[String] = []
	for _i in 47:
		帧.append("0")
	帧[0] = "38"			# WARP_CHAR_INFO（服务端 opcode；客户端只按字段位读）
	帧[1] = "1"
	帧[3] = "1"			# character_id
	帧[4] = "离线门"
	帧[5] = "1"			# gender
	帧[9] = "1"			# level
	帧[10] = "1"			# job
	帧[15] = "100"			# hp
	帧[16] = "100"			# maxHp
	帧[17] = "100"			# mp
	帧[18] = "100"			# maxMp
	帧[23] = "100000000"		# map_id（木叶村）
	帧[27] = "false"		# vip
	帧[31] = "0"			# lingFace
	帧[36] = "360"			# bag_capacity
	帧[37] = "-"			# 神器（空）
	帧[38] = "-"			# 魂结（空）
	帧[39] = "6&" + 灵器号 + "&-23&1&0&0&1&门&0&770002&15*3"	# 灵器
	帧[40] = "2&" + 忍具号 + "&-24&1&0&0&1&门&0&770001"		# 忍具
	帧[41] = "%d&3&17" % 技能号					# skillInfoList
	帧[42] = "-"
	帧[43] = "48"
	帧[44] = "false"
	帧[45] = "false"
	帧[46] = "0"
	return 帧


func _档未脏() -> bool:
	for 路 in _档前:
		if 门存档快照.读字节(String(路)) != (_档前[路] as PackedByteArray):
			return false
	return true


func _还原() -> void:
	_后端.authoritative_inventory = _旧["inventory"]
	_后端.authoritative_equipment = _旧["equipment"]
	_后端.authoritative_special_equipment = _旧["special"]
	_后端.authoritative_skills = _旧["skills"]
	_后端.authoritative_bag_capacity = _旧["bag"]
	_后端.in_game = _旧["in_game"]
	门存档快照.全还原(_档前)


func _查(过: bool, 文: String) -> void:
	if not 过:
		_红数 += 1
		print("!! " + 文)


func _红(文: String) -> void:
	_查(false, 文)
	if not _旧.is_empty():
		_还原()
	quit(1)


func _收尾() -> void:
	if _红数 == 0:
		print("%s：通过（warp 第 40 截 = 忍具落 -24 且名/数量对 / 第 39 截灵器仍在 -23 / "
				% 门名
				+ "第 41 截忍术解析到 %d 且忍具串没被当忍术 / 第 36 截格数不挪 / 两份 user:// 档未脏）" % 技能号)
		quit(0)
	else:
		print("%s：失败 %d 项" % [门名, _红数])
		quit(1)
