extends SceneTree
## 有头量具：把「NPC 头顶三档任务标记」「任务完成横幅」「选中箭头」真跑一遍并截屏。
##
## 为什么要有它：这三样都是**运行期建的节点**，静态读代码看不出来画没画出来
## （10-07 小地图那次就是"节点存在而图一张不画"被 `图层.源` 漏写蒙过去的）。
## 判据分两层：① 节点/纹理/位置的实际值；② 截屏上那块区域**到底有没有像素**。
##
## 用法（**不能加 --headless**，无头拿不到视口图像）：
##     "godot" --path . --script res://开发工具/截任务标记与横幅.gd
const 出目录 := "res://测试/截图/任务标记"
const 档名 := {1: "可接", 2: "可交", 3: "进行中"}

var _失败: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	if not 成立:
		_失败.append(说明)


func _run() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _帧 in 12:
		await process_frame
	var 生怪根 := 场景.get_node_or_null("LifeRoot")
	if 生怪根 == null:
		_断言(false, "没有 LifeRoot")
		_收()
		return
	var 全: Array = 生怪根.get("_entities") as Array
	var 们: Array = []
	for 实体 in 全:
		if 实体 is Node2D and String((实体 as Node2D).get("kind")) == "n":
			们.append(实体)
	_断言(们.size() >= 3, "本图至少要有 3 枚 NPC 才够摆三档（实际 %d）" % 们.size())
	if 们.size() < 3:
		_收()
		return

	# ① 三档标记：逐档建、逐档验实际生效的贴图文件名
	var 档序 := [1, 2, 3]
	var 期望图 := {1: "QuestIcon_0", 2: "QuestIcon_2", 3: "QuestIcon_1"}
	for i in 3:
		var 谁 := 们[i] as Node2D
		var 状态: int = 档序[i]
		生怪根.call("_挂任务标记", 谁, 状态)
		await process_frame
		await process_frame
		var 标 := 谁.get_node_or_null("QuestMarker") as Node2D
		_断言(标 != null, "%s 档没建出 QuestMarker" % 档名[状态])
		if 标 == null:
			continue
		_断言(bool(标.get("visible")), "%s 档标记不可见" % 档名[状态])
		_断言(String(标.get("entry_name")) == 期望图[状态],
				"%s 档应播 %s，实际「%s」" % [档名[状态], 期望图[状态], String(标.get("entry_name"))])
		var 图 := _取图(标)
		_断言(图 != null and 图.contains(期望图[状态]),
				"%s 档实际贴图不是真图（resource_path = %s）—— 自造件没被换掉" % [档名[状态], 图])
		var 高: float = 谁.call("贴图高")
		_断言(高 > 0.0, "%s 档 NPC 贴图高为 0，位置判据没意义" % 档名[状态])
		_断言(absf(float(标.position.y) - (-高 - 5.0)) < 0.01,
				"%s 档标记 y 应为 -贴图高-5（%.0f），实际 %.0f" % [档名[状态], -高 - 5.0, float(标.position.y)])

	# ② 选中箭头：挑一枚 NPC 点亮，验贴图与 y
	var 箭主 := 们[0] as Node2D
	var 箭 := 箭主.get_node_or_null("SelectionMarker") as Node2D
	_断言(箭 != null, "NPC 上没有预挂 SelectionMarker")
	if 箭 != null:
		箭.visible = true
		var 高2: float = 箭主.call("贴图高")
		_断言(absf(float(箭.position.y) - (-高2 - 8.0)) < 0.01,
				"箭头 y 应为 -贴图高-8（%.0f），实际 %.0f" % [-高2 - 8.0, float(箭.position.y)])
		_断言(String(箭.get("entry_name")) == "MobSelected_Effect_Skin",
				"箭头应播 MobSelected_Effect_Skin，实际「%s」" % String(箭.get("entry_name")))
		_断言(_取图(箭).contains("MobSelected_Effect_Skin"), "箭头实际贴图不是真图：%s" % _取图(箭))
	await process_frame
	await process_frame
	_截("三档标记与箭头", 们)

	# ③ 任务完成横幅：直接调 HUD 的 播任务完成横幅()，验节点 + 区域有像素
	var HUD: Node = get_first_node_in_group("game_hud")
	_断言(HUD != null, "没有 game_hud 组，量不到横幅")
	if HUD != null:
		HUD.call("播任务完成横幅")
		for _帧 in 20:
			await process_frame
		var 横 := _找横幅(HUD)
		_断言(横 != null, "播了横幅但 HUD 下找不到那个节点")
		if 横 != null:
			_断言(absf((横 as Node2D).position.x - 480.0) < 0.01,
					"横幅 x 应为 480（Config.STAGE_WIDTH/2，视口宽 960），实际 %.0f" % (横 as Node2D).position.x)
			_断言(absf((横 as Node2D).position.y - 50.0) < 0.01,
					"横幅 y 应为 50，实际 %.0f" % (横 as Node2D).position.y)
			_断言(float((横 as CanvasItem).modulate.a) > 0.5,
					"淡入窗口内 alpha 应已爬上去，实际 %.2f" % float((横 as CanvasItem).modulate.a))
			var 视 := root.get_texture().get_image()
			var 区 := 视.get_region(Rect2i(268, 50, 424, 98))
			_断言(_不透明像素数(区) > 2000,
					"横幅那块区域几乎是空的（不透明像素 %d）⇒ 节点在但没画出来" % _不透明像素数(区))
			区.save_png(出目录 + "/横幅区域.png")
		_截("整屏含横幅", [])
	_收()


## 从 EffectPlayer 里把当前生效的贴图路径挖出来（它内部是 `_sprite: Sprite2D`）。
func _取图(节点: Node) -> String:
	for 子 in 节点.get_children():
		if 子 is Sprite2D and (子 as Sprite2D).texture != null:
			return String((子 as Sprite2D).texture.resource_path)
	return ""


func _不透明像素数(图: Image) -> int:
	var 数 := 0
	for y in 图.get_height():
		for x in 图.get_width():
			if 图.get_pixel(x, y).a > 0.5:
				数 += 1
	return 数


func _找横幅(HUD: Node) -> Node:
	if HUD is Node2D and String(HUD.name) == "任务完成横幅":
		return HUD
	for 子 in HUD.get_children():
		var 找 := _找横幅(子)
		if 找 != null:
			return 找
	return null


func _截(名: String, _们: Array) -> void:
	var 图 := root.get_texture().get_image()
	图.save_png(出目录 + "/" + 名 + ".png")
	print("截图 → %s/%s.png（视口 %dx%d）" % [出目录, 名, 图.get_width(), 图.get_height()])


func _收() -> void:
	if _失败.is_empty():
		print("截任务标记与横幅：通过（三档真图 + 箭头 + 横幅都画出来了）")
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	quit(1)
