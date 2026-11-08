extends SceneTree

## 描边数值**从皮肤表读、不写死**：它是规则、不是不变量，规则一改这里就该跟着走
## （原先写死 3，2026-09-27 规则改回 2 之后本条就假红了 —— 见 §3.41.3 那条教训）。
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

## 结印页接入后的六项自检 —— 逐条照
## 素材目录内同页开发文档的第四节。
##
## 为什么单开一条：那一节列的六条全是"**别被宿主脚本改坏**"的观感项
## （描边、熟练度数值字号、按钮宽度、弹窗默认收起），它们**不报错、只在画面上变丑**，
## 一般的回归跑不出来。这条把它们逐项钉死。
##
## 用法：
##   Godot --headless --path . --script res://测试/结印页回归测试.gd

const 页面路径 := "res://场景/界面/窗口/人物/页面/结印页.tscn"
## 宿主那边的 `_刷结印数值` 是 static，直接拿脚本资源调 —— 这条门不让 `功能窗口` 上场，
## 只钉「换印直落 / 同面板补间」这一件（真窗口路径另有 `人物秘术页回归测试`）。
const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
## 说明里给的原值，逐字照抄。
const 熟练度上限 := [600, 1500, 4000, 6500, 9000, 12000,
	15000, 18000, 25000, 36000, 42000, 50000]

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 包 := load(页面路径) as PackedScene
	if 包 == null:
		_失败.append("结印页.tscn 加载不了")
		_收尾()
		return
	var 页 := 包.instantiate() as Control
	root.add_child(页)
	await process_frame

	# ① 12 个「熟练度值数值」的字号 = 皮肤表 `默认字号`。
	# ⚠️ **不再是说明.md 里的 8**（2026-10-17 巡检 #23，用户报「字体偏小、偏暗、不清晰」）：
	#   宋体的内嵌点阵只在 12 命中，8 会退回轮廓 + 灰度抗锯齿 ⇒ 又小又虚又暗；
	#   而原版 `MBar.labelFormat`（`JieYinPanel.as:502-513`）**根本不设 size** ⇒ 吃 Flash 默认 12。
	#   说明.md 那句"8px 小字别被宿主改坏"是**合并方的观感记录，不是原版真值** —— 这里以真值为准。
	#   阈值从皮肤表读、不写死（同本文件开头那条教训）。
	var 字号不对: Array[String] = []
	for i in 12:
		var 标 := _找(页, "提升结印阶数弹窗/印%d阶段/熟练度进度条/熟练度值数值" % (i + 1)) as Label
		if 标 == null:
			continue
		var 号: Variant = 标.get("theme_override_font_sizes/font_size")
		if 号 == null or int(号) != int(皮肤表.默认字号):
			字号不对.append("印%d=%s" % [i + 1, 号])
	_检(字号不对.is_empty(), "① 12 个「熟练度值数值」应都是 %spx，异常：%s" % [皮肤表.默认字号, 字号不对])

	# ② 所有文字仍有黑色描边（outline_size = 3）
	var 无描边: Array[String] = []
	var 有描边数 := 0
	for 子 in 页.find_children("*", "Label", true, false):
		var 标 := 子 as Label
		var 宽: Variant = 标.get("theme_override_constants/outline_size")
		var 色: Variant = 标.get("theme_override_colors/font_outline_color")
		if 宽 != null and int(宽) == 皮肤表.文字规则_描边数值 and 色 != null:
			有描边数 += 1
		elif 宽 != null or 色 != null:
			无描边.append("%s(宽=%s 色=%s)" % [标.name, 宽, 色])
	_检(有描边数 >= 41, "② 带黑色描边的 Label 应 >=41（说明里给的是 41），实际 %d" % 有描边数)
	_检(无描边.is_empty(), "② 有不完整的描边设置：%s" % [无描边])

	# ③ 四个按钮的宽度没被统一成 57
	var 被统一: Array[String] = []
	for 对 in [["提升结印", "."], ["开始提升按钮", "提升结印阶数弹窗"],
			["自动提升按钮", "提升结印阶数弹窗"]]:
		var 路 := String(对[0]) if String(对[1]) == "." else "%s/%s" % [对[1], 对[0]]
		var 钮 := _找(页, 路) as Button
		if 钮 == null:
			continue
		if is_equal_approx(钮.custom_minimum_size.x, 57.0):
			被统一.append(String(对[0]))
	_检(被统一.is_empty(), "③ 这些按钮被统一成 57 宽了：%s" % [被统一])

	# ④ 关闭按钮仍是 25x24
	var 关 := _找(页, "提升结印阶数弹窗/关闭按钮") as Control
	if 关 == null:
		_失败.append("④ 找不到 提升结印阶数弹窗/关闭按钮")
	else:
		var 尺 := 关.custom_minimum_size
		var 实 := 尺 if 尺 != Vector2.ZERO else 关.size
		_检(absf(实.x - 25.0) < 1.5 and absf(实.y - 24.0) < 1.5,
			"④ 关闭按钮应是 25x24，实际 %s（custom_minimum_size=%s size=%s）" % [实, 尺, 关.size])

	# ⑤ 12 个熟练度上限文本
	var 值不对: Array[String] = []
	for i in 12:
		var 标 := _找(页, "提升结印阶数弹窗/印%d阶段/熟练度进度条/熟练度值数值" % (i + 1)) as Label
		if 标 == null:
			continue
		var 期望 := str(熟练度上限[i])
		if not 标.text.contains(期望):
			值不对.append("印%d 期望含 %s 实为「%s」" % [i + 1, 期望, 标.text])
	_检(值不对.is_empty(), "⑤ 12 个熟练度上限对不上：%s" % [值不对])

	# ⑥ 弹窗默认收起
	var 弹 := _找(页, "提升结印阶数弹窗") as Control
	if 弹 == null:
		_失败.append("⑥ 找不到 提升结印阶数弹窗")
	else:
		_检(not 弹.visible, "⑥ 弹窗应默认收起（visible=false），实际 visible=%s" % 弹.visible)

	# ⑦ 场景自带的 [connection] 还在（提升结印 → open_popup、关闭按钮 → 滑出）
	#    —— 这两条是**他在场景里写好的**，宿主重写初始化时最容易被顺手覆盖掉。
	var 有开 := false
	var 有关 := false
	for 连 in (_找(页, "提升结印") as Button).pressed.get_connections():
		有开 = true
	if 弹 != null:
		var 关钮 := _找(页, "提升结印阶数弹窗/关闭按钮") as Button
		if 关钮 != null:
			for 连 in 关钮.pressed.get_connections():
				有关 = true
	_检(有开, "⑦ 「提升结印」应接着 open_popup（场景里的 [connection]）")
	_检(有关, "⑦ 「关闭按钮」应接着 _on_close_button_pressed（场景里的 [connection]）")

	# ⑧ 指针：指向阶段 = (阶段-1)*30 + 90
	#    原版 `JieYinPanel.as:460` `zhizhen.rotation = (param1-1)*30 + 90`，
	#    由服务端推的结印 buff 触发；**不是跟现实时钟**（他脚本原来那样）。
	var 针 := _找(页, "结印阵/时间指针/结印指针")
	if 针 == null:
		_失败.append("⑧ 找不到 结印阵/时间指针/结印指针")
	elif not 针.has_method("指向阶段"):
		_失败.append("⑧ 结印指针没有 `指向阶段()`（是不是又被改回跟时钟了）")
	else:
		# ⚠️ 无头下帧间隔极小，平滑 lerp 几百帧都转不到位 —— 测试里关掉平滑看**目标角度**。
		针.set("平滑跟随", false)
		for 阶 in [1, 5, 12]:
			针.call("指向阶段", 阶)
			for _i in 3:
				await process_frame
			var 期 := fposmod(float(阶 - 1) * 30.0 + 90.0, 360.0)
			var 实 := fposmod(针.rotation_degrees, 360.0)
			var 差 := absf(实 - 期)
			差 = minf(差, 360.0 - 差)
			_检(差 < 1.0, "⑧ 阶段 %d 指针应转 %.0f°，实际 %.1f°" % [阶, 期, 实])

	# ⑨ 弹窗里的「熟练度」真的画在当前阶上（2026-10-11 修：原脚本查的是写轮眼页的
	#    `$祝福值进度条`，本页没有 ⇒ 刷新熟练度() 一直空转、还吐 Node not found）
	if 弹 != null and 弹.has_method("刷新熟练度"):
		弹.call("刷新熟练度", 7, 123)
		## 熟练度那根接了 `进度条补间` 的 0.5 秒补间（§3.243，`JieYinTiShengWindow.as:35` 的
		## `_shulianBar` 是 MBarExpF）⇒ 等的是**墙上时钟**，"等 2 帧"在无头里短到微秒、必然假红。
		await create_timer(0.7).timeout
		var 阶7 := _找(页, "提升结印阶数弹窗/印7阶段") as Control
		var 阶1 := _找(页, "提升结印阶数弹窗/印1阶段") as Control
		_检(阶7 != null and 阶7.visible, "⑨ 刷新熟练度(7,…) 后应只亮 印7阶段")
		_检(阶1 != null and not 阶1.visible, "⑨ 刷新熟练度(7,…) 后 印1阶段 应藏起来")
		var 条 := _找(页, "提升结印阶数弹窗/印7阶段/熟练度进度条") as ProgressBar
		_检(条 != null and int(条.max_value) == 15000 and int(条.value) == 123,
			"⑨ 印7阶段进度条应是 123/15000，实际 %s/%s" % [条.value if 条 != null else "无", 条.max_value if 条 != null else "无"])
		var 值标 := _找(页, "提升结印阶数弹窗/印7阶段/熟练度进度条/熟练度值数值") as Label
		_检(值标 != null and 值标.text == "123/15000",
			"⑨ 印7阶段数值文本应是 123/15000，实际「%s」" % [值标.text if 值标 != null else "无"])
	else:
		_失败.append("⑨ 提升结印阶数弹窗 没有 `刷新熟练度()`")

	# ⑪ 切到别的印的数值面板 ⇒ 四根条**当帧就是真值**，不许从 0 扫过去
	#    （用户 2026-11-01 报修：「切换后，数值轴是多少数值就是多少数值，不要变化一次」）。
	#    原版四根是常驻 MBar（`JieYinPanel.as:156-168 createBar`），换选中阶只是
	#    给同一根条 `setData`；本工程按印拆成各自一套条（`结印页.tscn` 12 个 `数值容器`），
	#    换印 = 换一根从没写过的条（烘的值是 0）。
	#    期望值 = 数据的 `JieYin.stages.stage<阶>.attrs` 上限（达成 5000 已超上限 ⇒ 夹满）：
	#    印2 生命 1350 / 印3 1650 / 印5 3000。
	人物窗口脚本._刷结印数值(页, 7, 12, 7)
	for 对 in [[2, 1350], [3, 1650], [5, 3000]]:
		var 印号 := int(对[0])
		var 期望值 := float(对[1])
		人物窗口脚本._刷结印数值(页, 7, 12, 印号)
		var 条 := _找(页, "印式按钮/印%d/数值容器/生命" % 印号) as ProgressBar
		if 条 == null:
			_失败.append("⑪ 找不到 印%d 的生命条" % 印号)
			continue
		_检(absf(条.value - 期望值) < 0.5 and absf(条.max_value - 期望值) < 0.5,
			"⑪ 切到印%d 面板当帧就该是 %d/%d，实际 %.1f/%.0f"
				% [印号, int(期望值), int(期望值), 条.value, 条.max_value])
		_检(not 条.has_meta("tweenBar"), "⑪ 切到印%d 面板不该起补间（会从 0 扫过去）" % 印号)

	# ⑫ 同一个面板里数值真的变了 ⇒ 仍是 0.5s 补间（当前值 → 新值，不是 0 → 新值）
	#    `结印插值(7, 进度, maxhp)`：进度 0 ⇒ 5000、进度 15000 ⇒ 5300（stage6/7 的 maxhp）。
	人物窗口脚本._刷结印数值(页, 7, 0, 7)
	var 条7 := _找(页, "印式按钮/印7/数值容器/生命") as ProgressBar
	if 条7 == null:
		_失败.append("⑫ 找不到 印7 的生命条")
	else:
		人物窗口脚本._刷结印数值(页, 7, 15000, 7)
		_检(absf(条7.value - 5000.0) < 1.0, "⑫ 数值变化当帧应从当前值 5000 起补间，实际 %.1f" % 条7.value)
		await create_timer(0.7).timeout
		_检(absf(条7.value - 5300.0) < 1.0, "⑫ 0.5s 后应到 5300，实际 %.1f" % 条7.value)

	# ⑬ 指针：`指向阶段()` **当帧到位**（原版 `JieYinPanel.as:455-461` 直接赋值、没有补间）。
	#    本页每次回帧整页重建 ⇒ `_ready()` 先把指针摆回印1，若这里只设目标角度、靠 `_process`
	#    懒追赶，表现就是「提升一次，指针从 0 扫到当前位置」（用户 2026-11-01 报修）。
	#    ⚠️ 故意把 `平滑跟随` 打开：到位与否不许取决于那个开关。
	if 针 != null:
		针.set("平滑跟随", true)
		针.call("指向阶段", 5)
		var 期望13 := fposmod(4.0 * 30.0 + 90.0, 360.0)
		var 实13 := fposmod(针.rotation_degrees, 360.0)
		var 差13 := absf(实13 - 期望13)
		差13 = minf(差13, 360.0 - 差13)
		_检(差13 < 1.0, "⑬ 指向阶段(5) 当帧就应到 %.0f°，实际 %.1f°" % [期望13, 实13])

	_收尾()


func _找(页: Node, 路: String) -> Node:
	return 页.get_node_or_null(路)


func _检(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)


func _收尾() -> void:
	if _失败.is_empty():
		print("结印页回归测试：通过（说明里的六条自检 + ⑪换印直落 / ⑫同面板补间 / ⑬指针当帧到位 全过）")
		quit(0)
		return
	for 项 in _失败:
		push_error("结印页回归测试：失败 - %s" % 项)
	quit(1)
