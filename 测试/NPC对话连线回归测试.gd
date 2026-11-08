## 点 NPC → **对话真的弹出来**（走 `地图实体._open_dialog` 那条真连线）。
##
## ⚠️ **测方法 ≠ 测连线**：`功能入口回归测试` 是**直接调 `小地图面板.show_npc_dialog()`**，
## 绕过了 `地图实体._open_dialog` 里"找 HUD"那一步。这条门从 `地图实体._open_dialog`
## 这一头进去，把那条连线一起测了。
##
## ⭐ **它的来历值得记一笔**：我一度以为这条连线断了 —— 依据是"全工程 grep `add_to_group`
## 只找到 `player`，没人加进 `game_hud`，所以 `_hud` 恒为 null"。**是错的**：
## 那个组是 **`场景/界面/小地图面板.tscn` 里声明的 `groups=["game_hud"]`**，
## 由**场景文件**给，不由代码给 —— 只 grep 代码当然查不到。
## **是反向对照救的场**：我把"修复"撤掉后此门**照样通过** ⇒ 原代码根本没坏。
## （如果当时没做反向对照，就会去"修"一个不存在的 bug，还往文档里写错结论。）
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
	var 生怪根 := 场景.get_node_or_null("LifeRoot")
	var 面板 := 场景.get_node_or_null("小地图面板")
	if 生怪根 == null or 面板 == null:
		_check(false, "缺 LifeRoot / 小地图面板")
		_finish()
		return

	# ① 面板要能被 `_find_hud()` 找到（组 或 节点名，两条路至少通一条）
	_check(面板.is_in_group("game_hud"), "小地图面板应加入 game_hud 组（_find_hud 靠它）")
	生怪根.call("_find_hud")
	var hud = 生怪根.get("_hud")
	_check(hud != null, "_find_hud 应找到 HUD（组为空时按节点名兜底）")
	_check(hud != null and hud.has_method("show_npc_dialog"), "找到的 HUD 必须真的能 show_npc_dialog")

	# ② 本图找一个 NPC，走真连线
	var 目标: Node2D = null
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
	# 2026-10-04 合并「纲手三页」包：弹出的不再是旧假气泡 `_dialog_panel`（它常驻隐藏，
	# 只留名字/台词两枚 Label 当台词源），而是 `NPC对话窗.gd` 现建的原版两格窗。
	# 连线断言改钉新窗：`_dialog.根().visible` 必须真被点亮，旧板必须保持隐藏（防"半新半旧"）。
	# 2026-10-11 §3.106：旧假气泡**连场景子树一起退役**了（不再是"常驻隐藏"）⇒
	#   判据从"旧板必须隐藏"改成"**旧板已经不存在**"；台词源改成了普通 String。
	var 新窗: Node = 面板.get("_对话")
	if 新窗 == null:
		_check(false, "小地图面板里没有 _对话（新对话窗没挂上？）")
		_finish()
		return
	_check(面板.get("_dialog_panel") == null,
			"旧假气泡 `_dialog_panel` 该已退役（§3.106），实际还在")
	新窗.call("根").visible = false

	生怪根.call("_open_dialog", 编号)
	for _frame in 2:
		await process_frame
	_check((新窗.call("根") as Control).visible,
			"点 NPC 后原版两格对话窗应真的弹出来（原来 _hud 恒 null，这里是静默不弹）")
	var 名 := String(面板.get("_dialog_name"))
	if not 名.is_empty():
		_check(名 != "NPC", "对话面板上的名字应是这个 NPC 的名字（实际 %s）" % 名)
	# ③ 面板记的 NPC 编号应是刚点的那个
	_check(String(面板.get("_dialog_npc_id")) == 编号,
			"对话面板应记着刚点的是哪个 NPC（期望 %s，实际 %s）" % [编号, String(面板.get("_dialog_npc_id"))])
	# ④ 菜单行的**命中区**必须盖住"看得见的东西"（用户 2026-10-10 报「物品交易/离开
	#    点击范围过小」）。原版 `SelectionLalel` 是 Sprite+buttonMode ⇒ 命中区=子节点实际
	#    画出来的范围（`QuestDialog.as:442-456`，文字画在 y=−7）；Godot 的命中区=Control 矩形，
	#    那 −7 只当子节点偏移留着，就会「字的上半截点不到 + 上一行矩形盖住下一行的字」。
	var 根: Control = 新窗.call("根") as Control
	var 菜单: Control = 根.get_node_or_null("下格/菜单") as Control
	if 菜单 == null:
		_check(false, "对话窗里找不到 下格/菜单")
	else:
		var 们: Array = []
		for 子 in 菜单.get_children():
			var c := 子 as Control
			if c != null and c.visible:
				们.append(c)
		_check(们.size() >= 2, "菜单行至少两行（物品交易/离开），实际 %d" % 们.size())
		var 包住了 := 0
		var 缝 := 0
		for i in 们.size():
			var c: Control = 们[i]
			var 字: Control = c.get_node_or_null("文字") as Control
			var 手: Control = c.get_node_or_null("手形") as Control
			var 区 := c.get_global_rect()
			if 字 != null and 区.encloses(字.get_global_rect()):
				包住了 += 1
			if 手 != null and 区.encloses(手.get_global_rect()):
				包住了 += 1
			if i + 1 < 们.size():
				var 下: Control = 们[i + 1]
				if absf(区.end.y - 下.get_global_position().y) < 0.51:
					缝 += 1
		_check(包住了 == 们.size() * 2,
				"每一行的命中矩形都要包住自己的「文字」与「手形」（点得到看得见的东西），实 %d 期望 %d"
						% [包住了, 们.size() * 2])
		_check(缝 == 们.size() - 1,
				"行与行必须**无缝无叠**（有缝=点不到、重叠=点到上一行），实 %d 期望 %d"
						% [缝, 们.size() - 1])
		var 第一: Control = 们[0] as Control
		var 首字: Control = 第一.get_node("文字") as Control
		_check(absf(第一.get_global_position().y - 首字.get_global_position().y) < 0.51,
				"行的顶要正好压在文字的顶上（原版文字 y=−7 已并进命中区），实 %s vs %s"
						% [str(第一.get_global_position().y), str(首字.get_global_position().y)])
		## ⚠ 「真点一下」这条不放在无头门里：无头 `push_input` 拿不到拾取（实测 拾到=空、0 次），
		## 留在门里只会假红。它由有头量具 `开发工具/量对话行热区.gd` 出表 + 实机验收。
		## 上面三条不变量（命中矩形 ⊇ 文字/手形、行与行无缝无叠、行顶压住字顶）
		## 正是"点得到看得见的东西"的充要条件。
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("NPC对话连线回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)
