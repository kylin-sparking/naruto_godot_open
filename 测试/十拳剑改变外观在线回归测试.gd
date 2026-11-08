extends SceneTree
## 十拳剑「改变外观」的**在线**端到端门（2081:4/5/6）。
##
## 离线门 `十拳剑改变外观回归测试.gd` 只喂假帧，证明“客户端会解、窗口会建、只发差异”。
## 这条把同一组动作钉在**真服务端 + 真存档**上：
##   ① 夹具把开光十拳剑真穿在灵器槽(-23)、写轮眼铺到 6 阶；
##   ② 2081:4 回四脸 + 33 色，解锁位按 stage 算（6 阶 ⇒ 前两档 true、7/8 阶 false）；
##   ③ 2081:5/6 成功 ⇒ 落盘 `character.ling_face/ling_color` + 广播 199（第 13 位颜色）；
##   ④ 被拒（7/8 阶脸 / 不存在的色）⇒ success=0 且**不改内存、不落盘**；
##   ⑤ 真进图后玩家身上那层须佐能乎按新脸/新色显示，身体本身不换。
##
## 跑法（由 `开发工具/跑在线用例.ps1 -用例 十拳剑改变外观` 调，端口 18746/18747）：
##   python 开发工具/本地服务端夹具.py --root .fixture --reset \
##     --port 18746 --gm-http 18747 --ling-qi-appearance \
##     --run res://测试/十拳剑改变外观在线回归测试.gd --godot <Godot console exe>

const 门名 := "十拳剑改变外观在线回归测试"
const 神威脸 := 10000038
const 十拳脸 := 10000067
const 完全体脸 := 10000074
const 双刃脸 := 10000075
const 灵器槽 := -23
const 开光十拳剑 := 20200001

var _失败: Array[String] = []
var _判数 := 0
var _脸表: Array = []
var _色表: Array = []
var _结果: Array = []
var _外观帧: Array = []
var _颜色帧: Array = []
var _收好了 := false
var 会话引用: Node = null
var 原端口 := -1


func _记(成立: bool, 说明: String) -> void:
	_判数 += 1
	if not 成立:
		_失败.append(说明)


func _停(话: String) -> void:
	_还原设置()
	printerr("汇：判 %d 条 / 红 %d 条（%s：中断）" % [_判数, _失败.size() + 1, 门名])
	printerr("  红 - " + 话)
	quit(1)


func _帧(n := 1) -> void:
	for _i in range(n):
		await process_frame


func _等待(条件: Callable, 毫秒: int = 10000) -> bool:
	for _轮 in range(毫秒 / 50):
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


func _看门狗() -> void:
	await create_timer(180.0).timeout
	if _收好了:
		return
	printerr("汇：判 %d 条 / 红 %d 条（%s：看门狗超时）" % [_判数, _失败.size() + 1, 门名])
	quit(1)


func _还原设置() -> void:
	if 会话引用 != null and 原端口 >= 0:
		var 设置: Dictionary = 会话引用.get("game_settings")
		设置["backend_port"] = 原端口


func _on_脸表(脸: Array, 色: Array) -> void:
	_脸表 = 脸
	_色表 = 色


func _on_结果(动作: int, 成功: bool, 值: int) -> void:
	_结果.append([动作, 成功, 值])


func _on_外观(角色号: int, _性别: int, _肤色: int, 脸: int, 灵气脸: int, _装备串: String) -> void:
	_外观帧.append([角色号, 脸, 灵气脸])


func _on_颜色(角色号: int, 色: int) -> void:
	_颜色帧.append([角色号, 色])


## 在线是**每角色一份**存档：`NARUTO_MULTIPLAYER_ROOT/characters/<id>.json`。
## `NARUTO_SAVE_PATH` 是单机那份（夹具目录里确实也躺着一份，但那是别的角色的旧档），
## 拿错文件会读到恒 0 的 ling_face —— 第一版这门就栽在这里。
func _存档(角色号: int) -> Dictionary:
	var 根 := OS.get_environment("NARUTO_MULTIPLAYER_ROOT")
	var 路 := 根.path_join("characters").path_join("%d.json" % 角色号) if not 根.is_empty() else ""
	if 路.is_empty() or not FileAccess.file_exists(路):
		路 = OS.get_environment("NARUTO_SAVE_PATH")
	if 路.is_empty():
		return {}
	var 读 := FileAccess.open(路, FileAccess.READ)
	if 读 == null:
		return {}
	var 解 = JSON.parse_string(读.get_as_text())
	return 解 if 解 is Dictionary else {}


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _跑() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_停("缺单例（BackendConnection / GameSession）")
		return
	会话引用 = 会话
	后端.ling_qi_face_list_received.connect(_on_脸表)
	后端.ling_qi_appearance_result.connect(_on_结果)
	后端.char_look_changed.connect(_on_外观)
	后端.ling_color_changed.connect(_on_颜色)

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18746
	var 设置: Dictionary = 会话.get("game_settings")
	原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	后端.call("sync_character")
	if not await _等待(
			func(): return bool(后端.get("in_game")) and (后端.get("authoritative_inventory") as Array).size() > 0,
			15000):
		_停("进不了真实后端：%s - %s" % [后端.get("status"), 后端.get("detail")])
		return
	var 我号 := int(后端.get("character_id"))
	var 权: Dictionary = 后端.get("authoritative_stats")
	## 负槽装备来自 warp 帧第 39 截 / 2050 快照两条路，先后不定 ⇒ 等它到。
	var 都到了 := func() -> bool:
		var 权装 = 后端.get("authoritative_equipment")
		var 会装 = 会话.get("equipped_items")
		return 权装 is Dictionary and 会装 is Dictionary \
			and (权装 as Dictionary).has(灵器槽) and (会装 as Dictionary).has(灵器槽)
	await _等待(都到了, 5000)
	var 装: Dictionary = 后端.get("authoritative_equipment") if 后端.get("authoritative_equipment") is Dictionary else {}
	var 会话装: Dictionary = 会话.get("equipped_items") if 会话.get("equipped_items") is Dictionary else {}

	# ── ① 前置：夹具真的把剑穿在 -23、写轮眼 6 阶；客户端初始外观是 0/0 ──
	_记(int(权.get("lingFace", -1)) == 0 and int(权.get("lingQiColor", -1)) == 0,
			"① 开局灵器脸/色该是 0/0；实得 %s/%s" % [权.get("lingFace"), 权.get("lingQiColor")])
	var 槽件 = 装.get(灵器槽)
	_记(槽件 is Dictionary and int((槽件 as Dictionary).get("id", "0")) == 开光十拳剑,
			"① 灵器槽 -23 该穿着开光十拳剑 20200001；实得 %s（查不到=夹具前置没造上）" % [槽件])
	var 会话槽件 = 会话装.get(灵器槽)
	_记(会话槽件 is Dictionary and int((会话槽件 as Dictionary).get("id", "0")) == 开光十拳剑,
			"① 人物窗读的 `会话.equipped_items[-23]` 也得有这把剑，否则格子上点不到；实得 %s" % [会话槽件])
	if 会话槽件 is Dictionary:
		var 人物窗脚本: Script = load("res://脚本/界面/窗口/人物窗口.gd")
		var 菜单: Array = 人物窗脚本.装备菜单项(灵器槽, 会话槽件)
		_记(菜单.size() == 3 and String(菜单[2]) == "改变外观",
				"① 拿服务端真件过菜单判据该得 [卸下, 发到聊天框, 改变外观]；实得 %s" % [菜单])

	# ── ② 2081:4：四脸 + 33 色，解锁位按 6 阶算 ──
	后端.call("request_ling_qi_face_list")
	if not await _等待(func(): return _脸表.size() > 0, 10000):
		_停("② 发了 2081:4 但没收到脸表回帧（服务端 `_send_ling_qi_face_list` 没走到）")
		return
	_记(_脸表.size() == 4, "② 脸表该有 4 行；实得 %d" % _脸表.size())
	_记(_色表.size() == 33, "② 颜色表该有 33 行；实得 %d" % _色表.size())
	if _脸表.size() == 4:
		_记(int(_脸表[0].id) == 神威脸 and bool(_脸表[0].unlocked), "② 10000038（6 阶）该解锁；实得 %s" % [_脸表[0]])
		_记(int(_脸表[1].id) == 十拳脸 and bool(_脸表[1].unlocked), "② 10000067（6 阶）该解锁；实得 %s" % [_脸表[1]])
		_记(int(_脸表[2].id) == 完全体脸 and int(_脸表[2].required_stage) == 7 and not bool(_脸表[2].unlocked),
				"② 10000074 要 7 阶 ⇒ 6 阶号上必须灰；实得 %s" % [_脸表[2]])
		_记(int(_脸表[3].id) == 双刃脸 and int(_脸表[3].required_stage) == 8 and not bool(_脸表[3].unlocked),
				"② 10000075 要 8 阶 ⇒ 6 阶号上必须灰；实得 %s" % [_脸表[3]])
	if _色表.size() == 33:
		_记(int(_色表[0].id) == 0 and String(_色表[0].name) == "原色", "② 颜色 0 该叫「原色」；实得 %s" % [_色表[0]])
		_记(int(_色表[5].id) == 5 and is_equal_approx(float(_色表[5].red_mul), 1.14),
				"② 颜色 5 的乘值该逐值透传 1.14；实得 %s" % [_色表[5]])

	# ── ③ 改脸 10000038：成功 + 广播 199 + 落盘 ──
	_结果.clear()
	_外观帧.clear()
	后端.call("request_ling_qi_change_face", 神威脸)
	if not await _等待(func(): return _结果.size() > 0, 10000):
		_停("③ 2081:5:10000038 没收到结果帧")
		return
	_记(int(_结果[0][0]) == 5 and bool(_结果[0][1]) and int(_结果[0][2]) == 神威脸,
			"③ 改脸该回 success=1、值=10000038；实得 %s" % [_结果[0]])
	_记(int(权.get("lingFace", -1)) == 神威脸, "③ 权威镜像 lingFace 该变 10000038；实得 %s" % 权.get("lingFace"))
	if not await _等待(func(): return _外观帧.size() > 0, 5000):
		_停("③ 改脸成功后服务端该广播 199（`_change_ling_qi_appearance` 里先 _send_character_look）")
		return
	var 甲: Array = _外观帧[_外观帧.size() - 1]
	_记(int(甲[0]) == 我号 and int(甲[2]) == 神威脸,
			"③ 199 的收件人/灵气脸该是我 + 10000038；实得 %s" % [甲])
	var 存 := _存档(我号)
	var 角色: Dictionary = 存.get("character", {}) if 存.get("character") is Dictionary else {}
	_记(int(角色.get("ling_face", -1)) == 神威脸,
			"③ 真存档 character.ling_face 该落成 10000038；实得 %s" % 角色.get("ling_face"))

	# ── ④ 7 阶脸被拒：不写内存、不落盘、不广播 ──
	_结果.clear()
	_外观帧.clear()
	后端.call("request_ling_qi_change_face", 完全体脸)
	if not await _等待(func(): return _结果.size() > 0, 8000):
		_停("④ 越阶改脸没收到结果帧（服务端拒绝也要回 2081:5:0:<请求值>）")
		return
	_记(int(_结果[0][0]) == 5 and not bool(_结果[0][1]) and int(_结果[0][2]) == 完全体脸,
			"④ 6 阶号改 7 阶脸该回 success=0、值=10000074；实得 %s" % [_结果[0]])
	_记(int(权.get("lingFace", -1)) == 神威脸,
			"④ 被拒不许改权威镜像（仍该是 10000038）；实得 %s" % 权.get("lingFace"))
	_记(_外观帧.is_empty(), "④ 被拒不该广播 199；实得 %s" % [_外观帧])
	存 = _存档(我号)
	角色 = 存.get("character", {}) if 存.get("character") is Dictionary else {}
	_记(int(角色.get("ling_face", -1)) == 神威脸,
			"④ 被拒不许改存档；实得 %s" % 角色.get("ling_face"))

	# ── ⑤ 改色 5：成功 + 199 第 13 位 + 落盘；不存在的色被拒 ──
	_结果.clear()
	_颜色帧.clear()
	_外观帧.clear()
	后端.call("request_ling_qi_change_color", 5)
	if not await _等待(func(): return _结果.size() > 0 and _颜色帧.size() > 0, 10000):
		_停("⑤ 2081:6:5 没收到结果帧或 199 颜色位（两者都要有）")
		return
	_记(int(_结果[0][0]) == 6 and bool(_结果[0][1]) and int(_结果[0][2]) == 5,
			"⑤ 改色该回 success=1、值=5；实得 %s" % [_结果[0]])
	_记(int(权.get("lingQiColor", -1)) == 5, "⑤ 权威镜像 lingQiColor 该变 5；实得 %s" % 权.get("lingQiColor"))
	_记(int(_颜色帧[0][0]) == 我号 and int(_颜色帧[0][1]) == 5,
			"⑤ 199 第 13 位该让客户端发 ling_color_changed(我,5)；实得 %s" % [_颜色帧[0]])
	存 = _存档(我号)
	角色 = 存.get("character", {}) if 存.get("character") is Dictionary else {}
	_记(int(角色.get("ling_color", -1)) == 5,
			"⑤ 真存档 character.ling_color 该落成 5；实得 %s" % 角色.get("ling_color"))

	_结果.clear()
	后端.call("request_ling_qi_change_color", 99)
	if await _等待(func(): return _结果.size() > 0, 8000):
		_记(not bool(_结果[0][1]), "⑤ 不存在的颜色 99 该被拒（success=0）；实得 %s" % [_结果[0]])
		_记(int(权.get("lingQiColor", -1)) == 5, "⑤ 被拒不许改颜色；实得 %s" % 权.get("lingQiColor"))
	else:
		_记(false, "⑤ 非法颜色 99 没收到结果帧")

	# ── ⑥ 真进图：玩家身上那层须佐能乎按 10000038 / 5 显示，身体仍是普通人 ──
	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	await _帧(24)
	var 玩 = 图.get_node_or_null("Player")
	_记(玩 != null, "⑥ 地图场景该建出玩家节点")
	if 玩 != null:
		var 层 = 玩.get("灵器外观")
		_记(层 != null and is_instance_valid(层), "⑥ 玩家身上该挂灵器外观叠层")
		if 层 != null and is_instance_valid(层):
			_记(bool(层.get("visible")), "⑥ 叠层该可见（有脸 10000038）")
			_记(int(层.get("_脸")) == 神威脸 and int(层.get("_色")) == 5,
					"⑥ 叠层该按新脸/新色显示；实得 %s/%s" % [层.get("_脸"), 层.get("_色")])
			var 底 = 层.get("底")
			var 贴 = 底.sprite.texture if 底 != null and 底.sprite != null else null
			_记(贴 != null and String(贴.resource_path).contains("10000038"),
					"⑥ 叠层贴图该来自 10000038 那一套；实得 %s" % (String(贴.resource_path) if 贴 else "无"))
		var 身体 = 玩.get("player_sprite")
		var 身贴 = 身体.sprite.texture if 身体 != null and 身体.sprite != null else null
		_记(身贴 != null and not String(身贴.resource_path).contains("10000038"),
				"⑥ 身体本身不该被换成须佐能乎（灵器只是叠层）；实得 %s"
				% (String(身贴.resource_path) if 身贴 else "无"))

		# ── ⑦ 再换一张脸：叠层当场跟着换，不用重进图 ──
		_结果.clear()
		后端.call("request_ling_qi_change_face", 十拳脸)
		if await _等待(func(): return _结果.size() > 0, 10000):
			_记(bool(_结果[0][1]) and int(_结果[0][2]) == 十拳脸,
					"⑦ 同阶另一张脸 10000067 该成功；实得 %s" % [_结果[0]])
			await _帧(6)
			_记(int(层.get("_脸")) == 十拳脸,
					"⑦ 199 到了以后叠层该换到 10000067（不重进图）；实得 %s" % 层.get("_脸"))
		else:
			_记(false, "⑦ 改 10000067 没收到结果帧")

	# ── ⑧ 重登：落盘的脸/色必须随角色包回来 ──
	# 这一条专门照 `lingColor → lingQiColor` 的归一：换线帧只有脸、没有颜色位，
	# 颜色只能从登录角色包带进来。不归一的话重登后颜色退回原色（而当场改色那条 199 看不出来）。
	后端.call("sync_character")
	var 回来了 := await _等待(
			func(): return bool(后端.get("in_game")) \
				and int(权.get("lingFace", 0)) == 十拳脸 and int(权.get("lingQiColor", -1)) == 5,
			20000)
	_记(回来了, "⑧ 重登后该拿回脸 10000067 / 色 5；实得 %s/%s（in_game=%s）"
			% [权.get("lingFace"), 权.get("lingQiColor"), 后端.get("in_game")])
	if 回来了:
		var 看: Dictionary = 会话.call("自身外观")
		_记(int(看.get("lingFace", 0)) == 十拳脸 and int(看.get("lingQiColor", -1)) == 5,
				"⑧ 重登后 `自身外观()` 也该读到 10000067/5；实得 %s" % [看])
		## 重登时 warp 帧（负槽来源）和 2050 快照不是同一拍；属性先回来不等于装备表已到，
		## 这一句只等装备、别把时序差判成功能红（subset 后端实测过一次）。
		var 装备到了 := await _等待(
			func() -> bool:
				var 重装 = 会话.get("equipped_items")
				return 重装 is Dictionary and (重装 as Dictionary).has(灵器槽),
			5000)
		_记(装备到了, "⑧ 重登后灵器格仍该有剑（warp 第 39 截 + 快照合并两条路都要通）")
	_收好了 = true
	图.queue_free()
	await _帧(3)
	_还原设置()
	for 条 in _失败:
		printerr("  红 - " + 条)
	print("汇：判 %d 条 / 红 %d 条（%s：%s）" % [_判数, _失败.size(), 门名, "通过" if _失败.is_empty() else "失败"])
	quit(0 if _失败.is_empty() else 1)
