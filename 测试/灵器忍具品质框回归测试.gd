extends SceneTree

## 灵器/忍具的品质覆盖层：**人物面板格子**与**悬停详情框**都要有粉框 + 流光。
##
## 用户 2026-10-31 报：十拳剑装备后在人物面板「装备格没有流光外框，鼠标放上去的
## 装备详情框也没有外框」；八咫镜同样。
##
## 原版真值（这三处都是**整族恒粉框**，根本不看 aptitude）：
##   · 人物面板两格各是专用类 —— `LingQiCell.setCellValue`（`LingQiCell.as:85-92`）、
##     `RenJuCell.setCellValue`（`RenJuCell.as:85-92`）：`new EquipAptitudePinkF()` +
##     `new EquipAnimationF()`，条件只有"这格有值"；
##   · 提示框 `MToolTipLingQiTip.as:94-105` / `MToolTipRenJuTip.as:98-109`：同上；
##   · 背包格 `ItemWindowCell.addLingQiitemAnima`（`:170-188`）/
##     `addRenJuItemFrame`（`:191-204`）同样。
## 本工程人物面板用通用 `装备格` 顶这两格，以前一律按 `aptitude` 查（这两族没有该字段）
## ⇒ 整格什么都不叠；提示框则把灵气当普通装备、只按 aptitude 查。
##
## 反向腿（必须红）：`设置品质` 不传开关 ⇒ 不出粉框（仓库格/列表行原版就没有这条分支）。
##
## 运行：Godot --headless --path . --script res://测试/灵器忍具品质框回归测试.gd

const 装备品质 := preload("res://脚本/单例/装备品质.gd")
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 提示框场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
const 装备格场景 := preload("res://场景/界面/组件/装备格.tscn")
const 门存档快照 := preload("res://测试/门存档快照.gd")

const 灵器id := "20100001"   ## 十拳剑
const 忍具id := "65000001"   ## 八咫镜
const 紫装id := "01010011"   ## 普通武器（小太刀），实例给资质 4
const 粉框素材 := "res://素材/界面/装备品质/资质框_灵气.png"

var _失败: Array[String] = []
var _文件前 := {}


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")


func _查(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)


func _查粉框(宿主: Control, 该有: bool, 说明: String) -> void:
	var 框 := 宿主.get_node_or_null("资质框") as TextureRect
	_查(框 != null, "%s：找不到资质框节点" % 说明)
	if 框 == null:
		return
	if 该有:
		_查(框.visible and 框.texture != null and 框.texture.resource_path == 粉框素材,
			"%s：应有粉框（visible=%s tex=%s）" % [说明, 框.visible,
				框.texture.resource_path if 框.texture != null else "null"])
	else:
		_查(not 框.visible, "%s：不该有粉框（visible=%s）" % [说明, 框.visible])


func _查流光(宿主: Control, 该有: bool, 说明: String) -> void:
	var 灯 := 宿主.get_node_or_null("流光") as AnimatedSprite2D
	if 该有:
		_查(灯 != null and 灯.visible and 灯.is_playing(), "%s：应有在播的流光" % 说明)
	else:
		_查(灯 == null or not 灯.visible, "%s：不该有流光" % 说明)


func _run() -> void:
	# ---------- ① 提示框：灵器/忍具都恒粉框 + 流光 + 粉标题 ----------
	var 框 := 提示框场景.instantiate() as Control
	root.add_child(框)
	for 条 in [[灵器id, "十拳剑"], [忍具id, "八咫镜"]]:
		var 号: String = 条[0]
		var 名: String = 条[1]
		框.call("设置", 号, 100, 0, {"id": 号})
		await process_frame
		_查粉框(框.get_node("图标框") as Control, true, "提示框·%s" % 名)
		_查流光(框.get_node("图标框") as Control, true, "提示框·%s" % 名)
		var 标题 := 框.get_node("标题") as Label
		_查(标题.get_theme_color("font_color") == Color("ff5498"),
			"提示框·%s：标题应恒粉 #ff5498（UI_PINK），实际 %s"
			% [名, 标题.get_theme_color("font_color").to_html(false)])
		# 普通装备照资质走，别被粉框接管
		框.call("设置", 紫装id, 100, 0, {"id": 紫装id, "aptitude": 4})
		await process_frame
		var 紫框 := 框.get_node("图标框/资质框") as TextureRect
		_查(紫框.texture != null and 紫框.texture.resource_path == 装备品质.边框路径(4),
			"提示框·紫装：应按资质 4 的框，实际 %s"
			% (紫框.texture.resource_path if 紫框.texture != null else "null"))
	框.queue_free()

	# ---------- ② 格子开关：背包(两种都认) / 仓库(只认灵气) / 关着 ----------
	var 格 := 物品格场景.instantiate() as Button
	root.add_child(格)
	格.call("设置品质", {"id": 忍具id}, true, true)
	await process_frame
	_查粉框(格, true, "物品格·忍具（背包口径 认忍具=true）")
	_查流光(格, true, "物品格·忍具（背包口径）")
	格.call("清空品质覆盖层")
	格.call("设置品质", {"id": 忍具id}, true)
	await process_frame
	_查粉框(格, false, "物品格·忍具（仓库口径 没开认忍具）")
	var 器格 := 装备格场景.instantiate() as Button
	root.add_child(器格)
	器格.call("设置品质", {"id": 灵器id}, false)
	await process_frame
	_查粉框(器格, false, "装备格·灵器（页面没开 认灵气）")
	器格.call("设置品质", {"id": 灵器id}, true)
	await process_frame
	_查粉框(器格, true, "装备格·灵器（开了 认灵气）")
	器格.call("清空覆盖层")
	await process_frame
	_查粉框(器格, false, "清空覆盖层后")
	器格.queue_free()
	格.queue_free()

	# ---------- ③ 人物面板真窗口：灵器格/忍具格 + 悬停详情框 ----------
	var packed := load("res://场景/地图/地图场景.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _帧 in range(5):
		await process_frame
	var 会话 = root.get_node_or_null("GameSession")
	var 管理 := scene.get_node_or_null("窗口管理")
	var 人物窗: Node = 管理.call("取或建窗口", "人物") if 管理 != null else null
	if 会话 == null or 人物窗 == null:
		_失败.append("拿不到 GameSession 或人物窗口")
		_收尾()
		return
	var 会话槽: Dictionary = 会话.equipped_items
	var 原装备: Dictionary = 会话槽.duplicate(true)
	for 条 in [[灵器id, 装备部位表.灵器, "十拳剑"], [忍具id, 装备部位表.忍具, "八咫镜"]]:
		var 号: String = 条[0]
		var 位: int = 条[1]
		var 名: String = 条[2]
		会话槽.clear()
		会话槽[位] = {"id": 号, "name": 名, "category": "装备", "quantity": 1,
			"icon": 游戏数据.item_icon_path(号)}
		人物窗.call("open_page", "人物")
		for _帧 in range(6):
			await process_frame
		var 容器 := 人物窗.find_child("装备格子容器", true, false)
		var 面板格: Button = null
		if 容器 != null:
			面板格 = 容器.get_node_or_null(String(人物窗口脚本.装备格节点[位])) as Button
		if 面板格 == null:
			_失败.append("人物面板找不到 %s 的格子节点" % 名)
			continue
		_查粉框(面板格, true, "人物面板·%s 格" % 名)
		_查流光(面板格, true, "人物面板·%s 格" % 名)
		面板格.mouse_entered.emit()
		await process_frame
		var 悬框 := 人物窗.find_child("装备提示框", true, false) as Control
		if 悬框 == null:
			_失败.append("人物面板找不到 装备提示框")
		else:
			_查(悬框.visible, "人物面板·%s：悬停后提示框应可见" % 名)
			_查粉框(悬框.get_node("图标框") as Control, true, "人物面板悬停·%s" % 名)
			_查流光(悬框.get_node("图标框") as Control, true, "人物面板悬停·%s" % 名)
		面板格.mouse_exited.emit()
		await process_frame
	会话槽.clear()
	会话槽.merge(原装备, true)
	_收尾()


func _收尾() -> void:
	门存档快照.全还原(_文件前)
	if _失败.is_empty():
		print("灵器忍具品质框回归测试：通过（提示框灵/忍恒粉框+流光+粉标题 / "
			+ "格子开关三态 / 人物面板灵器格·忍具格 / 悬停详情框）")
		quit(0)
	else:
		for 项 in _失败:
			push_error("灵器忍具品质框回归测试：失败 - %s" % 项)
		quit(1)
