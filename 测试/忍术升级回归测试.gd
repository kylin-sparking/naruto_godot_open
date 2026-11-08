extends SceneTree

## 忍术「提升层数」离线门（2026-10-18）。
##
## 用户报障原话：「忍术面板，忍术不能升级了，要么是说缺什么忍术点（根本不存在这个东西），
## 要么是说忍术已经达到最高等级」。
##
## 真值（2.2.3 反编译）：
##   * 原版点「提升层数」只做两件事：按钮点灰 + 发 `SKILL_CHANGE(1330)`，
##     报文 `writeByte(2=UPGRADE), writeInt(skillId)`（`SkillChangeProcessor.as:24-31`）；
##     客户端**没有**任何"忍术点"判定，语言表里也没有"忍术点"这三个字。
##   * `UPDATE_SKILLS` 的三段是 `SkillInfo.decode` 的 id / skillLevel / **masterLevel**
##     （`data/skill/SkillInfo.as:35-40`）—— 第三段是熟练度，不是等级上限。
##   * 升级条件与扣费（服务端 `_upgrade_skill`）：人物等级 ≥ 下一层、
##     查克拉精华（zq）≥ 需求总量 − 当前熟练度、金币 ≥ 需求金币；
##     成功后 level+1、熟练度清零、扣金币与精华。
##
## 修前两个病：
##   ① `服务端同步.应用技能` 把 masterLevel 当 `max_level` 存 ⇒ 熟练度默认 0 ⇒
##      `level >= max_level` 恒真 ⇒ 一律"该忍术已达到最高等级"；
##   ② `游戏会话.upgrade_skill` 自造 `remaining_sp` 闸门 ⇒ 点几次就"忍术点不足"。
##
## 跑法：Godot --headless --path . --script res://测试/忍术升级回归测试.gd

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 服务端同步 := preload("res://脚本/单例/服务端会话同步.gd")

const 出 := "res://测试/截图/忍术升级.txt"
const 存档 := "user://玩家数据.json"
const 设置档 := "user://玩家设置.json"
const 会话源 := "res://脚本/单例/游戏会话.gd"
const 同步源 := "res://脚本/单例/服务端会话同步.gd"
const 后端源 := "res://脚本/单例/后端连接.gd"

var 总 := 0
var 红 := 0
var 日志: Array[String] = []
var 通知: Array[String] = []
var 存前 := PackedByteArray()
var 设前 := PackedByteArray()


func _记(过: bool, 说: String) -> void:
	总 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return PackedByteArray()
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _还原(路: String, 前: PackedByteArray) -> bool:
	if _字节(路) == 前:
		return true
	if 前.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(路))
		return not FileAccess.file_exists(路)
	var g := FileAccess.open(路, FileAccess.WRITE)
	if g == null:
		return false
	g.store_buffer(前)
	g.close()
	return _字节(路) == 前


func _尾() -> void:
	_记(_还原(存档, 存前), "跑完把存档按字节还原（本门会落盘）")
	_记(_还原(设置档, 设前), "跑完把设置档按字节还原")
	日志.append("")
	日志.append("汇：判 %d 条 / 红 %d 条" % [总, 红])
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)


## 剥掉注释行再比 —— 注释里会写旧字段名与 AS3 标识符，拿原文 grep 会自证。
func _码(路: String) -> String:
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return ""
	var 文 := g.get_buffer(g.get_length()).get_string_from_utf8()
	g.close()
	var 留: Array[String] = []
	for 行 in 文.split("\n"):
		if 行.lstrip("\t ").begins_with("#"):
			continue
		留.append(行)
	return "\n".join(留)


func _技能(编号: String, 等级: int, 熟练: int = 0) -> Dictionary:
	# `_rebuild_skill_slots()` 对主动技能直接取 `.name/.cooldown/.icon`，这几个键不能少。
	return {"id": 编号, "name": "测试忍术", "level": 等级, "master_level": 熟练,
		"cooldown": 1.0, "icon": "", "max_level": 0}


func _找(会, 编号: String) -> Dictionary:
	var i: int = 会._skill_index(编号)
	return 会.learned_skills[i] if i >= 0 else {}


func _initialize() -> void:
	存前 = _字节(存档)
	设前 = _字节(设置档)
	_表腿()
	var 会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_记(false, "拿不到 GameSession 单例")
		_尾()
		return
	会.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	_同步腿(会)
	_升级腿(会)
	_闸门腿(会)
	_接线腿()
	_尾()


func _表腿() -> void:
	# 抽样真值取自 `SkillReqTable.as:8`：[需要人物等级, 金币, 精华]。
	var 二 := 游戏数据.skill_upgrade_req(2, 1001001)
	_记(二.size() >= 3 and int(二[0]) == 2 and int(二[1]) == 4 and int(二[2]) == 62,
			"升级表[2] = [2, 4, 62]（原版 SkillReqTable.as），实际 %s" % str(二))
	var 五一 := 游戏数据.skill_upgrade_req(51, 1001001)
	_记(五一.size() >= 3 and int(五一[0]) == 51 and int(五一[1]) == 30280 and int(五一[2]) == 1344,
			"升级表[51] = [51, 30280, 1344]，实际 %s" % str(五一))


## 协议第三段是熟练度 —— 同步进来的必须是 `master_level`，不许再是 `max_level`。
func _同步腿(会) -> void:
	会.server_skills_loaded = true
	会.learned_skills.assign([{"id": "0001001", "name": "查克拉修炼", "level": 1,
		"master_level": 0, "cooldown": 5.0, "icon": ""}])
	服务端同步.应用技能(会, 1001, 3, 7)
	var 条 := _找(会, "0001001")
	_记(int(条.get("level", 0)) == 3, "同步 level=3 ⇒ 记录等级 3")
	_记(int(条.get("master_level", -1)) == 7,
			"同步第三段 7 是**熟练度** ⇒ master_level=7，实际 %d" % int(条.get("master_level", -1)))
	_记(not 条.has("max_level"),
			"不再生成 `max_level`（协议里根本没有这个字段；修前它被塞成熟练度 0）")
	服务端同步.应用技能(会, 1002, 2, 5)
	var 新 := _找(会, "0001002")
	_记(int(新.get("level", 0)) == 2 and int(新.get("master_level", -1)) == 5,
			"新同步的技能同样落 master_level=5")


## 核心：剩余 SP=0、记录里带着 `max_level:0`，也必须能升。
func _升级腿(会) -> void:
	会.set("backend_authoritative", false)
	会.server_skills_loaded = true
	会.learned_skills.assign([_技能("0001001", 50)])
	会.player_stats["level"] = 80
	会.player_stats["gold"] = 50000
	会.player_stats["zq"] = 5000
	会.player_stats["remaining_sp"] = 0
	通知.clear()
	var 成: bool = 会.upgrade_skill("0001001")
	var 条 := _找(会, "0001001")
	_记(成, "等级 50、max_level=0、remaining_sp=0 ⇒ 仍然升得动（修前先弹最高等级、再弹忍术点不足）")
	_记(int(条.get("level", 0)) == 51, "升后等级 51")
	_记(int(会.player_stats.get("gold", 0)) == 50000 - 30280,
			"扣金币 30280（51 层需求）⇒ 19720，实际 %d" % int(会.player_stats.get("gold", 0)))
	_记(int(会.player_stats.get("zq", 0)) == 5000 - 1344,
			"扣查克拉精华 1344 ⇒ 3656，实际 %d" % int(会.player_stats.get("zq", 0)))
	_记(int(会.player_stats.get("remaining_sp", -1)) == 0, "全程不动 remaining_sp（它不参与忍术升级）")
	_记(通知.is_empty(), "成功路径不许弹任何提示，实际 %s" % str(通知))

	# 熟练度抵扣精华：`SkillUpgradeConditionPane.as:93` = 总量 − masterLevel。
	会.learned_skills.assign([_技能("0001001", 51, 400)])
	会.player_stats["gold"] = 50000
	会.player_stats["zq"] = 5000
	通知.clear()
	_记(会.upgrade_skill("0001001"), "51 层带 400 熟练度 ⇒ 可升")
	_记(int(_找(会, "0001001").get("level", 0)) == 52, "升到 52 层")
	_记(int(会.player_stats.get("zq", 0)) == 5000 - (1412 - 400),
			"精华只扣 1412−400=1012 ⇒ 3988，实际 %d" % int(会.player_stats.get("zq", 0)))
	_记(int(_找(会, "0001001").get("master_level", -1)) == 0, "升级成功后熟练度清零（服务端行为）")


## 三道拒绝闸门：人物等级 → 精华 → 金币，且拒时整件事不发生。
func _闸门腿(会) -> void:
	会.player_stats["gold"] = 50000
	会.player_stats["zq"] = 5000
	会.player_stats["level"] = 80
	会.learned_skills.assign([_技能("0001001", 80)])
	通知.clear()
	_记(not 会.upgrade_skill("0001001"), "80 级人物升 81 层 ⇒ 拒绝")
	_记(int(_找(会, "0001001").get("level", 0)) == 80 and int(会.player_stats.get("gold", 0)) == 50000,
			"拒绝时等级/金币都不许动")
	_记(通知.size() == 1 and String(通知[0]).contains("81"),
			"提示「角色需要达到 81 级…」，实际 %s" % str(通知))

	会.player_stats["level"] = 80
	会.player_stats["gold"] = 3
	会.player_stats["zq"] = 5000
	会.learned_skills.assign([_技能("0001001", 1)])
	通知.clear()
	_记(not 会.upgrade_skill("0001001"), "金币 3 < 需求 4 ⇒ 拒绝")
	_记(int(会.player_stats.get("gold", 0)) == 3 and int(_找(会, "0001001").get("level", 0)) == 1,
			"金币不足时整件事不发生")
	_记(通知.size() == 1 and String(通知[0]).contains("金币不足"),
			"提示「金币不足，无法升级技能。」，实际 %s" % str(通知))

	会.player_stats["gold"] = 50000
	会.player_stats["zq"] = 61
	通知.clear()
	_记(not 会.upgrade_skill("0001001"), "精华 61 < 需求 62 ⇒ 拒绝")
	_记(int(会.player_stats.get("zq", 0)) == 61 and int(_找(会, "0001001").get("level", 0)) == 1,
			"精华不足时整件事不发生")
	_记(通知.size() == 1 and String(通知[0]).contains("62"),
			"提示「查克拉精华不足，还需要 62点。」，实际 %s" % str(通知))

	# 成功一条，证明上面三个拒绝不是"什么都升不动"。
	会.player_stats["zq"] = 5000
	通知.clear()
	_记(会.upgrade_skill("0001001"), "条件齐了 ⇒ 1 层升 2 层")
	_记(int(会.player_stats.get("gold", 0)) == 50000 - 4, "扣 4 金币")
	_记(int(会.player_stats.get("zq", 0)) == 5000 - 62, "扣 62 精华")


func _接线腿() -> void:
	var 会 := _码(会话源)
	var 同 := _码(同步源)
	var 后 := _码(后端源)
	_记(not 会.contains("忍术点"), "`游戏会话` 源码里没有「忍术点」（原版不存在的资源）")
	_记(not 会.contains("request_distribute_sp("), "升级不再走自造的 distribute_sp 请求")
	_记(会.contains("backend.request_skill_change(2, int(skill_id))"),
			"在线升级发 `SKILL_CHANGE` 的 action 2（原版 SkillChangeProcessor）")
	_记(后.contains("func request_skill_change(action: int, skill_id: int)"),
			"`request_skill_change` 段序是 (action, skillId)")
	_记(同.contains("\"master_level\": 熟练度"), "`应用技能` 把第三段落到 master_level")
	_记(not 同.contains("\"max_level\": 最高等级"), "`应用技能` 不再写 max_level")
