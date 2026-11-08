extends SceneTree

## 「意志格三件套 + 吞噬链路」门（2026-10-23 §3.186）——用户当天第四次实机报四件事：
##   ① 「意志吞噬的弹窗的位置是错误的，你参考一下单机版是怎么写的」；
##   ② 「身上的意志无法吞噬背包中的意志，修一下」；
##   ③ 「意志光有等级是不对的，你看一下单机版是怎么写的，照着做」；
##   ④ （钮皮繁体 ⇒ 单独素材补丁，`开发工具/重绘意志钮皮为简体.py`，门不判位图）。
##
## 真值（AS3 字面）：
##   ③ `YiZhiCell.drawYiZhi:195-208`：每格 = 图标(RotateComponent x=y=4) + **名称**
##      （`createChildren:113-119` 宽 64、y=32、居中、色=textColor）+ **等级**
##      （`:120-126` 宽 64、y=46、居中、`"Lv."+level`）。工程旧实现只挂图标+等级。
##   ② `YiZhiCell.upHandler:237-250`：落点有货 ⇒ `rongHeYiZhi(落点那件, 拖来那件)`，
##      **不分来源是背包还是穿戴位**。工程旧 `_格上那件` 只查 `spirit_bag`（`slot>=0`）
##      ⇒ 穿戴位（负数）取不到行 ⇒ 身上↔背包的融合整条断。
##   ① `FamillyPopUpWindow.popUpWindow` / `MDialog.showMessageDialog(stage)` = **stage 居中**。
##      工程旧写法把**当前页面**当遮罩传给 `输入确认弹.弹消息` ⇒ 弹窗在页面矩形内居中、
##      随页面飘（截图里飘在两窗之间）。正确遮罩 = 窗壳全屏 overlay（`_overlay`，
##      `_resize_overlay:1081-1083` 撑到视口全屏）。
##
## 本门（全离线、不连后端）：起真功能窗口开「遗址」页 → 往会话灌三件意志（两背包一穿戴）
## → 重渲 ⇒ ① 三件套逐件钉（图标/名称/等级 + 居中 + textColor + Lv. 前缀）；
## ② 直接调 `_处理意志拖放` 跑两条融合链（穿戴→背包、背包→穿戴）⇒ 弹窗必须挂在
## **overlay** 下且**主体 stage 居中**、正文主副名定对（同色比 level，级高的当主）；
## ③ 点「确定」不炸（离线 `spirit_feed` 返回 false，静默即可）。
## 对旧代码确定性红：旧 `_格上那件` ⇒ 来源行空 ⇒ 融合链断（无弹窗/主副错）；
## 旧遮罩 ⇒ 弹窗挂在页面下、position 随页面；旧填充 ⇒ 无 格名称。
##
## 运行：Godot --headless --path . --script res://测试/意志格三件套与吞噬链路回归测试.gd

const 页名 := "遗址"					# 功能窗口分派表 `"遗址": 意志窗口.渲染背包(self)`

var _失败: Array[String] = []
var _受检 := 0


func _initialize() -> void:
	call_deferred("_跑")


func _查(过: bool, 话: String) -> void:
	_受检 += 1
	if not 过:
		_失败.append(话)


func _印(话: String) -> void:
	print("[意志三件套] " + 话)


func _跑() -> void:
	# 无头视口默认 (64,64)，弹窗居中断言会算出负坐标 ⇒ 钉尺寸（门卫生，同 §3.185 门）
	root.size = Vector2i(960, 560)
	var 窗 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(窗)
	await process_frame
	窗.call("open_page", 页名)
	for _帧 in range(30):
		await process_frame
	var 会话 := root.get_node_or_null("GameSession")
	_查(会话 != null, "树上没有 GameSession 单例")
	if 会话 == null:
		_收尾()
		return
	# —— 灌三件（只改内存，不落存档）——
	#   id 全部取自 `数据/意志图鉴.json`（门同款查表，别写死名字）；
	#   color = SpiritColor int（GRAY1/GREEN2/BLUE3/YELLOW6，`SpiritColor.as:5-24`）。
	会话.set("spirit_bag", [
		{"id": "201", "color": 2, "slot": 1, "exp": 0, "level": 3},	# 凝神 green
		{"id": "301", "color": 3, "slot": 2, "exp": 0, "level": 5},	# 强悍 blue
		{"id": "301", "color": 3, "slot": 0, "exp": 0, "level": 2},	# 升级槽那件（slot 0）
	])
	会话.set("spirit_equipped", [
		{"id": "202", "color": 2, "slot": -1, "exp": 0, "level": 2},	# 憨厚 green（身上）
	])
	# ⚠️ 页面**每次渲染都是新建**的（`功能窗口._instantiate_page:4387`）⇒ 重渲前先清旧页，
	#   否则 `add_child` 撞名 ⇒ Godot 把新页自动改名 @Control@id、_找 拿到旧页（空数据）
	#   ⇒ 断言全假红（§3.185 一键三钮门同款坑）。
	var 页面容器 := _找(窗, "页面容器") as Control
	if 页面容器 != null:
		for 子 in 页面容器.get_children():
			页面容器.remove_child(子)
			子.queue_free()
	var 脚本: Script = load("res://脚本/界面/窗口/意志窗口.gd")
	脚本.call("渲染背包", 窗)
	for _帧 in range(5):
		await process_frame
	var 背包容器 := _找(窗, "背包容器") as Control
	var 穿容器 := _找(窗, "穿戴容器") as Control
	_查(背包容器 != null and 穿容器 != null, "背包容器/穿戴容器 至少缺一个")
	if 背包容器 == null or 穿容器 == null:
		_收尾()
		return

	# ── ③ 三件套：图标 + 名称 + 等级（原版 drawYiZhi 三件，颜色/对齐/前缀逐项） ──
	_验三件套(背包容器, "格_0", "凝神", "Lv.3", Color("#00FF00"))
	_验三件套(穿容器, "格_1", "憨厚", "Lv.2", Color("#00FF00"))
	# 空格不许残留三件套（旧件要 free 掉——`_填一格层` 的 find_children 清理）
	for 旧 in (背包容器.get_node_or_null("格_5") as Control).find_children(
			"格名称|格等级|格图标", "*", true, false):
		_查(false, "空格 背包格_5 上还挂着 %s（_填一格层 没清旧件）" % 旧.name)

	# ── ②① 融合链 A：身上（穿戴 -1）吞背包（slot 1）—— 用户报的场景 ──
	var 弹A := _跑融合(脚本, 穿容器.get_node_or_null("格_1"), 背包容器.get_node_or_null("格_0"))
	_查(弹A != null, "穿戴→背包 融合没有弹确认框（_格上那件 分表修了没？）")
	if 弹A != null:
		_验弹窗居中(弹A)
		var 文 := str((弹A.get_node_or_null("主体/正文") as RichTextLabel).text)
		# 同色(green)比 level：目标 lv3 > 来源 lv2 ⇒ **目标（凝神）当主**、来源（憨厚）当副
		_查(文.contains("凝神") and 文.contains("憨厚"),
				"融合正文主副名不对（应含 凝神 与 憨厚，实测：%s）" % 文)
		_查(文.find("凝神") < 文.find("憨厚"),
				"主副定反了（同色比 level，级高的当主 ⇒ 凝神 应在 憨厚 前，实测：%s）" % 文)
		_点确定(弹A)
	# ── 融合链 B：背包（slot 2, blue lv5）吞身上（-1）—— 反方向也要通 ──
	var 弹B := _跑融合(脚本, 背包容器.get_node_or_null("格_1"), 穿容器.get_node_or_null("格_1"))
	_查(弹B != null, "背包→穿戴 融合没有弹确认框（落点行也走分表）")
	if 弹B != null:
		_验弹窗居中(弹B)
		_点确定(弹B)

	# ── ④ 自动升级 UI 链（升级槽货 → 锁定勾选 → 钮 enabled/文案/点跑点停）──
	#    原版 `YiZhiPackWindow`：槽里有货才准勾（`onLockCheckBoxClick:639-660`），
	#    勾了才亮钮（`refreshAutoBtn`），钮 = 跑着就停 / 没跑就起（`onAutoUpgradeBtnClick:662-677`）。
	#    离线时循环喂发不出请求（`spirit_feed` 返回 false）⇒ 只验 UI 三态，不真等循环。
	var 页 := 页面容器.get_child(页面容器.get_child_count() - 1) as Control
	var 升级格 := _找(页, "升级格") as Control
	_查(升级格 != null, "页里没有 升级格")
	if 升级格 != null:
		var 槽名 := 升级格.get_node_or_null("名称") as Label
		var 槽级 := 升级格.get_node_or_null("等级") as Label
		_查(槽名 != null and 槽名.text == "强悍", "升级格没显示槽里那件的名称（实测 %s）" % [
			str(槽名.text) if 槽名 != null else "无"])
		_查(槽级 != null and 槽级.text == "Lv.2", "升级格等级文本不对（实测 %s）" % [
			str(槽级.text) if 槽级 != null else "无"])
		# ⚠️ 2026-10-24 §3.190（用户实机报「升级过后意志无法从升级框取出」）：
		#   原版升级格也是 `YiZhiCell`（`position=0`），`downHandler:93-99` 有货即起拖
		#   ⇒ 升级格**能当拖出源**。旧实现 `_接拖放(槽, …, false)` + `_处理意志拖放`
		#   `源槽==0` 直接 return ⇒ 升级槽里的意志永远拖不出。钉「可拖拽 + 拖出链路通」。
		_查(bool(升级格.get("可拖拽")) == true,
				"升级格必须可拖出（原版 downHandler 有货即起拖）——旧实现 false = 用户报的取不出")
		# 升级格 → 背包空格：应走 move 链（不弹融合确认、不吐掉）。
		#  目标格_5 是空格（灌数据只占了 slot 1/2/0），离线 spirit_move 返回 false 静默。
		var 目标空格 := 背包容器.get_node_or_null("格_5") as Control
		if 目标空格 != null:
			脚本.call("_处理意志拖放", 升级格, 目标空格, "", 0)
			for _帧 in range(2):
				await process_frame
			# 目标空格没货 ⇒ 不该弹融合确认框（弹了说明误判成融合）
			var 误弹 := false
			var 遮罩 := _找(窗, "遮罩") as Control
			if 遮罩 != null:
				for 子 in 遮罩.get_children():
					if String(子.name) == "消息确认框":
						误弹 = true
			_查(not 误弹, "升级格拖到背包空格不该弹融合确认框（目标是空，应走 move 链）")
	var 勾 := _找(页, "锁定勾选") as CheckBox
	var 钮 := _找(页, "自动升级钮") as BaseButton
	if 勾 != null and 钮 != null:
		# 原版口径（`onLockCheckBoxClick:639-660` + `refreshAutoBtn`）：**勾是前提**——
		# 槽里有货但没勾锁定 ⇒ 钮灰；勾上才亮。别猜反。
		_查(钮.disabled, "槽里有货但没勾锁定时钮该是灰的（原版 refreshAutoBtn 要求先勾）")
		勾.button_pressed = true
		勾.toggled.emit(true)
		for _帧 in range(2):
			await process_frame
		_查(not 钮.disabled, "勾上锁定后自动升级钮该亮")
		var 字 := 钮.get_node_or_null("字") as Label
		_查(字 != null and 字.text == "自动升级意志", "钮字初始文案不对（实测 %s）" % [
			str(字.text) if 字 != null else "无"])
		钮.pressed.emit()
		for _帧 in range(2):
			await process_frame
		var 跑着 := bool(会话.get("自动升级跑着")) if 会话 != null else false
		_查(跑着, "点自动升级钮没跑起来")
		if 跑着:
			# ⚠️ 起点会触发整页重渲（`_点自动升级` → `_refresh_current`）⇒ 钮/字都被
			#    重建，必须重新拿（旧引用是「previously freed」）。
			页 = 页面容器.get_child(页面容器.get_child_count() - 1) as Control
			钮 = _找(页, "自动升级钮") as BaseButton
			字 = 钮.get_node_or_null("字") as Label if 钮 != null else null
			_查(钮 != null and 字 != null and 字.text == "停止自动融合",
					"跑起来后钮字该换成「停止自动融合」（实测 %s）" % [
						str(字.text) if 字 != null else "无"])
			# ⚠️ §3.191（用户实机报「锁定意志在自动升级开始后就没有被勾选了，钮也变灰」）：
			#    自动升级每跳触发重渲 ⇒ 页面重建会把勾选框打回未勾 ⇒ 钮 disabled。
			#    钉「重渲后勾仍勾上 + 钮 enabled」——勾选态必须跨重渲持续（会话记 +
			#    `set_pressed_no_signal` 回填）。
			var 重渲勾 := _找(页, "锁定勾选") as CheckBox
			_查(重渲勾 != null and bool(重渲勾.button_pressed),
					"重渲后锁定勾选该保持勾上（用户报：开始升级后勾没了）")
			_查(钮 != null and not 钮.disabled, "重渲后自动升级钮该保持亮（勾在 ⇒ 钮在）")
			# §3.191 第一刀：升级格的图标 z 序——图标必须插在名称/等级**之前**
			# （场景子序 格底/悬停/名称/等级，add_child 追加到最顶层会盖住文字，
			# 用户看到「意志的信息跳在模型后面」）。
			var 升级格2 := _找(页, "升级格") as Control
			if 升级格2 != null:
				var 图标 := 升级格2.get_node_or_null("格图标") as Node
				var 名节点 := 升级格2.get_node_or_null("名称") as Node
				_查(图标 != null and 名节点 != null
						and 升级格2.get_children().find(图标) < 升级格2.get_children().find(名节点),
						"升级格图标该画在名称/等级**下层**（图标 index 应小于名称 index）")
			if 钮 != null:
				钮.pressed.emit()		# 再点一次 = 停
				for _帧 in range(2):
					await process_frame
				_查(not bool(会话.get("自动升级跑着")), "再点一次没停下来")
	_收尾()


## 直接驱动 `_处理意志拖放`（static）跑一条融合链，返回弹窗遮罩层（没弹 = null）。
func _跑融合(脚本: Script, 来源: Control, 目标: Control) -> Control:
	if 来源 == null or 目标 == null:
		return null
	脚本.call("_处理意志拖放", 来源, 目标, "", 0)
	var 窗 := root.get_children().back() as Node
	var 遮罩 := _找(窗, "遮罩") as Control
	if 遮罩 == null:
		return null
	for 子 in 遮罩.get_children():
		if String(子.name) == "消息确认框":
			return 子 as Control
	return null


## 弹窗必须 stage 居中：遮罩 = 全屏 overlay，主体 position = (视口宽-302)/2, (高-弹窗高)/2 向下取整。
## ⚠️ 弹窗高**不能写死 87**：融合正文 `YIZHI_RONGHE_TIP` 自带一个 `<br>`（两行），
##    `弹消息` 自 10-17 起按真实折行算 `文本高 = 15×行数 + 8`（`setMessage:411`）⇒
##    两行是 14+38+50 = 102。这里按正文实际行数算期望，赌的是"相对遮罩居中 + 高度公式"，
##    不是某一句话恰好占几行；遮罩本身必须是全屏 overlay（页面当遮罩就会只在页面内居中）。
func _验弹窗居中(遮罩层: Control) -> void:
	var 主体 := 遮罩层.get_node_or_null("主体") as Control
	_查(主体 != null, "弹窗里没有 主体")
	if 主体 == null:
		return
	var 正文 := 遮罩层.get_node_or_null("主体/正文") as RichTextLabel
	var 行数 := 1 if 正文 == null else maxi(1, 正文.get_parsed_text().count("\n") + 1)
	var 望高 := 14.0 + (15.0 * float(行数) + 8.0) + 50.0		# 正文 y14 + 文本高 + 底高 50
	var 望x := floorf((遮罩层.size.x - 302.0) * 0.5)
	var 望y := floorf((遮罩层.size.y - 望高) * 0.5)
	_查(int(遮罩层.size.x) == int(root.size.x) and int(遮罩层.size.y) == int(root.size.y),
			"确认框遮罩不是全屏 overlay（实测 %s，视口 %s）——又拿页面当遮罩了"
			% [遮罩层.size, root.size])
	_查(int(主体.size.y) == int(望高),
			"确认框高应为 %d（正文 %d 行：14+15×%d+8+50），实为 %d"
			% [int(望高), 行数, 行数, int(主体.size.y)])
	_查(absf(主体.position.x - 望x) < 0.5 and absf(主体.position.y - 望y) < 0.5,
			"弹窗不在舞台中心（stage 居中才对，实测 %s，期望 (%.0f,%.0f)）——遮罩传错了？"
			% [主体.position, 望x, 望y])
	var 遮罩名 := str(遮罩层.get_parent().name)
	_查(遮罩名 == "遮罩", "弹窗挂在 %s 下而不是全屏遮罩（页面内居中就会随页面飘）" % 遮罩名)


func _点确定(遮罩层: Control) -> void:
	var 钮 := 遮罩层.get_node_or_null("主体/确定") as Button
	if 钮 == null:
		_查(false, "弹窗里没有 确定 钮")
		return
	钮.pressed.emit()		# 回调：收窗 + `spirit_feed`（离线返回 false，静默即可）


## 三件套逐件钉：图标 texture 非空；名称/等级 Label 在、文本对、居中、吃 textColor。
func _验三件套(容器: Control, 格名: String, 望名: String, 望级: String, 望色: Color) -> void:
	var 格 := 容器.get_node_or_null(格名) as Control
	_查(格 != null, "%s/%s 不在场景里" % [容器.name, 格名])
	if 格 == null:
		return
	var 图 := 格.get_node_or_null("格图标") as TextureRect
	_查(图 != null and 图.texture != null, "%s 没有图标 texture" % 格名)
	var 名 := 格.get_node_or_null("格名称") as Label
	_查(名 != null, "%s 没有 格名称 Label（原版 drawYiZhi 三件套：图标+名称+等级）" % 格名)
	if 名 != null:
		_查(名.text == 望名, "%s 名称文本 = %s（期望 %s）" % [格名, 名.text, 望名])
		_查(名.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
				"%s 名称不居中（原版 align=center）" % 格名)
		_查(名.get_theme_color("font_color") == 望色,
				"%s 名称颜色不对（应吃图鉴 textColor %s，实测 %s）"
				% [格名, str(望色), str(名.get_theme_color("font_color"))])
	var 级 := 格.get_node_or_null("格等级") as Label
	_查(级 != null, "%s 没有 格等级 Label" % 格名)
	if 级 != null:
		_查(级.text == 望级, "%s 等级文本 = %s（期望 %s，Lv. 前缀 + 居中）" % [格名, 级.text, 望级])
		_查(级.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
				"%s 等级不居中（原版 align=center，旧实现是右对齐）" % 格名)


func _收尾() -> void:
	if _失败.is_empty():
		print("意志格三件套与吞噬链路：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 条 in _失败:
		printerr("意志格三件套与吞噬链路：" + 条)
	quit(1)


func _找(n: Node, 名: String) -> Node:
	if n == null:
		return null
	if String(n.name) == 名:
		return n
	for c in n.get_children():
		var 果 := _找(c, 名)
		if 果 != null:
			return 果
	return null
