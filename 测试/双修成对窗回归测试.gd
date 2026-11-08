extends SceneTree
## 双修成对窗（打坐那颗「双修」球开出来的两扇）离线门。
## 参照值**全部从 AS3 手抄**（每条带行号，见 `真值/窗口/双修选人窗.md`），不从被测场景反查。
##
## 跑法：`"godot" --path "." --headless --script res://测试/双修成对窗回归测试.gd`
##
## ⚠ 这一族钮在场景里是 **TextureButton**（`BaseButton` 的子类、**不是** `Button` 的子类）⇒
## 门里的转型一律写 `as BaseButton` / `as TextureButton`。写 `as Button` 会静默拿到 null，
## 而接线那侧当场崩、面板上却什么都看不出来（10-18 第一次跑就是这形态）。
## ⚠ 所有点击走 `root.push_input(..., true)`，不用 `pressed.emit()`：后者绕过命中测试，
## 钮摆错位置、被别的件压住、disable 了还能点，这三种坏它都测不出来。

const 简介场景路 := "res://场景/界面/窗口/双修/双修简介窗.tscn"
const 选人场景路 := "res://场景/界面/窗口/双修/双修选人窗.tscn"
const 成对脚本 := "res://脚本/界面/窗口/双修/双修成对窗.gd"

## ──  逐件矩形（窗口坐标）──────────────────────────────────────────────
## 简介窗 = `ShuangxiuWindow.as:40-105`
const 简介件 := {
	"窗底": [0.0, 0.0, 279.0, 228.0],			# :43-44 background 279×228
	"标题": [0.0, 3.0, 279.0, 18.0],				# MWindow.as:166-173 小底标题 y=3、整幅居中
	"关钮": [248.0, 4.0, 25.0, 24.0],			# :48 + MWindow.as:210-219 x=round(279−25−6)、y=题y+1
	"内容底": [6.0, 30.0, 267.0, 192.0],			# :50-55 bg2 x=6 y=30 w=底宽−12=267 h=192
	"子面板": [11.0, 135.0, 257.0, 83.0],			# :56-61 bg3 x=11 y=135 w=bg2宽−10=257 h=83
	"简介一": [16.0, 39.0, 250.0, 36.0],			# :78-85 box1 @(16,39)；tf 高 = textHeight+6 = 30+6
	"简介二": [16.0, 93.0, 250.0, 36.0],			# :86-93 box2 @(16,93)；同上
	"简介三": [16.0, 145.0, 250.0, 59.0],		# :96-105 box3 @(16,145)；leading=4 ⇒ 15·3+2·4+6=59
}
## 选人窗 = `SelectPlayerWindow.as:369-423` + `:123-164` + `:212-229`
const 选人物件 := {
	"窗底": [0.0, 0.0, 292.0, 279.0],
	"标题": [0.0, 3.0, 292.0, 18.0],
	"关钮": [261.0, 4.0, 25.0, 24.0],			# x=round(292−25−6)=261
	"内容底": [6.0, 30.0, 280.0, 215.0],			# :377-382
	"列表底": [10.0, 83.0, 270.0, 142.0],		# :383-388
	"输入框底": [88.0, 36.0, 102.0, 21.0],		# :389-393（高未设 ⇒ 吃皮 21）
	"横线一": [14.0, 60.0, 252.0, 2.0],			# :394-399
	"横线二": [14.0, 104.0, 252.0, 2.0],		# :412-417
	"竖分隔一": [148.0, 84.0, 2.0, 20.0],		# :400-405
	"竖分隔二": [204.0, 84.0, 2.0, 20.0],		# :406-411
	"选中条": [12.0, 108.0, 265.0, 19.0],		# :418-423 curSelectCell（全窗只有这一根）
	"名标签": [11.0, 36.0, 78.0, 18.0],			# :124-126
	"名输入": [91.0, 37.0, 99.0, 18.0],			# :127-134
	"结果标签": [11.0, 64.0, 263.0, 18.0],		# :146-147
	"表头一": [13.0, 85.0, 132.0, 18.0],			# :148-150
	"表头二": [150.0, 85.0, 51.0, 18.0],			# :151-153
	"表头三": [206.0, 85.0, 51.0, 18.0],			# :154-156
	"行容器": [12.0, 108.0, 265.0, 117.0],		# :162-165
	"模糊提示": [11.0, 223.0, 182.0, 18.0],		# :157-159
	"页码": [211.0, 224.0, 34.0, 18.0],			# :135-144
	"上一页钮": [194.0, 223.0, 15.0, 13.0],		# :222-225
	"下一页钮": [244.0, 223.0, 15.0, 13.0],		# :226-229
	"搜索钮": [207.0, 36.0, 37.0, 22.0],			# :212-213 w=btn_width_two=37
	"查看资料钮": [26.0, 251.0, 61.0, 22.0],		# :214-216 w=btn_width_four=61
	"多功能钮": [116.0, 251.0, 61.0, 22.0],		# :217-219
	"取消钮": [201.0, 251.0, 61.0, 22.0],		# :220-221
}
## ── ② 三段文案（`原版数据.语言(键)` 现查的原文；`<font>`/`<br/>` 按本工程口径转 BBCode）──
const 三段 := {
	"简介一": "[color=#ff9100]请输入你希望与之双修的角色名，\n点击开始双修按钮，进入打坐双修模式[/color]",
	"简介二": "[color=#00ff00]开始双修后，打坐的双方在查克拉精华和经验\n获得速度上将比单独打坐加快20%[/color]",
	"简介三": "[color=#ffffff]注意：\n1.双修的另一方必须处于你身边一格范围内\n2.任何一方中断打坐状态，均将中断双修模式[/color]",
}
## 钮文案 = `ShuangxiuWindow.setData:146/148` 把选人窗那两颗改写成的样子
const 钮文案 := {"多功能钮": "双修简介", "取消钮": "开始双修", "查看资料钮": "查看资料", "搜索钮": "搜索"}
const 标题文案 := {"双修简介窗": "双修简介", "双修选人窗": "查询玩家"}
## ──  ⑥ 钮的四档真值 ──────────────────────────────────────────────────
## 皮：`StyleUtil.as:7-12` `skinFilters` = up 0 / over +30 / down −40，禁用 = `getGrayFilter()`。
## 字色：`MButton3.as:69-74` `_textColors`（十进制原样，换算成色由这里自己算）：
##   up 16577692=#FCF49C、over 16777155=#FFFFC3、down 11316658=#ACADB2、disabled 9671571=#939393
const 字色原值 := {"常态": 16577692, "悬停": 16777155, "按下": 11316658, "禁用": 9671571}
## 每颗钮：派生基名 + 宽高（**文件名**判的是"实际生效的那张"，不是路径）
const 钮皮 := {
	"查看资料钮": ["钮底61", 61.0, 22.0],
	"多功能钮": ["钮底61", 61.0, 22.0],
	"取消钮": ["钮底61", 61.0, 22.0],
	"搜索钮": ["钮底37", 37.0, 22.0],
	"上一页钮": ["分页上一页", 15.0, 13.0],
	"下一页钮": ["分页下一页", 15.0, 13.0],
}

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 假后端: Node
var 假地图: Node
var 提示: Array = []
var 鼠位 := Vector2(-120.0, -120.0)


func _判(对: bool, 说明: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 说明)


func _近(a: Array, b: Array) -> bool:
	for i in 4:
		if absf(float(a[i]) - float(b[i])) > 0.6:
			return false
	return true


func _矩形(件: Control) -> Array:
	return [件.position.x,件.position.y,件.size.x,件.size.y]


## 实际生效的那张皮 = `texture_normal` 的文件名（四档全都写这一个槽）。
func _皮(钮: Control) -> String:
	var 图: Texture2D = (钮 as TextureButton).texture_normal
	return 图.resource_path.get_file() if 图 != null else ""


func _字(钮: Control) -> Label:
	return 钮.get_node_or_null("Label") as Label


func _色(钮: Control) -> Color:
	var 字 := _字(钮)
	return 字.get_theme_color("font_color") if 字 != null else Color(0, 0, 0, 0)


func _色of(十进制: int) -> Color:
	return Color(float(十进制 >> 16 & 0xFF) / 255.0, float(十进制 >> 8 & 0xFF) / 255.0,
			float(十进制 & 0xFF) / 255.0, 1.0)


## 参照值自己算出来写成十六进制（**不许**把"实得"塞进"期望"那一格：
## 10-18 这条打成 `常态字色 = #FFFFFF … 实得 ffffff`，红了也看不出谁对谁错）。
func _期望色(档名: String) -> String:
	return _色of(int(字色原值[档名])).to_html(false)


func _initialize() -> void:
	await _跑()
	## ⚠ 协程中途报错 ⇒ 末尾那句汇总根本不会打印、`失败` 还是 0 ⇒ 退出码 0 = **假绿**。
	if not 跑完了:
		失败 += 1
		print("红：门没跑到底（中途报错，看上面最后一条 SCRIPT ERROR）")
	if 失败 == 0:
		print("双修成对窗离线门：通过 %d，红 0" % 通过)
		quit(0)
		return
	print("双修成对窗离线门：通过 %d，红 %d" % [通过, 失败])
	quit(1)


func _跑() -> void:
	print("双修成对窗离线门开始")
	## ⚠ 无头跑 `root.size` **必须等第一帧之后再设**：在 `_initialize` 那一层设会被启动流程顶回去，
	## 窗口停在默认的 **64×64** ⇒ 视口拾取整体失效（`mouse_entered` 不来、`BaseButton` 连 `pressed`
	## 都不发，因为它要求按下时自己 `is_hovered()`）。10-18 探针实测：设完立刻 `await process_frame`
	## 仍是 (64,64)，跑过一帧之后再设才落到 (960,560)。
	## ⇒ 这条不设对，下面所有"真点"判据会整批假红；而 `emit()` 写法则整批假绿。
	await process_frame
	root.size = Vector2i(960, 560)
	await process_frame
	await process_frame
	_判(root.size == Vector2i(960, 560),
			"量具自检：窗口尺寸落到 %s（不是 960×560 就等于拿 64×64 的视口在判点击）" % str(root.size))
	var 真后端 := root.get_node_or_null("BackendConnection")
	if 真后端 != null:
		root.remove_child(真后端)
	假后端 = 假后端类.new()
	假后端.name = "BackendConnection"
	root.add_child(假后端)
	## 「开始双修」的落点是**地图**（`玩家.get_parent()` 上那个有 `请求双修` 的节点）。
	## 这里挂一个同签名的替身：真地图要整张场景，而这一门判的是"面板把号交给谁"。
	假地图 = 假地图类.new()
	假地图.name = "LifeRoot"
	root.add_child(假地图)
	## ⚠ 假玩家**不挂在假地图下面**：夹具的形状要照**产品代码的查法**造（`_地图()` 按名字找
	## `LifeRoot`），不能照"玩家他爹就是地图"这个猜测造 —— 10-18 就是造错了形状，
	## 于是离线门全绿、同一份代码在在线门上一点就什么都不发（那种绿比红更坏）。
	var 演员层 := Node.new()
	演员层.name = "演员层"
	root.add_child(演员层)
	var 假玩家 := Node2D.new()
	假玩家.name = "玩家替身"
	假玩家.add_to_group("player")
	演员层.add_child(假玩家)
	var 管理 := (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate() as CanvasLayer
	root.add_child(管理)
	## 「地图回一句拒绝 ⇒ 屏幕上说出来」那条判据收的是 **GameSession 的信号**。
	## ⚠ 不接这一条，`提示` 永远是空数组 ⇒ 判据退化成"什么都不说也算对"（10-18 就是这条静默漏了）。
	var 会 := root.get_node_or_null("GameSession")
	_判(会 != null and 会.has_signal("notification_requested"),
			"量具自检：拿得到 GameSession 的提示信号（拿不到就没有一条判据能证明话说出来了）")
	if 会 != null:
		会.notification_requested.connect(func(文: String) -> void: 提示.append(String(文)))
	await process_frame
	var 成对 := load(成对脚本)

	# ── ① 逐件矩形 ──
	for 项 in [[简介场景路, 简介件, "双修简介窗"], [选人场景路, 选人物件, "双修选人窗"]]:
		var 件窗: Control = (load(String(项[0])) as PackedScene).instantiate() as Control
		root.add_child(件窗)
		await process_frame
		for 名 in (项[1] as Dictionary):
			var 子 := 件窗.get_node_or_null(String(名)) as Control
			_判(子 != null, "%s：%s 取得到" % [项[2], 名])
			if 子 == null:
				continue
			var 期望: Array = (项[1] as Dictionary)[名]
			_判(_近(_矩形(子), 期望),
					"%s.%s 矩形 = %s，实得 %s" % [项[2], 名, str(期望), str(_矩形(子))])
		for 名 in 钮文案:
			var 钮 := 件窗.get_node_or_null(String(名)) as BaseButton
			if 钮 == null:
				continue
			var 字 := _字(钮)
			_判(字 != null and 字.text == String(钮文案[名]),
					"%s 的文案 = 「%s」，实得「%s」" % [名, 钮文案[名], 字.text if 字 != null else "‹没 Label›"])
		var 题 := 件窗.get_node_or_null("标题") as Label
		_判(题 != null and 题.text == String(标题文案[项[2]]),
				"%s 的标题烘进场景了（编辑器里看得见的就是运行期那句），实得「%s」"
						% [项[2], 题.text if 题 != null else ""])
		件窗.queue_free()
		await process_frame

	# 简介窗三段：逐段比**含换行位置**（少一个换行就是排版错）
	var 简: Control = (load(简介场景路) as PackedScene).instantiate() as Control
	root.add_child(简)
	await process_frame
	for 名 in 三段:
		var 文 := 简.get_node(String(名)) as RichTextLabel
		_判(文 != null and 文.text == String(三段[名]),
				"%s 文案逐字 = 语言表原文（含换行），实得「%s」" % [名, 文.text if 文 != null else "‹取不到›"])
		_判(文 != null and 文.bbcode_enabled and not 文.scroll_active,
				"%s 开了 BBCode 且 scroll_active=false（不关就会多出一条版本里没有的滚动条）" % 名)
	简.queue_free()
	await process_frame

	# ── ③ 点球只发帧、**不开窗** ──
	假后端.清()
	_判(not bool(成对.已开(管理)), "开局没开")
	成对.点球(管理)
	_判(假后端.搜过 == [[4, 2, ""]],
			"点球只发一发 searchType **4** + mode **2**（= 同屏可见玩家，不带名字），实得 %s" % str(假后端.搜过))
	_判(not bool(成对.已开(管理)),
			"★ 帧发出去了、回帧还没到 ⇒ 屏幕上**一扇都不许有**（原版 `Client.onCharSearchResult:5003-5010` 才开窗）")

	# ── ④ 回帧 ⇒ 两扇成对摆位 ──
	假后端.authoritative_char_search_类型 = 4
	成对.回帧(管理, _三行())
	_判(bool(成对.已开(管理)), "回帧到了 ⇒ 两扇开出来")
	var 态: Dictionary = 成对.取状态(管理)
	var 简窗: Control = 态["简介"]
	var 选人窗: Control = 态["选人"]
	_判(简窗 != null and 选人窗 != null, "两扇都建出来了")
	if 简窗 == null or 选人窗 == null:
		跑完了 = true
		return
	var 屏 := 管理.get_viewport().get_visible_rect().size
	var 总宽 := 279.0 + 292.0 + 1.0
	_判(absf(简窗.position.x - maxf(0.0, floorf((屏.x - 总宽) * 0.5))) <= 1.0,
			"简介窗在**左**、整体按 572 宽居中（x=%.1f，屏宽 %.0f）" % [简窗.position.x, 屏.x])
	_判(absf(选人窗.position.x - (简窗.position.x + 280.0)) <= 0.01,
			"选人窗贴简介窗右边、**中间 1 像素缝**（`UIMain2.as:3173/3175`），实得 %.1f" % 选人窗.position.x)
	_判(absf(选人窗.position.y - 简窗.position.y) <= 0.01, "两窗**同一个 y**（`UIMain2.as:3170-3171`）")
	_判(简窗.get_index() > 选人窗.get_index(),
			"简介窗压在选人窗之上（原版先 setDOShow(选人) 再 setDOShow(简介)）")

	# ── ⑤ 行、列、选中条、悬停高亮 ──
	var 容 := 选人窗.get_node("行容器") as Control
	_判(容.get_child_count() == 3, "三行数据 ⇒ 三行（每页 5），实得 %d" % 容.get_child_count())
	var 第一行: Control = 容.get_child(0) as Control
	var 第二行: Control = 容.get_child(1) as Control
	_判(absf(第二行.position.y - 第一行.position.y - 23.0) <= 0.01,
			"行步距 23 = 行高 21 + 2（`SPW:246`），实得 %.1f" % (第二行.position.y - 第一行.position.y))
	_判((第一行.get_node("名") as Label).text == "油女澪",
			"第 1 列 = 名字，实得「%s」" % (第一行.get_node("名") as Label).text)
	_判((第一行.get_node("等级") as Label).text == "37",
			"第 2 列 = 等级，实得「%s」" % (第一行.get_node("等级") as Label).text)
	_判((第一行.get_node("职业") as Label).text != "300" and not (第一行.get_node("职业") as Label).text.is_empty(),
			"第 3 列 = **职业名**而不是职业号，实得「%s」" % (第一行.get_node("职业") as Label).text)
	_判(第一行.get_node_or_null("头像") == null,
			"★ 这一族**没有头像列**（`SelectPlayerWindowCell.as:44-55` 只有名/级/职三段 ⇒ 加头像就是自造）")
	_判(not (选人窗.get_node("选中条") as Control).visible, "没点行之前那根选中条不显示")
	_判((选人窗.get_node("查看资料钮") as BaseButton).disabled, "没选人 ⇒「查看资料」不可点")
	## 悬停高亮 = `SelectPlayerWindowCell.as:102-103`：**真移鼠标**，不 `emit()`。
	await _移到(第一行.get_global_rect().position + 第一行.size * 0.5)
	var 亮 := 第一行.get_node("悬停") as Control
	_判(亮.visible, "鼠标移到行上 ⇒ 那一行的悬停条显示（`ROLL_OVER`）")
	await _移到(Vector2(-120.0, -120.0))
	_判(not 亮.visible, "移开 ⇒ 悬停条收起（`ROLL_OUT`）")
	_点(第一行)
	await process_frame
	var 条 := 选人窗.get_node("选中条") as Control
	_判(条.visible, "点行（真事件 push_input）⇒ 那根**共享**的选中条显示出来")
	_判(absf(条.position.y - 108.0) <= 0.01, "选中条停在第 1 行上（y=108），实得 %.1f" % 条.position.y)
	_判(not (选人窗.get_node("查看资料钮") as BaseButton).disabled, "选了人 ⇒「查看资料」可点")
	_点(第二行)
	await process_frame
	_判(absf(条.position.y - 131.0) <= 0.01,
			"换选第 2 行 ⇒ 选中条跟着移到 131，而且**全窗还是只有一根**（实得 y %.1f，行里没多建：%s）" % [
				条.position.y, str(容.get_children().all(func(子: Node) -> bool:
						return (子 as Control).get_node_or_null("选中条") == null))])
	## 选中那一行的**悬停条要给选中条让开**（原版 `curSelectCell` 压住它，两条不叠）。
	await _移到(第二行.get_global_rect().position + 第二行.size * 0.5)
	_判(not (第二行.get_node("悬停") as Control).visible,
			"悬停条在**已选中**那一行上不显示（选中条已经压在那儿，两条叠起来就是原版没有的样子）")
	await _移到(Vector2(-120.0, -120.0))

	# ──  ⑥ 六颗钮的 MButton3 四档 ──────────────────────────────────────
	# 常态 → 悬停 → 按下 → **松手（回 up，不是 hover）** → 移开 → 再悬停
	for 名 in ["查看资料钮", "多功能钮", "搜索钮"]:
		var 钮 := 选人窗.get_node(名) as TextureButton
		_判(not 钮.disabled, "%s 这会儿可点（禁用档另外单独判）" % 名)
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"%s 是手型光标（`MButton3.init():135` buttonMode+useHandCursor）" % 名)
		var 基: String = String((钮皮[名] as Array)[0])
		_判(_皮(钮) == 基 + ".png", "%s 常态皮 = %s.png，实得 %s" % [名, 基, _皮(钮)])
		_判(_色(钮) == _色of(字色原值["常态"]),
				"%s 常态字色 = #%s（`MButton3.as:69-74` up=16577692），实得 %s"
				% [名, _期望色("常态"), _色(钮).to_html(false)])
		var 心: Vector2 = 钮.get_global_rect().position + 钮.size * 0.5
		await _移到(心)
		_判(_皮(钮) == 基 + "_悬停.png",
				"★ %s 悬停换的是**预烘皮** %s_悬停.png（+30 加性滤镜烘进图里），实得 %s" % [名, 基, _皮(钮)])
		_判(_色(钮) == _色of(字色原值["悬停"]),
				"%s 悬停字色 = #%s（over=16777155），实得 %s" % [名, _期望色("悬停"), _色(钮).to_html(false)])
		_判(root.gui_get_hovered_control() == 钮,
				"%s 真的被视口拾取到了（不是 emit 演出来的）" % 名)
		root.push_input(_按(true, 心), true)
		for _帧 in 3:
			await process_frame
		_判(_皮(钮) == 基 + "_按下.png", "%s 按下 = %s_按下.png（−40），实得 %s" % [名, 基, _皮(钮)])
		_判(_色(钮) == _色of(字色原值["按下"]),
				"%s 按下字色 = #%s（down=11316658），实得 %s" % [名, _期望色("按下"), _色(钮).to_html(false)])
		root.push_input(_按(false, 心), true)
		for _帧 in 3:
			await process_frame
		_判(_皮(钮) == 基 + ".png",
				"★ %s **松手仍停在钮上**也回常态（`MButton3.as:103-108` 松手推 STATE_UP；用 texture_hover 实现的话这一档会留在悬停皮）" % 名)
		_判(_色(钮) == _色of(字色原值["常态"]),
				"%s 松手字色也回 #%s（up）那一档，实得 %s" % [名, _期望色("常态"), _色(钮).to_html(false)])
		await _移到(Vector2(-120.0, -120.0))
		_判(_皮(钮) == 基 + ".png", "%s 移开回常态" % 名)
		await _移到(心)
		_判(_皮(钮) == 基 + "_悬停.png",
				"%s **再悬停还会亮**（状态机不是只走一遍的一次性接线）" % 名)
		await _移到(Vector2(-120.0, -120.0))
	_判(_皮(选人窗.get_node("查看资料钮")) == "钮底61.png" and _皮(选人窗.get_node("多功能钮")) == "钮底61.png",
			"三档换的是**各自那张**（每颗钮记住自己的常态图，不会把上一颗的皮留在这一颗上）")
	## 禁用档 = 灰皮，而且**鼠标移上去也不变亮**。
	## ⚠ 翻页这一腿要先有**超过一页**的数据：三行只有一页，那时「下一页」也是禁用的，
	## 拿它判"点得动"就是判一条永远走不到的路（假不敏感）。
	假后端.authoritative_char_search_类型 = 4
	成对.回帧(管理, _十二行())
	await process_frame
	var 上一页 := 选人窗.get_node("上一页钮") as TextureButton
	var 下一页 := 选人窗.get_node("下一页钮") as TextureButton
	_判((选人窗.get_node("页码") as Label).text == "1/3", "喂 12 行 ⇒ 三页，实得「%s」"
			% (选人窗.get_node("页码") as Label).text)
	_判(上一页.disabled and _皮(上一页) == "分页上一页_灰.png",
			"第一页 ⇒「上一页」禁用且显示**灰皮**（`getGrayFilter()`），实得 %s" % _皮(上一页))
	await _移到(上一页.get_global_rect().position + 上一页.size * 0.5)
	_判(_皮(上一页) == "分页上一页_灰.png",
			"禁用的那颗**悬停不变亮**（原版 STATE_DISABLED 不推 lightFilter）")
	_点(上一页)
	await process_frame
	_判((选人窗.get_node("页码") as Label).text == "1/3",
			"禁用的那颗点下去**不翻页**（emit 会绕过这一条）")
	await _移到(Vector2(-120.0, -120.0))
	_判(下一页.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "翻页箭头也是手型")
	## ⚠ 箭头这一族**常态就是通用控件那张原图**（文件名叫 `下一页.png`），只有三档派生图
	## 在 `素材/界面/专用控件/分页*_` 下（已逐像素验过 `派生 == 原图 ±30/−40`）⇒ 期望按文件名判，别猜前缀。
	_判(_皮(下一页) == "下一页.png", "可点的箭头停在常态皮，实得 %s" % _皮(下一页))
	_点(下一页)
	await process_frame
	_判((选人窗.get_node("页码") as Label).text == "2/3", "下一页点得动，实得「%s」"
			% (选人窗.get_node("页码") as Label).text)
	_判(not 上一页.disabled and _皮(上一页) == "上一页.png",
			"翻到第 2 页 ⇒「上一页」解禁并换回常态皮（禁用态留在钮上就是没按当前态重画），实得 %s" % _皮(上一页))

	# ── ⑦ 空列表 ⇒「开始双修」不给点 ──
	假后端.authoritative_char_search_类型 = 4
	成对.回帧(管理, [])
	_判((选人窗.get_node("取消钮") as BaseButton).disabled,
			"★ 回帧是空的 ⇒「开始双修」disabled（`setData:330-346` 空表两颗一起 disable）")
	_判(_皮(选人窗.get_node("取消钮")) == "钮底61_灰.png",
			"空表时那颗「开始双修」显示灰皮，实得 %s" % _皮(选人窗.get_node("取消钮")))
	_判(_色(选人窗.get_node("取消钮")) == _色of(字色原值["禁用"]),
			"空表时那颗的字色 = #%s（disabled=9671571），实得 %s" % [
					_期望色("禁用"), _色(选人窗.get_node("取消钮")).to_html(false)])
	_判(not (选人窗.get_node("多功能钮") as BaseButton).disabled,
			"「双修简介」那颗**无条件**可点（`setEnabledBtn:455-466`）")
	_判(容.get_child_count() == 0, "空表 ⇒ 行清空，实得 %d 行" % 容.get_child_count())
	假后端.authoritative_char_search_类型 = 4
	成对.回帧(管理, _三行())
	_判(not (选人窗.get_node("取消钮") as BaseButton).disabled, "又回了一批行 ⇒「开始双修」恢复可点")
	_判(_皮(选人窗.get_node("取消钮")) == "钮底61.png", "恢复可点 ⇒ 灰皮也一起退掉，实得 %s"
			% _皮(选人窗.get_node("取消钮")))

	# ── ⑧ 搜索钮与两族分流 ──
	(选人窗.get_node("名输入") as LineEdit).text = " 木叶 "
	假后端.清()
	_点(选人窗.get_node("搜索钮"))
	await process_frame
	_判(假后端.搜过 == [[4, 1, "木叶"]],
			"输入框 +「搜索」（真点）= searchType 仍是 **4**、mode 1 按名字搜、名字已 strip，实得 %s"
			% str(假后端.搜过))
	_判(_源码含("脚本/界面/功能窗口.gd", "request_char_search(名, 1, 100)"),
			"家族「查询玩家」发的是 searchType **100**（原版 `FamillyManager.as:897`）⇒ 两族不再抢同一帧")
	_判(_源码含("脚本/界面/窗口/家族/家族列表填充.gd", "authoritative_char_search_类型"),
			"家族列表填充按类型号过滤回帧（不然双修的回帧会把它的列表刷掉）")
	var 原样: int = 容.get_child_count()
	假后端.authoritative_char_search_类型 = 100
	成对.回帧(管理, [])
	_判(容.get_child_count() == 原样,
			"★ searchType 100 的回帧**不改**这一组的行（分流靠类型号，不靠「我刚好开着」）")

	# ── ⑨ 开始双修 = 交给地图那条闸 ──
	假后端.authoritative_char_search_类型 = 4
	成对.回帧(管理, _三行())
	await process_frame
	_点(容.get_child(1) as Control)
	await process_frame
	假地图.请求过.clear()
	假后端.清()
	_点(选人窗.get_node("取消钮"))
	await process_frame
	_判(假地图.请求过 == [1002],
			"「开始双修」（真点）把选中那行的号交给地图（`HealHandler.requestToDoubleHeal`，与头像菜单同一闸），实得 %s"
			% str(假地图.请求过))
	_判(假后端.搜过.is_empty() and 假后端.资料过.is_empty(),
			"★ 这一扇**不自己发 86:3**（发邀在地图那侧，够不够近、要不要先赶路都由它判），实得 %s / %s"
			% [str(假后端.搜过), str(假后端.资料过)])
	_判(not bool(成对.已开(管理)), "发出去了 ⇒ 这一组收掉")
	成对.点球(管理)
	假后端.authoritative_char_search_类型 = 4
	成对.回帧(管理, _三行())
	await process_frame
	态 = 成对.取状态(管理)
	选人窗 = 态["选人"]
	_点((选人窗.get_node("行容器") as Control).get_child(0) as Control)
	await process_frame
	假后端.清()
	_点(选人窗.get_node("查看资料钮"))
	await process_frame
	_判(假后端.资料过 == [1001],
			"「查看资料」发的是**选中那个人**的 full-info 请求（`SelectPlayerWindow.as:325-328` clickCharacter），实得 %s"
			% str(假后端.资料过))
	假地图.回话 = "你当前正在双修，无法再发起新的双修"
	提示.clear()
	_点(选人窗.get_node("取消钮"))
	await process_frame
	_判(提示 == [假地图.回话], "地图回一句拒绝 ⇒ 屏幕上说出来（实得 %s）" % str(提示))
	_判(bool(成对.已开(管理)), "被拒 ⇒ 窗留着，人可以改选另一个再试")
	假地图.回话 = ""

	# ── ⑩ 拖动：两扇一起走；列表区不吞 ──
	态 = 成对.取状态(管理)
	简窗 = 态["简介"]
	选人窗 = 态["选人"]
	var 原选 := 选人窗.position
	var 原简 := 简窗.position
	拖(选人窗, Vector2(120.0, 12.0), Vector2(180.0, 40.0))
	await process_frame
	_判(absf(选人窗.position.x - (原选.x + 60.0)) <= 1.0,
			"拖选人窗顶部 29 像素 ⇒ 它自己挪（实得 x %.1f，期望 %.1f）" % [选人窗.position.x, 原选.x + 60.0])
	_判(absf(简窗.position.x - (原简.x + 60.0)) <= 1.0 and absf(简窗.position.y - 选人窗.position.y) <= 1.0,
			"★ 简介窗**跟着一起走**并保持贴左同高（原版 reparent 成子件，这里同步位移，屏幕上等价）")
	var 拖后 := 选人窗.position
	拖(选人窗, Vector2(120.0, 120.0), Vector2(200.0, 200.0))
	await process_frame
	_判(选人窗.position == 拖后, "按在**列表区**（y≥29）不许拖动（`MWindow.as:27` 顶部 29 才是拖动区）")

	# ── ⑪ 两颗关钮的分工 ──
	_点(简窗.get_node("关钮"))
	await process_frame
	_判(not 简窗.visible and bool(成对.已开(管理)),
			"简介窗那颗关钮**只藏简介**（原版它没重写 onCloseBtnClick ⇒ 不联动）")
	_点(选人窗.get_node("多功能钮"))
	await process_frame
	_判(简窗.visible, "点「双修简介」那颗 ⇒ 简介窗又出来（`ShuangxiuWindow.__shuangxiuJianjie`）")
	_判(absf(简窗.position.x - (选人窗.position.x - 279.0)) <= 0.01,
			"重新贴回选人窗左边、缝 **0 像素**（`:114` 字面写的 `x = 选人窗.x − width`，与初开那 1 像素不同）")
	_判(简窗.get_index() > (态["选人"] as Control).get_index(),
			"提到最上层这一步也做了（原版 `reverseDisplay`）")
	_点(选人窗.get_node("关钮"))
	await process_frame
	_判(not bool(成对.已开(管理)), "选人窗那颗关钮 ⇒ 整组收掉（`SelectPlayerWindow.remove():271-274` 带关伴窗）")

	# ──  分页 ──
	成对.点球(管理)
	假后端.authoritative_char_search_类型 = 4
	成对.回帧(管理, _十二行())
	await process_frame
	态 = 成对.取状态(管理)
	选人窗 = 态["选人"]
	var 容2 := 选人窗.get_node("行容器") as Control
	_判(容2.get_child_count() == 5, "12 行数据 ⇒ 第一页只画 5 行（pageSize=5），实得 %d" % 容2.get_child_count())
	_判((选人窗.get_node("页码") as Label).text == "1/3",
			"页码 = 1/3，实得「%s」" % (选人窗.get_node("页码") as Label).text)
	_判((选人窗.get_node("上一页钮") as BaseButton).disabled, "第一页 ⇒「上一页」不可点")
	_点(选人窗.get_node("下一页钮"))
	await process_frame
	_判((容2.get_child(0).get_node("名") as Label).text == "第6号",
			"翻一页 ⇒ 换的是第 6 行起那批，第一行实得「%s」" % (容2.get_child(0).get_node("名") as Label).text)
	for _i in 6:
		_点(选人窗.get_node("下一页钮"))
		await process_frame
	_判((选人窗.get_node("页码") as Label).text == "3/3",
			"连点下一页也不会翻过头（越界直接 return），实得「%s」" % (选人窗.get_node("页码") as Label).text)
	_判((容2.get_child(容2.get_child_count() - 1).get_node("名") as Label).text == "第12号",
			"最后一页剩下那两行也画出来了")
	_判(_皮(选人窗.get_node("下一页钮")) == "分页下一页_灰.png",
			"翻到末页 ⇒「下一页」自己变灰（禁用重画），实得 %s" % _皮(选人窗.get_node("下一页钮")))
	成对.关掉(管理)
	_判(not bool(成对.已开(管理)), "关掉 ⇒ 整组没了，可以再来一轮")
	跑完了 = true


## 真事件：走视口的输入派发，不用 `gui_input.emit()`（那条会演绿：状态机要的坐标/命中它都拿不到）。
func _点(件: Control) -> void:
	var 心: Vector2 = 件.get_global_rect().position + 件.size * 0.5
	## 两跳再点：**同一帧连发两条 motion 视口只按最后一条拾取** ⇒ 大距离瞬移不触发
	## `mouse_entered`，按钮收不到 hover 就直接点，四档那条链会假断。
	root.push_input(_动(鼠位 + (心 - 鼠位) * 0.5), true)
	root.push_input(_动(心), true)
	for 按 in [_按(true, 心), _按(false, 心)]:
		root.push_input(按, true)
	鼠位 = 心


## 移鼠标也分两跳（同上）。
func _移到(位: Vector2) -> void:
	root.push_input(_动(鼠位 + (位 - 鼠位) * 0.5), true)
	await process_frame
	root.push_input(_动(位), true)
	## 输入步与验步之间隔 3 帧：读的是画完之后的状态。
	for _帧 in 3:
		await process_frame
	鼠位 = 位


func 拖(件: Control, 起: Vector2, 终: Vector2) -> void:
	var 底 := 件.get_global_rect().position
	root.push_input(_按(true, 底 + 起), true)
	var 动 := _动(底 + 终)
	root.push_input(动, true)
	root.push_input(_按(false, 底 + 终), true)
	鼠位 = 底 + 终


func _动(位: Vector2) -> InputEventMouseMotion:
	var 动 := InputEventMouseMotion.new()
	动.position = 位
	动.global_position = 位
	return 动


func _按(按下: bool, 位: Vector2) -> InputEventMouseButton:
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = 按下
	按.position = 位
	按.global_position = 位
	return 按


func _源码含(相对路径: String, 子串: String) -> bool:
	var 文 := FileAccess.get_file_as_string("res://" + 相对路径)
	if 文.is_empty():
		文 = FileAccess.get_file_as_string(相对路径)
	return 文.contains(子串)


func _三行() -> Array:
	return [
		{"character_id": 1001, "name": "油女澪", "level": 37, "job": 300, "line": 1},
		{"character_id": 1002, "name": "木叶忍者", "level": 41, "job": 100, "line": 1},
		{"character_id": 1003, "name": "春野樱", "level": 12, "job": 200, "line": 1},
	]


func _十二行() -> Array:
	var 出: Array = []
	for i in 12:
		出.append({"character_id": 2000 + i, "name": "第%d号" % (i + 1), "level": i + 1, "job": 100, "line": 1})
	return 出


## 假后端**只记参数**，不在这里拼 `1282:…` —— 拼串是 `后端连接` 自己的活，
## 由 `测试/后端协议回归测试.gd` 拿真对象钉包体形状。在这儿照抄一份格式 = 两边一起错、互相印证。
class 假后端类 extends Node:
	var in_game := true
	var 搜过: Array = []
	var 资料过: Array = []
	## 与真后端**同名**：控制器读的就是这一格（`authoritative_char_search_类型`），
	## 名字对不上就等于"永远不匹配"⇒ 那条分流判据会静默变成"什么都不画也算对"。
	var authoritative_char_search_类型 := 0

	func 清() -> void:
		搜过.clear()
		资料过.clear()

	func request_char_search(名: String, mode: int, search_id: int) -> bool:
		搜过.append([search_id, mode, 名])
		return true

	func request_char_full_info(号: int) -> bool:
		资料过.append(号)
		return true


class 假地图类 extends Node:
	var 请求过: Array = []
	var 回话 := ""

	func 请求双修(号: int) -> String:
		请求过.append(号)
		return 回话
