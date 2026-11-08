extends SceneTree

## 离线门：`脚本/界面/提示条面板.gd`（原版 `MessageTipPane2` 那两块任务提示条）。
##
## 三条腿，各挡一类「看着像做完了」：
##  * **版式腿**：宽/高/两个件的落位全部由本文件**按 AS3 常数自己再算一遍**（`draw():150-207`
##    那串累加），再与脚本的 `算块()` 和**运行期节点的实际 position/size** 三方比。
##    只判"我确实调过布局"等于没判 —— 少加一个 `+5` 屏幕上是看得见的，断言里必须算出来。
##  * **状态机腿**：`isAutoQuestFun():386-427` 的四组合（自动交接 开/关 × 档 11/12）
##    + 环任务那条例外 + 「点 X 不走路」。这一族静态截图验不出来。
##    点钮走**真 push_input**（`mouse_entered.emit()` 那一类演绿不算测过）。
##  * **接线腿**：HUD 那两头（`_于任务接上` / `_于任务交付`）必须把动作交给提示条的
##    `确定点击`，而不是自己抄一份走路 —— 抄了就会再犯"开关一勾连路都不走"那条。
##
## 跑法：Godot --path . --headless --script res://测试/提示条本体回归测试.gd
## 纯建控件 + 注入鼠标事件 ⇒ 不碰 user://（`离线门不许写存档`）。

const 提示条 := preload("res://脚本/界面/提示条面板.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const HUD路 := "res://脚本/界面/小地图面板.gd"

## ── 本文件**自己抄一份** AS3 常数（出处逐条写在 提示条面板.gd 的头注释）──
const G_顶 := 27.0			# MessageTipPane2.as:162  var _loc1_:int = 27
const G_标题高 := 15.0		# 12px 宋体单行 textHeight（本工程既有口径）
const G_正文高 := 4.0			# 空 TextField 只剩上下各 2px 内缩
const G_件距 := 5.0			# :171/:186  两个 `+ 5`
const G_钮高 := 22.0			# MButtonF 的 upSkin(tag18) 原生高
const G_钮底距 := 15.0		# :191  `+= okBtn.height + 15`
const G_标题富余 := 20.0		# :167  `background.width = titleText.width + 20`
const G_钮字富余 := 6.0		# MButton3.as:383  isScale9Grid ⇒ 宽 = 文字 + 6
const G_关闭右距 := 5.0		# :205
const G_关闭上距 := 5.0		# :206
const G_小地图下距 := 70.0		# UIMain2.as:2660
const G_屏宽 := 960.0
const G_小地图高 := 200.0
const G_底板边距 := [40.25, 12.05, 29.25, 20.5]		# 符号175 splitter ÷20，[左,右,上,下]
const G_底板原生 := Vector2(263, 252)

const 任务名 := "修行开始"
const 号 := 1003

var 总 := 0
var 红 := 0
var 日志: Array[String] = []
var 收到: Array = []		# 记录 确定点击(类型, 任务号)


func _记(过: bool, 说: String) -> void:
	总 += 1
	if not 过:
		红 += 1
		日志.append("  !! " + 说)
	else:
		日志.append("  √ " + 说)


func _同(实, 期, 说: String) -> void:
	## 两边都能转 float 时按 **1e-4 容差**比：StyleBoxTexture 的四条边距存的是 real32，
	## 12.05 写进去读出来是 12.0500001907349 —— 拿 str 硬比会把量具自己判红。
	var a = 实 if 实 is Vector2 else float(实) if _可转(实) else 实
	var b = 期 if 期 is Vector2 else float(期) if _可转(期) else 期
	var 过 := false
	if a is float and b is float:
		过 = absf(a - b) < 0.0001
	else:
		过 = str(a) == str(b)
	_记(过, "%s：实得 %s，期望 %s" % [说, str(实), str(期)])


func _可转(v) -> bool:
	return v is int or v is float or (v is String and (v as String).is_valid_float())


func _号宽(文: String) -> float:
	var 尺 := 0.0
	for i in 文.length():
		if 文.unicode_at(i) > 0x2E80:
			尺 += 12.0
		else:
			尺 += 6.0
	return 尺


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	## ⚠ 无头必须在 add_child **之前**钉窗口尺寸，否则视口拿不到 GUI 命中 ⇒ 点了静默不生效
	##   （同 小地图标记回归测试.gd:89-91 那条；这里不钉，摆位量到的屏宽还是默认 64）
	root.size = Vector2i(int(G_屏宽), 560)
	var S = load("res://脚本/界面/提示条面板.gd")
	_记(S != null, "提示条面板 能 load（parse 炸在这里就会红，不会静默零覆盖）")
	if S == null:
		_尾()
		return
	# ⚠ **必须 await**：`_版式腿` 末尾有 `await process_frame`，不 await ⇒ 调用处立刻开跑
	#   `_行为腿`，最后那条"清空后层里没剩节点"跟 `_尾()` 抢（2026-10-22 扫出来的一批同类之一）。
	await _版式腿(S)
	await _行为腿(S)
	await _真点击腿(S)
	_接线腿()
	_尾()


## ── 版式腿：三方比（本文件算的 / 脚本算块() / 运行期节点实际值）────────────
func _版式腿(S) -> void:
	var 层: Control = S.new()
	root.add_child(层)
	for 档 in [提示条.档接取, 提示条.档交付]:
		var 标 := "接受【%s】任务" % 任务名 if 档 == 提示条.档接取 else "【%s】完成任务" % 任务名
		var 钮 := "前往任务地点" if 档 == 提示条.档接取 else "回复任务"
		var 标高 := _号宽(标)
		var 期宽 := 标高 + G_标题富余
		var 期高 := G_顶 + G_标题高 + G_件距 + G_正文高 + G_件距 + G_钮高 + G_钮底距
		var 期钮宽 := _号宽(钮) + G_钮字富余
		var 期钮y := G_顶 + G_标题高 + G_件距 + G_正文高 + G_件距
		var 几: Dictionary = S.算块(档, 任务名)
		_记(String(几["标题文"]) == 标, "档%d 标题文案逐字（DATA_TITLE_%s）" % [档, "12" if 档 == 提示条.档接取 else "13"])
		_记(String(几["钮文"]) == 钮, "档%d 钮文案逐字（DATA_BTNTEXT_%s）" % [档, "12" if 档 == 提示条.档接取 else "13"])
		_同(float(几["宽"]), 期宽, "档%d 块宽 = 标题宽 + 20" % 档)
		_同(float(几["高"]), 期高, "档%d 块高 = 27+15+5+4+5+22+15" % 档)
		_同(float(几["钮宽"]), 期钮宽, "档%d 钮宽 = 文字宽 + 6" % 档)
		_同((几["钮位"] as Vector2).y, 期钮y, "档%d 钮 y = 那串累加到钮头上的值" % 档)
		_同((几["标题位"] as Vector2).y, G_顶, "档%d 标题 y = 27" % 档)
		_同((几["标题位"] as Vector2).x, float(floori((期宽 - 标高) / 2.0)), "档%d 标题 x = 整除居中" % 档)
		_同((几["钮位"] as Vector2).x, float(floori((期宽 - 期钮宽) / 2.0)), "档%d 钮 x = 整除居中（>>1 不是四舍五入）" % 档)
		## 运行期节点：不自动 ⇒ 条会留在屏上，可以直接量
		层.报小地图高(G_小地图高)
		层.显示(档, 号 + 档, 任务名, false, false)
		var 条 := _找条(层, 档)
		_记(条 != null, "档%d 建得出条（不自动时留在屏上）" % 档)
		if 条 == null:
			continue
		_同(条.size, Vector2(期宽, 期高), "档%d 运行期条的 size 与算式一致" % 档)
		_同(条.mouse_filter, Control.MOUSE_FILTER_STOP, "档%d 条自己吃鼠标（原版是窗口）" % 档)
		var 题 := 条.get_node("标题") as Label
		var 钮节 := 条.get_node("确定") as Button
		var 底 := 条.get_node("底板") as Panel
		var 关 := 条.get_node("关闭") as TextureButton
		_记(题 != null and 钮节 != null and 底 != null and 关 != null, "档%d 四件齐全（底板/关闭/标题/确定）" % 档)
		_同(题.position, (几["标题位"] as Vector2), "档%d 标题落位 == 算式" % 档)
		_同(钮节.position, (几["钮位"] as Vector2), "档%d 钮落位 == 算式" % 档)
		_同(钮节.size, Vector2(期钮宽, G_钮高), "档%d 钮尺寸" % 档)
		_同(题.text, 标, "档%d 标题真画的是那句文案" % 档)
		_同(钮节.text, 钮, "档%d 钮真画的是那句文案" % 档)
		_记(题.mouse_filter == Control.MOUSE_FILTER_IGNORE, "档%d 标题不吃鼠标" % 档)
		_记(底.mouse_filter == Control.MOUSE_FILTER_IGNORE, "档%d 底板不吃鼠标（原版 background 不参与命中）" % 档)
		_同(题.get_theme_color("font_color"), Color(1, 1, 0, 1), "档%d 标题色 #FFFF00（createTitleTF 默认参）" % 档)
		_同(钮节.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "档%d 钮手型" % 档)
		var 皮 := 底.get_theme_stylebox("panel") as StyleBoxTexture
		_记(皮 != null, "档%d 底板是 StyleBoxTexture" % 档)
		if 皮 != null:
			_记(皮.texture != null and String(皮.texture.resource_path).ends_with("提示条底板.png"),
					"档%d 底板皮 = 符号175 那张（不是 提示框.png）" % 档)
			_同(皮.texture_margin_left, float(G_底板边距[0]), "档%d 九宫格左边距" % 档)
			_同(皮.texture_margin_right, float(G_底板边距[1]), "档%d 九宫格右边距" % 档)
			_同(皮.texture_margin_top, float(G_底板边距[2]), "档%d 九宫格上边距" % 档)
			_同(皮.texture_margin_bottom, float(G_底板边距[3]), "档%d 九宫格下边距" % 档)
			for 项 in ["left", "top", "right", "bottom"]:
				_同(皮.get("content_margin_%s" % 项), 0.0, "档%d content_margin_%s 必须 0" % [档, 项])
		_同(关.position, Vector2(期宽 - 关.texture_normal.get_size().x - G_关闭右距, G_关闭上距),
				"档%d 关闭钮落位（宽−皮宽−5, 5）" % 档)
		## 位置：x = 屏宽 − 块宽、y = 小地图高 + 70。
		## ⚠ 屏宽**现读视口**、不钉 960：原版 `Config.STAGE_WIDTH` 就是运行期舞台宽，
		##   钉成常数等于把"窗口最大化后提示条偏左"这种错判成合格（横幅那条踩过，见 任务提示链门:67-68）。
		var 屏 := 层.get_viewport().get_visible_rect().size.x
		_记(absf(屏 - G_屏宽) < 1.0, "量具自己：视口宽应是 %s，实得 %s（钉 root.size 没生效）" % [str(G_屏宽), str(屏)])
		_同(条.position, Vector2(屏 - 期宽, G_小地图高 + G_小地图下距), "档%d 摆位 == 屏宽−块宽 / 小地图高+70" % 档)
	层.清空()
	await process_frame
	_记(层.get_child_count() == 0, "清空() 之后层里没剩节点（queue_free 已落地）")
	层.free()


## ── 状态机腿：四组合 + 环任务例外 + 去重 + 移除 ─────────────────────────
func _行为腿(S) -> void:
	var 层: Control = S.new()
	root.add_child(层)
	层.确定点击.connect(func(类: int, 编: int) -> void: 收到.append([类, 编]))
	收到.clear()
	## ① 没勾开关 + 非环 + 档11 ⇒ 隐藏并自动点一次确定 ⇒ 走路信号发出去、条不留
	var 结: Dictionary = 层.显示(提示条.档接取, 号, 任务名, false, true)
	_记(bool(结["自动点了"]), "① 没勾开关接非环任务 ⇒ 自动点确定（isAutoQuestFun:394-395）")
	_同(层.条数(), 0, "① 点完自己收掉（__onOkClick 末尾 onCloseBtnClick）")
	_同(收到, [[提示条.档接取, 号]], "① 走路信号发的是 (11, 任务号)")
	## ② 勾了开关 + 档11 ⇒ 条留在屏上、不发信号
	收到.clear()
	结 = 层.显示(提示条.档接取, 号, 任务名, false, false)
	_记(not bool(结["自动点了"]), "② 勾了开关 ⇒ 不自动点（:403-407 那一支）")
	_同(层.条数(), 1, "② 条留在屏上等玩家点")
	_记(_条可见(层, 提示条.档接取), "② 这条是**看得见**的（原版 visible = true）")
	_同(收到, [], "② 没点 ⇒ 一步都不走")
	## ③ 没勾开关 + **环任务** + 档11 ⇒ 仍然不自动点（:392 那条例外）
	层.清空()
	收到.clear()
	await process_frame
	结 = 层.显示(提示条.档接取, 号, 任务名, true, true)
	_记(not bool(结["自动点了"]), "③ 环任务即使没勾也不自动点（isLoopQuest 例外）")
	_同(层.条数(), 1, "③ 条留在屏上")
	## ④ 档12 两支
	层.清空()
	收到.clear()
	await process_frame
	结 = 层.显示(提示条.档交付, 号, 任务名, false, true)
	_记(bool(结["自动点了"]), "④ 没勾开关交付 ⇒ 自动点确定（:411-415）")
	_同(收到, [[提示条.档交付, 号]], "④ 走路信号发的是 (12, 任务号)")
	收到.clear()
	结 = 层.显示(提示条.档交付, 号 + 1, 任务名, true, false)
	_记(not bool(结["自动点了"]), "④ 勾了开关交付 ⇒ 显示等点（环任务例外**不管**交付档）")
	_同(收到, [], "④ 等点期间不发走路信号")
	## ⑤ 去重：同 type + 同任务号 第二次不建（UIMain2:2642-2648）
	层.清空()
	await process_frame
	层.显示(提示条.档交付, 号, 任务名, false, false)
	结 = 层.显示(提示条.档交付, 号, 任务名, false, false)
	_记(not bool(结["建了"]), "⑤ 同档同任务号第二次不重复建")
	_同(层.条数(), 1, "⑤ 屏上仍只有一条")
	## ⑥ 换任务号要能并存
	层.显示(提示条.档交付, 号 + 7, 任务名, false, false)
	_同(层.条数(), 2, "⑥ 不同任务号各一条（原版不堆叠、位置相同 ⇒ 会重叠，那是原版行为）")
	## ⑦ 移除：按档清 / 两档一起清
	层.清空()
	await process_frame
	层.显示(提示条.档接取, 号, 任务名, false, false)
	层.显示(提示条.档交付, 号, 任务名, false, false)
	_同(层.移除任务提示(提示条.档接取, 号), 1, "⑦ 按档清：清掉 1 条")
	_同(层.条数(), 1, "⑦ 交付档那条留着")
	_同(层.移除任务提示(-1, 号), 1, "⑦ 类型 −1 ⇒ 两档都清（showCompleteTip:706-707 就是这么成对清的）")
	_同(层.条数(), 0, "⑦ 清完")
	## ⑧ 点 X：条收掉，但**不发**走路信号（真鼠标点在关闭钮的矩形上）
	收到.clear()
	层.显示(提示条.档交付, 号, 任务名, false, false)
	var 条 := _找条(层, 提示条.档交付)
	await _点钮((条.get_node("关闭") as TextureButton).get_global_rect().get_center())
	_同(层.条数(), 0, "⑧ 点 X 条收掉")
	_同(收到, [], "⑧ 点 X **不走路**（onCloseBtnClick 只派发 CLOSE_PANE）")
	await process_frame
	层.free()


## ── 真点击腿：鼠标事件走完整命中链，证明那枚钮在那个矩形上真点得着 ─────────
func _真点击腿(S) -> void:
	var 层: Control = S.new()
	root.add_child(层)
	层.确定点击.connect(func(类: int, 编: int) -> void: 收到.append([类, 编]))
	收到.clear()
	层.显示(提示条.档交付, 号, 任务名, false, false)
	var 条 := _找条(层, 提示条.档交付)
	_记(条 != null, "真点击：先摆出一条")
	if 条 == null:
		层.free()
		return
	await _点钮((条.get_node("确定") as Button).get_global_rect().get_center())
	_同(收到, [[提示条.档交付, 号]], "真点击：鼠标点在钮矩形中心 ⇒ 走路信号发出来")
	_同(层.条数(), 0, "真点击：点完条自己收掉")
	## 反面对照：同一处若点在条**外面**（x 再往左 40）不该有任何反应
	层.显示(提示条.档交付, 号, 任务名, false, false)
	条 = _找条(层, 提示条.档交付)
	收到.clear()
	var 外 := (条.get_node("确定") as Button).get_global_rect().get_center() + Vector2(-40.0, 0.0)
	await _点钮(外)
	_同(收到, [], "反向对照：偏 40 像素点空处 ⇒ 什么都不发（证明上一条不是演绿）")
	_同(层.条数(), 1, "反向对照：点空处不收条")
	await process_frame
	层.free()


## ── 接线腿：HUD 两头必须把动作交给提示条，不许自己抄一份走路 ───────────────
func _接线腿() -> void:
	var 文 := _读(HUD路)
	_记(文.contains("const 提示条 := preload(\"res://脚本/界面/提示条面板.gd\")"),
			"HUD 没挂上提示条脚本")
	_记(文.contains("_提示条 = 提示条.new()") and 文.contains("add_child(_提示条)"),
			"HUD 没建提示条层 ⇒ 那块条永远不出现")
	_记(文.contains("_提示条.确定点击.connect(_于提示条确定)"),
			"HUD 没接 确定点击 ⇒ 条出来了但点了没反应")
	var 接上段 := _截段(文, "func _于任务接上", "func ")
	_记(_有码(接上段, "_是环任务(条)"),
			"_于任务接上 丢了环任务守卫（原版 startQuest:270 是 !isLoopQuest() 才弹）")
	_记(接上段.contains("提示条.档接取") and not _有码(接上段, "前往NPC("),
			"_于任务接上 里还自己抄了一份走路 ⇒ 两条路会各走各的（走路只许在 _于提示条确定）")
	_记(not _有码(接上段, "if not _自动交接():"),
			"_于任务接上 还拿「自动交接」当走路总闸 ⇒ 勾上就连条都不弹了（本次改的就是这条）")
	var 交付段 := _截段(文, "func _于任务交付", "func ")
	_记(_有码(交付段, "播任务完成横幅()"), "_于任务交付 没播横幅")
	_记(_有码(交付段, "提示条.档交付"), "_于任务交付 没挂交付档的条")
	_记(not _有码(交付段, "前往NPC("),
			"_于任务交付 还自己走路 ⇒ 勾了开关也会走（原版那一支是等玩家点）")
	var 确定段 := _截段(文, "func _于提示条确定", "func ")
	_记(确定段.contains("任务交付NPC") and 确定段.contains("前往NPC("),
			"_于提示条确定 的交付支没接上「走去交付 NPC」（MessageTipPane2:280-283）")
	_记(确定段.contains("_寻路目标"), "_于提示条确定 的接取支没走 gotoQuestPoint 那份算式")
	var 环段 := _截段(文, "func _是环任务", "func ")
	_记(环段.contains("[\"daily\", \"weekly\", \"banghui\"]"),
			"_是环任务 的词表不是 isLoopQuest 那三类（monthly/loop/huodong/mixin 都不算环）")
	_记(皮肤表.提示条底板 == "res://素材/界面/原版窗口/通用控件/提示条底板.png"
			and ResourceLoader.exists(皮肤表.提示条底板),
			"提示条底板这张皮没进皮肤表或盘上不存在")
	var 皮 := load(皮肤表.提示条底板) as Texture2D
	_记(皮 != null and 皮.get_size() == G_底板原生,
			"提示条底板原生尺寸 != 263×252（符号175 的边界），实得 %s" % ("" if 皮 == null else str(皮.get_size())))
	var 边: Array = 皮肤表.九宫格[皮肤表.提示条底板]
	_同(边, G_底板边距, "皮肤表里那份九宫格边距与 splitter 解出来的不一致")
	_记(float(边[0]) + float(边[1]) <= G_底板原生.x and float(边[2]) + float(边[3]) <= G_底板原生.y,
			"九宫格边距自检：横向/纵向之和超过原生尺寸 = 解错了（那样等于整幅拉伸）")


func _条可见(层: Control, 档: int) -> bool:
	var 条 := _找条(层, 档)
	return 条 != null and 条.visible


## 层的 `_条` 数组就是权威表（{"节点","类型","任务号","块"}），按类型取最后一条。
func _找条(层: Control, 档: int, 序: int = -1) -> Control:
	var 中: Control = null
	for 存 in 层.get("_条") as Array:
		var d: Dictionary = 存 as Dictionary
		if int(d["类型"]) == 档 and (序 < 0 or int(d["任务号"]) == 序):
			中 = d["节点"] as Control
	return 中


func _点钮(位: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	root.push_input(移)
	for _帧 in range(2):
		await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位
	按.global_position = 位
	root.push_input(按)
	for _帧 in range(2):
		await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.button_mask = 0
	放.position = 位
	放.global_position = 位
	root.push_input(放)
	for _帧 in range(4):
		await process_frame


func _读(路: String) -> String:
	var f := FileAccess.open(路, FileAccess.READ)
	if f == null:
		return ""
	var 文 := f.get_as_text()
	f.close()
	return 文


## 段里**只留代码行**再判"含不含"：这几条判据钉的是「这一支不许自己走路」，
## 而注释里正写着"由 `_于提示条确定` 去 `前往NPC(…)`" —— 不剥注释就会假红（本轮实测）。
func _有码(段: String, 串: String) -> bool:
	for 行 in 段.split("
"):
		var 净 := 行.strip_edges()
		if 净.begins_with("##"):
			continue
		if 净.contains(串):
			return true
	return false


func _截段(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > a else 文.substr(a)


func _尾() -> void:
	日志.append("")
	日志.append("汇：共 %d 条，红 %d 条" % [总, 红])
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)
