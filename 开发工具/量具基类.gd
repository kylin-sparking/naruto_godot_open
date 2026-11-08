extends SceneTree

## 页面量具基类 —— 小地图弹窗那批 `截XX页.gd` 的共用骨架。
##
## 为什么有它：每页的量具都是同一套流程（走 `窗口管理.打开(页名)` 的真实路径 → 按页签切页 →
## 逐件量"页面局部矩形" → 逐字对语言表 → 截图 → 落 `几何.txt` → 退出码当硬门），
## 差别只有那几张表。以前每页抄一份（亲热天堂 215 行、宝石工艺 560 行），改一处口径要改两遍。
##
## 子类只要实现：`页名()`、`根节点名()`、`期望()`、`路径()`、`页面件表()`、`页面文案表()`，
## 需要更多门就再覆盖 `额外校验()` / `收尾校验()`。
##
## 三条已经踩过、写死在这里的口径：
##   * **切页与断言/截图必须分帧**：`_refresh_current()` 是 deferred，`root.get_texture()`
##     拿到的又是上一帧的画面 ⇒ 每步一帧，别在同一帧里点完再量。
##   * **页签/子页按序号取**（`_第几`），不按名字 —— 场景里的名字是给人看的，改名不该搞崩量具。
##   * 出目录要在 `_initialize` 里先建：`Image.save_png("res://…")` 不自动建目录。
##
## 用法（**不能加 --headless**）：
##   Godot --path . --script res://开发工具/截XX页.gd -- --出目录=res://测试/截图/XX

var 出目录 := ""
var 行: Array[String] = []
var 有错 := false
var 帧 := 0
var 场景: Node = null
var 窗口: Node = null
var 队列: Array[Callable] = []
var 等待 := 0


## ── 子类要实现的 ──
func 页名() -> String:
	return ""


func 根节点名() -> String:
	return ""


func 页签数() -> int:
	return 1


func 期望() -> Dictionary:
	return {}


func 路径() -> Dictionary:
	return {}


func 页面件表() -> Dictionary:
	return {}


func 页面文案表() -> Dictionary:
	return {}


func 文案表() -> Dictionary:
	return {}


## 页签序号映射：默认第 n 个可切换页签 = 容器里第 n 枚钮。
## 有的窗口（资讯查询）容器里还混着**永久隐藏的钮**和**不参与选中的钮**，
## 那种页既不该被"切页"也不该被量宽 ⇒ 子类把这里映射到真正的可切换页。
func 页签序号(_页号: int) -> int:
	return _页号


## 页签宽是不是 `文字宽 + 6`（`MButton3.as:383`，`isScale9Grid=true` 才成立）。
## `isScale9Grid=false` 且代码写死 `width = btn_width_*` 的（资讯查询）要返回 false，
## 那时宽度改按 `期望()` 表里登记的 `页签N` 判。
func 页签宽按文字() -> bool:
	return true


## 有没有"一页一个子页容器"（`内容盒` 的第 i 个子节点 = 第 i 页）。
## 资讯查询那种"切页只换 ScrollPane.source、不换 visible"的窗要返回 false。
func 有子页() -> bool:
	return true


## 有没有页签条。`PetWindow` 这类**一页无签**的整窗（原版根本没有 TabButtonBar，
## 只有一个 `fl.controls.List` 选宠）返回 false —— 否则 `_步切页/_步验页` 会去
## `分页` 容器取第 0 枚钮，取不到就假报"页签 0 取不到"。
func 有页签() -> bool:
	return true


## 页签条 / 内容盒 的节点名（按序号取子节点用）。
func 页签容器名() -> String:
	return "分页"


func 内容容器名() -> String:
	return "内容框"


## 子类追加的门（每页都跑一遍）。
func 额外校验(_页: Control, _页号: int) -> void:
	pass


## 全页量完之后的一次性门（皮肤接线、皮来源等）。
func 收尾校验(_页: Control) -> void:
	pass


## ── 骨架 ──
func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			出目录 = 键值[1]
	if 出目录.is_empty():
		出目录 = "res://测试/截图/%s" % 页名()
	if not DirAccess.dir_exists_absolute(出目录):
		DirAccess.make_dir_recursive_absolute(出目录)
	# 步骤表开工前排满：在 `_process` 里"空了就重排"会永不退出（实测跑到超时被杀）。
	队列.append(_步打开窗口)
	队列.append(_步撑视口)
	队列.append(_步藏HUD)
	for 页号 in 页签数():
		队列.append(_步切页.bind(页号))
		队列.append(_步验页.bind(页号))
		队列.append(_步拍底片.bind(页号))
		队列.append(_步存底片.bind(页号))
		队列.append(_步抓图.bind(页号))
	_队列尾()


func _队列尾() -> void:
	队列.append(_步收尾校验)


func _process(_delta: float) -> bool:
	帧 += 1
	if 帧 < 8:
		return false
	if 等待 > 0:
		等待 -= 1
		return false
	if 队列.is_empty():
		_收尾()
		return true
	队列.pop_front().call()
	return false


func _步打开窗口() -> void:
	var 地图 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 地图 == null:
		_错("无法加载地图场景")
		return
	场景 = 地图.instantiate()
	root.add_child(场景)
	var 窗口管理 := 场景.get_node_or_null("窗口管理")
	if 窗口管理 == null:
		_错("地图场景下没有 窗口管理")
		return
	窗口 = 窗口管理.call("取或建窗口", 页名()) as Node
	if 窗口 == null:
		_错("窗口管理 没建出「%s」窗口" % 页名())
		return
	窗口管理.call("打开", 页名())
	等待 = 3


func 主窗() -> Control:
	return 窗口.get_node_or_null("遮罩/主窗口") as Control if 窗口 != null else null


## 视口比窗口矮/窄时（本项目 960×560，意志学习窗 772×564），`功能窗口.窗口偏移` 只能把窗口
## 居中 ⇒ 上下各露出视口外 2px。裁图 `get_region(负原点)` 会把整张客户端图**往下顶 2px**，
## 实测对证出来的 best offset 全是 ±2 ⇒ 抓图前先把窗口撑到装得下整窗，再让窗口重算居中。
func _步撑视口() -> void:
	var 主 := 主窗()
	if 主 == null or 窗口 == null:
		return
	var 视口 := root.get_visible_rect().size
	var 窗 := Vector2i(int(主.size.x), int(主.size.y))
	var 新 := Vector2i(maxi(int(视口.x), 窗.x + 16), maxi(int(视口.y), 窗.y + 16))
	# ⚠ 视口与窗口**必须同奇偶**：居中位置 = (视口 − 窗口)/2，奇偶不同就是 x.5，
	#    打出来的整窗裁图整体偏半像素 ⇒ 对证里每件 best offset 在 +1/+2 之间乱跳，
	#    细边类件（格圈、盘缘）凭空多出 11~18% 假红（实测 意志背包 663 宽 vs 960 视口）。
	if (新.x - 窗.x) % 2 != 0:
		新.x += 1
	if (新.y - 窗.y) % 2 != 0:
		新.y += 1
	if int(新.x) == int(视口.x) and int(新.y) == int(视口.y):
		return
	root.size = 新
	if 窗口.has_method("窗口偏移"):
		窗口.call("窗口偏移", Vector2.ZERO)
	行.append("  视口撑到 %dx%d（窗口 %dx%d 原视口 %dx%d：装不下会被顶出视口、奇偶不同会整体偏半像素）"
			% [新.x, 新.y, 窗.x, 窗.y, 视口.x, 视口.y])
	等待 = 4


## HUD 四块（头像/小地图/聊天/技能）与窗口同在一张截图里会把钮态、色带全污染
## （实测 资讯查询 底 8 行被技能栏橙色盖住、中部被头像紫球盖住）。量具要的是**窗口本体**，
## 开完窗就把它们关掉；真机叠层顺序另由 交互相应 那套量具判。
func _步藏HUD() -> void:
	for 名 in ["头像面板", "小地图面板", "聊天面板", "技能面板", "系统消息"]:
		var 件: Node = 场景.get_node_or_null(名)
		if 件 != null:
			件.set("visible", false)
	等待 = 2


func 页根() -> Control:
	var 主 := 主窗()
	if 主 == null:
		return null
	var 找 := _找节点(主, 根节点名()) as Control
	if 找 == null:
		_错("主窗口下找不到 %s" % 根节点名())
	return 找


func _步切页(页号: int) -> void:
	var 页 := 页根()
	if 页 == null:
		return
	if not 有页签():
		等待 = 2
		return
	var 钮 := _第几(页.get_node_or_null(页签容器名()), 页签序号(页号)) as Button
	if 钮 == null:
		_错("页签 %d 取不到（%s 容器缺子节点？）" % [页号, 页签容器名()])
		return
	if not bool(钮.button_pressed):
		钮.emit_signal("pressed")
	等待 = 2


## 取件路径。**表里没登记的键必须在这里报错**：GDScript 对 Dictionary 用 `表[缺键]`
## 是运行时错误，会把当前这一步整个打断（实测：一行 `件路径["材料格1/标签"]` 让后面
## 四条标签断言静默消失，退出码却还是 0）。
func 取路径(名: String) -> String:
	var 表 := 路径()
	if not 表.has(名):
		_错("件路径表里没登记 %s" % 名)
		return ""
	return 表[名]


func _步验页(页号: int) -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 页签条 := 页.get_node_or_null(页签容器名()) as Control
	if not 有页签():
		行.append("=== 页 %d（无页签窗口）===" % 页号)
	else:
		var 钮 := _第几(页签条, 页签序号(页号)) as Button
		if 钮 == null:
			_错("页签 %d 取不到" % 页号)
			return
		if not bool(钮.button_pressed):
			_错("切页信号没生效：页签 %d 未处于按下态" % 页号)
		行.append("=== 页 %d（页签「%s」）===" % [页号, 钮.text])
	_量件表(页, 页号)
	_验公共(页)
	额外校验(页, 页号)
	_验文案(页, 页号)
	行.append("")


## 按 `页面件表()[页号]` 逐件量尺（`有页签()` 与无页签两条路共用，别抄两份）。
func _量件表(页: Control, 页号: int) -> void:
	for 名 in 页面件表().get(页号, []):
		var 路 := 取路径(名)
		if 路.is_empty():
			continue
		var 件 := 页.get_node_or_null(路) as Control
		if 件 == null:
			_错("缺节点 %s（%s）" % [名, 路])
			continue
		if not 期望().has(名):
			_错("期望表里没登记 %s" % 名)
			continue
		量(页, 件, 名, 期望()[名])
		if 件 is RichTextLabel and (件 as RichTextLabel).scroll_active:
			_错(("%s 还开着 scroll_active —— 原版 TextArea2 是 dynamic TextField，不出滚动条，"
				 + "文本比盒高时直接画出去") % 名)


## 页签位置 + 内容框 + 底部提交钮这类"每页都在"的件。
func _验公共(页: Control) -> void:
	var 页签条 := 页.get_node_or_null(页签容器名()) as Control
	if 页签条 != null and 页签宽按文字():
		var x := 10.0
		var 量具 := Label.new()
		页.add_child(量具)
		for i in 页签数():
			var 钮 := _第几(页签条, 页签序号(i)) as Button
			if 钮 == null:
				continue
			量具.text = 钮.text
			量具.add_theme_font_size_override("font_size", 12)
			量具.reset_size()
			var 宽 := int(量具.size.x) + 6
			量(页, 钮, "页签%d" % i, [x, 9.0, 宽, 22.0])
			x += float(宽) + 1.0
		量具.queue_free()
	for 名 in 公共件():
		var 路 := 取路径(名)
		if 路.is_empty() or not 页.get_node_or_null(路) is Control:
			continue
		量(页, 页.get_node_or_null(路) as Control, 名, 期望()[名])
	# 子页可见性：只允许当前页可见
	var 内容盒 := 页.get_node_or_null(内容容器名()) as Control
	if 内容盒 != null and 页签数() > 1 and 有子页():
		for i in 页签数():
			var 子页 := _第几(内容盒, i) as Control
			var 钮 := _第几(页签条, 页签序号(i)) as Button
			if 子页 == null or 钮 == null:
				continue
			var 当前 := bool(钮.button_pressed) == (i == 当前页号) and 子页.visible == (i == 当前页号)
			有错 = 有错 or (not 当前)
			行.append("  页签%d pressed=%s 子页 %s visible=%s %s" % [
				i, 钮.button_pressed, 子页.name, 子页.visible, "√" if 当前 else "!! 错"])


## 子类在 `_步验页` 里设；基类用它判可见性。
var 当前页号 := 0


func 公共件() -> Array[String]:
	return ["内容框"]


func 量(页: Control, 件: Control, 名: String, 想: Array) -> void:
	var 原点 := 页.get_global_position()
	var 全 := 件.get_global_position()
	# `CheckBox` 不再折"皮肤相对控件内缩 4"：主题补上 `CheckBox/hover_pressed` 空盒之后
	# 控件矩形 == 皮肤矩形（10-25 前那 4 是 27 地板撑出来的，量具当时要折回去才对得上原版）。
	var 实 := [全.x - 原点.x, 全.y - 原点.y, 件.size.x, 件.size.y]
	var 偏 := false
	for i in 4:
		if absf(实[i] - float(想[i])) > 0.01:
			偏 = true
	有错 = 有错 or 偏
	行.append("  %-16s 实(%6.1f,%6.1f %5.1fx%-5.1f) 期(%6.1f,%6.1f %5.1fx%-5.1f) %s" % [
		名, 实[0], 实[1], 实[2], 实[3],
		float(想[0]), float(想[1]), float(想[2]), float(想[3]), "!! 偏" if 偏 else "√"])


func _验文案(页: Control, 页号: int) -> void:
	行.append("  --- 文案 vs 语言表原文 ---")
	for 名 in 页面文案表().get(页号, []):
		var 路 := 取路径(名)
		if 路.is_empty():
			continue
		var 件 := 页.get_node_or_null(路)
		if 件 == null:
			_错("%s 取不到（%s）" % [名, 路])
			continue
		var 原文: String = 文案表().get(名, "")
		if 原文.is_empty():
			_错("%s 没登记原文" % 名)
			continue
		if 件 is RichTextLabel:
			比对文本(名, (件 as RichTextLabel).text, 译文为BBCode(原文))
		elif 件 is Label:
			比对文本(名, (件 as Label).text, 纯文本(原文))
		elif 件 is Button:
			# `CheckBox` / `OptionButton` / `MenuButton` 都是 `Button` 子类 ⇒ 文字在 `.text`。
			# 2026-10-03 宝石工艺页实测：原来只有 RichTextLabel/Label 两支，勾选框直接落进
			# "既不是…也不是…"那条错 ⇒ 自造文案（把语言表的"本次操作使用"写成"使用幸运符"）躲过了门。
			比对文本(名, (件 as Button).text, 纯文本(原文))
		else:
			_错("%s 既不是 RichTextLabel / Label 也不是 Button" % 名)
	行.append("")


func 比对文本(名: String, 实: String, 想: String) -> void:
	var 同 := 实 == 想
	有错 = 有错 or (not 同)
	行.append("  %-16s %s" % [名, "√ 与语言表逐字一致" if 同 else "!! 不一致"])
	if not 同:
		行.append("    烘的：%s" % 实)
		行.append("    应译：%s" % 想)


## `功能窗口.译文为BBCode()` 的等价实现；两边要改时一起改（都注了出处）。
func 译文为BBCode(原文: String) -> String:
	var 文 := 原文
	文 = 文.replace("\r\n", "\n").replace("\r", "\n")
	文 = 文.replace("<br/>", "\n").replace("<br>", "\n")
	文 = 文.replace("<font color='", "[color=").replace("<font color=\"", "[color=")
	文 = 文.replace("'>", "]").replace("\">", "]")
	文 = 文.replace("</font>", "[/color]")
	return 文


func 纯文本(原文: String) -> String:
	var 文 := 译文为BBCode(原文)
	# `#ff9900` = `UIConfig.UI_ORANGE`（材料格标签那类 `MGlowLabel.color` 直接设的值，
	# 不在语言表的 `<font>` 里，但页面表常把它写进"原文"当颜色分段 ⇒ 剥离表必须收它，
	# 否则会把橙标签判成"文案不符"。2026-10-03 宝石工艺页实测。）
	for 串 in ["[color=#ffffff]", "[color=#00ff00]", "[color=#ff9100]", "[color=#ff9900]",
			  "[color=#0081ff]", "[color=#ff0000]", "[/color]"]:
		文 = 文.replace(串, "")
	return 文


func _步收尾校验() -> void:
	var 页 := 页根()
	if 页 != null:
		收尾校验(页)


## 先**把窗口藏了**拍一张同矩形的「底片」。
## 为什么必须有它：原版所有皮肤都是半透的（`MYellow_background` alpha≈230、穿戴盘描边更低），
## 屏幕上那一点 = `alpha·皮肤 + (1−alpha)·它下面的地图`。像素参照若从**透明黑**往上叠，
## 整窗会系统性偏暗（2026-09-28 实测：意志背包页盘缘中位差 +13、4 个件超阈 11~18%），
## 而差的那部分根本不是移植错，是参照少了底图。
func _步拍底片(页号: int) -> void:
	var 主 := 主窗()
	if 主 == null:
		_错("底片步取不到主窗口")
		return
	主.hide()
	等待 = 3


## 隔帧后画面里确实没有窗口了 ⇒ 存底片，再把窗口显回来（下一步 `_步抓图` 抓带窗口的图）。
func _步存底片(页号: int) -> void:
	var 图像 := root.get_texture().get_image()
	var 主 := 主窗()
	if 图像 == null or 主 == null:
		_错("底片前置不全（视口图像/主窗口）")
		return
	var 起点 := Vector2i(int(主.get_global_position().x), int(主.get_global_position().y))
	var 尺 := Vector2i(int(主.size.x), int(主.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起点.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起点.y)
	图像.get_region(Rect2i(起点, 尺)).save_png("%s/底片_页%d.png" % [出目录, 页号])
	主.show()
	等待 = 3
	行.append("  底片 %s/底片_页%d.png（%dx%d，供半透层当参照背景）" % [出目录, 页号, 尺.x, 尺.y])


func _步抓图(页号: int) -> void:
	var 图像 := root.get_texture().get_image()
	var 主 := 主窗()
	if 图像 == null or 主 == null:
		_错("截图前置不全（视口图像/主窗口）")
		return
	var 起点 := Vector2i(int(主.get_global_position().x), int(主.get_global_position().y))
	var 尺 := Vector2i(int(主.size.x), int(主.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起点.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起点.y)
	图像.get_region(Rect2i(起点, 尺)).save_png("%s/客户端_页%d.png" % [出目录, 页号])
	行.append("  截图 %s/客户端_页%d.png（%dx%d）" % [出目录, 页号, 尺.x, 尺.y])


func _收尾() -> void:
	if not DirAccess.dir_exists_absolute(出目录):
		DirAccess.make_dir_recursive_absolute(出目录)
	var f := FileAccess.open("%s/几何.txt" % 出目录, FileAccess.WRITE)
	if f != null:
		for 一 in 行:
			f.store_line(一)
		f.close()
	print("\n".join(行))
	print("%s：%s" % [页名(), "不通过" if 有错 else "几何、文案、接线全部对上"])
	quit(1 if 有错 else 0)


func _错(文本: String) -> void:
	有错 = true
	行.append("!! " + 文本)
	push_error("量具[" + 页名() + "]：" + 文本)


## 按**序号**取第 n 个 Control 子节点，不按名字。
func _第几(父: Node, n: int) -> Node:
	if 父 == null:
		return null
	var 序 := -1
	for 子在 in 父.get_children():
		if 子在 is Control:
			序 += 1
			if 序 == n:
				return 子在
	return null


func _找节点(父: Node, 名字: String) -> Node:
	for 子 in 父.get_children():
		if 子.name == 名字:
			return 子
		var 结果 := _找节点(子, 名字)
		if 结果 != null:
			return 结果
	return null
