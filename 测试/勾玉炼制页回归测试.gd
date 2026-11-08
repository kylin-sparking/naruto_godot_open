extends SceneTree

## 静音「勾玉炼制」（原版 `equip/YuLianJinJieWindow` 360×407 + 三页签面板）的**行为门**。
##
## 逐件几何不在这里 —— `测试/原版服务窗回归测试.gd` 已经把 66 件逐个比 `勾玉炼制_期望.json`，
## 而且它会**重跑生成器**比对场景（手改 .tscn 立刻红）。这里量的是那一族门看不见的事：
##   ① **切页**：真 `push_input` 点页签 ⇒ 三枚容器的 visible 只有一枚真、
##      选中枚走 `disabled` 槽（= 显示 `selectedUpSkin` tag118、**不灰**、悬停不变亮）、
##      其余枚回 `enabled`；提交钮文字跟着换「开始进阶 / 开始合成 / 开始重置」。
##   ② **投料钮的初始文字逐字**：页0「放入玉链」、页1/页2「放入勾玉」。
##      原版 `GouYuCompositePanel.showView:142` / `GouYuResetPanel.showView:85` 拿错成 `[2]`
##      「取出玉链」—— 2026-11-02 用户明确要求改正（**有意偏离 AS3**）；有料后三页
##      都换「取出勾玉 / 取出玉链」。
##   ③ **材料4 静态灰**：`GouYuCompositePanel.as:259` 在 `createChildren` 里就 `applyGrayFilter()`
##      ⇒ 离线就得看到那一格是灰的（shader 挂在格上、图标与数量一起灰），
##      而 材料1-3 `:256-258` 显式 `applyGrayFilter(false)` ⇒ **不许灰**。
##   ④ **离线不假造**：七枚格子（投料/结果/材料1-3）一颗图标都不许长出来；
##      但 **材料4 那一枚必须有精玉灵珠的图** —— 原版 `showView:140` 拿的是 `Etc.json` 的静态配置
##      （`jade.merge.level2.needItemId = 16000031`），不连服务端也画 ⇒ 少它就是"图标也没有"（用户打回）。
##      同批打回还钉住：分隔线是 `LineHPicF` **那张图**（不是涂色 ColorRect）、`y = 块高 − 2`；
##      两块「本次操作…」是 `verticalAlign = horizontalAlign = true` + `algin="center"` ⇒ 两轴居中。
##   ⑤ **三支各有分工**（2026-10-13 更正）：**提交**走真协议（§3.123，带物品才发）；
##      **投料**走**拖放**（§3.136，落点件 `勾玉放入格.gd`；原版那一支是 `ItemDropBox` 的
##      `UpShelfCursor` 光标收集态，本工程没跟手光标件 ⇒ 用同族拖放。三页各一道闸门）；
##      **购买**走 `功能窗口.请求商城商品`（原版共用材料格 `ItemCaiLiaoBox.buyHandler` 那跳
##      `REQUEST_CASH_ITEM_INFO`，`id = 材料4 = 16000031`）⇒ 本门装假后端钉那一包。
##      ⚠️ 2026-10-13 之前这里写着"投料原版是背包格右键、没有单帧请求"—— **是错的**：
##      三个面板都有 `ItemDropBox` + 投料钮 + `validateItem`。
##   ⑥ **成对摆位**：原版 `UIMain2.as:3848-3866` 走 `centerTwoWindow(这扇, ITEM_WINDOW2_F)`
##      ⇒ 开这扇必须连背包一起开；主窗照原版按自己高度居中，背包（556 高）夹进屏内，
##      顶边因此**不再平齐**（2026-10-31 有意偏离，见 `_量成对`）。
##   ⑦ **编辑器 == 运行期**：场景烘的开屏态（页签0 选中、面板0 可见、提交钮「开始进阶」）
##      与运行期第一帧逐个相同 ⇒ 读 `.tscn` 文本比对，读运行期值等于自证。
##   ⑧ **载荷由真背包格自己 `_get_drag_data`**（2026-10-29 改）：此前每条腿都手搓
##      `{"归属":"背包","物品id":…,"来源格":假格}` —— 那是假绿 #23 那一族：落点拒收
##      "归属没填 / 物品id 空 / 格子 disabled / 没图"的拖，门照样绿。现在先 `背包._render_page()`
##      把这五行真渲染成格子，再让**那一格自己**交载荷，`_can_drop_data` / `_drop_data` 吃的都是运行时真值。
##   ⑨ **每页各一份料**（`YuLianJinJieWindow.as:56-59` 换页先对**离开那页** `backItemToEquip`）：
##      原来三页共用一个 `static var _物品` ⇒ 页1 放勾玉、切回页0 点提交，发的是**勾玉那格的槽位**
##      给 `request_special_stage_up`。这条腿钉"切走即清 + 不串页 + 空料不发帧"，**⑨b 再把同一件事钉到
##      协议面上**：三页各放各的料、各点一次提交，帧文本逐条对（`special:1` / `merge:3` / `change:3`）。
##   ⑩ **悬停详情框**（原版每枚 `SimpleItemCell` 都挂 `MToolTipItem`，`SimpleItemCell.as:220`）：
##      此前这扇窗**一个提示框节点都没建** ⇒ 投进去之后鼠标停在上面什么也不出（用户报的那条）。
##      钉五件事：两套框在页上、三枚投料格+两枚结果格都不是 IGNORE、玉链走**装备**框（标题=那件玉链、
##      **明细里带得上背包真行那条 `plus_attributes`**）、勾玉走**物品**框、结果格弹的是**下一级**那件
##      （「勾玉（2级）」）、空料格悬停两套都收起。
##
## ⚠ 三条硬口径（都是这个工程踩过的）：
##   · `push_input` 前先钉 `root.size`（无头默认视口拿不到 GUI 命中，点了静默不生效）；
##   · 改状态与断言之间隔 3 帧；
##   · 本门不落存档：跑前记 `user://玩家数据.json` 的字节、跑完断言**没变**（真点原生钮
##     会经 `_set_check` 那条链落盘 ⇒ 邻居门次日假红，见记忆《离线门不许写存档》）。
##
## 运行：Godot --headless --path . --script res://测试/勾玉炼制页回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "勾玉炼制"
const 场景路 := "res://场景/界面/窗口/勾玉炼制/勾玉炼制窗.tscn"
const 控制器 := preload("res://脚本/界面/窗口/勾玉炼制窗.gd")

const 黄 := Color(0.988235, 0.956863, 0.611765)		# #FCF49C `MButton3.as:69-74`
const 提交文 := ["开始进阶", "开始合成", "开始重置"]
const 投料文 := ["放入玉链", "放入勾玉", "放入勾玉"]		# 页1/2 = 用户 2026-11-02 要求改正（原版 [2] 串号）
const 面板名 := ["面板0", "面板1", "面板2"]
const 投料钮路 := ["内容底/面板0/投料框0/投料钮0", "内容底/面板1/合成投料框/合成投料钮",
		"内容底/面板2/重置投料框/重置投料钮"]		# 钮在投料框里（与控制器同源，路径写错=点不到）
const 空格子 := ["内容底/面板0/投料框0/投料格0", "内容底/面板0/投料框0/结果格0",
		"内容底/面板1/合成投料框/合成投料格", "内容底/面板1/合成投料框/合成结果格",
		"内容底/面板1/材料盒/材料1/材料1格", "内容底/面板1/材料盒/材料2/材料2格",
		"内容底/面板1/材料盒/材料3/材料3格"]		# ⚠ 材料4格**不在这里**：原版离线就有精玉灵珠图标（见 珠格）
## 精玉灵珠那一格：`GouYuCompositePanel.showView:140-141` 用 `Etc.json EquipSystem.jade.merge.level2`
## 的 `needItemId` 造 itemData ⇒ **不连服务端也画得出**（2026-10-05 用户实机图打回的一条）。
const 珠格 := "内容底/面板1/材料盒/材料4/材料4格"
const 珠编号 := "16000031"
## 三页的落点格 / 结果格（与控制器同源；页2 没有结果格）。
const 投料格路 := ["内容底/面板0/投料框0/投料格0", "内容底/面板1/合成投料框/合成投料格",
		"内容底/面板2/重置投料框/重置投料格"]
const 结果格路 := ["内容底/面板0/投料框0/结果格0", "内容底/面板1/合成投料框/合成结果格", ""]
## 页1 的三枚材料格 = 成功 / 退还 / 剩余（`GouYuCompositePanel.operationResultHandler:61-103`）。
const 材料格路 := ["内容底/面板1/材料盒/材料1/材料1格", "内容底/面板1/材料盒/材料2/材料2格",
		"内容底/面板1/材料盒/材料3/材料3格"]
const 放入格脚本 := preload("res://脚本/界面/组件/勾玉放入格.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
## 背包页面根（`格子容器/物品格_%d` 挂在它下面）—— ⑧ 那批腿要从**真格子**取拖拽载荷。
const 背包页根 := "原版背包内容"
## `EquipLineTextArea.as:31/55-58`：分隔线是 `LineHPicF`(symbol133) **这张图**、`y = 块高 − 2`。
## 每条 = [件路, 它所属块的声明高]（块高从 `.tscn` 里读，不写死数）。
const 分隔线 := ["内容底/面板0/说明盒0/说明条0_1/说明条0_1线", "内容底/面板0/说明盒0/说明条0_2/说明条0_2线",
		"内容底/面板1/合成说明条/合成分隔线",
		"内容底/面板2/重置说明盒/重置说明条1/重置分隔线1", "内容底/面板2/重置说明盒/重置说明条2/重置分隔线2"]
## `verticalAlign = horizontalAlign = true` + `algin="center"` 那两块（`YuLianUpgragePanel.as:161-162`
## / `GouYuResetPanel.as:183-184`）⇒ 件路 + 盒高 38（15×2+4+4）+ 在父盒里垂直居中的 y。
const 居中块 := [["内容底/面板0/结果区0/结果文0", 83.0], ["内容底/面板2/重置材料盒/重置结果文", 99.0]]

var 场景: Node
var 管: Node
var 红数 := 0
var 日志: Array[String] = []
var 通知记录: Array[String] = []
var 存档前 := ""


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


## 假后端：三条请求各记一笔（§3.123）。
class 假后端:
	extends Node
	var in_game := true
	var 收到: Array = []

	func request_special_stage_up(位置: int) -> bool:
		收到 = ["special:%d" % 位置]
		return true

	func request_merge_jade(位置: int) -> bool:
		收到 = ["merge:%d" % 位置]
		return true

	func request_change_jade(位置: int) -> bool:
		收到 = ["change:%d" % 位置]
		return true

	## 「购买」那一支（`功能窗口.请求商城商品`）。参数是**物品 id**，不是槽位。
	func request_cash_item_info(物品id: int) -> bool:
		收到 = ["cash_item:%d" % 物品id]
		return true

	func request_cash_money() -> bool:
		return true


## 装个假后端 + 让窗**带一件**"槽位 7"的料开到第 `页` 页 ⇒ 点提交，返回是否走到真发。
## ⚠ 走的是 `背包窗口._开勾玉炼制窗` 那条真入口（`_jade_item` + `_页` + `_render_page`），
##   不再直接写控制器内部状态 —— 带进来的那件如今由 `渲染` 存进 `_带入`、`切页` 才装到该页。
##   只写内存（`_jade_item` 与假后端都挂在宿主上），跑完由本函数末尾还原。
func 试带物品(页: int, 假) -> bool:
	var 窗 := _窗()
	窗.set("_backend", 假)
	窗.set("_jade_item", {"id": "01100001", "slot_index": 7, "quantity": 1})
	控制器._页 = 页
	窗.call("_render_page")
	for _帧 in range(3):
		await process_frame
	_清通知()
	# ⚠️ 这里用 `pressed.emit()` 而不是真鼠标：`_render_page` 之后 `_页()` 可能拿到**上一帧那个
	#    已被 free 的页**（门当场崩过一次），而"点得动"这件事**上面页0 那条已经用真鼠标验过**了。
	var 钮 := (窗.get("_content") as Control).get_child(0).get_node_or_null("提交钮") as Button
	if 钮 == null:
		收尾("试带物品：重渲染后找不到 提交钮")
		return false
	钮.pressed.emit()
	await process_frame
	窗.set("_backend", null)
	窗.set("_jade_item", {})
	控制器.新会话()
	return 假.收到.size() == 1


func _尾通知() -> String:
	return 通知记录[通知记录.size() - 1] if not 通知记录.is_empty() else ""


func _清通知() -> void:
	通知记录.clear()


func _窗() -> Node:
	return 管._窗口们.get(页名) as Node


func _页() -> Control:
	var 窗 := _窗()
	if 窗 == null:
		return null
	var 出: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			出 = 子 as Control
	return 出


func _钮(页: Control, 路径: String) -> Button:
	return 页.get_node(路径) as Button


func 移到(位置: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位置
	移.global_position = 位置
	root.push_input(移)


func 点(位置: Vector2) -> void:
	移到(位置)
	await _等(2)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位置
	按.global_position = 位置
	root.push_input(按)
	await _等(2)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 位置
	放.global_position = 位置
	root.push_input(放)
	await _等(3)


func 点钮(钮: Control) -> void:
	await 点(钮.get_global_rect().get_center())


func _存档字节() -> String:
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)		# ⚠ 不钉这个，无头视口拿不到 GUI 命中 ⇒ 点了静默不生效
	存档前 = _存档字节()
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 != null and 会.has_signal("notification_requested"):
		会.notification_requested.connect(func(文本: String) -> void: 通知记录.append(文本))
	控制器.新会话()
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	管.call("全部关闭")
	管.call("打开", 页名)
	await _等(5)
	await _量开窗()
	await _量页签0()
	await _量投料文字()
	await _量灰与空()
	await _量线与居中()
	await _量切页()
	await _量三支()
	await _量投料拖放()
	await _量说明与材料()
	await _量成对()
	await _量烘值()
	收尾()


func 收尾(致命: String = "") -> void:
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	var 现 := _存档字节()
	_记(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（本门不落存档；变了会让邻居门次日假红）")
	if 现 != 存档前:
		日志.append("   ⇒ 说明这一族按钮里有支会写档：查 `_set_check` / `存档.保存()` 的调用链")
	for 一 in 日志:
		print(一)
	print("勾玉炼制页回归：%s（红 %d 项）" % ["通过" if 红数 == 0 else "不通过", 红数])
	quit(1 if 红数 > 0 else 0)


## ── ① 开窗：外框 / 内容底 / 三枚页签的几何与皮 ──────────────────────────────
func _量开窗() -> void:
	日志.append("=== 开窗（360×407 + 页面自烘 MYellow）===")
	var 窗 := _窗()
	_记(窗 != null, "落地页「%s」开出来了" % 页名)
	if 窗 == null:
		return
	var 页 := _页()
	_记(页 != null and String(页.name) == "原版勾玉炼制内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	## 2026-11-02 用户要求改名（有意偏离 AS3 的「玉链进阶」）：窗标题 = 「玉链勾玉打造」。
	_记(String(窗._title.text) == "玉链勾玉打造",
			"标题是「玉链勾玉打造」（用户 2026-11-02 要求；AS3 原为「玉链进阶」`YuLianJinJieWindow.as:142`）——**不是**菜单行文字「勾玉炼制」、也不是称号「勾玉指导员」，实测「%s」" % 窗._title.text)
	_记(absf(窗._window.size.x - 360.0) < 0.6 and absf(窗._window.size.y - 407.0) < 0.6,
			"外框 360×407（`:38` `super(360,407,false)`），实测 %.0f×%.0f"
			% [窗._window.size.x, 窗._window.size.y])
	# 内容底归**页面**：第三参 false ⇒ 宿主不许垫（垫了 = 两块 MYellow 叠起来比原版更不透明）
	var 底 = 窗._content_bg
	_记(底 != null and not bool(底.visible),
			"宿主的 内容底 **不显形**（AS3 第三参 false ⇒ 底由页面自己烘在 `内容底` 这件上）")
	var 黄底 := 页.get_node("内容底") as NinePatchRect
	_记(黄底 != null and String(黄底.texture.resource_path).get_file() == "内容面板.png",
			"页面里的 内容底 皮 = 内容面板.png（MYellow_background tag10），实测「%s」"
			% (String(黄底.texture.resource_path).get_file() if 黄底 != null and 黄底.texture != null else "无"))
	_记(黄底 != null and absf(黄底.position.x - 5.0) < 0.6 and absf(黄底.position.y - 29.0) < 0.6
			and absf(黄底.size.x - 350.0) < 0.6 and absf(黄底.size.y - 316.0) < 0.6,
			"内容底 窗口坐标 (5,58) 350×316（`:148-149` 宽−10 / 高−91、摆 (BORDER_GAP, tabBar.y+20)），实测窗口位 (%.0f,%.0f) %.0f×%.0f" % [黄底.position.x, 黄底.position.y + 29.0,
													黄底.size.x, 黄底.size.y])
	_记(bool(页.get_node("提交钮").visible), "提交钮在（`:154-160` 构造期就 addChild）")


## ── ② 页签：三枚 54 宽、x = 10/65/120、四档字色同一个、选中枚走 disabled 槽 ──
func _量页签0() -> void:
	日志.append("=== 页签条（TabButtonBar + MTabButtonF）===")
	var 页 := _页()
	var 条 := 页.get_node("分页") as Control
	_记(条.get_child_count() == 3, "三枚页签（`YU_LIAN_TAB_BUTTON_NAMES` 三条），实测 %d" % 条.get_child_count())
	var 位对 := true
	for i in 3:
		var 钮 := 条.get_child(i) as Button
		if absf(钮.position.x - float(i * 55)) > 0.6 or absf(钮.position.y) > 0.6 \
				or absf(钮.size.x - 54.0) > 0.6 or absf(钮.size.y - 22.0) > 0.6:
			位对 = false
	_记(位对, "枚 i 在条内 (i*55, 0)、54×22（`TabButtonBar.as:21/92` gap=1 + `MButton3.measure` 字宽+6）")
	var 条位 := 条.position
	_记(absf(条位.x - 10.0) < 0.6 and absf(条位.y - 9.0) < 0.6,
			"页签条在窗口 (10,38)（`:144-145`），实测页面 (%.0f,%.0f) = 窗口 (%.0f,%.0f)"
			% [条位.x, 条位.y, 条位.x, 条位.y + 29.0])
	var 色对 := true
	for i in 3:
		var 钮 := 条.get_child(i) as Button
		for 槽 in ["font_color", "font_hover_color", "font_pressed_color",
				"font_hover_pressed_color", "font_disabled_color"]:
			var c: Color = 钮.get_theme_color(槽)
			if absf(c.r - 黄.r) > 0.01 or absf(c.g - 黄.g) > 0.01 or absf(c.b - 黄.b) > 0.01:
				色对 = false
	_记(色对, "五档字色**全是** #FCF49C（`MTabButton.as:12` 把四档赋成同一个值 ⇒ 换态不换字色）")
	_记(bool(条.get_child(0).disabled) and not bool(条.get_child(1).disabled)
			and not bool(条.get_child(2).disabled),
			"开屏只有枚 0 `disabled=true` ⇒ 选中枚走 **disabled 槽**（`MTabButton.as:35-39` `selected = !enabled`）")
	var 正 := _钮(页, "分页/页签0")
	_记(正.get_theme_stylebox("disabled").get("texture") != null
			and String(正.get_theme_stylebox("disabled").texture.resource_path).get_file() == "分页按钮选中.png",
			"disabled 槽的皮 = 分页按钮选中.png（tag118 `MTabButton_disabled`，**名字坑：它就是选中样式**）")
	_记(正.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "页签是手型")


## ── ③ 三枚投料钮的文字逐字（页1/2 按用户要求改正为「放入勾玉」）───────────────
func _量投料文字() -> void:
	日志.append("=== 三枚投料钮文字（逐字；页1/2 为改正后的「放入勾玉」）===")
	var 页 := _页()
	var 歪: Array = []
	for i in 3:
		var 钮 := _钮(页, 投料钮路[i])
		if 钮.text != 投料文[i]:
			歪.append([i, 钮.text, 投料文[i]])
	_记(歪.is_empty(), "投料钮文字 = 放入玉链 / 放入勾玉 / 放入勾玉（页1/2 用户 2026-11-02 要求改正，有意偏离原版 `[2]` 串号）实测 %s" % str(歪))
	var 提 := _钮(页, "提交钮")
	_记(提.text == 提交文[0], "开屏提交钮「%s」（`:156` 用 `[3]`）" % 提.text)
	_记(absf(提.position.x - 296.0) < 0.6 and absf(提.position.y - 351.0) < 0.6
			and absf(提.size.x - 54.0) < 0.6,
			"提交钮窗口坐标 (296,380) 54 宽（`:157-158` x = 宽−钮宽−5−5、y = 高−钮高−5），实测 %.0f/%.0f"
			% [提.position.x, 提.position.y + 29.0])


## ── ④ 静态灰 / 七枚空格 / 材料4 那颗精玉灵珠 ────────────────────────────────
func _量灰与空() -> void:
	日志.append("=== 静态灰（材料4）+ 离线不假造图标 + 精玉灵珠真有图 ===")
	var 页 := _页()
	var 四 := 页.get_node(珠格) as CanvasItem
	var 一 := 页.get_node("内容底/面板1/材料盒/材料1/材料1格") as CanvasItem
	_记(四.material is ShaderMaterial,
			"材料4 格**离线就灰**（`GouYuCompositePanel.as:259` 在 createChildren 里就 applyGrayFilter()）")
	_记(一.material == null,
			"材料1 格**不灰**（`:256` applyGrayFilter(false)）⇒ 灰是逐枚的，不是一片")
	var 有图: Array = []
	for 路径 in 空格子:
		var 格 := 页.get_node(路径) as CanvasItem
		for 子 in 格.get_children():
			if 子 is TextureRect:
				有图.append(路径)
				break
	_记(有图.is_empty(), "七枚空格零图标（投料/结果/材料1-3 等运行期 itemData ⇒ 有图标就是假数据）实测 %s" % str(有图))
	# 材料4 那一格**反过来**：原版 `showView:140-141` 用静态配置造 itemData ⇒ 离线就该有图
	var 图: TextureRect = null
	var 数: Label = null
	for 子 in 页.get_node(珠格).get_children():
		if 子 is TextureRect:
			图 = 子 as TextureRect
		elif 子 is Label:
			数 = 子 as Label
	_记(图 != null and String(图.texture.resource_path).contains(珠编号),
			"材料4 离线就有**精玉灵珠**图标（`Etc.json jade.merge.level2.needItemId = %s`，不连服务端）实测「%s」"
			% [珠编号, String(图.texture.resource_path).get_file() if 图 != null and 图.texture != null else "无"])
	_记(图 != null and absf(图.position.x - 3.0) < 0.6 and absf(图.position.y - 3.0) < 0.6,
			"图标 34×34 在 40 格里居中取整 (3,3)（`SimpleItemCell.as:160-165`），实测 %s"
			% (str(图.position) if 图 != null else "无"))
	_记(数 != null and 数.text == " ",
			"数量烘的是原版那句 `label = \" \"`（一个空格，不是 0）实测「%s」" % (数.text if 数 != null else "无"))
	_记(四.material is ShaderMaterial and 图 != null and 数 != null
			and 图.material == 四.material and 数.material == 四.material,
			"灰是**格/图标/数量三层各挂同一份** `mat1`（10-04 实测：只挂父层时 TextureRect 子节点吃不到 ⇒ 工程口径三层都挂；语义仍等于原版挂在 itemCell 上的那一份 `filters`）")


## ── ④b 分隔线 = LineHPicF 那张图、y = 块高 − 2；结果文字两轴居中 ────────────
## （2026-10-05 用户实机图打回「分隔线不对、有些文字位置也不对」的两条根因）
func _量线与居中() -> void:
	日志.append("=== 分隔线（LineHPicF 图 + y=块高−2）与「本次操作…」两轴居中 ===")
	var 页 := _页()
	var 歪: Array = []
	for 路径 in 分隔线:
		var 件 := 页.get_node(路径) as TextureRect
		var 块 := 件.get_parent() as Control
		var 皮 := String(件.texture.resource_path).get_file() if 件.texture != null else "无"
		var 该 := float(块.size.y) - 4.0 + 2.0
		if 皮 != "横向分隔线.png" or absf(件.position.y - 该) > 0.6 or absf(件.size.x - 块.size.x) > 0.6:
			歪.append([路径, 皮, 件.position.y, 该, 件.size.x, 块.size.x])
	_记(歪.is_empty(),
			"五枚分隔线都是 `横向分隔线.png`（原版 `LineHPicF` symbol133，**不是**涂色的 ColorRect）、y = 块高−4+2、宽 = 块宽（`EquipLineTextArea.as:31/55-58` + `:66-69`）实测 %s" % str(歪))
	var 偏: Array = []
	for 组 in 居中块:
		var 件 := 页.get_node(String(组[0])) as RichTextLabel
		var 盒高 := 件.size.y
		var 该y := (float(组[1]) - 盒高) / 2.0
		if int(件.horizontal_alignment) != 1 or absf(件.position.y - 该y) > 0.6 or absf(盒高 - 38.0) > 0.6:
			偏.append([组[0], 件.horizontal_alignment, 件.position.y, 该y, 盒高])
	_记(偏.is_empty(),
			"两块「本次操作消耗金币…」= 盒内**水平居中 + 垂直居中**（`verticalAlign = horizontalAlign = true` + `algin=center` ⇒ `Box.as:400-413` holder 摆 (高−内容高)/2）；文本盒高 15×2+4+4 = 38 实测 %s" % str(偏))
	# 四枚材料名标签：`ItemCaiLiaoBox.as:136` `align = "center"` + `:75` `label.width = _width`
	# ⇒ 文字在 56/60 宽里**居中**。SPEC 漏 `对齐` 就按左对齐画 = 用户实机图打回「这排文字位置有点偏左」。
	var 名歪: Array = []
	for i in 4:
		var 名 := 页.get_node("内容底/面板1/材料盒/材料%d/材料%d名" % [i + 1, i + 1]) as Label
		var 盒 := 名.get_parent() as Control
		if int(名.horizontal_alignment) != 1 or absf(名.size.x - 盒.size.x) > 0.6:
			名歪.append([i + 1, 名.horizontal_alignment, 名.size.x, 盒.size.x])
	_记(名歪.is_empty(), "四枚材料名标签（成功/退还/剩余/精玉灵珠）= 居中且宽 = 块宽（`ItemCaiLiaoBox.as:136/75`），实测 %s" % str(名歪))


## ── ⑤ 真点页签切页 ──────────────────────────────────────────────────────────
func _量切页() -> void:
	日志.append("=== 真 push_input 点页签（visible / disabled / 提交钮文字 三件一起换）===")
	var 页 := _页()
	for 序 in [1, 2, 0]:
		await 点钮(_钮(页, "分页/页签%d" % 序))
		var 只对 := true
		for i in 3:
			var 可 := bool((页.get_node("内容底/%s" % 面板名[i]) as Control).visible)
			var 选 := bool(_钮(页, "分页/页签%d" % i).disabled)
			if 可 != (i == 序) or 选 != (i == 序):
				只对 = false
		_记(只对 and _钮(页, "提交钮").text == 提交文[序],
				"点页签%d ⇒ 只有 %s 可见、该枚转选中、提交钮「%s」，实测钮文字「%s」"
				% [序, 面板名[序], 提交文[序], _钮(页, "提交钮").text])


## ── ⑥ 三支：提交发真协议、投料只回显、购买发商城那条 ────────────────────────
func _量三支() -> void:
	日志.append("=== 提交 / 投料 / 购买 三支 ===")
	var 页 := _页()
	_清通知()
	await 点钮(_钮(页, "提交钮"))
	# ⚠️ 提交那支从"只回显"改成**真协议**（§3.123）：本门开窗时**没带物品** ⇒ 该提示"先从背包选一件"。
	_记(_尾通知().contains("先从背包里选中一件"),
			"没带物品就点提交 ⇒ 点名叫「先从背包里选中一件玉链/勾玉」，实测「%s」" % _尾通知())
	# ★ 带上物品 + 三页各发对应请求（假后端收）—— 三条请求以前**全工程零调用点**，就是这一支缺的
	var 假 := 假后端.new()
	_记(await 试带物品(0, 假) and 假.收到 == ["special:7"],
			"页0 玉链升阶 ⇒ 发 request_special_stage_up(槽位)，实测 %s" % str(假.收到))
	_记(await 试带物品(1, 假) and 假.收到 == ["merge:7"],
			"页1 勾玉合成 ⇒ 发 request_merge_jade(槽位)，实测 %s" % str(假.收到))
	_记(await 试带物品(2, 假) and 假.收到 == ["change:7"],
			"页2 勾玉重置 ⇒ 发 request_change_jade(槽位)，实测 %s" % str(假.收到))
	_清通知()
	# ⚠️ 上面那三发各调用过一次 `_render_page`（换带物品的页）⇒ 这里的 `页` 已经**被 free**，
	#    必须**重取**（否则 `_钮(页, …)` 崩成"previously freed"，而本门会照样打"通过" —— §3.120 记过）。
	页 = _页()
	for _帧 in range(3):
		await process_frame
	# 「投料钮」那一支挪去 ⑪（2026-10-31 它从"只回显一句拖放指引"改成真的弹选物清单，
	# 判据也跟着走到清单那几条腿上，见 `_量说明与材料`）。
	# 购买钮是 `ItemCaiLiaoBox(_showBuyBtn=true)` 里的件、整块 `材料盒` 在 **面板1** ⇒
	# 只有切到页签1 那一面才点得到（原版同一个形状，不是我们裁的）。切页前先清通知，
	# 免得把「切页」的回显算进这一支。
	await 点钮(_钮(页, "分页/页签1"))
	_清通知()
	# ⚠️ 2026-10-11 起「购买」**不再是桩**：原版共用材料格 `ItemCaiLiaoBox.buyHandler:46-55`
	#    发的是 `REQUEST_CASH_ITEM_INFO`（`id = itemCell.itemData.id`），这里就是材料4 那件
	#    （精玉灵珠 `16000031`）；回包 1079 由 `功能窗口.打开商城购买窗` 弹购买窗。
	#    判据钉**真发包**（同上面三条玉链请求的手法），不钉文案。
	var 假买 := 假后端.new()
	var 主 := _窗()
	主.set("_backend", 假买)
	await 点钮(_钮(页, "内容底/面板1/材料盒/材料4/材料4购买钮"))
	for _帧 in range(2):
		await process_frame
	_记(假买.收到 == ["cash_item:16000031"],
			"购买（页签1 那面）⇒ 发 request_cash_item_info(16000031 精玉灵珠)，实测 %s" % str(假买.收到))
	主.set("_backend", null)
	await 点钮(_钮(页, "分页/页签0"))		# 回开屏态 ⇒ 后面「烘值」那节量的就是首屏


## ── ⑦ 投料（拖放，§3.136）────────────────────────────────────────────────
## 走的是**真拖放路径**（落点件挂上之后 `_can_drop_data` / `_drop_data`），不是直接调控制器 ——
## 那样才量得到"格挂没挂上、接不接鼠标、信号通不通"。载荷也不手搓，见下面 `_真载荷`（⑧）。
func _拖(格: Control, 载荷: Dictionary) -> void:
	if 格.has_method("_drop_data"):
		格.call("_drop_data", Vector2.ZERO, 载荷)


## 注进场子的一条背包行：id **八位补零**（§3.129）、`slot_index` 不变量、**带真图标路径**。
## ⚠ icon 不许省：`_渲染格子` 只在 `ResourceLoader.exists(icon)` 时才摆图并解除 `disabled`
##   ⇒ 没图的格子 `_get_drag_data` 直接返回 null（`可拖拽格.gd:77`），下面⑧那批腿就量不到东西。
##   同一条口径见 `背包道具回归测试.gd:119-127` 的 `_件()`。
## ⚠ `词条` 是**客户端形态**的 `plus_attributes`（`Array[Dictionary]`，键 `attribute_type`/`attribute_value`，
##   见 `后端连接._parse_named_rows` 与 `装备提示框.gd:490-517`）——服务端存档里存的是 `[[4,10]]` 那种**成对**，
##   上线由 `_encode_item_payload` 翻成这两键，门直接塞成对会让提示框一条都不显（看着像 UI 坏）。
func _料条(格: int, 物品id: String, 名: String, 件数: int, 词条: Array = []) -> Dictionary:
	var 图 := 游戏数据.item_icon_path(物品id)
	if 图.is_empty() or not ResourceLoader.exists(图):
		图 = "res://素材/界面/原版窗口/通用控件/物品格.png"
	var 条 := {"id": 物品id, "name": 名, "quantity": 件数, "slot_index": 格, "icon": 图}
	if not 词条.is_empty():
		条["plus_attributes"] = 词条
	return 条


## 背包第 `格号`（1 基）那一**枚真格子**（页0 = 格 1~30）。
func _背包格(格号: int) -> Button:
	var 包 := 管._窗口们.get("背包") as Node
	if 包 == null:
		return null
	var 页 := (包.get("_content") as Control).find_child(背包页根, true, false) as Control
	if 页 == null:
		return null
	return 页.get_node_or_null("格子滚动/格子容器/物品格_%d" % (格号 - 1)) as Button


## 让那一格**自己**交拖拽载荷（假绿 #23 的解药：归属/物品id/来源格 全是运行时真值）。
func _真载荷(格号: int) -> Dictionary:
	var 格 := _背包格(格号)
	if 格 == null:
		return {}
	var 载: Variant = 格.call("_get_drag_data", Vector2.ZERO)
	return 载 if typeof(载) == TYPE_DICTIONARY else {}


func _量投料拖放() -> void:
	日志.append("=== 投料（拖放）：类型闸 / 满级·拆开闸 / 落上刷新 / 取出 / 每页各一份料 / 悬停详情框 ===")
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 == null:
		收尾("投料：没有 GameSession")
		return
	var 快照: Array = (会.inventory as Array).duplicate(true)
	会.inventory.clear()
	# 格1 稻荷玉链(非满级，带 1 条附加词条) / 格2 八尺琼玉链(满级) / 格3 勾玉1级 / 格4 勾玉15级 / 格5 勾玉1级×2
	# 词条走**客户端形**（Array[Dictionary]，`attribute_type` 4 = 攻击）——服务端存档里那份是
	# `[[4,30]]` 成对，翻形发生在 `_encode_item_payload`，提示框读的是翻完之后。
	会.inventory.append(_料条(1, "01200010", "稻荷玉链", 1,
			[{"attribute_type": 4, "attribute_value": 30}]))
	会.inventory.append(_料条(2, "01200060", "八尺琼玉链", 1))
	会.inventory.append(_料条(3, "13100000", "勾玉（1级）", 1))
	会.inventory.append(_料条(4, "13100014", "勾玉（15级）", 1))
	会.inventory.append(_料条(5, "13100000", "勾玉（1级）", 2))
	await _等(2)
	# **真渲染**背包 ⇒ 上面五行长出格子（不重渲染，拿到的还是清档前那批格子的载荷）。
	var 包 := 管._窗口们.get("背包") as Node
	if 包 == null:
		收尾("投料：背包没随这扇窗一起开出来（`伴随背包`）")
		return
	包.call("_render_page")
	await _等(3)

	# 类型闸（纯函数，直接问）
	_记(放入格脚本.可收("01200010", 0) and 放入格脚本.可收("01200060", 0), "页0 该收玉链（四位码 120）")
	_记(not 放入格脚本.可收("13100000", 0), "页0 不该收勾玉")
	_记(放入格脚本.可收("13100000", 1) and 放入格脚本.可收("13100100", 2), "页1/页2 该收勾玉（前三位 131）")
	_记(not 放入格脚本.可收("01200010", 1), "页1 不该收玉链")
	_记(not 放入格脚本.可收("01010011", 0), "页0 不该收普通武器")

	# ⑧ 载荷本身：真格子交出来的三件必须齐（手搓载荷永远量不到"格子没开拖/没填 id"）
	var 载2 := _真载荷(2)
	_记(not 载2.is_empty(), "格2（满级玉链）自己能起拖 ⇒ `可拖拽`/`icon`/`归属`/`disabled` 四件齐，实测 %s" % str(载2.keys()))
	if not 载2.is_empty():
		var 源2 := 载2.get("来源格") as Node
		_记(String(载2.get("归属", "")) == "背包" and String(载2.get("物品id", "")) == "01200060"
				and 源2 != null and int(源2.get("槽位号")) == 2,
				"载荷三件 = 归属「背包」/ 物品id 01200060 / 来源格.槽位号 2，实测「%s」/「%s」/「%s」" % [
					String(载2.get("归属", "")), String(载2.get("物品id", "")),
					str(int(源2.get("槽位号"))) if 源2 != null else "无源格"])

	var 页 := _页()
	# ① 页0：满级玉链不收且弹原版那句话；正常玉链收下并刷新
	_清通知()
	_拖(页.get_node(投料格路[0]), 载2)
	await _等(2)
	_记(_尾通知() == "该玉链已经是最高阶！", "页0 满级玉链 ⇒「该玉链已经是最高阶！」，实测「%s」" % _尾通知())
	_记(控制器.料(0).is_empty(), "满级玉链不该被收下")
	var 载1 := _真载荷(1)
	_记(bool((页.get_node(投料格路[0]) as Control).call("_can_drop_data", Vector2.ZERO, 载1)),
			"真载荷该过页0 的 `_can_drop_data`（手搓的那条只证明判据，不证明格子接得住真拖）")
	_拖(页.get_node(投料格路[0]), 载1)
	await _等(2)
	_记(int(控制器.料(0).get("slot_index", 0)) == 1, "稻荷玉链该收下（记来源槽 1）")
	_记(_钮(页, 投料钮路[0]).text == "取出玉链", "收下后钮文字该换「取出玉链」")
	_记((页.get_node(投料格路[0] + "/投料图标") as TextureRect).texture != null, "收下后投料格该出图标")

	# ② 页2：整摞勾玉×2 **直接收**（用户 2026-11-02 要求不再拆成 1 个；
	#    服务端 `_change_jade_attribute:53959-53975` 本来就是一次消耗 1 个、生成 1 个）
	控制器.切页(页, 2)
	await _等(2)
	_清通知()
	_拖(页.get_node(投料格路[2]), _真载荷(5))
	await _等(2)
	_记(int(控制器.料(2).get("quantity", 0)) == 2,
			"页2 勾玉×2 ⇒ 整摞收下（用户要求：不必拆成1个，一次消耗/生成1个），实测料 %s" % str(控制器.料(2)))
	_记(_尾通知() != "请将物品拆开成1个再进行该操作！", "页2 不许再弹「请将物品拆开成1个…」，实测「%s」" % _尾通知())
	_记(_钮(页, 投料钮路[2]).text == "取出勾玉", "页2 收下后钮文字「取出勾玉」（原版 `[3]`）")

	# ②b 页2：**满级勾玉也收** —— 旧代码把页1 的满级闸错套到了页2（AS3
	#     `GouYuResetPanel.validateItem:109-136` 只查类型、没有 nextId 判断），
	#     用户 2026-11-02 报「重置里拖入勾玉却提示已经最高等级」。
	await 点钮(_钮(页, 投料钮路[2]))		# 先取出上面那摞
	await _等(2)
	_记(控制器.料(2).is_empty(), "页2 再点同一枚 ⇒ 取出那摞（满级腿的前置）")
	_清通知()
	_拖(页.get_node(投料格路[2]), _真载荷(4))
	await _等(2)
	_记(int(控制器.料(2).get("slot_index", 0)) == 4 and _尾通知() != "该勾玉已经是最高等级！",
			"页2 满级勾玉 ⇒ 照样收下（重置不套页1 的满级闸），实测料 %s / 通知「%s」" % [str(控制器.料(2)), _尾通知()])
	_记(_钮(页, 投料钮路[2]).text == "取出勾玉", "页2 满级勾玉收下后钮文字「取出勾玉」")
	await 点钮(_钮(页, 投料钮路[2]))		# 收拾干净，后面 ⑦ 还要用页2
	await _等(2)
	_记(控制器.料(2).is_empty(), "页2 满级腿收尾 ⇒ 取出干净（后面 ⑦ 复用页2）")

	# ③ 页1：满级勾玉不收；正常勾玉收下并出**下一级**结果图标
	控制器.切页(页, 1)
	await _等(2)
	_清通知()
	_拖(页.get_node(投料格路[1]), _真载荷(4))
	await _等(2)
	_记(_尾通知() == "该勾玉已经是最高等级！", "页1 满级勾玉 ⇒「该勾玉已经是最高等级！」，实测「%s」" % _尾通知())
	var 载3 := _真载荷(3)
	_拖(页.get_node(投料格路[1]), 载3)
	await _等(2)
	_记(_钮(页, 投料钮路[1]).text == "取出勾玉", "页1 收下后钮文字该换「取出勾玉」")
	var 结果图标 := 页.get_node_or_null(结果格路[1] + "/结果图标") as TextureRect
	_记(结果图标 != null and 结果图标.texture != null, "页1 结果格该出**下一级**勾玉的图标")

	# ④ 取出：点钮 ⇒ 清格、钮文字翻回去、**不发帧**
	var 假 := 假后端.new()
	_窗().set("_backend", 假)
	await 点钮(_钮(页, 投料钮路[1]))
	await _等(2)
	_记(控制器.料(1).is_empty(), "点「取出勾玉」该清掉那份料")
	_记(_钮(页, 投料钮路[1]).text == 投料文[1], "取出后钮文字该翻回初始那串「%s」" % 投料文[1])
	_记(假.收到.is_empty(), "取料不该发任何帧（原版那一支也不发）")
	_窗().set("_backend", null)

	# ⑨ 每页各一份料：切走即清（`YuLianJinJieWindow.as:56-59`），且**不许串页**
	_拖(页.get_node(投料格路[1]), 载3)
	await _等(2)
	控制器.切页(页, 0)
	await _等(2)
	_记(控制器.料(1).is_empty(), "切走 ⇒ 页1 那份料被清（原版对离开那页调 `backItemToEquip`）")
	_记((页.get_node(投料格路[1] + "/投料图标") as TextureRect).texture == null, "切走后页1 投料格该没图标")
	_记(_钮(页, 投料钮路[1]).text == 投料文[1], "切走后页1 投料钮该翻回「%s」" % 投料文[1])
	_记(控制器.料(0).is_empty(), "页1 的勾玉不许串到页0（原来三页共用一份 `_物品` 就串在这）")
	var 假串 := 假后端.new()
	_窗().set("_backend", 假串)
	_清通知()
	await 点钮(_钮(页, "提交钮"))
	await _等(2)
	_记(假串.收到.is_empty() and _尾通知().contains("先从背包里选中一件"),
			"页0 空料点提交 ⇒ 不发进阶帧、点名叫选一件（实测 %s /「%s」；串页的老写法会发 special:3）"
			% [str(假串.收到), _尾通知()])
	_窗().set("_backend", null)

	# ⑨b 把"不串页"钉到**协议面**上：三页各发各的那条帧、且槽位取的是本页那份料。
	#     串页的老写法（三页共用 `_物品`）在这里会发成 `merge:3` 给页0、或把勾玉那格的槽位
	#     交给 `request_special_stage_up` ⇒ 服务端拿一件勾玉去做玉链进阶，玩家看不到任何报错，
	#     东西却凭空没了。这一族只能钉帧文本，钉 UI 是钉不住的。
	var 假三 := 假后端.new()
	_窗().set("_backend", 假三)
	_拖(页.get_node(投料格路[0]), 载1)
	await _等(2)
	await 点钮(_钮(页, "提交钮"))
	await _等(2)
	_记(假三.收到 == ["special:1"],
			"页0 放玉链(背包格1)点提交 ⇒ 只发一条 `request_special_stage_up(1)`，实测 %s" % str(假三.收到))
	控制器.切页(页, 1)
	await _等(2)
	_拖(页.get_node(投料格路[1]), 载3)
	await _等(2)
	await 点钮(_钮(页, "提交钮"))
	await _等(2)
	_记(假三.收到 == ["merge:3"],
			"页1 放勾玉(背包格3)点提交 ⇒ 只发一条 `request_merge_jade(3)`，实测 %s" % str(假三.收到))
	控制器.切页(页, 2)
	await _等(2)
	_拖(页.get_node(投料格路[2]), 载3)
	await _等(2)
	await 点钮(_钮(页, "提交钮"))
	await _等(2)
	_记(假三.收到 == ["change:3"],
			"页2 放勾玉(背包格3)点提交 ⇒ 只发一条 `request_change_jade(3)`，实测 %s" % str(假三.收到))
	_窗().set("_backend", null)
	# 回到 ⑩ 的前置：停在页0、料全空（`切页` 清的是**离开那页** ⇒ 这一句把页2 那份也带走了）
	控制器.切页(页, 0)
	await _等(2)

	# ⑩ 悬停详情框：两套框在页上、五枚格收得到鼠标、玉链→装备框 / 勾玉→物品框 / 结果格→下一级那件
	var 装备框 := 页.get_node_or_null("装备提示框") as Control
	var 物品框 := 页.get_node_or_null("物品提示框") as Control
	_记(装备框 is Control and 物品框 is Control,
			"页上有运行期建的两套提示框（场景是 SPEC 生成物 ⇒ 只能 `渲染` 时 `建提示框`）")
	if 装备框 == null or 物品框 == null:
		控制器.切页(页, 0)
		会.inventory.assign(快照)
		await _等(2)
		return
	var 非忽略 := true
	for 路 in [投料格路[0], 投料格路[1], 投料格路[2], 结果格路[0], 结果格路[1]]:
		if (页.get_node(路) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE:
			非忽略 = false
	_记(非忽略, "三枚投料格 + 两枚结果格的 mouse_filter 都不是 IGNORE ⇒ 悬停弹得出（投料格是 STOP 也接悬停）")
	_拖(页.get_node(投料格路[0]), 载1)
	await _等(2)
	_记(not 装备框.visible and not 物品框.visible, "悬停前两套框都收起")
	(页.get_node(投料格路[0]) as Control).mouse_entered.emit()
	await process_frame
	_记(装备框.visible and not 物品框.visible, "悬停玉链格该弹**装备**提示框（`装备部位表.位置` ≠ 0 → `MToolTipZhuangBei`）")
	_记(String(装备框.get("_标题").text) == "稻荷玉链",
			"装备提示框标题就是那一件玉链（读的是**背包真行**的 id），实测「%s」" % String(装备框.get("_标题").text))
	# 标题对 ≠ 框是活的：只印名字的框看起来也"正常"。这一条验的是**整条数据通路** ——
	# 提示框拿到的 `实例` 必须是背包那一行本身，`plus_attributes` 才落得进 `_明细`。
	var 明细 := 装备框.get("_明细") as RichTextLabel
	var 明细文 := "" if 明细 == null else String(明细.get_parsed_text()).replace("\n", "⏎")
	_记(明细文.contains("攻击") and 明细文.contains("+30"),
			"装备提示框**明细**里长出那一件的附加词条「攻击 +30」（读的是背包真行的 plus_attributes，不是只有标题）——实测「%s」" % 明细文.left(160))
	(页.get_node(投料格路[0]) as Control).mouse_exited.emit()
	await process_frame
	_记(not 装备框.visible, "移开鼠标该收起装备提示框")
	控制器.切页(页, 1)
	await _等(2)
	_拖(页.get_node(投料格路[1]), 载3)
	await _等(2)
	(页.get_node(投料格路[1]) as Control).mouse_entered.emit()
	await process_frame
	_记(物品框.visible and not 装备框.visible, "悬停勾玉格该弹**物品**提示框（宝石类不是 EqpData）")
	_记(String(物品框.get("_标题").text) == "勾玉（1级）",
			"投料格标题 = 放进去那件「勾玉（1级）」，实测「%s」" % String(物品框.get("_标题").text))
	(页.get_node(投料格路[1]) as Control).mouse_exited.emit()
	await process_frame
	(页.get_node(结果格路[1]) as Control).mouse_entered.emit()
	await process_frame
	_记(物品框.visible and not 装备框.visible, "悬停结果格（下一级预览）也该弹**物品**提示框")
	_记(String(物品框.get("_标题").text) == "勾玉（2级）",
			"结果格弹的是**下一级**那件「勾玉（2级）」，不是投料格那件，实测「%s」" % String(物品框.get("_标题").text))
	# ⑩b 宝石段（2026-10-31 用户报：详情框不写它加哪个忍术）
	#     原版 `MToolTipDefault.as:132-151`：宝石类（非秽章石）在分隔线后多一段。
	#     勾玉支 =「勾玉属性」+ 绿字「技能名  +N层」；名字 = `StringTool.getSkillString(skill)`
	#     查 `String.Skill`，层数取 `inlay.level`（**不是** `stone_level`，6 级起两者分叉）。
	var 抬头 := 物品框.get("_宝石抬头") as Label
	var 值行 := 物品框.get("_宝石值") as Label
	_记(抬头 != null and 抬头.visible and 抬头.text == "勾玉属性",
			"勾玉详情框有「勾玉属性」抬头（原版 `MTOOTIP_STONE_GOUYU_PRORERTIES`，色 #8ea8d8），实测「%s」"
			% ("" if 抬头 == null else 抬头.text))
	_记(值行 != null and 值行.visible and 值行.text == "怪力  +2层",
			"结果格那颗（2 级、忍术 1002001）⇒ 绿字「怪力  +2层」，实测「%s」"
			% ("" if 值行 == null else 值行.text))
	_记(值行 != null and 值行.get_theme_color("font_color") == Color("00ff00"),
			"勾玉值行是绿字 #00ff00（原版 attributeDesc 外面包 `<font color=\"#00ff00\">`）")
	var 绑定位 := 物品框.get("_绑定") as Control
	# ⚠ y 先落到局部再进 `%`：格式化实参是**先求值**的，抬头/值行缺一个就会在这里裸 deref
	#    （门里崩了不报红、直接挂死 —— 见 §3.244）。
	var 线y := (物品框.get("_分隔线") as Control).position.y
	var 抬y := 0.0 if 抬头 == null else 抬头.position.y
	var 绑y := 0.0 if 绑定位 == null else 绑定位.position.y
	_记(抬头 != null and 值行 != null and 绑定位 != null
			and 抬y > 线y and 值行.position.y > 抬y and 绑y > 值行.position.y,
			"块序照原版：分隔线 → 宝石段（抬头在上、值在下）→ 价格/绑定"
			+ "（实测 分隔线 y%.1f / 抬头 y%.1f / 值行 y%.1f / 绑定 y%.1f）"
			% [线y, 抬y, 值行.position.y if 值行 != null else 0.0, 绑y])
	(页.get_node(结果格路[1]) as Control).mouse_exited.emit()
	await process_frame
	物品框.call("设置", "13100805", 1, 99)		# 6 级天之咒印：stone_level=6、inlay.level=7
	await process_frame
	_记(值行 != null and 值行.text == "天之咒印  +7层",
			"6 级天之咒印勾玉 ⇒「天之咒印  +7层」（层数取 `inlay.level`，拿 `stone_level`=6 会少 1 层），实测「%s」"
			% ("" if 值行 == null else 值行.text))
	# ⑩c 普通宝石（130 前缀）：同一段版式，抬头换「宝石属性」、值是白字「属性名　+数值」。
	#     原版 `MToolTipDefault.as:147-149` + `StoneData.getAttributeDesc:83-90`。
	物品框.call("设置", "13000000", 1, 99)		# 红色宝石(1级)：atk +3
	await process_frame
	_记(抬头 != null and 抬头.visible and 抬头.text == "宝石属性",
			"普通宝石 ⇒ 抬头换成「宝石属性」（原版 `CN.MTOOTIP_STONE_PRORERTIES`），实测「%s」"
			% ("" if 抬头 == null else 抬头.text))
	_记(值行 != null and 值行.visible and 值行.text == "攻击　+3",
			"红色宝石(1级) ⇒「攻击　+3」（`ATTR_TYPES.atk` → `ITEM_ATTR_NAME_ATK`，全角空格），实测「%s」"
			% ("" if 值行 == null else 值行.text))
	_记(值行 != null and 值行.get_theme_color("font_color") == Color.WHITE,
			"普通宝石的值行是**白字**（`attributeDesc` 没有 font 包，吃文本框 textColor=16777215）")
	物品框.call("设置", "13020009", 1, 99)		# 蓝色宝石(影10级)：maxhp +1500
	await process_frame
	_记(值行 != null and 值行.text == "生命值上限　+1500",
			"maxhp 宝石 ⇒「生命值上限　+1500」（词条表按 `StoneData.ATTR_TYPES` 的键查），实测「%s」"
			% ("" if 值行 == null else 值行.text))
	物品框.call("设置", "13200000", 1, 99)		# 秽章石：原版整段不画（`isItemAHuiZhangShi`）
	await process_frame
	_记(抬头 != null and not 抬头.visible and 值行 != null and not 值行.visible,
			"秽章石（132 前缀）⇒ 宝石段整体收起（原版 `!isItemAHuiZhangShi(value.id)` 那一半）")
	# 132 前缀是**硬闸**：就算这件真带了属性列，也不许画（否则这条腿只是靠「数据里没那两列」兜住的）。
	物品框.call("_填宝石属性", "13200000", {"category": "宝石", "stone_attr_type": "atk", "stone_attr_value": 5})
	await process_frame
	_记(抬头 != null and not 抬头.visible and 值行 != null and not 值行.visible,
			"秽章石**带着** `stone_attr_type` 也整段收起（132 前缀那一半是硬闸，不靠数据缺列兜底）")
	# 空料格：悬停必须把两套都收掉（`格子提示框.gd:48-54` 的空格那一支）
	控制器.切页(页, 2)
	await _等(2)
	(页.get_node(投料格路[2]) as Control).mouse_entered.emit()
	await process_frame
	_记(not 物品框.visible and not 装备框.visible, "悬停**空**投料格 ⇒ 两套框都收起，不留上一件的残影")
	(页.get_node(投料格路[2]) as Control).mouse_exited.emit()

	控制器.切页(页, 0)
	会.inventory.assign(快照)
	await _等(2)


## ── ⑪ 放入钮 / 消耗与几率 / 材料4 / 合成回包（2026-10-31 用户报的四条）────────
## 用户原话：「三个子面板，都会默认放入一个玉链的图标」「放入对应道具的按钮功能没有实装，
## 只能拖拽道具到道具格」「操作消耗金币、成功概率的值没有正确接入，当前全是 0」
## 「勾玉合成子面板，合成成功，没有在成功、退还、剩余显示道具数量，精玉灵珠也没有正常显示
## 背包里的精玉灵珠数量，始终是灰色的」。期望值一律来自 `数据/装备打造.json` 与 AS3 行号：
##   页0 `special.stageup.stage2` = 100000 金币 / 50%（`YuLianUpgragePanel.as:187-190 / :193-220`）
##        ⚠ 是 `special.stageup`，**不是**顶层 `stageup`（顶层那块 10000/10 是装备进阶窗的）
##   页1 `jade.merge.level2` = prob 100、`needMoney` 客户端写死 0（`GouYuCompositePanel.as:296-306`）
##   页2 `jade.change.level1` = 1000 金币 / 70%（`GouYuResetPanel.as:160-164`）
##   材料4 需要数 = `needItemCnt × ⌊枚数/3⌋`，不足一批按一批（`getNeedItemCout:307-311`）；
##        灰 = 拥有 < 需要（`updateDescription:161-170`）
func _说明文(页: Control, 序: int) -> String:
	var 文 := 页.get_node_or_null(控制器.说明路[序]) as RichTextLabel
	return "" if 文 == null else 文.text


func _量说明与材料() -> void:
	日志.append("=== 放入钮 / 消耗与几率 / 材料4 / 合成回包 ===")
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 == null:
		收尾("说明与材料：没有 GameSession")
		return
	var 快照: Array = (会.inventory as Array).duplicate(true)
	var 旧金币 := int(会.player_stats.get("gold", 0))
	会.inventory.clear()
	会.inventory.append(_料条(1, "01200010", "稻荷玉链", 1))
	会.inventory.append(_料条(2, "13100000", "勾玉（1级）", 1))
	会.inventory.append(_料条(3, "13100014", "勾玉（15级）", 1))
	会.inventory.append(_料条(4, "16000031", "精玉灵珠", 2))
	会.inventory.append(_料条(5, "13100000", "勾玉（1级）", 3))
	会.inventory.append(_料条(6, "01200060", "八尺琼玉链", 1))
	会.inventory.append(_料条(7, "13100000", "勾玉（1级）", 6))
	会.player_stats["gold"] = 200000
	var 窗 := _窗()

	# ① 带物品开一次 → 关掉重开：三页都不许留残影图标（用户说的「都默认放入一个玉链图标」）
	控制器.新会话()
	窗.set("_jade_item", _料条(1, "01200010", "稻荷玉链", 1))
	窗.call("_render_page")
	await _等(3)
	var 页 := _页()
	_记(int(控制器.料(0).get("slot_index", 0)) == 1,
			"带物品开窗 ⇒ 那件确实落到页0（先证「带得进去」，否则下面的空态是假绿）")
	窗.call("close")
	await _等(1)
	管.call("打开", 页名)
	await _等(4)
	页 = _页()
	var 带 = 窗.get("_jade_item")
	_记(typeof(带) == TYPE_DICTIONARY and (带 as Dictionary).is_empty(),
			"重开一次 ⇒ 宿主不再留着上一件的 `_jade_item`（原版 `selectedBtnHandler:96-98` 装完即置 null），实测 %s" % str(带))
	var 空料对 := true
	for i in 3:
		if not 控制器.料(i).is_empty():
			空料对 = false
	_记(空料对, "重开一次 ⇒ 三页料全空（`开窗` 那一轮复位），实测 %s"
			% str([控制器.料(0), 控制器.料(1), 控制器.料(2)]))
	var 残影: Array = []
	for 路 in [投料格路[0], 投料格路[1], 投料格路[2], 结果格路[0], 结果格路[1]]:
		for 名 in ["投料图标", "结果图标"]:
			var 图 := (页.get_node(路) as Control).get_node_or_null(名) as TextureRect
			if 图 != null and 图.texture != null:
				残影.append(路 + "/" + 名)
	_记(残影.is_empty(), "重开一次 ⇒ 三枚投料格 / 两枚结果格**一个图标都没有**（用户报的「三个子面板都默认放入玉链图标」），实测残留 %s" % str(残影))

	# ② 页0：消耗/几率接的是 `special.stageup.stage2` = 100000 / 50
	控制器.收料(窗, 页, 0, 1)
	await _等(1)
	var 期0 := "[color=#ffffff]本次操作消耗金币：100000\n本次操作成功几率：50%[/color]"
	_记(_说明文(页, 0) == 期0,
			"页0 玉链1阶 ⇒ 说明块 = %s（`YuLianUpgragePanel.setConfigure:187-190` + `updateDescription:193-220`），实测「%s」"
			% [期0, _说明文(页, 0)])
	会.player_stats["gold"] = 0
	控制器.刷新页(页, 窗, 0)
	var 期0红 := "[color=#ffffff]本次操作消耗金币：[color=#ff0000]100000[/color]\n本次操作成功几率：50%[/color]"
	_记(_说明文(页, 0) == 期0红,
			"金币 0 < 100000 ⇒ 那个数换红（`updateDescription:196-197`），实测「%s」" % _说明文(页, 0))
	会.player_stats["gold"] = 200000
	控制器.刷新页(页, 窗, 0)

	# ③ 页1：说明 = 「若合成失败…」+ 0 金币 + 100%（jade.merge.level2；needMoney 写死 0）
	#    ⚠ 那两句**各自一个 `<font>` 块**：`updateDescription:181` 是
	#    `DESCS[2] + "<br/>" + 模板` —— 语言表里 DESCS_3 自己带 `<font>…</font>`、
	#    模板（EQUIP_STRENGTH_DESC_TEMPLATE_0）也自己带白字包 ⇒ 不是一整块白字。
	控制器.切页(页, 1)
	await _等(1)
	控制器.收料(窗, 页, 1, 2)
	await _等(1)
	var 期1 := "[color=#ffffff]若合成失败不会对勾玉本身造成任何影响[/color]\n[color=#ffffff]本次操作消耗金币：0\n本次操作成功几率：100%[/color]"
	_记(_说明文(页, 1) == 期1,
			"页1 勾玉1级 ⇒ 「若合成失败…」+ 0 金币 + 100%%（`GouYuCompositePanel.updateDescription:148-182` + `setConfigure:296-306` 的 `needMoney = 0`），实测「%s」"
			% _说明文(页, 1))

	# ④ 材料4：角标 = 需要数、灰 = 拥有 < 需要（用户报的「精玉灵珠始终是灰色」）
	var 珠 := 页.get_node(珠格) as Control
	var 珠数 := 珠.get_node("材料4格_数量") as Label
	var 珠图 := 珠.get_node("材料4格_图标") as TextureRect
	_记(珠数.text == "1", "材料4 角标 = 需要数 1（`getNeedItemCout`: 1 × ⌊1/3⌋ → 不足一批按 1），实测「%s」" % 珠数.text)
	_记(珠.material == null and 珠数.material == null and 珠图.material == null,
			"背包有 2 颗精玉灵珠 ≥ 需要 1 ⇒ **整格不灰**（`updateDescription:161-170`；用户报的「始终是灰色」），实测 %s/%s/%s"
			% [str(珠.material), str(珠数.material), str(珠图.material)])
	会.inventory[3] = {}
	控制器.刷新页(页, 窗, 1)
	_记(珠.material is ShaderMaterial and 珠.material == 珠数.material and 珠.material == 珠图.material,
			"背包 0 颗 < 需要 1 ⇒ 格/图标/数量**三层同一份灰**（`ItemCaiLiaoBox.applyGrayFilter`）")
	会.inventory[3] = _料条(4, "16000031", "精玉灵珠", 2)
	控制器.收料(窗, 页, 1, 7)		# 勾玉 ×6 ⇒ 需要 2
	await _等(1)
	_记(珠数.text == "2", "勾玉 ×6 ⇒ 需要数 = 1 × ⌊6/3⌋ = 2（不是恒 1），实测「%s」" % 珠数.text)
	_记(珠.material == null, "拥有 2 == 需要 2 ⇒ 不灰（判据是 `拥有 < 需要`，等于不灰）")
	会.inventory[3] = _料条(4, "16000031", "精玉灵珠", 1)
	控制器.刷新页(页, 窗, 1)
	_记(珠.material is ShaderMaterial, "拥有 1 < 需要 2 ⇒ 又变灰")
	会.inventory[3] = _料条(4, "16000031", "精玉灵珠", 2)

	# ⑤ 1042 回包落三格（页1 在场时接管）：成功 2 / 退还 1 / 剩余 3
	控制器.收料(窗, 页, 1, 2)
	await _等(1)
	_清通知()
	# 通用那句走的是 `_show_hint` → 窗口的 `_status` 标签（不是 `notification_requested`），
	# 所以「不发提示」这条腿必须读那个标签 —— 读通知总线的话它恒绿（M4 变异也抓不到）。
	var 状态 := 窗.get("_status") as Label
	if 状态 != null:
		状态.text = ""
	窗.call("_on_item_change_result", 1042, {
		"kind": "stone_merge", "success_count": 2, "success_item_id": 13100001, "success_level": 3,
		"failed_count": 1, "failed_item_id": 13100000, "left_count": 3, "left_item_id": 13100000})
	await _等(4)
	页 = _页()
	_记(int(控制器._合成结果.get("success_count", 0)) == 2 and 控制器.料(1).is_empty(),
			"页1 收到 1042 ⇒ 结果存下、投料被清（`GouYuCompositePanel.operationResultHandler:61-103`）")
	var 期数 := ["2", "1", "3"]
	var 期id := ["13100001", "13100000", "13100000"]
	var 材歪: Array = []
	for i in 3:
		var 格 := 页.get_node(材料格路[i]) as Control
		var 图 := 格.get_node_or_null("材料图标") as TextureRect
		var 标 := 格.get_node_or_null("材料数量") as Label
		var 皮 := "" if 图 == null or 图.texture == null else String(图.texture.resource_path)
		if 图 == null or not 皮.contains(期id[i]) or 标 == null or 标.text != 期数[i]:
			材歪.append([i, 皮.get_file(), "" if 标 == null else 标.text])
	_记(材歪.is_empty(),
			"成功/退还/剩余三格 = 2×勾玉2级 / 1×勾玉1级 / 3×勾玉1级（图标 + 右下角标；用户报的「不显示数量」），实测 %s" % str(材歪))
	var 状态文 := "" if 状态 == null else String(状态.text)
	_记(状态 != null and not 状态文.contains("宝石合成"),
			"勾玉合成回包**不发**通用那句「宝石合成结果：…」（原版这一支只填格、不弹提示），实测「%s」" % 状态文)

	# ⑥ 「放入」钮 = 弹清单（原版 `UpShelfCursor`），不是只回显一句拖放指引
	_清通知()
	await 点钮(_钮(页, 投料钮路[1]))
	await _等(1)
	var 弹 = 控制器._选择器
	var 文列: Array = []
	if is_instance_valid(弹):
		for i in 弹.item_count:
			文列.append(弹.get_item_text(i))
	_记(is_instance_valid(弹) and String(弹.name) == "放入选择",
			"没料点「放入/取出」钮 ⇒ 弹「放入选择」清单（`_点投料` → `_弹选择`；用户报的「按钮功能没实装」）")
	_记(文列 == ["勾玉（1级） ×1", "勾玉（15级） ×1", "勾玉（1级） ×3", "勾玉（1级） ×6"],
			"页1 清单只列收得下的勾玉、一条一摞（名称 ×数量），实测 %s" % str(文列))
	if is_instance_valid(弹):
		_清通知()
		弹.id_pressed.emit(1)		# 第 2 条 = 勾玉 15 级（满级）
		await _等(1)
		_记(_尾通知() == "该勾玉已经是最高等级！" and 控制器.料(1).is_empty(),
				"清单里选满级勾玉 ⇒ 「该勾玉已经是最高等级！」、不收（`validateItem:288-292`），实测「%s」" % _尾通知())
		弹.hide()
		await _等(1)
		await 点钮(_钮(页, 投料钮路[1]))
		await _等(1)
		弹 = 控制器._选择器
		if is_instance_valid(弹):
			弹.id_pressed.emit(2)		# 第 3 条 = 勾玉 ×3
		await _等(1)
	_记(int(控制器.料(1).get("quantity", 0)) == 3 and _钮(页, 投料钮路[1]).text == "取出勾玉",
			"清单里选勾玉 ×3 ⇒ 真放进投料格（记整摞 3 枚）、钮文字「取出勾玉」")
	if is_instance_valid(弹):
		弹.hide()
	await _等(1)
	await 点钮(_钮(页, 投料钮路[1]))
	await _等(1)
	_记(控制器.料(1).is_empty() and _钮(页, 投料钮路[1]).text == 投料文[1],
			"有料再点同一枚 ⇒ 取出（清料 + 钮文字翻回「%s」），实测「%s」" % [投料文[1], _钮(页, 投料钮路[1]).text])

	# ⑦ 页0 / 页2 的清单与各页闸门
	控制器.切页(页, 0)
	await _等(1)
	_清通知()
	await 点钮(_钮(页, 投料钮路[0]))
	await _等(1)
	弹 = 控制器._选择器
	var 文0: Array = []
	if is_instance_valid(弹):
		for i in 弹.item_count:
			文0.append(弹.get_item_text(i))
	_记(文0 == ["稻荷玉链 ×1", "八尺琼玉链 ×1"],
			"页0 清单只列玉链（满阶那条也列 —— 类型闸过了，满阶闸在 `validateItem` 那道），实测 %s" % str(文0))
	if is_instance_valid(弹):
		_清通知()
		弹.id_pressed.emit(1)		# 第 2 条 = 八尺琼玉链（满阶）
		await _等(1)
		_记(_尾通知() == "该玉链已经是最高阶！" and 控制器.料(0).is_empty(),
				"清单里选满阶玉链 ⇒ 「该玉链已经是最高阶！」、不收（`validateItem:88-92`），实测「%s」" % _尾通知())
		弹.hide()
		await _等(1)
		await 点钮(_钮(页, 投料钮路[0]))
		await _等(1)
		弹 = 控制器._选择器
		if is_instance_valid(弹):
			弹.id_pressed.emit(0)
		await _等(1)
	var 投图 := 页.get_node_or_null(投料格路[0] + "/投料图标") as TextureRect
	_记(int(控制器.料(0).get("slot_index", 0)) == 1 and _钮(页, 投料钮路[0]).text == "取出玉链"
			and 投图 != null and 投图.texture != null,
			"清单里选稻荷玉链 ⇒ 真放进投料格（槽 1、格里有图标、钮文字「取出玉链」）—— 用户报的「放入钮没实装」")
	if is_instance_valid(弹):
		弹.hide()
	await 点钮(_钮(页, 投料钮路[0]))
	await _等(1)
	_记(控制器.料(0).is_empty() and _钮(页, 投料钮路[0]).text == 投料文[0],
			"页0 有料再点同一枚 ⇒ 取出（清料 + 「%s」）" % 投料文[0])
	控制器.切页(页, 2)
	await _等(1)
	_清通知()
	await 点钮(_钮(页, 投料钮路[2]))
	await _等(1)
	弹 = 控制器._选择器
	if is_instance_valid(弹):
		弹.id_pressed.emit(2)		# 勾玉 ×3
		await _等(1)
	_记(int(控制器.料(2).get("quantity", 0)) == 3 and _钮(页, 投料钮路[2]).text == "取出勾玉",
			"页2 清单里选勾玉 ×3 ⇒ 整摞收下、钮文字「取出勾玉」（不再要求拆成1个），实测料 %s" % str(控制器.料(2)))
	if is_instance_valid(弹):
		弹.hide()

	控制器.切页(页, 0)
	控制器.新会话()
	会.inventory.assign(快照)
	会.player_stats["gold"] = 旧金币
	await _等(2)


## ── ⑧ 成对摆位（centerTwoWindow）───────────────────────────────────────────
##
## 原版 `:3170-3171`：主窗 `setLocationCenter` 按**自己**高度居中、伙伴 `y = 主.y`（顶边平齐）。
## 2026-10-31 起背包 556 高（10 行一屏全露）⇒ 它跟着 407 高的勾玉窗居中会垂出下沿 72px，
## 所以背包单独夹进屏内（y = 560-556 = 4），**顶边因此不再平齐**；主窗仍按原版 76。
## 下面三个数（76 / 4 / 560）都是门里写死的真值，不向被测对象要。
func _量成对() -> void:
	日志.append("=== 开窗要连背包一起开：主窗照原版居中、背包整扇留在屏内 ===")
	var 主 := _窗()
	var 包 = 管._窗口们.get("背包")
	_记(包 != null, "开这扇时背包**同步开**（`UIMain2.as:3852` `centerTwoWindow(这扇, ITEM_WINDOW2_F)`）")
	if 包 == null:
		return
	var a: Control = 主._window
	var b: Control = 包.get("_window") as Control
	_记(absf(a.get_global_position().y - 76.0) < 1.2,
			"主窗仍按原版自己高度竖直居中（(560-407)/2 = 76），实测 y %.1f"
			% a.get_global_position().y)
	_记(absf(b.get_global_position().y - 4.0) < 1.2,
			"背包（556 高）夹到屏内：560-556 = 4，实测 y %.1f" % b.get_global_position().y)
	_记(b.get_global_position().y >= -0.5
			and b.get_global_position().y + b.size.y <= 560.5,
			"背包整扇在 960x560 里（顶 %.1f / 底 %.1f）—— 随身药店、神秘商店那几行不能出屏"
			% [b.get_global_position().y, b.get_global_position().y + b.size.y])
	_记(b.get_global_position().x >= a.get_global_position().x + a.size.x - 1.5,
			"背包贴在主窗右侧（不叠在主窗上），实测 主右沿 %.0f、背包左 %.0f"
			% [a.get_global_position().x + a.size.x, b.get_global_position().x])


## ── ⑧ 编辑器 == 运行期：读 .tscn 文本比对开屏态 ─────────────────────────────
func _量烘值() -> void:
	日志.append("=== 场景烘的开屏态 == 运行期第一帧（读 .tscn 文本，不读运行期值）===")
	var 文 := FileAccess.get_file_as_string(场景路)
	_记(文.contains("[node name=\"页签0\"") and 文.contains("disabled = true"),
			"页签0 在 .tscn 里就 `disabled = true`（编辑器里就是选中态）")
	var 块 := 文.substr(文.find("[node name=\"面板1\""))
	块 = 块.substr(0, 块.find("[node name=", 10))
	_记(块.contains("visible = false"),
			"面板1 在 .tscn 里就 `visible = false`（开屏只有面板0 可见 ⇒ 编辑器与运行期同一态）")
	_记(文.contains("text = \"开始进阶\""), "提交钮烘的文字 = 开始进阶")
	_记(文.contains("text = \"取出玉链\""), "投料钮烘的文字含「取出玉链」（原版串号也一起烘，别只在运行期改）")
	_记(文.count("texture_margin_bottom = 4.75") >= 3,
			"三枚页签的未选皮边距 = §4.2 真值 4.75 下边距（不是旧的拟合值 7）")
	# ↓ 三条是 2026-10-05 拿实机图打回后补的（分隔线 / 精玉灵珠 / 两轴居中）——烘进场景才算数
	_记(文.contains("横向分隔线.png") and 文.count("type=\"ColorRect\"") == 0,
			"场景里**一枚 ColorRect 都没有**、五枚分隔线烘的都是 `横向分隔线.png`（= 原版 `LineHPicF`）⇒ 那条线是**图**，不是自造的色条")
	_记(文.contains(珠编号),
			"精玉灵珠那张图标**烘在 .tscn 里**（编辑器里就看到，不是运行期才长出来）")
	var 结 := _节(文, "结果文0")
	var 重 := _节(文, "重置结果文")
	_记(结.contains("horizontal_alignment = 1") and 结.contains("offset_top = 22.5")
			and 重.contains("horizontal_alignment = 1") and 重.contains("offset_top = 30.5"),
			"两块「本次操作…」在 .tscn 里就写着居中与居中后的 y（22.5 / 30.5），实测 结果文0 %s / 重置结果文 %s"
			% ["√" if 结.contains("horizontal_alignment = 1") else "缺",
				"√" if 重.contains("horizontal_alignment = 1") else "缺"])


## 取 `.tscn` 里某个节点自己的属性块（到下一个 `[node ` 为止）—— 烘值只能读文本，读运行期值等于自证。
func _节(文: String, 名: String) -> String:
	var 头 := 文.find("[node name=\"%s\"" % 名)
	if 头 < 0:
		return ""
	var 尾 := 文.find("[node ", 头 + 10)
	return 文.substr(头, 尾 - 头) if 尾 > 头 else 文.substr(头)
