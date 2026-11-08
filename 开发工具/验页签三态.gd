extends SceneTree
## 设置页四枚页签的**真鼠标三态**门 + 像素证据（有头，不能加 --headless）。
##
## 为什么还要这一条：`测试/设置页回归测试.gd` 已经按实际生效值断言了 `_设态` 换的是哪张皮，
## 但"换了图"和"肉眼看得出亮/暗"是两件事 —— 派生皮要是算错（比如 alpha 被动了、或偏移符号写反），
## 皮肤文件名照样对、画面却毫无变化。2026-09-30 用户问的就是"按下去没反应"，得拿像素回话。
##
## 步序（照 `开发工具/验底栏钮态.gd` 的三条坑）：
##   常态 → 悬停 → 按下 → 松手(仍停在上面) → 移开
##   「松手仍停在上面」这一步是关键：原版 `MButton3.as:103-108` 松手回 **STATE_UP 不是 OVER**，
##   所以这一帧应当**回到常态亮度**（而不是继续亮着）—— 用 texture_hover 实现会在这一步露馅。
##
## 跑法：Godot --path . --script res://开发工具/验页签三态.gd
## 产物：测试/截图/页签三态_对照/{态_<页签>_<步名>.png ×5×4, 三态.txt, 退出码}

const 地图 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 出图 := "res://测试/截图/页签三态_对照"
const 页签 := ["页签系统设置", "页签快速键", "页签特殊设置", "页签客户端"]
## 每步 = [步名, 输入序列]。"进入 + 落位" 是两帧两跳：同一帧连发两条 motion 视口只按最后一条
## 拾取，大距离瞬移不触发 mouse_entered（`开发工具/验底栏钮态.gd` 坑 1）。
## 「松手仍停上」额外补一步 `关独立窗`：点 页签快速键 会把快捷键独立窗开出来**盖住这排页签**
## （实测裁到的像素从棕 (145,93,56) 变成灰 (82,78,78)），不挪开就拍不到页签本身。
## 关窗与拍图隔 ≥1 帧（本帧改的可见性不进本帧的 `root.get_texture()`）。
const 步序 := [["常态", ["移出"]], ["悬停", ["进入", "落位"]], ["按下", ["按下"]],
		["松手仍停上", ["松开", "关独立窗"]], ["移开", ["移出"]]]
const 起始帧 := 30
const 步间隔 := 4
const 移出位 := Vector2(6, 6)

var _帧 := 0
var _场: Node
var _窗: Node
var _行: Array[String] = []
var _失败: Array[String] = []
var _鼠 := Vector2.ZERO
var _上鼠 := Vector2.ZERO


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(出图)
	_场 = (load(地图) as PackedScene).instantiate()
	root.add_child(_场)


func _钮(名: String) -> TextureButton:
	return _窗.find_child(名, true, false) as TextureButton if _窗 != null else null


func _皮(钮: TextureButton) -> String:
	var 图 := 钮.texture_normal as Texture2D
	return String(图.resource_path).get_file() if 图 != null else "<空>"


func _发移动(点: Vector2) -> void:
	_鼠 = 点
	var e := InputEventMouseMotion.new()
	e.position = 点
	e.global_position = 点
	e.relative = 点 - _上鼠
	_上鼠 = 点
	root.push_input(e)


func _发键(点: Vector2, 按下: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = 点
	e.global_position = 点
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = 按下
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if 按下 else 0
	root.push_input(e)


func _步(名: String, 动作: String) -> void:
	var 钮 := _钮(名)
	if 钮 == null:
		_失败.append("找不到页签：" + 名)
		return
	var 心: Vector2 = 钮.get_global_rect().get_center()
	match 动作:
		"移出":
			_发移动(移出位)
		"关独立窗":
			_关快捷键窗()
		"进入":
			_发移动(_鼠.lerp(心, 0.5))		# 第一跳：只到中点（大距离瞬移不触发 mouse_entered）
		"落位", "按下", "松开":
			_发移动(心)
			if 动作 != "落位":
				_发键(心, 动作 == "按下")


func _验(名: String, 步名: String) -> void:
	var 钮 := _钮(名)
	if 钮 == null:
		return
	var 皮 := _皮(钮)
	var 期: String = String(({"常态": "页签未选.png", "悬停": "页签未选_悬停.png",
			"按下": "页签未选_按下.png", "松手仍停上": "页签未选.png",
			"移开": "页签未选.png"} as Dictionary)[步名])
	# 第 1 枚开局就是选中（disabled）⇒ 它永远拿不到三态，期望恒为未加亮的基皮
	if 名 == 页签[0]:
		期 = "页签未选.png"
	var 拾 := root.call("gui_get_hovered_control") as Control
	var 位: Vector2 = 钮.get_global_transform_with_canvas() * Vector2.ZERO
	var 串 := "%-14s %-12s 皮=%-22s hovered=%-14s 屏幕矩形=(%d,%d,%d,%d)" % [
		名, 步名, 皮, 拾.name if 拾 != null else "<无>",
		roundi(位.x), roundi(位.y), roundi(钮.size.x), roundi(钮.size.y)]
	if 皮 != 期:
		_失败.append("%s %s：皮应是 %s，实际 %s" % [名, 步名, 期, 皮])
		串 += "  !! 期望 " + 期
	elif 步名 != "常态" and 步名 != "移开" and 名 != 页签[0] and 拾 != 钮:
		_失败.append("%s %s：拾取没落在这枚页签上（实际 %s）" % [名, 步名, 拾.name if 拾 != null else "<无>"])
	_行.append(串)
	_裁(钮, 名, 步名)


func _裁(钮: Control, 名: String, 步名: String) -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null:
		_失败.append("视口图像为空（不能加 --headless）")
		return
	var 原: Vector2 = 钮.get_global_transform_with_canvas() * Vector2.ZERO
	var 尺 := Vector2i(roundi(钮.size.x), roundi(钮.size.y))		# 紧贴矩形、不外扩（屏缘会切）
	var 左 := Vector2i(clampi(roundi(原.x), 0, 图.get_width() - 1),
			clampi(roundi(原.y), 0, 图.get_height() - 1))
	尺.x = mini(尺.x, 图.get_width() - 左.x)
	尺.y = mini(尺.y, 图.get_height() - 左.y)
	图.get_region(Rect2i(左, 尺)).save_png(出图 + "/态_%s_%s.png" % [名, 步名])


var _序: Array[Callable] = []
var _号 := 0
var _下帧 := 起始帧


func _process(_d: float) -> bool:
	_帧 += 1
	if _序.is_empty() and _帧 == 起始帧 - 2:
		var 管 := _场.get_node_or_null("窗口管理")
		if 管 == null:
			quit(1)
			return true
		_窗 = 管.call("取或建窗口", "设置")
		管.call("打开", "设置")
		_窗.call("open_page", "设置")
		for 名 in 页签:
			_序.append(Callable(self, "_复位"))		# 上一枚可能点出了独立窗（快速键）⇒ 抢走拾取
			for 步 in 步序:
				for 动作 in (步[1] as Array):
					_序.append(Callable(self, "_步").bind(名, String(动作)))
				_序.append(Callable(self, "_验").bind(名, String(步[0])))
		_序.append(Callable(self, "_收尾"))
	if _帧 < _下帧 or _号 >= _序.size():
		return false
	_下帧 = _帧 + 步间隔
	_序[_号].call()
	_号 += 1
	return false


## 只收「快捷键」那扇独立窗（点 页签快速键 会把它开出来抢走 hovered、并盖住这排页签），
## **不能** `全部关闭` —— 那会把被测的设置窗自己也关掉，后面每一步都变成 `hovered=<无>`（第一版就是这么全红）。
func _关快捷键窗() -> void:
	var 管 := _场.get_node_or_null("窗口管理")
	if 管 == null:
		_失败.append("找不到 窗口管理")
		return
	var 窗们: Dictionary = 管.get("_窗口们") as Dictionary
	var 快: Node = 窗们.get("快捷键") as Node
	if 快 != null and bool(快.call("已打开")):
		快.call("close")


func _复位() -> void:
	_关快捷键窗()
	(_场.get_node_or_null("窗口管理") as Node).call("打开", "设置")	# 保证被测窗在顶上、且开着
	_发移动(移出位)


func _收尾() -> void:
	_行.append("")
	for 行 in _失败:
		_行.append("!! " + 行)
	_行.append("页签三态：%d 枚 × %d 步，红 %d" % [页签.size(), 步序.size(), _失败.size()])
	var f := FileAccess.open(出图 + "/三态.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_行))
		f.close()
	for 行 in _行:
		print(行)
	quit(1 if not _失败.is_empty() else 0)
