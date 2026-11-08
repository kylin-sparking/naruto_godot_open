extends "res://开发工具/截意志学习页.gd"

## 意志学习 5 枚原版钮的**三态状态机门**（常态 / 悬停 +30 / 按下 −40 / 松手回常态）。
##
## 为什么单独一条门：用户报「一键学习/拾取那些按钮都是可以点击的，你没做完」。
## 原版这五枚全是 `ProgramButton extends MButton3`（`ProgramButton.as:7`）——
## **每组只有一张皮**，悬停/按下是运行时加性 ColorMatrixFilter
## （`StyleUtil.as:7-12` `skinFilters={up:0,over:30,down:-40}`、`:43-47` 不动 alpha），
## 手型光标在 `MButton3.init():135`，松手回的是 **STATE_UP 而不是 OVER**
## （`MButton3.mouseUpHandler:103-108`）。静态截图与几何门都验不出这一族东西。
##
## 逐步断言的是**实际生效值**：`texture_normal` 的文件名、`mouse_default_cursor_shape`、
## 视口 hover 归属、点击回执文案；每步还裁一张等尺寸图给 `出意志钮态对照图.py` 逐像素判。
##
## 用法（**不能加 --headless**，无头拿不到视口图像）：
##   Godot --path . --script res://开发工具/截意志钮态.gd -- "--出目录=res://测试/截图/意志钮态_对照"
## 然后：python 开发工具/出意志钮态对照图.py

const 步间隔 := 3	# 输入步与验步之间隔 3 帧：裁的是上一帧画完的视口图像

## 件路径名 → 三态皮基名（常态在 `原版窗口/意志/`，派生两态在 `专用控件/`）
const 钮表 := {
	"一键学习": "意志_一键学习", "全部拾取": "意志_全部拾取", "全部卖出": "意志_全部卖出",
	"返回": "意志_返回", "打开背包": "意志_打开背包",
}
## 点击回执（`TeacherPanel:89/185/209` 三条 request 后端没有 ⇒ 按项目约定回「需要连接原版服务端」）
const 回执表 := {
	"一键学习": "一键学习意志需要连接原版服务端",
	"全部拾取": "拾取全部意志需要连接原版服务端",
	"全部卖出": "卖出全部意志需要连接原版服务端",
}
## 件路径名 → 常态皮文件名（在 `素材/界面/原版窗口/意志/`，就是场景里烘的那张原件）
const 常皮表 := {
	"一键学习": "钮_一键学习.png", "全部拾取": "钮_全部拾取.png", "全部卖出": "钮_全部卖出.png",
	"返回": "钮_返回.png", "打开背包": "打开背包钮.png",
}
const 步序 := ["常态", "悬停", "按下", "松手", "移开", "再悬停"]
## 步 → 期望生效的皮后缀："" 表示"该回到常态那张原件"
const 步期望 := {"常态": "", "悬停": "_悬停", "按下": "_按下", "松手": "", "移开": "", "再悬停": "_悬停"}


func _队列尾() -> void:
	# 先**摘掉**五枚钮的 `pressed` 回执：状态机那 6 步里「按下→松手」是真的完整点击，
	# 「返回村庄」一被按就关窗 ⇒ 后面每枚钮都测不到（实测就是从这里开始整片红）。
	# 三态本身只吃 hover/button_down/button_up，与 pressed 无关 ⇒ 摘掉不影响被测的东西。
	队列.append(_步拆动作)
	for 名 in 钮表:
		for 步 in 步序:
			队列.append(_步送输入.bind(名, 步))
			# 悬停要**分两帧两跳**：同一帧连发两条 motion，视口只按最后一条做拾取，
			# 从远处一步跳到中心会**不发 mouse_entered**（skill 记过的实测坑）。
			if 步 == "悬停" or 步 == "再悬停":
				队列.append(_步进心.bind(名))
			队列.append(_步验.bind(名, 步))
	队列.append(_步接回)
	队列.append(_步点回执)
	队列.append(_步验回执)
	队列.append(_步点返回)
	队列.append(_步验返回)


var _试过: Dictionary = {}
var _摘掉的: Dictionary = {}	## 件路径名 → pressed 的 Callable 数组（测完原样接回）


func _步拆动作() -> void:
	for 名 in 钮表:
		var 件 := 钮件(名)
		if 件 == null:
			continue
		var 列: Array = []
		for 连 in 件.get_signal_connection_list("pressed"):
			列.append(连.callable)
			件.disconnect("pressed", 连.callable)
		_摘掉的[名] = 列
	_摘提示()
	等待 = 2




## 跑状态机**之前**把页面上所有 `文字提示_*` 摘掉。
## 为什么必须摘：提示框是页面根的最上层子节点（原版挂 stage，层级等价），
## 鼠标一停在钮上它就浮在钮的右下方 ⇒ `root.get_texture()` 里那块皮被提示盖住，
## 逐像素判定的就不再是那张皮（2026-09-28 实测：`打开背包` 的 5 个像素就是这么红的）。
## 提示本身另有两道门专管：`验意志导师交互.gd`（MToolTipText）/`验意志格渲染.gd`（YiZhiTip）。
func _摘提示() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	for 子 in 页.get_children():
		if String(子.name).begins_with("文字提示_"):
			页.remove_child(子)
			子.queue_free()


func _步接回() -> void:
	for 名 in _摘掉的:
		var 件 := 钮件(String(名))
		if 件 == null:
			continue
		for 回 in (_摘掉的[名] as Array):
			件.connect("pressed", 回 as Callable)
	等待 = 2


func 钮件(名: String) -> Control:
	var 页 := 页根()
	return 页.get_node_or_null(取路径(名)) as Control if 页 != null else null


## 鼠标移到钮中心；大距离瞬移同一帧只按最后一条 motion 做拾取
## （skill 记过的坑）⇒ 分两帧两跳：先跳中点，下一帧再进中心。
func _移到(件: Control, 点: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


func _步送输入(名: String, 步: String) -> void:
	var 件 := 钮件(名)
	if 件 == null:
		_错("取不到钮 %s" % 名)
		return
	var 心: Vector2 = 件.get_global_rect().position + 件.get_global_rect().size / 2.0
	# 「移开」的落点：页面里那块**空白背景**（意志格排 y=71..133 与导师面板 y=425 之间），
	# 不能用 `心 + (0,160)` —— 下面那几枚钮加 160 就掉出视口（视口才 580 高），
	# 视口外的 motion 不更新 hover ⇒ 半程/进心两跳都白走，实测「再悬停」拿不到亮态。
	var 远: Vector2 = 页根().get_global_position() + Vector2(300, 200)
	match 步:
		"常态":
			_移到(件, 远)
		"悬停":
			_移到(件, (心 + 远) / 2.0)	# 上一帧在 远 ⇒ 这帧只跳半程，下一帧才进中心
		"按下":
			_移到(件, 心)
			_键(件, 心, true)
		"松手":
			_移到(件, 心)
			_键(件, 心, false)
		"移开":
			_移到(件, 远)
		"再悬停":
			_移到(件, (心 + 远) / 2.0)
	等待 = 2 if 步 == "悬停" or 步 == "再悬停" else 步间隔


## 第二跳：从中点进到钮中心（`_步送输入` 的 悬停/再悬停 只走半程）。
func _步进心(名: String) -> void:
	var 件 := 钮件(名)
	if 件 == null:
		return
	var 心: Vector2 = 件.get_global_rect().position + 件.get_global_rect().size / 2.0
	_移到(件, 心)
	等待 = 步间隔


func _键(件: Control, 点: Vector2, 按下: bool) -> void:
	var 键 := InputEventMouseButton.new()
	键.position = 点
	键.global_position = 点
	键.button_index = MOUSE_BUTTON_LEFT
	键.pressed = 按下
	root.push_input(键)


func _步验(名: String, 步: String) -> void:
	var 件 := 钮件(名) as TextureButton
	if 件 == null:
		_错("取不到钮 %s" % 名)
		return
	var 皮 := 件.texture_normal as Texture2D
	var 得 := 皮.resource_path.get_file() if 皮 != null else "<无皮>"
	var 想 := String(步期望[步])
	# 派生两态 = `专用控件/<基名>_悬停|_按下.png`；"" 档 = 回常态那张原件（`原版窗口/意志/`）
	var 想名 := "%s%s.png" % [钮表[名], 想] if 想 != "" else String(常皮表[名])
	var 对: bool = 得 == 想名
	if not 对:
		_错("%s 第「%s」步 生效皮=「%s」，应为「%s」（rect=%s mf=%d dis=%s vis=%s）" % [
			名, 步, 得, 想名, 件.get_global_rect(), 件.mouse_filter, 件.disabled, 件.visible])
	if not 对 and (步 == "悬停" or 步 == "再悬停") and not _试过.has(名):
		# 第一颗钮的 hover 偶发收不到（视口鼠标位还没建立 ⇒ 首个 mouse_entered 丢）。
		# ⚠️ 重试**必须换个坐标**：hover 归属只在位置变化时重算，原地重发同一条 motion
		#    等于什么都没做（2026-09-28 实测：原地补一跳仍然红）。⇒ 先偏 3px 再进心。
		#    只补一次，不循环。
		_试过[名] = true
		var 心: Vector2 = 件.get_global_rect().position + 件.get_global_rect().size / 2.0
		_移到(件, 心 + Vector2(3, 3))
		等待 = 2
		队列.append(_步进心.bind(名))
		队列.append(_步验.bind(名, 步))
		return
	if 件.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_错("%s 没有手型光标（原版 MButton3.init():135 useHandCursor=true）" % 名)
	裁图(件, 名, 步)
	_行("  %-6s %-4s 皮=%-24s 应为 %-24s %s" % [名, 步, 得, 想名, "√" if 对 else "!!"])


## 每步裁一张**等尺寸、不外扩**的图（skill 坑②：视口图不跟 root.size 变，外扩会被屏缘切）。
func 裁图(件: Control, 名: String, 步: String) -> void:
	var 图像 := root.get_texture().get_image()
	var 盒 := 件.get_global_rect()
	var 起 := Vector2i(int(盒.position.x), int(盒.position.y))
	var 尺 := Vector2i(int(盒.size.x), int(盒.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	图像.get_region(Rect2i(起, 尺)).save_png("%s/态_%s_%s.png" % [出目录, 名, 步])


## 三枚「全部/一键」钮：点下去要有回执（原版是 request，后端没这条协议 ⇒ 按约定提示）。
func _步点回执() -> void:
	for 名 in 回执表:
		var 件 := 钮件(名)
		if 件 == null:
			continue
		var 心: Vector2 = 件.get_global_rect().position + 件.get_global_rect().size / 2.0
		_移到(件, 心)
		_键(件, 心, true)
		_键(件, 心, false)
	等待 = 步间隔


func _步验回执() -> void:
	var 主 := 主窗()
	var 状 := 主.get_node_or_null("后端状态") as Label if 主 != null else null
	if 状 == null:
		_错("没有 后端状态 Label")
		return
	var 键名 := 回执表.keys()
	var 最后一枚 := String(键名[键名.size() - 1])
	if 状.text != String(回执表[最后一枚]):
		_错("点完「%s」状态=「%s」，应为「%s」⇒ 钮根本没收到点击" % [最后一枚, 状.text, 回执表[最后一枚]])
	else:
		行.append("  钮可点        最后一枚「%s」⇒ 状态「%s」√" % [最后一枚, 状.text])


## `backMainTownHandler:214-217` = `setDOShow(窗,false)` ⇒ 点「返回村庄」应当**关掉本窗**。
func _步点返回() -> void:
	var 件 := 钮件("返回")
	if 件 == null:
		return
	var 心: Vector2 = 件.get_global_rect().position + 件.get_global_rect().size / 2.0
	_移到(件, 心)
	_键(件, 心, true)
	_键(件, 心, false)
	等待 = 步间隔


func _步验返回() -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗 := 管理.call("取窗口", "意志学习") as Node if 管理 != null else null
	var 开: bool = 窗 != null and bool(窗.call("已打开"))
	if 开:
		_错("点了「返回村庄」窗还开着（原版 backMainTownHandler 是 setDOShow(...,false) 关窗）")
	else:
		行.append("  返回可点        点「返回村庄」⇒ 本窗已关闭 √")
