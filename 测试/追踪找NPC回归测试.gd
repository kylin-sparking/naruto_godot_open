## 任务追踪面板里点「任务接取：<NPC>」那条链接 → **走到 NPC 跟前**。
##
## 真值 `CharacterHandler.MovePlayerToNpc()`（`:685-717`）：
##   `guajiHandler.isStart = false` → 取 NPC 所在图与坐标 →
##   **同图就 `pathFind(x, y)` 走过去**，跨图先 `MovePlayerToMap`。
## 触发点是 `QuestTrackerItemRenderer` 的 `event:findNpc` 链接（`:200/216`）。
##
## ⚠️ 我们原来这条注释写的是"**本工程还没有寻路 API**，先按本图 NPC 开对话"——
##    于是点它是**开对话**，不是走过去。`走向()` 现在有了（§3.67 A4），照原版改回**走过去**。
extends SceneTree

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _run() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _frame in 12:
		await process_frame
	var 面板 := 场景.get_node_or_null("小地图面板")
	var 玩家 := 场景.get_node_or_null("Player")
	if 面板 == null or 玩家 == null:
		_check(false, "缺 小地图面板 / Player")
		_finish()
		return
	_check(面板.has_method("_追踪链接点击"), "小地图面板应实现 _追踪链接点击")

	# 本图里找一个 NPC
	# ⚠️ 别用 `get_nodes_in_group("npc")` —— 全工程没人往那个组里加过东西，恒为空。
	var 生怪根 := 场景.get_node_or_null("LifeRoot")
	var 目标: Node2D = null
	if 生怪根 != null:
		for 实体 in 生怪根.get("_entities") as Array:
			var 谁 := 实体 as Node2D
			if 谁 != null and String(谁.get("kind")) == "n" and String(谁.get("entity_id")) != "":
				目标 = 谁
				break
	if 目标 == null:
		_check(false, "本地图没有 NPC，本条测不到东西")
		_finish()
		return
	var 编号 := String(目标.get("entity_id"))

	# 把玩家挪到 NPC 远处，好分辨"有没有开始走"
	玩家.set("position", 目标.global_position + Vector2(-600.0, 0.0))
	玩家.call("cancel_auto_path")
	_check(not bool(玩家.get("click_move_active")), "起手不该已经有一条路线")
	_check(玩家.get("自动接近目标") == null, "起手不该有'走过去打'那条命令")

	# 造一个带 find_npc meta 的富文本（原版链接的 id 就存在渲染器字段/meta 里）
	var 标 := RichTextLabel.new()
	标.set_meta("find_npc", int(编号))
	面板.add_child(标)
	面板.call("_追踪链接点击", "event:findNpc", 标)

	_check(bool(玩家.get("click_move_active")), "点 findNpc 链接应真的起一条路线（原版 MovePlayerToNpc）")
	_check(玩家.get("自动接近目标") == null, "这条是**走过去**，不是'走过去打'那条命令")
	# 终点应是 NPC 脚下那块脚点
	var 脚点 := 场景.get_node_or_null("Footholds")
	if 脚点 != null:
		var 落点: Dictionary = 脚点.call("find_click_target", 目标.global_position)
		_check(String(玩家.get("click_target_fh_id")) == String(落点.get("id", "")),
				"路线终点应是 NPC 脚下的脚点（期望 %s，实际 %s）"
				% [String(落点.get("id", "")), String(玩家.get("click_target_fh_id"))])

	# 不在本图的编号：不该乱走，也不该起一条空路线
	玩家.call("cancel_auto_path")
	标.set_meta("find_npc", 99999999)
	面板.call("_追踪链接点击", "event:findNpc", 标)
	_check(not bool(玩家.get("click_move_active")),
			"NPC 不在本图时不该起路线（跨图那条 `MovePlayerToMap` 本工程还没接，别假装走得到）")
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("追踪找NPC回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)
