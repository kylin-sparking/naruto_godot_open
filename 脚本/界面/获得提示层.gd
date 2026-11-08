extends Control

## 原版 `com/mxw/uifl/chat/NoticePnl.as` —— **右下角那列"获得提示"**。
##
## 它不是弹窗、不是一块板，就是一列**右对齐的描边文字**，从面板原点往上长：
##   位置 `x = STAGE_WIDTH − 250`、`y = STAGE_HEIGHT − 125`（`:35-36`，都是运行期舞台尺寸）
##   单行宽 250、`autoSize = RIGHT` ⇒ **右对齐**、字号 12、`GlowFilter(0,1,2,2,4,3)` 黑色外发光
##   最多 8 行（`:19` `MAX_LINES`），第 9 行进来时**最旧那行**被摘掉（`:103-106` `shift()`）
##   排布（`doLayout:68-80`）：从**最后一条**开始 `y = 累计 − 文本高`，再 `累计 = y − 5`
##     ⇒ 最新的一行贴在面板原点上方，越旧的越靠上（整列向上长）
##   计时（`addNotice:89-91` + `onTimeHand:109-138`）：**每来一条就把计时器归零**；
##     前 10 秒整块 alpha=1，之后每 50ms 减 0.1（≈0.5 秒淡完），alpha ≤ 0.1 时**整块清空**并停表
##     ⇒ 注意是"整块一起淡出、一起清空"，不是每行各自计时。
##
## 谁来写这一列（本工程）：`后端连接` 照原版 `DataCenter.updateOneStatu` 算属性差值、
## 照 `ItemManager` 算背包增减，拼好文案后发 `获得提示` 信号 ⇒ 这里只负责画。

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

const 最大行 := 8				# NoticePnl.as:19
const 面板宽 := 250.0			# :47 tf.width = 250（也是 x = 舞台宽 − 250 的那个 250）
const 行距 := 5.0				# :77 _loc1_ = tf.y − 5
const 停留秒 := 10.0			# :25 TIME_SHOW = 10（秒，Timer.delay=1000）
const 淡出步长 := 0.1			# :117 alpha = (10 − (count − 10)) / 10
const 淡出帧秒 := 0.05			# :116 Timer.delay = 50
const 字号 := 12				# :43

var _行: Array[RichTextLabel] = []
var _秒表 := 0.0
var _淡出 := false
var _淡出计 := 0.0
## 对应 `API.dataCenter.selectInfoWindowCharInfoData`（`:84` 每条都往历史里塞一份，
## 给"角色信息/选中信息"那块窗回看用）。本工程那扇窗还没做 ⇒ 先只留数组，别丢。
var 历史: Array[String] = []
const 历史上限 := 200


func _init() -> void:
	name = "获得提示层"
	## 原版 `mouseChildren = mouseEnabled = false`（`:30-31`）⇒ 这一列完全不挡鼠标。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


## 位置跟着**运行期舞台**走（`:35-36` 用的是 `Config.STAGE_WIDTH/HEIGHT`，那两个数就是
## `Game.as:76-93` 的 onResizeHandler 写进去的真实窗口尺寸），所以这里接视口尺寸变化，
## 和原版一样"不缩放、只重排"。宿主只需 `add_child` 这一层，不必再摆它。
func _ready() -> void:
	var 视口 := get_viewport()
	if 视口 != null:
		视口.size_changed.connect(func() -> void: 摆到舞台(视口.get_visible_rect().size))
		摆到舞台(视口.get_visible_rect().size)


## 对应 `addNotice(htmlText)`。原版传的是 `<font color=…>` 那套，
## 本工程统一在**发送方**就拼成 BBCode（`[color=#00cc33]…[/color]`），这里只做转义兜底。
func 加一条(文本: String) -> void:
	历史.append(文本)
	if 历史.size() > 历史上限:
		历史.pop_front()
	var 条 := RichTextLabel.new()
	条.name = "获得%d" % (历史.size())
	条.bbcode_enabled = true
	条.fit_content = true
	条.scroll_active = false
	## ⚠ `RichTextLabel` **没有** `width` 这个属性（那是 Control 的 `size.x`），
	##   写 `条.width = 250` 是无头运行期才报的 "Invalid assignment of property or key 'width'"，
	##   parse 阶段过、一调用就整条静默中断（2026-10-10 探针抓到：行数恒为 0）。
	条.size = Vector2(面板宽, 0.0)
	条.custom_minimum_size = Vector2(面板宽, 0.0)
	条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	条.add_theme_font_size_override("normal_font_size", 字号)
	条.add_theme_font_size_override("normal_font_size", 字号)
	## 行距走本工程统一口径 **AS3 leading + 2**（`TextArea2` 那一条）：原版 TextField 的
	## leading=0，但 Godot 12px 行盒比 Flash 的 textHeight 矮 2px ⇒ 补 2 才和别的文字件同密。
	## 原版一行装不下的长文案会折行（`multiline = wordWrap = true`，`:97`），折出来就靠这个数。
	条.add_theme_constant_override("line_separation", 2)
	条.add_theme_color_override("font_outline_color", 皮肤表.文字规则_描边色)
	条.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
	条.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT		# autoSize = RIGHT
	条.text = 文本
	add_child(条)
	_行.append(条)
	while _行.size() > 最大行:
		var 旧 := _行[0]
		_行.remove_at(0)
		旧.queue_free()
	## 每来一条都重置整块的寿命（`:89-91` delay=1000 / reset / start + alpha=1）
	_秒表 = 0.0
	_淡出 = false
	_淡出计 = 0.0
	modulate.a = 1.0
	_摆位()


func 行数() -> int:
	return _行.size()


func 清空() -> void:
	for 条 in _行:
		条.queue_free()
	_行.clear()
	modulate.a = 1.0
	_秒表 = 0.0
	_淡出 = false
	_淡出计 = 0.0


func _process(增量: float) -> void:
	if _行.is_empty():
		return
	_秒表 += 增量
	if not _淡出:
		if _秒表 < 停留秒:
			_摆位()
			return
		## 越过 10 秒这一拍 alpha **仍是 1**（原版 `count == TIME_SHOW` 那一下算出来就是
		## `(10 − 0)/10 = 1`，淡出从下一拍才开始）⇒ 只把**超出**的那一点记进淡出账，
		## 否则一帧 0.5 秒会把淡出一次吃掉 10 档，变成"瞬间消失"。
		_淡出 = true
		_淡出计 = _秒表 - 停留秒
	else:
		## ⚠ 这一句不能省：淡出的账要**逐帧累加**。漏了它，`_淡出计` 永远停在越过那一拍的
		##   零头 ⇒ while 一次都不进 ⇒ 这一列**永远挂在那儿不淡**（2026-10-10 门抓到）。
		_淡出计 += 增量
	while _淡出计 >= 淡出帧秒:
		_淡出计 -= 淡出帧秒
		modulate.a = maxf(0.0, modulate.a - 淡出步长)
	if modulate.a <= 淡出步长:
		## `:123-137` alpha ≤ 0.1 ⇒ 整块清空 + 停表（**不是**一行行各自消失）
		清空()
		return
	_摆位()


## 原版 `doLayout`：从最后一条往上排，`y = 累计 − 文本高`、`累计 = y − 5`。
## Godot 侧 `fit_content` 的行高要等布局跑完才准 ⇒ 每帧重排一次（最多 8 行，代价可忽略），
## 这样"刚写进去的那行"下一帧就会把上面几行顶对位置。
func _摆位() -> void:
	var 累计 := 0.0
	var i := _行.size() - 1
	while i >= 0:
		var 条 := _行[i]
		var 高 := 条.size.y
		if 高 <= 0.0:
			高 = 条.get_combined_minimum_size().y
		条.position = Vector2(0.0, 累计 - 高)
		累计 = 条.position.y - 行距
		i -= 1


## `:35-36` 用的是**运行期**舞台尺寸（原版 `Config.STAGE_WIDTH/HEIGHT`）⇒ 跟着视口走，别钉常数。
func 摆到舞台(舞台: Vector2) -> void:
	position = Vector2(舞台.x - 面板宽, 舞台.y - 125.0)
