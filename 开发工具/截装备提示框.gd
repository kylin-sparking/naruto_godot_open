extends SceneTree

## 把「装备提示框」组件单独渲染出来截图，用来和原版真机图做并排 / 8 倍单件对证。
##
## 与 `截物品提示框.gd` 同源：提示框是**贴鼠标弹**的浮层，跑整个游戏去截会带上背包和地图、
## 裁图原点难对；这里把它放在固定位置 (20,20)，裁图原点就是 (20,20)。
##
## 装备的「这一件」的运行时字段（endure/strengthen/inlays/apitude…）来自
## `测试/基线/装备快照/*.json` 里某一槽，用 `--槽=` 指定哪个位置（默认 -1 武器）。
##
## 用法（**不能加 --headless**）：
##   Godot --path . --script res://开发工具/截装备提示框.gd -- \
##     --物品=01010011 --快照=res://测试/基线/装备快照/武器.json --槽=-1 --出=res://测试/截图/装备提示框.png

const 提示框场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

var _物品 := "01010011"
var _快照 := "res://测试/基线/装备快照/武器.json"
var _槽 := "-1"
var _等级 := 100
var _职业 := 300
var _出 := "res://测试/截图/装备提示框.png"
var _帧 := 0
var _框: Control
var _已填 := false
var _待截 := false


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() != 2:
			continue
		match 键值[0]:
			"--物品": _物品 = 键值[1]
			"--快照": _快照 = 键值[1]
			"--槽": _槽 = 键值[1]
			"--等级": _等级 = int(键值[1])
			"--职业": _职业 = int(键值[1])
			"--出": _出 = 键值[1]
	_框 = 提示框场景.instantiate() as Control
	root.add_child(_框)
	_框.position = Vector2(20.0, 20.0)


## ⚠️ `SceneTree._process` **不是协程**，里面写 `await` 不会挂起、后面几句当帧就跑完了，
## 于是 "await 等渲染" 实际没等 —— 第一次写这个工具就卡在这儿。
## 照 `截物品提示框.gd` 的状态机：本帧填内容，**隔一帧**再截图
## （本帧 set 的文本要到帧末才画进视口）。
func _process(_delta: float) -> bool:
	_帧 += 1
	# 等主题与字体就绪（第一帧量字体会拿到空字体，行高会是 0）。
	if _帧 < 5:
		return false
	if not _已填:
		var 实例 := _读实例()
		_框.call("设置", _物品, _等级, _职业, 实例)
		_框.position = Vector2(20.0, 20.0)
		_框.scale = Vector2.ONE
		_框.visible = true
		print("截装备提示框：框 size=%s，实例字段 %d 个" % [_框.size, 实例.size()])
		_已填 = true
		return false
	if not _待截:
		_待截 = true
		return false
	root.get_texture().get_image().save_png(_出)
	print("截装备提示框：已存 %s（物品 %s，槽 %s）" % [_出, _物品, _槽])
	quit(0)
	return true


## 从快照里取该槽的实例字段；取不到就返回空字典（提示框会走"没有实例数据"的分支）。
func _读实例() -> Dictionary:
	if not FileAccess.file_exists(_快照):
		push_error("快照不存在：%s" % _快照)
		return {}
	var 解析 = JSON.parse_string(FileAccess.get_file_as_string(_快照))
	if typeof(解析) != TYPE_DICTIONARY:
		return {}
	for 键 in 解析:
		if str(键) == _槽:
			return (解析[键] as Dictionary).duplicate(true)
	return {}
