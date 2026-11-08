extends SceneTree
# 好友子窗几何门（headless，表驱动）：期望读 `数据/界面/好友子窗_*.json`（与场景同一份 SPEC），
# 逐件比**窗口坐标**矩形（这两扇自成一窗、不减内容区原点），另钉三条：
#   ① 标题/关钮落点按 `MWindow.as:162-221` 现算（小底 y=3、非小底 y=5；关钮 x=round(宽−25−6)、y=标题y+1）
#      —— 不是抄来的数，公式变了门要响；
#   ② 每颗 TextureButton 运行期必须有皮（丢皮 = 白框）；
#   ③ 原版初值 disabled 的钮（选人窗"查看资料/多功能"）运行期读到的确实是**灰皮**档。
# 跑法：Godot --path . --headless --script res://测试/好友子窗回归测试.gd

const 目录 := "res://场景/界面/窗口/好友/"
const 期望目录 := "res://数据/界面/"
const 容差 := 1.0
const 关钮宽 := 25.0
var _红 := 0


func _initialize() -> void:
	var 名单 := Array(DirAccess.get_files_at(期望目录))
	名单.sort()
	var 窗数 := 0
	var 件数 := 0
	for 名 in 名单:
		var 文件 := String(名)
		if not 文件.begins_with("好友子窗_") or not 文件.ends_with(".json"):
			continue
		var 窗名: String = 文件.trim_prefix("好友子窗_").trim_suffix(".json")
		var f := FileAccess.open(期望目录.path_join(文件), FileAccess.READ)
		var 期: Dictionary = JSON.parse_string(f.get_as_text())
		f.close()
		var 根: Control = (load(目录 + 窗名 + ".tscn") as PackedScene).instantiate()
		root.add_child(根)
		窗数 += 1
		根.call("装配", load("res://测试/假好友宿主.gd").new())	# 场景根已挂 家族子窗.gd，只递宿主
		var 宽: float = (期["窗"] as Array)[0]
		var 题Y: float = 3.0 if bool(期["小底"]) else 5.0
		_量(窗名, "标题", 根.get_node("标题"), [0, 题Y, 宽, 18.0], 根)
		_量(窗名, "关钮", 根.get_node("关钮"), [roundf(宽 - 关钮宽 - 6.0), 题Y + 1.0, 关钮宽, 24.0], 根)
		件数 += 2
		for 键 in 期["件"]:
			if 键 in ["标题", "关钮"]:
				continue
			_量(窗名, 键, _找(根, 键), (期["件"][键] as Array)[0], 根)
			件数 += 1
		for 子 in 根.get_children():
			if 子 is TextureButton and (子 as TextureButton).texture_normal == null:
				_报("%s/%s 运行期没皮" % [窗名, 子.name])
		验禁用档(窗名, 根)
		根.free()
	print("好友子窗几何门：%d 窗 / %d 件，红 %d" % [窗数, 件数, _红])
	quit(1 if _红 > 0 else 0)


## 期望表（`好友子窗_*.json`）记的是**件名 + 窗口坐标**；场景里嵌套的件（`消息容器` 挂在
## `消息视口` 下）局部 `position` 是相对父节点的，所以这里按名字递归找、再沿父链把
## position 累加回窗口原点。生成器只减父原点不减中间层，靠的就是这一步。
func _找(根: Control, 名: String) -> Control:
	var 直 := 根.get_node_or_null(名) as Control
	if 直 != null:
		return 直
	return 根.find_child(名, true, false) as Control


func _窗坐标(节: Control, 根: Control) -> Vector2:
	var p := Vector2.ZERO
	var 游: Node = 节
	while 游 != null and 游 != 根:
		if 游 is Control:
			p += (游 as Control).position
		游 = 游.get_parent()
	return p


func _量(窗名: String, 件: String, 节: Control, 局: Array, 根: Control) -> void:
	if 节 == null:
		_报("%s/%s 节点没找到" % [窗名, 件])
		return
	var 位 := _窗坐标(节, 根)
	var d := maxf(maxf(absf(位.x - float(局[0])), absf(位.y - float(局[1]))),
			maxf(absf(节.size.x - float(局[2])), absf(节.size.y - float(局[3]))))
	if d > 容差:
		_报("%s/%s 实测 (%s,%s,%s,%s) ≠ 期望 %s" % [窗名, 件, 位.x, 位.y, 节.size.x, 节.size.y, 局])


## 选人窗那两枚原版初值就 disabled（`SPW:215,218`）⇒ 控制器必须把它们摆成灰皮档。
func 验禁用档(窗名: String, 根: Control) -> void:
	for 钮名 in ["查看资料钮", "多功能钮"]:
		var 钮 := 根.get_node_or_null(钮名) as TextureButton
		if 钮 == null:
			continue
		if not 钮.disabled:
			_报("%s/%s 初值没 disabled（原版 SPW:215/218）" % [窗名, 钮名])
		elif not String(钮.texture_normal.resource_path).ends_with("_灰.png"):
			_报("%s/%s disabled 却没拿灰皮（%s）" % [窗名, 钮名, 钮.texture_normal.resource_path])


func _报(话: String) -> void:
	_红 += 1
	print("!! " + 话)
