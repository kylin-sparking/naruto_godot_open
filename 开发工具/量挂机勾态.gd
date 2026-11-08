## 有头量具：挂机页那 25 枚勾**移过来会不会亮、按下去会不会暗、松手回不回常态、禁用压不压得住悬停**。
##
## 为什么要它（用户 2026-10-19 实机打回「你做的挂机页没有点击交互性，原版点各种内容都有
## 点击效果，你做的很死板」）：这颗勾的全部反馈都在**方框那张皮的亮度**上，而 404 条离线门
## 一条都没判过亮度 —— 它只判「点下去状态翻不翻」。而且场景里那颗 `Button` 是 `flat=true`，
## Godot 的 flat **只免画 `normal` 那一张**，`hover`/`pressed` 仍照主题画（`按钮.png` 会整行铺过去），
## ⇒ "有没有反馈、反馈是不是原版那一种"只能在**屏幕上**量，读节点属性读不出来。
##
## 真值口径（三条都会被这条量具钉住）：
##   * `MCheckBox.as:6` → `MButton3` ⇒ over/down = `getLightFilter(±30/−40)`（`StyleUtil.as:7-12,43-47`）
##   * `MButton3.as:103-108` 松手回 **STATE_UP**（不是 OVER）⇒ 不移开鼠标就不该再亮
##   * `MButton3.as:444-451` `textColor` 把四档写成同一个数 ⇒ **文字不许变色**
##   * `MButton3.as:461-478` `set enabled(true)` 把 `_state` 钉回 STATE_UP ⇒ VIP 恢复后
##     哪怕鼠标还压在它身上，也必须回**常态**（不是悬停）
##
## 跑法（**不能加 `--headless`**，无头拿不到视口图像与拾取）：
##   godot --path . --script res://开发工具/量挂机勾态.gd
## 外面套 `本地包装脚本`（按下会落存档；那份包装按字节快照/还原两份共用存档）。
## 产物：`测试/截图/挂机勾态/勾_<件>_<态>.png` 逐态裁图 + `user://挂机勾态量具.txt`，
##       裁图交给 `开发工具/出勾态对照图.py` 按 `getLightFilter` 公式逐像素判。
extends SceneTree

const 出目录 := "res://测试/截图/挂机勾态"
## 每一步"应当生效的皮后缀"（`开发工具/生成复选框态图.py` 烘出来的 `_悬停/_按下/_灰`）。
const 期望后缀 := {
	"常态": "", "悬停": "_悬停", "按下": "_按下", "松手": "", "移开": "", "再悬停": "_悬停",
	"禁用": "_灰", "恢复": "",
}

var 行: Array[String] = []
var 红 := 0
var 判数 := 0
var 会: Node
var 场: Node
var 页: Control
var 鼠 := Vector2.ZERO
var 上一鼠 := Vector2.ZERO
var 出图 := 0
var 清单: Array[String] = []
var 击: Dictionary = {}		# "件名|down" / "|up" / "|press" → 次数（按下投递是否真的落在这颗钮上的证据口）


func _initialize() -> void:
	call_deferred("_跑")


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _判(对: bool, s: String) -> void:
	判数 += 1
	if 对:
		_记("ok   " + s)
	else:
		红 += 1
		_记("红   " + s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


## 两跳：同一帧连发两条 MouseMotion，视口只按**最后一条**做拾取 ⇒ 大距离瞬移不发
## `mouse_entered`（skill `flash-mbutton3-state-skins` 坑 1，实测过）。
func _跳到(点: Vector2) -> void:
	if 鼠.distance_to(点) > 48.0:
		_移动((鼠 + 点) * 0.5)
		await _帧(2)
	_移动(点)
	await _帧(3)


func _移动(点: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = 点
	e.global_position = 点
	e.relative = 点 - 上一鼠
	上一鼠 = 点
	鼠 = 点
	root.push_input(e)


func _键(点: Vector2, 按下: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = 点
	e.global_position = 点
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = 按下
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if 按下 else 0
	root.push_input(e)


func _皮名(件: TextureRect) -> String:
	if 件 == null or 件.texture == null:
		return "〈没皮〉"
	return 件.texture.resource_path.get_file().trim_suffix(".png")


func _拾取名() -> String:
	var 中 = root.call("gui_get_hovered_control")
	return (中 as Node).name if 中 != null else "〈无〉"


## 圆心**每次现算**：窗口在开窗后头几十帧里还会挪位，抄一份旧坐标 = 鼠标打在空处，
## 于是"皮没换"这种红其实是量具自己没打中（实测同一份代码两次跑一次中一次不中）。
func _钮心(钮: Control) -> Vector2:
	var 矩 := 钮.get_global_rect()
	return 矩.position + 矩.size * 0.5


func _取件(件名: String) -> Array:
	var 根: Control = 页.get_node_or_null(件名) as Control
	if 根 == null:
		return []
	return [根, 根.get_node_or_null("点击区域") as Button,
			根.get_node_or_null("指示框") as TextureRect,
			根.get_node_or_null("标记") as TextureRect,
			根.get_node_or_null("文本") as Label]


## 把鼠标"钉"在这颗钮上：每次都用**当下的**全局矩形重算圆心，拾取没落到它上面就重试。
## 为什么要重试而不是"算一次就打一次"：实测同一份代码两次跑，第一枚的悬停一次中、
## 另一次拾取到的是 `主窗口`（鼠标坐标对不上钮的矩形）⇒ 开窗后头几十帧里窗口还在挪/
## 布局还没落定。量具自己抖 = 判据红得没意义，所以先让它自己把鼠标找对地方，
## 找不到就把矩形打出来（红行必须可比）。
func _指到(钮: Control, 件名: String, 态: String) -> void:
	var 最后一次 := "〈无〉"
	for 试 in 8:
		var 矩 := 钮.get_global_rect()
		var 心: Vector2 = 矩.position + 矩.size * 0.5
		await _跳到(心)
		最后一次 = _拾取名()
		if 最后一次 == "点击区域":
			return
		## 拾取没落上：先甩到别处再回来（补一次真正"变了位置"的 motion，逼视口重新拾取）。
		await _跳到(Vector2(6.0, 6.0))
	_记("  （重试 8 次仍拾取不到：%s 的 圆心=%s 矩形=%s 窗口位=%s）" % [
			态, str(钮.get_global_rect().position + 钮.get_global_rect().size * 0.5),
			str(钮.get_global_rect()), str(页.get_global_rect().position)])


func _计(件名: String, 键: String) -> void:
	击[件名 + 键] = int(击.get(件名 + 键, 0)) + 1


## 按下/抬起**重试到"这颗钮真的收到了"**为止（最多 4 次），理由实测过：同一份代码连跑四次，
## 其中一次第一条的 `button_down` 根本没来（拾取到的确实是这颗钮，皮却停在常态）
## ⇒ 那是**投递时机的抖**，不是产品坏。留"重试 4 次仍收不到 ⇒ 让判据点名红"这一条出口，
## 所以真把按下改坏（例如"整页拆掉重建"那一族回归）照样会红 —— 只是不会被抖误伤。
func _按下(钮: Button, 件名: String) -> void:
	for 试 in 4:
		var 前: int = int(击.get(件名 + "d", 0))
		_键(_钮心(钮), true)
		await _帧(2)
		if int(击.get(件名 + "d", 0)) > 前:
			return
		_键(_钮心(钮), false)		# 这半次没收到 down ⇒ 先抬掉，别留"卡住按下"的半态
		await _帧(2)


func _抬起(钮: Button, 件名: String) -> void:
	for 试 in 4:
		var 前: int = int(击.get(件名 + "u", 0))
		## 抬在**鼠标当下所在位置**（不是钮心）：真鼠标就是这么动的 —— 挂机页那两枚勾的还原
		## 点击需要"还在钮上 ⇒ 完成一次 `pressed`"，而那颗 X 需要"已经离开 ⇒ 只回常态、**不关窗**"。
		_键(鼠, false)
		await _帧(2)
		if int(击.get(件名 + "u", 0)) > 前:
			return
		await _帧(2)


func _点一下(钮: Button, 件名: String) -> void:
	await _按下(钮, 件名)
	await _抬起(钮, 件名)


## 一枚勾走六步 + 一次真点击（按下→松手 就是那次打勾），逐格判"实际生效的皮文件名"。
## `态` 为 "移开" 时把鼠标甩到屏幕角；"松手" 只发抬起（不移动）⇒ 抓得住"松手还停在悬停档"那种错。
func _走勾(件名: String) -> void:
	var 件 := _取件(件名)
	if 件.is_empty():
		_判(false, "%s 查无 ⇒ 这一枚根本没量" % 件名)
		return
	var 根: Control = 件[0]
	var 钮: Button = 件[1]
	var 框: TextureRect = 件[2]
	var 记: TextureRect = 件[3]
	var 字: Label = 件[4]
	if 钮 == null or 框 == null or 记 == null or 字 == null:
		_判(false, "%s 四件不齐（钮=%s 框=%s 记=%s 字=%s）⇒ 这一枚根本没量" % [
				件名, str(钮 != null), str(框 != null), str(记 != null), str(字 != null)])
		return
	_判(根.has_method("刷态"),
			"%s 组件根必须有 `刷态`（`_勾禁用` 靠它把禁用档刷上；没有 = 那句 `call` 静默无效）" % 件名)
	_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"%s 要手型光标（`MButton3.init()` `:135` buttonMode = useHandCursor）" % 件名)
	钮.button_down.connect(_计.bind(件名, "d"))
	钮.button_up.connect(_计.bind(件名, "u"))
	钮.pressed.connect(_计.bind(件名, "p"))
	await _跳到(Vector2(6.0, 6.0))
	var 常 := _皮名(框)
	var 色0 := 字.get_theme_color("font_color").to_html(false)
	字色底[件名] = 色0
	var 初记显 := 记.visible		# 出厂勾没勾是数据说了算（`autoReplyHp` 默认 true），
	_判(常 == "复选框未选", "%s 常态的框皮应是 复选框未选，实得 %s" % [件名, 常])	# 量具只管"点一下要翻"
	_评(根, 件名, "常态")

	## 量具自证（第一枚曾经"按下时拾取到的还是主窗口" ⇒ 心 与实际屏幕位对不上）：
	## 把窗口尺寸、视口图尺寸、这颗钮的全局矩形与圆心一并打出来，红的时候才分得清
	## 是"皮没换"还是"鼠标根本没打到它"。
	_记("  量具坐标：root.size=%s 视口图=%s 钮全局矩形=%s 圆心=%s" % [
			str(root.size), str(root.get_texture().get_image().get_size()),
			str(钮.get_global_rect()), str(_钮心(钮))])
	await _指到(钮, 件名, "悬停")
	_评(根, 件名, "悬停")
	await _按下(钮, 件名)
	_评(根, 件名, "按下")
	await _抬起(钮, 件名)
	_评(根, 件名, "松手")
	## 阳性对照：一次真点击要把勾翻过来 —— 否则"两张皮都换档"那条可能一整段都没跑。
	_判(记.visible != 初记显, "%s 真点一下要把标记从 %s 翻过来（实得 %s）" % [
			件名, str(初记显), str(记.visible)])
	await _跳到(Vector2(6.0, 6.0))
	_评(根, 件名, "移开")
	await _指到(钮, 件名, "再悬停")
	_评(根, 件名, "再悬停")
	## 还原：再点一次把标记退回开跑前那一档，鼠标甩开。
	await _点一下(钮, 件名)
	await _跳到(Vector2(6.0, 6.0))
	_判(记.visible == 初记显, "%s 再点一次要把标记退回开跑前那一档（实得 %s，原 %s）" % [
			件名, str(记.visible), str(初记显)])
	## 计数自计到：这一枚从头到尾应当**恰好**被完整点过两次（一次打勾、一次还原）。
	## 少了 = 有一发按下/抬起没落到这颗钮上（量具自己抖或页面被重建），多了 = 重复投递。
	_判(int(击.get(件名 + "p", 0)) == 2,
			"%s 这一整段要恰好两次 `pressed`（实得 %d 次，按下 %d / 抬起 %d）⇒ 数目不对就说明有几步是假跑" % [
			件名, int(击.get(件名 + "p", 0)),
			int(击.get(件名 + "d", 0)), int(击.get(件名 + "u", 0))])
	## 字色恒定这一条在这里补判一次：整段六步里 文本 的 font_color 一个字节都不该动。
	_判(字.get_theme_color("font_color").to_html(false) == 色0,
			"%s 走完六步文字色必须还是 %s（原版四档同一个值）" % [件名, 色0])


## 逐态判据：框皮 / 盖在上面的标记皮 / 拾取目标 / 字色 + 出图。
func _评(根: Control, 件名: String, 态: String) -> void:
	var 钮: Button = 根.get_node("点击区域")
	var 框: TextureRect = 根.get_node("指示框")
	var 记: TextureRect = 根.get_node("标记")
	var 字: Label = 根.get_node("文本")
	var 该 := str(期望后缀[态])		# ⚠ 一律 `str()`：GDScript 4 的 `String(…)` 构造器对
	## 非字符串 Variant 会当场 `Invalid call`（`--check-only` 也不报），这里字典取值是 Variant。
	var 实 := _皮名(框)
	_判(实 == "复选框未选" + 该, "%s %s ⇒ 框皮应是「复选框未选%s」，实得 %s" % [件名, 态, 该, 实])
	if 记.visible:
		var 实记 := _皮名(记)
		_判(实记 == "复选框选中" + 该,
				"%s %s 且已勾 ⇒ 盖在上面那张也应是「复选框选中%s」，实得 %s（两张不同档 = 悬停时打勾会留一块亮底）" % [
				件名, 态, 该, 实记])
	_判(字.get_theme_color("font_color").to_html(false) == str(字色底.get(件名, "")),
			"%s %s 时文字色必须还是常态那份，实得 %s（换了就是自己加戏：`textColor` 四档同一个值）" % [
			件名, 态, 字.get_theme_color("font_color").to_html(false)])
	if 态 == "悬停" or 态 == "再悬停" or 态 == "按下":
		_判(_拾取名() == "点击区域", "%s %s 时视口拾取到的应是这颗点击区域，实得 %s" % [件名, 态, _拾取名()])
	_裁(根, 件名, 态)
	_记("  %s %s → 框=%s 记=%s(可见=%s) 拾取=%s" % [
			件名, 态, 实, _皮名(记), str(记.visible), _拾取名()])


var 字色底 := {}


## 禁用那一枚：先悬停让它亮，再**直接**把 `disabled` 翻真 + 叫组件重刷皮
## （2026-10-25 之前这一条走的是真路径"属性帧 → `重刷VIP` → `_按VIP闸` → `_勾禁用`"，
## 那道 VIP5 闸按用户报修 5.1/5.2 整族删了 ⇒ 改由量具自己下 disabled，量的仍是同一档皮）
## ⇒ 禁用必须**压倒悬停**变成灰皮；然后翻回可用 ⇒ 必须回**常态**
## （`MButton3.as:467-470` 重新可用时把 `_state` 钉成 STATE_UP，而不是还停在悬停）。
func _走禁用勾(件名: String) -> void:
	var 件 := _取件(件名)
	if 件.is_empty():
		_判(false, "%s 查无 ⇒ 这一条根本没量" % 件名)
		return
	var 根: Control = 件[0]
	var 钮: Button = 件[1]
	字色底[件名] = (件[4] as Label).get_theme_color("font_color").to_html(false)
	await _跳到(Vector2(6.0, 6.0))
	var 心: Vector2 = _钮心(钮)
	_记("  量具坐标（禁用那枚）：钮全局矩形=%s 圆心=%s 窗口位=%s" % [
			str(钮.get_global_rect()), str(心), str(页.get_global_rect().position)])
	_判(not 钮.disabled, "壬：夹具——「%s」开跑时要是可用（不可用 = 这条测的是禁用不是悬停）" % 件名)
	_判(心.x > 0.0 and 心.y > 0.0 and 心.x < float(root.size.x) and 心.y < float(root.size.y) \
			and 钮.get_global_rect().size.x > 6.0,
			"壬：夹具——「%s」的圆心要在视口里、点击区不能细到打不中（实得 圆心=%s 尺寸=%s）" % [
			件名, str(心), str(钮.get_global_rect().size)])
	## 常态基线：这一枚不点，所以 `常态` 与后面的 `恢复` 是同档同顶皮同文字 ⇒
	## 像素门拿这两张做"逐字节（容差内）相同"的形状对照。
	_评(根, 件名, "常态")
	await _指到(钮, 件名, "悬停")
	_评(根, 件名, "悬停")
	钮.disabled = true
	根.call("刷态")
	await _帧(6)
	_判(钮.disabled, "手动下过 disabled + 重刷皮之后「%s」要禁用（实得 禁用=%s）" % [件名, str(钮.disabled)])
	_评(根, 件名, "禁用")
	钮.disabled = false
	根.call("刷态")
	await _帧(6)
	_判(not 钮.disabled, "翻回可用之后「%s」要重新可用（实得 禁用=%s）" % [件名, str(钮.disabled)])
	_评(根, 件名, "恢复")
	await _跳到(Vector2(6.0, 6.0))


func _裁(件: Control, 件名: String, 态: String) -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null:
		_判(false, "视口图像为空 ⇒ 不能加 --headless 跑")
		return
	var 原点: Vector2 = 件.get_global_transform_with_canvas() * Vector2.ZERO
	var 左 := Vector2i(roundi(原点.x), roundi(原点.y))
	var 尺 := Vector2i(roundi(件.size.x), roundi(件.size.y))
	左.x = clampi(左.x, 0, 图.get_width() - 1)
	左.y = clampi(左.y, 0, 图.get_height() - 1)
	尺.x = mini(尺.x, 图.get_width() - 左.x)
	尺.y = mini(尺.y, 图.get_height() - 左.y)
	DirAccess.make_dir_recursive_absolute(出目录)
	var 档 := "%s/勾_%s_%s.png" % [出目录, 件名, 态]
	if 图.get_region(Rect2i(左, 尺)).save_png(档) == OK:
		出图 += 1
		var 框: TextureRect = 件.get_node("指示框")
		var 记: TextureRect = 件.get_node("标记")
		## 清单每一行 = 这张裁图当时生效的是哪两张皮 + 方框在**裁图局部坐标**里的矩形。
		## ⚠ 这里只登记"显示的是哪个文件"；屏幕上那 19×19 到底等不等于那张皮 ±30/−40，
		## 由 `开发工具/出勾态对照图.py` 拿**素材文件本身**按 `getLightFilter` 算期望逐像素判
		## —— 期望值不从被测对象身上取（否则 = 自证，见记忆「判据的期望值不许从被测对象读」）。
		## 末列 `顶基名` = 这一档**盖在最上面**的那张**常态**皮名（勾上了是 `标记`，没勾是 `指示框`）
		## ⇒ 像素门按它去 `素材/…/通用控件/` 读文件本身算期望，不用再去猜是哪一张。
		var 顶基名 := "复选框选中" if 记.visible else "复选框未选"
		清单.append("|".join([件名, 态, 档.replace("res://", ""), _皮名(框), _皮名(记),
				str(记.visible), str(框.position.x), str(框.position.y),
				str(框.size.x), str(框.size.y), str(件.size.x), str(件.size.y),
				str(件.get_node("文本").text), 顶基名]))


## 主窗壳右上角那颗 X（`MWindowCloseBtnF` = `MButton3` 族，`StyleUtil.as:7-12` over +30 / down −40）。
## **不在钮上松手** —— 那一下会把整扇窗关掉，后面的判据全作废；抬起放到钮外，
## 这样 `pressed` 不发、窗还在，而"松手回 STATE_UP"这一条由挂机页那两颗大钮的门（⑬）钉。
## 期望值是**素材文件本身**算出来的（`出勾态对照图.py`），这里只报"当前挂的是哪个文件"。
func _走关钮() -> void:
	var 钮 := root.find_child("关闭按钮", true, false) as Button
	if 钮 == null:
		_判(false, "主窗壳的「关闭按钮」查无 ⇒ 这一条根本没量（每一扇窗的 X 都归它）")
		return
	await _跳到(Vector2(6.0, 6.0))
	var 名0 := 钮.icon.resource_path.get_file() if 钮.icon != null else "〈没图〉"
	_判(名0 == "关闭按钮.png", "X 常态挂的应是 关闭按钮.png，实得 %s" % 名0)
	_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"X 要手型光标（`MButton3.init()` `:135`）；这个值烘在 `场景/界面/功能窗口.tscn` 里")
	钮.button_down.connect(_计.bind("窗口X", "d"))
	钮.button_up.connect(_计.bind("窗口X", "u"))
	for 信 in ["mouse_entered", "mouse_exited", "button_down", "button_up"]:
		_判(钮.get_signal_connection_list(信).size() >= 1,
				"X 的 `%s` 要接上（`功能窗口._bind_scene_nodes` 里接的），实得 %d 条" % [
				信, 钮.get_signal_connection_list(信).size()])
	_裁皮(钮, "窗口X", "常态", "关闭按钮", Vector2.ZERO)
	await _指到2(钮, "窗口X", "悬停")
	_判(_图名(钮) == "关闭按钮_悬停.png", "X 悬停 ⇒ 实际生效的图应是 关闭按钮_悬停.png，实得 %s" % _图名(钮))
	_裁皮(钮, "窗口X", "悬停", "关闭按钮", Vector2.ZERO)
	await _按下(钮, "窗口X")
	_判(_图名(钮) == "关闭按钮_按下.png", "X 按下 ⇒ 应是 关闭按钮_按下.png，实得 %s" % _图名(钮))
	_裁皮(钮, "窗口X", "按下", "关闭按钮", Vector2.ZERO)
	await _跳到(Vector2(6.0, 6.0))
	_判(_图名(钮) == "关闭按钮.png", "X 移开 ⇒ 要回常态，实得 %s（停在悬停档 = 松手还亮着那一族）" % _图名(钮))
	await _抬起(钮, "窗口X")
	_裁皮(钮, "窗口X", "移开", "关闭按钮", Vector2.ZERO)


func _图名(钮: Button) -> String:
	return 钮.icon.resource_path.get_file() if 钮 != null and 钮.icon != null else "〈没图〉"


## 与 `_指到` 同一条重试逻辑，但按"图名对不对"来判成功（那颗 X 的名字不是"点击区域"）。
func _指到2(钮: Control, 件名: String, 态: String) -> void:
	for 试 in 8:
		await _跳到(_钮心(钮))
		if _拾取名() == String(钮.name):
			return
		await _跳到(Vector2(6.0, 6.0))


## 只有一张皮的件（那颗 X）用的裁图 + 清单：`框` 位置给的是**图标在钮里的居中偏移**。
func _裁皮(钮: Button, 件名: String, 态: String, 基名: String, 偏移: Vector2) -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null:
		_判(false, "视口图像为空 ⇒ 不能加 --headless 跑")
		return
	var 原点: Vector2 = 钮.get_global_transform_with_canvas() * Vector2.ZERO
	var 左 := Vector2i(roundi(原点.x) + int(偏移.x), roundi(原点.y) + int(偏移.y))
	var 尺 := Vector2i(25, 24)
	左.x = clampi(左.x, 0, 图.get_width() - 1)
	左.y = clampi(左.y, 0, 图.get_height() - 1)
	尺.x = mini(尺.x, 图.get_width() - 左.x)
	尺.y = mini(尺.y, 图.get_height() - 左.y)
	DirAccess.make_dir_recursive_absolute(出目录)
	var 档 := "%s/勾_%s_%s.png" % [出目录, 件名, 态]
	if 图.get_region(Rect2i(左, 尺)).save_png(档) == OK:
		出图 += 1
		清单.append("|".join([件名, 态, 档.replace("res://", ""), _图名(钮), "〈无〉", "false",
				"0", "0", "25", "24", str(钮.size.x), str(钮.size.y), "", 基名]))


func _跑() -> void:
	root.size = Vector2i(960, 560)
	场 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(60)
	会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_判(false, "找不到 /root/GameSession ⇒ 后面全部判不了")
		_收()
		return
	## 与游戏里那颗「挂机」球同一个入口（`技能面板.gd:769`）。
	会.call("request_feature", "挂机")
	await _帧(20)
	页 = 场.find_child("原版挂机设置内容", true, false) as Control
	if 页 == null:
		_判(false, "request_feature(\"挂机\") 之后页面根节点没建出来 ⇒ 全部判不了")
		_收()
		return
	await _走勾("复选拾取金币")
	await _走禁用勾("复选自动出售装备")
	await _走勾("复选生命阈值")
	await _走关钮()
	await _收()


func _收() -> void:
	## 量具自检：出了几张图。少图 = 某一步根本没走到（`_评` 里已经判过，这里只兜一道）。
	## 20 = 勾 16 张（金币 6 + 生命阈值 6 + VIP 那枚 4）+ 那颗 X 4 张。
	_判(出图 >= 20, "壬：量具自计到——至少该出 20 张逐态裁图（勾 16 + X 4），实得 %d 张 ⇒ 少了就是中途静默报错" % 出图)
	_判(清单.size() == 出图,
			"壬：量具自计到——清单行数要等于出图数（实得 清单 %d / 出图 %d）⇒ 不相等 python 那道像素门会少判几张" % [
			清单.size(), 出图])
	## 清单整份重写（不是追加）：留着上一轮的条目会让像素门拿旧裁图配新表。
	var 名 := FileAccess.open(出目录 + "/清单.txt", FileAccess.WRITE)
	if 名 != null:
		名.store_string("\n".join(清单) + "\n")
		名.close()
	else:
		_判(false, "清单.txt 打不开 ⇒ 像素门没有输入，这一条必须红（不许静默少一道门）")
	var f := FileAccess.open("user://挂机勾态量具.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	_记("挂机勾态量具：判 %d 条，红 %d 条，出图 %d 张 → user://挂机勾态量具.txt" % [判数, 红, 出图])
	quit(0 if 红 == 0 else 1)
