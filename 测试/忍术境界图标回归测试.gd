extends SceneTree

## 忍术境界图标（`Character.setTotalSkillLevel`，用户 2026-10-20 报「忍术境界达标时形象下不显示境界标志」）。
##
## 原版这条线有两头：
##   · **自己**：总层数 = 已学忍术层数之和（`DataCenter.getTotalSkillLevel`）；
##   · **别人**：服务端 `UPDATE_CHAR_SKILL_LEVEL = 1348`（`<ii>` 角色号 + 总层数）→
##     `CharacterHandler.onForeignCharAllskillLevel:801` → 那个人 `Character.setTotalSkillLevel`。
## 本工程以前**一条 1348 都没解**（grep 只命中注释）⇒ 别人的名字行下永远没有境界图标。
##
## 这条门钉三件事：
##   ① `1348:<角色号>:<总层数>` 解得出、信号数值对；
##   ② 档位按 `SkillJingJie` 那七个门槛算、贴图 `Effect_RenShuJingJie_<档>/1.png`、缩放 族徽边长/30；
##   ③ 图标/底框挂在**名字行**（`_statusIconPane.y = _namePane.y`），且底框在图标下面（树序）。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 忍术境界门槛 := [100, 250, 450, 700, 1000, 1400, 1900]
const 忍术境界原边长 := 30.0

var _failures: Array[String] = []
var _已记 := 0


func _initialize() -> void:
	call_deferred("_run")


func _记(条件: bool, 说明: String) -> void:
	_已记 += 1
	if not 条件:
		_failures.append(说明)


func _失败(说明: String) -> void:
	_failures.append(说明)
	_收尾()


func _收尾() -> void:
	if _failures.is_empty():
		print("忍术境界图标回归测试：通过（%d 条断言：1348 解帧 / 档位贴图缩放 / 名字行摆位 / 底框树序 / 自家总层数）" % _已记)
	else:
		for 条 in _failures:
			printerr("  ✗ ", 条)
		print("忍术境界图标回归测试：失败 %d 条 / 共 %d 条" % [_failures.size(), _已记])
		quit(1)
		return
	quit(0)


func _run() -> void:
	root.size = Vector2i(960, 560)
	var 场景 := (load(地图资源.playable_scene_path(默认地图)) as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame

	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_失败("拿不到 BackendConnection")
		return
	# 地图实体脚本挂在 LifeRoot 上（地图场景.tscn：path="res://脚本/地图/地图实体.gd" id="6_life"）。
	var 实体 := 场景.get_node_or_null("LifeRoot")
	if 实体 == null:
		_失败("拿不到 LifeRoot（地图实体）")
		return

	# ① 解帧：`1348:<角色号>:<总层数>`
	var 收到: Array = []
	后端.connect("他人忍术境界收到", func(号: int, 层: int) -> void: 收到.append([号, 层]))
	后端.call("_handle_char_skill_level_text", PackedStringArray(["1348", "777", "250"]))
	await process_frame
	_记(收到.size() == 1, "`1348` 没有转发（他人忍术境界收到 一次都没发）")
	if 收到.size() == 1:
		_记(int(收到[0][0]) == 777 and int(收到[0][1]) == 250,
			"`1348` 解出来的号/层数不对：%s" % [收到[0]])

	# ② 远程玩家：造一个跟真身同形的演员（Nameplate 在名字行）
	var 演员 := Node2D.new()
	演员.name = "远程玩家_777"
	场景.add_child(演员)
	var 名牌 := Label.new()
	名牌.name = "Nameplate"
	名牌.text = "测试玩家"
	名牌.size = Vector2(94, 20)
	名牌.position = Vector2(-47, 0)
	演员.add_child(名牌)
	var 行高 := 名牌.get_theme_font("font").get_height(名牌.get_theme_font_size("font_size"))
	实体.call("_刷远程境界图标", 演员, 250)

	var 图 := 演员.get_node_or_null("SkillJingJieIcon") as Sprite2D
	var 框 := 演员.get_node_or_null("SkillJingJieIconFrame") as Sprite2D
	_记(图 != null, "`_刷远程境界图标` 没建出 SkillJingJieIcon")
	_记(框 != null, "`_刷远程境界图标` 没建出底框 SkillJingJieIconFrame")
	if 图 != null:
		var 期望档 := 0
		for i in 忍术境界门槛.size():
			if 250 >= int(忍术境界门槛[i]):
				期望档 = i
		_记(图.texture != null and String(图.texture.resource_path).contains("Effect_RenShuJingJie_%d" % 期望档),
			"总层 250 应当贴第 %d 档（实得 %s）" % [期望档, "" if 图.texture == null else 图.texture.resource_path])
		_记(is_equal_approx(图.scale.x, 18.0 / 忍术境界原边长),
			"境界图标缩放应 = 族徽边长/30（实得 %s）" % 图.scale)
		# 报修 8 那条缝：图标排锚在原版"牌原点"上（= 该行墨迹底 + **4** 个空行，
		# `RoleNamePane.as:122/134/171/182` + `Character.as:1501`），4 这个数手抄在这儿，
		# 别从产品码取 —— 取来就自洽了、把缝改成 0 也照样绿。+1 是图标在 20×20 框里的内缩。
		_记(is_equal_approx(图.position.y, 名牌.position.y + 行高 + 4.0 + 1.0),
			"境界图标 y 应在名字行**下面留 4px 缝**（期望 %s，实得 %s）" % [
				名牌.position.y + 行高 + 4.0 + 1.0, 图.position.y])
		_记(图.position.x < 0.0, "单枚境界图标应左偏（原版 `_statusIconPane.x = -10 * 数量`），实得 %s" % 图.position.x)
	if 图 != null and 框 != null:
		_记(框.get_index() < 图.get_index(), "底框必须排在图标前面（同级按树序绘制，先加的在下层）")

	# ③ 不够 100 层 ⇒ 整件不画（`SkillJingJie.getJingjie(总层) < 0`）
	实体.call("_刷远程境界图标", 演员, 99)
	await process_frame
	_记(演员.get_node_or_null("SkillJingJieIcon") == null, "总层 99 还留着境界图标（档 < 0 应当整件不画）")

	# ④ 自家那头：总层数来自已学忍术层数之和（离线口径）。
	# 先清空 ⇒ 连自家原有的那枚也要收掉；再灌 100 层 ⇒ 重新长出来。
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_失败("拿不到 GameSession")
		return
	var 原技能: Array = 会话.get("learned_skills").duplicate(true)
	会话.set("learned_skills", [] as Array[Dictionary])
	实体.call("_刷忍术境界图标")
	await process_frame
	_记(场景.find_child("SkillJingJieIcon", true, false) == null,
		"总层 0 时自家还留着境界图标（档 < 0 应当整件不画）")
	会话.set("learned_skills", [{"id": "0001000", "level": 100, "master_level": 0}] as Array[Dictionary])
	实体.call("_刷忍术境界图标")
	await process_frame
	var 自家 := 场景.find_child("SkillJingJieIcon", true, false) as Sprite2D
	var 人物 := get_first_node_in_group("player") as Node2D
	_记(自家 != null, "自家总层 100 时没长境界图标（`_刷忍术境界图标` 没建出来）")
	if 自家 != null and 人物 != null:
		_记(自家.get_parent() == 人物, "自家的境界图标没挂在人物身上")
	# ⑤ 加层也要进境界：基础 60 + 加层 390 = 450 ⇒ 第 3 档（门槛 450）。
	#   修前只数 `level`，450 层还贴着上一档的图（用户 2026-11-07 报）。
	会话.set("learned_skills", [
		{"id": "1001001", "level": 20, "master_level": 0},
		{"id": "1001002", "level": 20, "master_level": 0},
		{"id": "1001003", "level": 20, "master_level": 0}] as Array[Dictionary])
	会话.set("skill_added_levels", {"1001001": 200, "1001002": 100, "1001003": 90})
	实体.call("_刷忍术境界图标")
	await process_frame
	var 加层图 := 场景.find_child("SkillJingJieIcon", true, false) as Sprite2D
	_记(加层图 != null and 加层图.texture != null
			and String(加层图.texture.resource_path).contains("Effect_RenShuJingJie_2"),
		"⭐ 基础 60 + 加层 390 = 450 ⇒ 自家境界图标必须是第 3 档（实得 %s）"
		% ("" if 加层图 == null or 加层图.texture == null else 加层图.texture.resource_path))
	会话.set("skill_added_levels", {})
	会话.set("learned_skills", 原技能)
	实体.call("_刷忍术境界图标")
	await process_frame

	_收尾()
