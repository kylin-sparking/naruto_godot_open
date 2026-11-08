extends SceneTree
## 师徒申请窗（原版 `AgreestToturWindow`）离线门（#225，2026-10-17）。
## 逐件参照值 = `真值/窗口/师徒推荐窗.md` §④（AS3 行号都在那），**门里自己按算式重算一遍**，
## 不从被测场景反查（照抄被测代码自造的数 = 两边一起错、互相印证，10-16 那种假绿不再犯）。
##
## 覆盖九段：① 排版公式（`dolayout():120-126` 三级递推）② 两档文案与 `%1` 的位置
## ③ BBCode 里 `[u]` 只裹名字（原版 `<a>` 也只裹 `%1`）④ 场景烘的皮与九宫格边距
## ⑤ 开窗的是**服务端那一帧**（喂 `77:4`/`77:5` 原文，不是我自己调开窗）
## ⑥ 运行期逐件矩形 == 门算的那份 ⑦ 两颗钮各发哪一发（档 1 = 7/5、档 2 = 8/6）
## ⑧ 名字那一段点了发 `94:0`（⚠ 不是 94:4 —— 4 只换顶栏血蓝、不开窗）
## ⑨ 一扇轮流：开着时来第二封 ⇒ 排队，关掉才放下一封（原版同屏多扇，这是登记过的偏离）。
##
## 跑法：`"godot" --path . --headless --script res://测试/师徒申请窗回归测试.gd`
## ⚠ "点得到"不归本门 —— 无头拿不到视口命中，那一腿在**有头**量具 `开发工具/验头像信息钮.gd` 里真鼠标跑。

const 场景路径 := "res://场景/界面/窗口/师徒/师徒申请窗.tscn"
const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 窗脚本 := preload("res://脚本/界面/窗口/师徒/师徒申请窗.gd")
const 假后端脚本 := preload("res://测试/测试后端连接.gd")

## —— 门自己的真值（`AgreestToturWindow.as` + `UIConfig.as:964`，不读被测常量表）——
const 边 := 6.0			# `:95-96` `_bg2.x = _bg2.y = 6`
const 黄高 := 80.0		# `:97-98`
const 窗高 := 128.0		# `:91` `background.height`（`dolayout` 不改高）
const 文高 := 20.0		# `:101` `_tf.height = 20`
const 钮宽 := 37.0		# `UIConfig.as:964 btn_width_two`
const 钮高 := 22.0
const 文补 := 6.0			# `:120` `_tf.width = textWidth + 6`
const 底补 := 20.0		# `:121` `_bg2.width = _tf.width + 20`
const 窗补 := 20.0		# `:122` `background.width = _bg2.width + 20`
const 钮下 := 5.0			# `:126` `y = _bg2.y + _bg2.height + 5`

var 通过 := 0
var 失败 := 0
var 跑完了 := false


func _initialize() -> void:
	call_deferred("_跑")


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
		print("  √ " + 话)
	else:
		失败 += 1
		printerr("  !! " + 话)


func _近(实得: Array, 期望: Array, 限 := 0.51) -> bool:
	if 实得.size() != 期望.size():
		return false
	for i in 期望.size():
		if absf(float(实得[i]) - float(期望[i])) > 限:
			return false
	return true


func _盒(件: Control) -> Array:
	return [件.position.x, 件.position.y, 件.size.x, 件.size.y]


## 门自己按 AS3 算式算一遍（`量` = 正文的像素宽，不含 `+6`）。
func _期望(量: float) -> Dictionary:
	var 文宽 := 量 + 文补
	var 黄宽 := 文宽 + 底补
	var 窗宽 := 黄宽 + 窗补
	var 格 := (黄宽 - 2.0 * 钮宽) / 3.0
	return {
		"底": [0.0, 0.0, 窗宽, 窗高],
		"黄底": [边, 边, 黄宽, 黄高],
		"文": [边 + (黄宽 - 文宽) / 2.0, 边 + (黄高 - 文高) / 2.0, 文宽, 文高],
		"确定": [边 + 格, 边 + 黄高 + 钮下, 钮宽, 钮高],
		"取消": [边 + 格 + 钮宽 + 格, 边 + 黄高 + 钮下, 钮宽, 钮高],
	}


func _跑() -> void:
	print("师徒申请窗离线门开始")
	await process_frame
	# ① 排版公式：四档宽度（含小数与超长名）逐件对
	for 量 in [100.0, 263.0, 400.0, 12.5]:
		var 算 := 窗脚本.排版(量)
		var 望 := _期望(量)
		var 全对 := true
		for 键 in 望:
			var 实: Rect2 = 算[键]
			if not _近([实.position.x, 实.position.y, 实.size.x, 实.size.y], 望[键]):
				全对 = false
				printerr("     件 %s 量=%s 期望 %s 实得 [%s, %s, %s, %s]" % [
						键, 量, 望[键], 实.position.x, 实.position.y, 实.size.x, 实.size.y])
		_判(全对, "排版公式：量宽 %s ⇒ 五件矩形逐级递推一致（窗宽 = 量宽+46 = %s）" % [量, 望["底"][2]])

	# ②③ 两档文案 + 只有名字可点
	_判(窗脚本.正文(1, "张三") == "张三想拜你为师，是否同意？",
			"档 1 正文 = 「张三想拜你为师，是否同意？」（实得「%s」）" % 窗脚本.正文(1, "张三"))
	_判(窗脚本.正文(2, "张三") == "张三想收你为徒，是否同意？",
			"档 2 正文 = 「张三想收你为徒，是否同意？」（实得「%s」）" % 窗脚本.正文(2, "张三"))
	var 串 := 窗脚本.富文本(1, 1001, "张三")
	_判(串.contains("[url=1|1001][u]张三[/u][/url]"),
			"BBCode：`[u]` 与 `[url]` 只裹名字那一段（链接带 `档|号`），实得「%s」" % 串)
	_判(串.ends_with("想拜你为师，是否同意？[/color][/color]"),
			"BBCode：名字后面那句是白字、且整串收在两层 color 里（实得尾巴「%s」" % 串.right(30))

	# ④ 场景烘的皮与九宫格边距（运行期读回，不查 .tscn 文本）
	var 窗: Control = (load(场景路径) as PackedScene).instantiate()
	root.add_child(窗)
	await process_frame
	var 底 := 窗.get_node("底") as NinePatchRect
	var 黄 := 窗.get_node("黄底") as NinePatchRect
	_判(底 != null and 黄 != null, "两块底都在（底 = MDilog_bgSkin、黄底 = MYellow_background）")
	if 底 != null:
		_判(String(底.texture.resource_path).ends_with("通用控件/对话框底板.png"),
				"底用的就是那张对话框皮（实得「%s」）" % String(底.texture.resource_path).get_file())
		## ⚠ 这里必须读 `patch_margin_*`：Godot 4.7 的 NinePatchRect 只有这一套属性名，
		## 写成 `texture_margin_*`（那是 StyleBoxTexture 的键）会被**静默丢掉** ⇒ 边距恒 0、
		## 整幅拉伸。全工程这条踩了 84 处，另单 #254 待点头再改。
		_判(_近([底.patch_margin_left, 底.patch_margin_top, 底.patch_margin_right, 底.patch_margin_bottom],
				[28, 33, 30, 33]),
				"底的九宫格边距 = 28/33/30/33（`DefineScalingGridTag` 184），实得 [%d, %d, %d, %d]" % [
						底.patch_margin_left, 底.patch_margin_top, 底.patch_margin_right, 底.patch_margin_bottom])
	if 黄 != null:
		_判(String(黄.texture.resource_path).ends_with("通用控件/内容面板.png"),
				"黄底 = 内容面板（MYellow_background，`原版皮肤表.gd:29`），实得「%s」" % String(黄.texture.resource_path).get_file())
		_判(_近([黄.patch_margin_left, 黄.patch_margin_top, 黄.patch_margin_right, 黄.patch_margin_bottom],
				[11, 10, 10, 11]),
				"黄底的九宫格边距 = 11/10/10/11（`原版皮肤表.gd:124`），实得 [%d, %d, %d, %d]" % [
						黄.patch_margin_left, 黄.patch_margin_top, 黄.patch_margin_right, 黄.patch_margin_bottom])
	var 确 := 窗.get_node("确定钮") as Button
	var 取 := 窗.get_node("取消钮") as Button
	var 文 := 窗.get_node("文") as RichTextLabel
	_判(确 != null and 取 != null and String(确.text) == "确定" and String(取.text) == "取消",
			"两颗钮文字 = COMMON_OK/COMMON_CANCEL（实得「%s」「%s」）" % [确.text, 取.text])
	_判(确 != null and 确.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"确定钮是手型光标（原版 MButton3 `buttonMode = useHandCursor = true`）")
	_判(确 != null and String(确.get_theme_stylebox("normal").texture.resource_path).ends_with("洗点/确定钮.png"),
			"确定钮的皮 = 洗点那族 37×22 那张（实得「%s」）" % String(确.get_theme_stylebox("normal").texture.resource_path).get_file())
	_判(取 != null and String(取.get_theme_stylebox("normal").texture.resource_path).ends_with("洗点/取消钮.png"),
			"取消钮的皮 = 洗点那张取消钮（实得「%s」）" % String(取.get_theme_stylebox("normal").texture.resource_path).get_file())
	_判(文 != null and not 文.scroll_active and 文.bbcode_enabled
			and 文.get_theme_font_size("normal_font") == 12,
			"正文：RichTextLabel、12 号、bbcode 开、scroll_active 关（开了会多出原版没有的滚动条）")
	root.remove_child(窗)
	窗.queue_free()
	await process_frame

	# ⑤ 开窗 = 服务端那一帧：**真·autoload 后端**收原文，`窗口管理` 那侧自己开
	# （⚠ 别再 new 一枚叫 `BackendConnection` 的：autoload 已经占了这个名，
	#   `add_child` 会被改成 `BackendConnection@2`，而 `窗口管理` 监听的是 autoload 那枚的信号
	#   ⇒ 帧喂进假的那枚，窗永远不开，看着像"消费者没接"。上行才用注入的假后端。）
	var 真: Node = root.get_node("BackendConnection")
	var 后: Node = 假后端脚本.new()
	后.name = "师徒门假后端"
	root.add_child(后)
	await process_frame
	var 管理: Node = (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame
	var 申请 := 管理.get_node("师徒申请层/师徒申请窗") as Control
	_判(申请 != null, "申请窗烘在 窗口管理 的「师徒申请层」里（不靠运行期 new 隐形节点）")
	if 申请 == null:
		_收尾()
		return
	申请.后端覆盖 = 后
	_判(not 申请.visible, "没帧 = 不开窗（开局不该有一扇悬在那儿）")
	真.call("_handle_bridge_text", "77:4:1001:张三")
	for i in 3:
		await process_frame
	_判(申请.visible, "喂进服务端原文 `77:4:1001:张三` ⇒ 窗自己开出来（消费者 = 窗口管理，不是我调开窗）")
	_判(int((申请.call("现在") as Dictionary).get("档", 0)) == 1
			and int((申请.call("现在") as Dictionary).get("号", 0)) == 1001,
			"档 = 1（来拜我）、号 = 1001（实得 %s）" % str(申请.call("现在")))

	# ⑥ 运行期逐件矩形 == 门按公式算的那份（量的宽由门自己量，用**这一扇**自己的字体现量）
	var 字体 := (申请.get_node("文") as RichTextLabel).get_theme_font("normal_font")
	var 量 := ceilf(字体.get_string_size(窗脚本.正文(1, "张三"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	var 望 := _期望(量)
	for 键 in 窗脚本.节点名:
		var 件: Control = 申请.get_node(窗脚本.节点名[键])
		_判(_近(_盒(件), 望[键]), "运行期 %s 矩形 = (%s)，实得 (%s)（正文量得 %s）" % [
				窗脚本.节点名[键], 望[键], _盒(件), 量])
	_判(_近([申请.size.x, 申请.size.y], 望["底"].slice(2, 4)),
			"整扇 = 底那一块的大小（窗宽 = 文字宽 + 46，实得 %s）" % str(申请.size))
	## 名字换成超长的一串 ⇒ 整扇要跟着变宽（写死 302 就会把字切掉，这条就是这么抓的）
	申请.call("填", 1, 1001, "一个很长很长很长很长很长的忍者名字")
	var 量长 := ceilf(字体.get_string_size(窗脚本.正文(1, "一个很长很长很长很长很长的忍者名字"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	_判(absf(申请.size.x - (量长 + 文补 + 底补 + 窗补)) < 0.51,
			"名字变长 ⇒ 窗宽跟着变（量长 %s ⇒ 期望 %s，实得 %s）" % [量长, 量长 + 46.0, 申请.size.x])
	_判(申请.size.y == 窗高, "高**永远** 128（`:91` 钉死、`dolayout` 不动它），实得 %s" % 申请.size.y)

	# ⑦ 两颗钮各发哪一发（分发用 emit；"点得到"在有头量具那一腿）
	申请.call("填", 1, 1001, "张三")
	后.sent_requests.clear()
	(申请.get_node("确定钮") as Button).emit_signal("pressed")
	_判(后.sent_requests.size() == 1 and int(后.sent_requests[0].opcode) == 77
			and String(后.sent_requests[0].content) == "7:1001",
			"档 1 点「确定」⇒ `77:7:1001`（原版 `Tutor_requestAcceptTutor`），实发 %s" % str(后.sent_requests))
	_判(not 申请.visible, "点完确定 ⇒ 这扇自己收掉（原版 `onClickOkBtn` 结尾 `onCloseBtnClick`）")
	申请.call("填", 1, 1001, "张三")
	后.sent_requests.clear()
	(申请.get_node("取消钮") as Button).emit_signal("pressed")
	_判(后.sent_requests.size() == 1 and String(后.sent_requests[0].content) == "5:1001",
			"档 1 点「取消」⇒ `77:5:1001`（拒绝拜师），实发 %s" % str(后.sent_requests))
	申请.call("填", 2, 1002, "李四")
	后.sent_requests.clear()
	(申请.get_node("确定钮") as Button).emit_signal("pressed")
	_判(String(后.sent_requests[0].content) == "8:1002",
			"档 2 点「确定」⇒ `77:8:1002`（同意收徒，别和档 1 混成 7），实发 %s" % str(后.sent_requests))
	申请.call("填", 2, 1002, "李四")
	后.sent_requests.clear()
	(申请.get_node("取消钮") as Button).emit_signal("pressed")
	_判(String(后.sent_requests[0].content) == "6:1002",
			"档 2 点「取消」⇒ `77:6:1002`（拒绝收徒），实发 %s" % str(后.sent_requests))

	## 只有 1/2 两档：原版 `AgreestToturWindow` 的 TYPE 常量就两个值（`TYPE_PRENTICE=1`/`TYPE_TEACHER=2`），
	## 上行 7/8/5/6 也只按这两档分 ⇒ 后端那两个函数必须**拒绝别的档号**。
	## 这条是被自己的变异测出来的（10-17 M7：把 `档 in [1, 2]` 放开成 `[1, 2, 3]`，
	## 原来那 41 条**一条都不会红** —— 因为所有判据只喂 1 和 2 ⇒ 少这一格就等于给"自造第三档"开了后门）。
	后.set("in_game", true)
	后.sent_requests.clear()
	_判(not bool(后.call("request_tutor_accept", 3, 1001)) and 后.sent_requests.is_empty(),
			"档 3（原版没有这一档）点同意 ⇒ 一条都不发，实发 %s" % str(后.sent_requests))
	后.sent_requests.clear()
	_判(not bool(后.call("request_tutor_refuse", 0, 1001)) and 后.sent_requests.is_empty(),
			"档 0 点拒绝 ⇒ 一条都不发，实发 %s" % str(后.sent_requests))

	# ⑧ 名字那一段 = 看对方人物窗：`94:0`，**不是** 94:4
	后.set("in_game", true)
	申请.call("填", 1, 1001, "张三")
	后.sent_requests.clear()
	## ⚠ `meta_clicked` 挂在 **RichTextLabel** 上，不在这扇窗身上 —— 从窗上 emit 会报
	## `Can't emit non-existing signal`，那两条判据就都变成"什么都没发"的空判（第二格就是这么假绿的）。
	(申请.get_node("文") as RichTextLabel).emit_signal("meta_clicked", "1|1001")
	_判(后.sent_requests.size() == 1 and int(后.sent_requests[0].opcode) == 94
			and String(后.sent_requests[0].content) == "0:1001",
			"点名字 ⇒ `94:0:<号>`（`UI.as:674` clickCharacter 就是 requestCharFullInfo；发 4 是选中那发）实发 %s" % str(后.sent_requests))
	后.sent_requests.clear()
	(申请.get_node("文") as RichTextLabel).emit_signal("meta_clicked", "乱码")
	## 原版 `onLink` 只在 `split("|").length > 1` 时才动 ⇒ 形状不对**什么都不发**。
	## 这条之所以不是空判：上一格已经证明"同一个 emit 走得通、会发出一发"。
	_判(后.sent_requests.is_empty(),
			"链接串不是 `档|号` 形状 ⇒ 一条都不发（`AgreestToturWindow.as:42` 那个 length>1 的闸）实发 %s" % str(后.sent_requests))

	# ⑨ 一扇轮流：开着时来第二封 ⇒ 排队；关掉才放下一封
	后.set("in_game", false)
	申请.call("填", 1, 2001, "王五")
	真.call("_handle_bridge_text", "77:5:2002:赵六")
	for i in 3:
		await process_frame
	_判(int((申请.call("现在") as Dictionary).get("号", 0)) == 2001,
			"已经开着的时候来第二封 ⇒ **不换窗**（第一封还在手上，实得 %s）" % str(申请.call("现在")))
	_判(管理.get("_师徒队列").size() == 1,
			"第二封进了排队（实得 %s）" % str(管理.get("_师徒队列")))
	(申请.get_node("取消钮") as Button).emit_signal("pressed")
	for i in 3:
		await process_frame
	_判(bool((申请.call("现在") as Dictionary).get("开着", false))
			and int((申请.call("现在") as Dictionary).get("号", 0)) == 2002
			and int((申请.call("现在") as Dictionary).get("档", 0)) == 2,
			"关掉第一封 ⇒ 排队的第二封自动放上（实得 %s）" % str(申请.call("现在")))
	_判(管理.get("_师徒队列").is_empty(), "放完队列就空了（实得 %s）" % str(管理.get("_师徒队列")))

	_收尾()


func _收尾() -> void:
	跑完了 = true
	print("师徒申请窗离线门：通过 %d，红 %d" % [通过, 失败])
	quit(1 if 失败 > 0 else 0)
