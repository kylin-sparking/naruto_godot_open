extends SceneTree

## 逐个打开人物面板的主分页/子页并截图，用来"看"哪些页有内容、哪些是空的。
## 走的是功能入口测试同一条路径：底栏按钮 → 功能窗口 → 页面。
##
## 用法（**不能加 --headless**，无头驱动拿不到视口图像）：
##   Godot --path . --script res://开发工具/截窗口页.gd -- --出目录=res://测试/截图/人物面板
##
## 可选 `--快照=<json>`：截图前把一份**真服务端**的装备快照灌进 `GameSession.equipped_items`，
## 用来截"**装着装备**的人物面板"（离线示例数据身上是空的，空面板证明不了那一格会亮）。
## 快照由 `测试/装备部位在线回归测试.gd` 在穿上装备那一刻导出（设 NW_EQUIP_SNAPSHOT_OUT）。

const 主分页 := ["角色", "秘术", "血继界限"]
const 子分页 := [
	["人物", "手里剑", "结印"],
	["八门", "柔拳", "寄坏之术"],
	["写轮眼", "轮回六道"],
]

var _出目录 := "res://测试/截图/人物面板"
var _快照 := ""
var _帧 := 0
var _场景: Node = null
var _功能窗口: Node = null
var _主序号 := 0
var _子序号 := 0
var _已就绪 := false
var _截图数 := 0
var _待截 := false
var _等待 := 0

func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			_出目录 = 键值[1]
		elif 键值.size() == 2 and 键值[0] == "--快照":
			_快照 = 键值[1]
	var 场景脚本 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场景脚本 == null:
		push_error("无法加载地图场景")
		quit(1)
		return
	_场景 = 场景脚本.instantiate()
	root.add_child(_场景)

func _process(_delta: float) -> bool:
	_帧 += 1
	if _帧 < 8:
		return false
	if not _已就绪:
		# 装载要放在这里，不能放 `_initialize`：那时场景树还没激活，
		# `get_node("/root/...")` 会报 "outside the active scene tree"。
		if not _快照.is_empty():
			_装载快照(_快照)
		_打开人物面板()
		_已就绪 = true
		return false
	# ⚠️ **切页之后要隔几帧再抓**。原来这里是 `_帧 % 4` 控节奏、切页与抓图在同一帧 ——
	# 抓到的其实是**上一页**（症状：存成「八门」的那张是结印页）。
	# 改成状态机：切页 → 等 3 帧 → 抓。
	if _待截:
		if _等待 > 0:
			_等待 -= 1
			return false
		_待截 = false
		_抓图()
		return false
	if _主序号 >= 主分页.size():
		print("截窗口页：共 %d 张，目录 %s" % [_截图数, _出目录])
		quit(0)
		return true
	_切页()
	_待截 = true
	_等待 = 3
	return false

## 把真服务端的装备快照灌进会话。JSON 的键恒为字符串（§3.9.5 第 6 条），这里转回位置 int。
func _装载快照(路径: String) -> void:
	if not FileAccess.file_exists(路径):
		push_error("快照不存在：%s" % 路径)
		return
	var 解析 = JSON.parse_string(FileAccess.get_file_as_string(路径))
	if typeof(解析) != TYPE_DICTIONARY:
		push_error("快照解析失败：%s" % 路径)
		return
	var 会话 := root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		push_error("拿不到 /root/GameSession")
		return
	会话.equipped_items.clear()
	for 键 in 解析:
		会话.equipped_items[int(键)] = (解析[键] as Dictionary).duplicate(true)
	print("截窗口页：已装载装备快照 %s，槽=%s" % [路径, 会话.equipped_items.keys()])

func _打开人物面板() -> void:
	# 多窗口改造后，功能窗口按页各自一个实例（见 脚本/界面/窗口管理.gd）。
	_功能窗口 = _场景.get_node_or_null("窗口管理").call("取或建窗口", "人物")
	var 底栏 := _场景.get_node_or_null("技能面板/技能栏") as Control
	if _功能窗口 == null or 底栏 == null:
		push_error("缺少 功能窗口 或 底栏")
		quit(1)
		return
	for 节点 in 底栏.find_children("*", "BaseButton", true, false):
		var 按钮 := 节点 as BaseButton
		if 按钮 != null and 按钮.tooltip_text == "人物":
			按钮.pressed.emit()
			print("截窗口页：已打开人物面板")
			return
	push_error("底栏没找到 tooltip=人物 的按钮")

## 切到当前要截的那一页（**不抓图** —— 抓图由 `_抓图` 隔几帧再做）。
func _切页() -> void:
	var 名称: String = String(子分页[_主序号][_子序号])
	# 先切主分页。直接调窗口的切页方法：按钮 press 在这里不生效（原因待查），
	# 而切页方法本身就是按钮回调，等价且更可靠。
	if _功能窗口.has_method("_set_character_main_tab"):
		_功能窗口.call("_set_character_main_tab", _主序号)
	# 再切子分页（按文字找）
	var 子容器 := _功能窗口.find_child("子分页", true, false)
	if 子容器 != null:
		for 节点 in 子容器.get_children():
			var 按钮 := 节点 as BaseButton
			if 按钮 != null and 按钮.text == 名称:
				按钮.button_pressed = true
				按钮.pressed.emit()
				break


## 抓当前这一页并存盘。**必须在 `_切页()` 之后隔几帧再调**，否则抓到的是上一页。
func _抓图() -> void:
	var 名称: String = String(子分页[_主序号][_子序号])
	var 图像 := root.get_texture().get_image()
	if 图像 == null:
		push_error("视口图像为空（不能加 --headless）")
		quit(1)
		return
	if not DirAccess.dir_exists_absolute(_出目录):
		DirAccess.make_dir_recursive_absolute(_出目录)
	图像.save_png("%s/%s.png" % [_出目录, 名称])
	_截图数 += 1
	print("截窗口页：已存 %s" % 名称)
	_子序号 += 1
	if _子序号 >= 子分页[_主序号].size():
		_子序号 = 0
		_主序号 += 1
