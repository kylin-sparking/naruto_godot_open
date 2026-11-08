extends SceneTree

## 装备品质覆盖层的**对证图**：六档资质 + 灵气，一次画全，跟原版素材逐像素比。
##
## 走的是真组件、真方法（`物品格.tscn` / `装备格.tscn` / `装备提示框.tscn`
## + `可拖拽格.设置品质` / `装备品质.挂覆盖层`），不是另搭一套演示场景 ——
## 所以这张图亮就代表格子/装备格/提示框三处都亮，暗了就三处一起暗。
##
## 用法（**不能加 --headless**，无头驱动拿不到视口图像）：
##   Godot --path . --script res://开发工具/截品质覆盖层.gd -- --出=res://测试/截图/品质覆盖层.png

const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
const 装备格场景 := preload("res://场景/界面/组件/装备格.tscn")
const 提示框场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 品质表 := preload("res://脚本/单例/装备品质.gd")

var _出 := "res://测试/截图/品质覆盖层.png"
var _帧 := 0
var _已搭 := false
var _待截 := false
## 搭出来的格子（[背包格, 装备格] 一对一对存），`_报实测` 要用它读**节点上的真实状态**。
var _格子: Array = []


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出":
			_出 = 键值[1]


func _撑开窗口() -> void:
	# 窗口默认只有工程设置的 960x560，而这张对证台要摆到 (1280,1600)：
	# 不撑开，第 3 列之后的提示框就全在视口外（`root.get_texture()` 抓的是窗口大小）。
	# ⚠️ 必须在**窗口建好之后**设 —— 在 `_initialize` 里赋值不生效（实测窗口仍是工程设置的 960x560）。
	root.size = Vector2i(1280, 1600)
	print("截品质覆盖层：窗口 %s" % root.size)


func _process(_delta: float) -> bool:
	_帧 += 1
	if _帧 == 1:
		_撑开窗口()
	if _帧 < 6:
		return false
	if not _已搭:
		_搭()
		_已搭 = true
		return false
	if not _待截:
		# 覆盖层是上一帧末才画进视口的，隔一帧再抓。
		_待截 = true
		return false
	var 图像 := root.get_texture().get_image()
	if 图像 == null:
		push_error("视口图像为空（不能加 --headless）")
		quit(1)
		return true
	var 目录 := _出.get_base_dir()
	if not DirAccess.dir_exists_absolute(目录):
		DirAccess.make_dir_recursive_absolute(目录)
	图像.save_png(_出)
	print("截品质覆盖层：已存 %s" % _出)
	quit(0)
	return true


func _搭() -> void:
	var 样本 := _取样()
	var 舞台 := Control.new()
	舞台.name = "品质对证台"
	root.add_child(舞台)
	# 底色用纯黑：框是亮色细描边，压在原版深灰格子底上量不出边缘。
	var 底 := ColorRect.new()
	底.color = Color(0.0, 0.0, 0.0, 1.0)
	底.size = Vector2(1280.0, 1600.0)
	舞台.add_child(底)

	for 序 in 样本.size():
		var 件: Dictionary = 样本[序]
		var x := 40.0 + 150.0 * 序
		var 标签 := Label.new()
		标签.text = String(件.get("显示", ""))
		标签.position = Vector2(x - 24.0, 18.0)
		标签.size = Vector2(144.0, 20.0)
		舞台.add_child(标签)

		var 背 := 物品格场景.instantiate() as Button
		背.position = Vector2(x, 46.0)
		舞台.add_child(背)
		_填格子(背, 件, true)

		var 身 := 装备格场景.instantiate() as Button
		身.position = Vector2(x, 106.0)
		舞台.add_child(身)
		_填格子(身, 件, false)
		_格子.append([背, 身])

	_排提示框(舞台, 样本)
	_报实测(样本)


## 同一件物品摆进一种格子：图标 + 覆盖层，全走组件自己的方法。
func _填格子(格: Button, 件: Dictionary, 认灵气: bool) -> void:
	var 物品: Dictionary = 件.get("物品", {})
	格.icon = 游戏数据.item_icon(String(物品.get("id", "")))
	格.disabled = false
	格.call("设置品质", 物品, 认灵气)


## 每件一张提示框，4 列排开（单张约 293 宽、内容多时会到 400 高）。
func _排提示框(舞台: Control, 样本: Array) -> void:
	for 序 in 样本.size():
		var 件: Dictionary = 样本[序]
		var 物品: Dictionary = 件.get("物品", {})
		var 框 := 提示框场景.instantiate() as Control
		舞台.add_child(框)
		框.call("设置", String(物品.get("id", "")), 100, 300, 物品)
		框.position = Vector2(20.0 + 300.0 * (序 % 4), 200.0 + 440.0 * int(序 / 4))
		框.visible = true


## 六档资质用同一件玩家装备（图标实测存在），只换 aptitude；
## 最后一件是灵气（十拳剑），验"没有 aptitude 也照样粉框 + 流光"那条分支。
func _取样() -> Array:
	var 结果: Array = []
	for 档 in range(1, 7):
		结果.append({
			"显示": "资质%d %s" % [档, String(品质表.档(档).get("颜色名", "?"))],
			"物品": _实例("01010014", 档),
		})
	结果.append({"显示": "灵气 无aptitude", "物品": _实例("20100001", 0)})
	return 结果


func _实例(物品id: String, 资质: int) -> Dictionary:
	var 条目 := {
		"id": 物品id,
		"name": String(游戏数据.item_name(物品id)),
		"icon": String(游戏数据.item_icon_path(物品id)),
		"quantity": 1,
		"endure": 100,
		"max_endure": 100,
		"strengthen": 0,
	}
	if 资质 > 0:
		条目["aptitude"] = 资质
	return 条目


## 把每个格子里覆盖层**节点上的真实状态**打出来 —— 截图看着像有框，节点上可能是空的。
func _报实测(样本: Array) -> void:
	for 序 in _格子.size():
		var 件: Dictionary = 样本[序]
		var 行 := "%s" % String(件.get("显示", ""))
		for 格 in _格子[序]:
			var 框 := (格 as Node).get_node_or_null("资质框") as TextureRect
			var 光 := (格 as Node).get_node_or_null("流光") as AnimatedSprite2D
			行 += " | %s: 框=%s/%s 光=%s/%s" % [
				格.name,
				"有" if (框 != null and 框.visible) else "无",
				"" if (框 == null or 框.texture == null) else String(框.texture.resource_path).get_file(),
				"有" if (光 != null and 光.visible) else "无",
				"" if 光 == null else "%s(%d帧)" % [光.animation,
					光.sprite_frames.get_frame_count(光.animation) if 光.sprite_frames != null else 0]]
		print("截品质覆盖层：%s" % 行)
