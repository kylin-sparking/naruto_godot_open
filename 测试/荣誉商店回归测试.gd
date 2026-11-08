extends SceneTree
## 荣誉类页签（#50 / §3.227）离线门：`数据/荣誉商店.json` 那张表、`2323 MUYE_BATTLE` 的
## 收发两头，以及商城页「荣誉类」那一面的渲染与点击。
## 参照值手抄自 `真值/窗口/商城窗口.md` 的荣誉页一节，AS3 出处
## `RongYuPanel.as:91-107` / `RongYuItemCell.as:50-101,136-144,151-154,175-196` /
## `MuYeDaZhanManager.onMuyeBattle_updateFamePoint:599-625` / `CashShopWindow2.as:129-138,375-378`，
## **不从被测场景反查**。
##
## 覆盖：① 表 = 11 行 (itemId, famePoint) **按 GameData 键序**字面钉 + 每行物品在 GameData 查得到
## ② 下行 `2323:8:<积分>` ⇒ 存进 `authoritative_muye_battle.fame_point` 并发一次信号（**0 也要发**）
## ③ 动作 0/1/3/7 与畸形帧全是静默 no-op，且**不许**碰积分（只有 8 是积分的来源）
## ④ 上行 `2323:3:<id>:<数量>`：默认数量 1、id/数量非法不发且返回 false
## ⑤ 点「荣誉类」页签 ⇒ **一发 432 都不许有**（含正向对照：点「药品类」必须把标记踩下去）
##    + 分页条隐 / 商品列表框**仍显**（原版同矩形轮换）/ 11 行荣誉行 / 没有「还没接」占位
## ⑥ 一行逐件矩形、字号 12、三处颜色、文案「荣誉：」「兑换」、千分位、荣誉值宽 = 文字宽 + 3
## ⑦ 窗开着时来一帧 `2323:8:` ⇒ 「荣誉积分值」改写，且荣誉三件**不再被藏**
## ⑧ 点「兑换」⇒ 恰好一帧 `3:<id>:1`、**不做任何本地成功动作**（不写死加物品、不提示成功）
##
## ⚠ 三条口径：
##   · 本门**不碰 `user://`**：④⑧ 的出帧走 `测试/测试后端连接.gd` 那份替身（只记不写 socket）；
##     ⑤ 只是把真后端的 `in_game` 临时置真来让 `游戏会话._online_backend()` 认它 —— 真后端的
##     `send_game_request` 还要 `_tcp` 已连，无头下永远 false ⇒ 一帧也出不去，跑完立刻改回 false。
##   · `_shop_tab` 是**宿主窗口**上的变量（页面每来一帧整棵重建），所以点完页签要重新找控件；
##   · `"…" % 一个 Array` 会被当成 N 个格式参数 ⇒ 运行时报错、门假绿 ⇒ 一律 `% [值]` 或 `str(值)`。
##
## 跑法：Godot --headless --path . --script res://测试/荣誉商店回归测试.gd

const 窗场景路径 := "res://场景/界面/功能窗口.tscn"
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 数字格式 := preload("res://脚本/界面/数字格式.gd")

## 荣誉表真值（GameData `MuyeBattle.shop` 的键序 0..10）。⚠ **行序就是显示序**：
## 按 famePoint 排会变成 2,3,5,6,10,20,30,40,50,100,1000，按 itemId 排会把 1000 那件排到最前，
## 两种都不是原版玩家看到的那一列（`RongYuPanel.setData` 直接按 Object 键序往 List 里塞）。
const 荣誉表 := [[1410001, 1000], [13200000, 2], [16000035, 50], [16000015, 5],
				[11010077, 10], [15028002, 3], [15028001, 40], [11020006, 30],
				[11020012, 6], [11020016, 100], [11010099, 20]]

## `RongYuItemCell` 行局部坐标（`init()` + `setLabel()` 的 `y = 传入y − 2`）。
## 荣誉值那一件宽度运行时改成「文字宽 + 3」（`:94-101,188`）⇒ 这里只当**起始**烘值看，
## 实际断言拆成 x/y/高 三项 + 单独的宽度腿。
const 行件 := {"物品格": [10.0, 10.0, 40.0, 40.0], "物品格/图标": [3.0, 3.0, 34.0, 34.0],
				"名称": [55.0, 10.0, 117.0, 18.0], "荣誉标签": [55.0, 28.0, 43.0, 18.0],
				"荣誉值": [90.0, 28.0, 18.0], "说明": [175.0, 0.0, 350.0, 54.0],
				"兑换": [532.0, 22.0, 37.0, 22.0], "分隔线": [0.0, 60.0, 592.0, 2.0]}
const 行高 := 62.0
const 行宽 := 592.0
const UI_BLUE := Color(0.117647, 0.564706, 1.0, 1.0)		# 2003199 = #1E90FF
const UI_GREEN := Color(0.0, 1.0, 0.0, 1.0)				# 65280
const UI_WHITE := Color(1.0, 1.0, 1.0, 1.0)				# 16777215

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 场: Node = null
var 会话: Node = null
var 后: Node = null
var 内容: Control = null
var 帧数 := 0
var 通知: Array = []


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)


func _矩形(件: Control) -> Array:
	return [件.offset_left, 件.offset_top,
			件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 参.size():
		return false
	for i in 实.size():
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


func _找(根节点: Node, 名: String) -> Node:
	for 子 in 根节点.get_children():
		if String(子.name) == 名:
			return 子
		var 深 := _找(子, 名)
		if 深 != null:
			return 深
	return null


func _等(个数: int) -> void:
	for i in 个数:
		await process_frame


func _喂(原文: String) -> void:
	后.call("_handle_bridge_text", 原文)


func _积分() -> int:
	return int((后.get("authoritative_muye_battle") as Dictionary).get("fame_point", -1))


## ① 表本体：行、序、值，外加"每行都能在 GameData 查到物品"（名字/图标/说明全靠它）。
func _一_荣誉表() -> void:
	var 条: Array = 游戏数据.荣誉商店()
	_判(条.size() == 荣誉表.size(), "荣誉表 %d 行，应为 %d 行" % [条.size(), 荣誉表.size()])
	var 实测: Array = []
	for 行 in 条:
		实测.append([int((行 as Dictionary).get("itemId", 0)), int((行 as Dictionary).get("famePoint", -1))])
	_判(实测 == 荣誉表, "荣誉表逐行 (itemId, famePoint) 应为 %s，实得 %s" % [str(荣誉表), str(实测)])
	var 按积分: Array = 荣誉表.map(func(x: Array) -> Array: return x.duplicate())
	按积分.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	_判(实测 != 按积分, "行序被排过（正好等于按 famePoint 升序）⇒ 显示顺序和原版不一样")
	var 查不到: Array = []
	for 对 in 荣誉表:
		if ((游戏数据.item(str(int(对[0]))) as Dictionary) as Dictionary).is_empty():
			查不到.append(对[0])
	_判(查不到.is_empty(), "这几件在 GameData 里查不到 ⇒ 名字/图标/说明全是空的：%s" % str(查不到))


## ② 唯一的那条积分帧：存值 + 发信号，且 **0 也是合法值**。
func _二_下行积分帧() -> void:
	后.set("authoritative_muye_battle", {"fame_point": 0})
	帧数 = 0
	if not 后.荣誉积分帧.is_connected(_记帧):
		后.荣誉积分帧.connect(_记帧)
	_喂("2323:8:1234")
	_判(_积分() == 1234 and 帧数 == 1,
			"`2323:8:1234` ⇒ fame_point 应为 1234 且发一帧信号，实得 %s / %d 次" % [str(_积分()), 帧数])
	_喂("2323:8:0")
	_判(_积分() == 0 and 帧数 == 2,
			"原版 `onMuyeBattle_updateFamePoint` 无条件赋值，用 `if 积分:` 判会漏掉 0 "
			+ "⇒ 积分清零帧 `2323:8:0` 被吞了（fame=%s、%d 次）" % [str(_积分()), 帧数])


func _记帧(值: int) -> void:
	帧数 += 1
	_判(值 >= 0, "信号里带出来一个负积分：%d" % 值)


## ③ 其余动作号 + 畸形帧 ⇒ 静默收下，一不能改积分、二不该吵。
## （3 线登录本来就会白收 `2323:0:0:1800`；一 push_warning 就是每次上线刷一行噪声。）
func _三_其余动作静默() -> void:
	_喂("2323:8:777")
	帧数 = 0
	for 原文 in ["2323:0:0:1800", "2323:1:1:2:3:4:5", "2323:3:1410001:0", "2323:7:1",
			"2323:8:", "2323:8", "2323:8:abc", "2323", "2323:8:12.5"]:
		_喂(原文)
	_判(_积分() == 777 and 帧数 == 0,
			"动作 0/1/3/7 与畸形帧（段数不够 / 非整数 / 小数）里有一跳动了积分或发了信号："
			+ "（应停在 777 / 0 次）fame=%s、信号 %d 次" % [str(_积分()), 帧数])
	# 别的 opcode 也带个 `:8:` 不该串味（`match` 走的是 opcode，不是段数）
	_喂("9999:8:5")
	_判(_积分() == 777, "别的 opcode 被当 2323 收了 ⇒ fame=%s" % str(_积分()))


## ④ 上行线格式：`3:<id>:<数量>`，默认数量 1；非法值一帧不发。
func _四_上行线格式() -> void:
	var 线 := 测试后端.new()
	_判(bool(线.request_muye_prize(1410001)) and 线.sent_requests.size() == 1
			and int(线.sent_requests[0]["opcode"]) == 2323
			and str(线.sent_requests[0]["content"]) == "3:1410001:1",
			"兑换上行 = `2323` 的 `3:<id>:1`（原版 `RongYuItemCell.buyBtnClick:151-154` 恒传数量 1），"
			+ "实得 %s" % str(线.sent_requests))
	线.sent_requests.clear()
	线.request_muye_prize(13200000, 5)
	_判(线.sent_requests.size() == 1 and str(线.sent_requests[0]["content"]) == "3:13200000:5",
			"显式数量要带进报文，实得 %s" % str(线.sent_requests))
	线.sent_requests.clear()
	_判(not bool(线.request_muye_prize(0)) and not bool(线.request_muye_prize(-5))
			and not bool(线.request_muye_prize(1410001, 0)) and 线.sent_requests.is_empty(),
			"id ≤ 0 / 数量 ≤ 0 应返回 false 且一帧不发，实发 %s" % str(线.sent_requests))
	线.free()


## ⑤ 点「荣誉类」页签：只切面板、不发商品请求。
## 判式用 `游戏会话.request_cash_shop` 的**入口副作用**当标记（进函数就
## `cash_shop_loading = true` + `server_cash_shop_loaded = true` + `shop_catalog.clear()`）；
## 正向对照点「药品类」必须把标记踩下去，否则这条腿是空转。
func _五_页签不发请求() -> void:
	var 页签们: Array = (场.call("_取商城分页表") as Dictionary).get("页签", []) as Array
	var 荣誉下标: int = 页签们.find("荣誉类")
	_判(荣誉下标 >= 0, "分页表里没有「荣誉类」页签：%s" % str(页签们))
	if 荣誉下标 < 0:
		return
	_判(bool(场.call("_是商城荣誉页", 荣誉下标)) and not bool(场.call("_是商城荣誉页", 0)),
			"`_是商城荣誉页` 判反了（荣誉下标=%s）" % str(荣誉下标))
	后.set("in_game", true)
	var 原: Array[Dictionary] = 会话.shop_catalog
	var 哨: Array[Dictionary] = [{"id": "1410001", "sn": 1, "price": 1000, "name": "哨兵"}]
	会话.shop_catalog = 哨
	会话.set("cash_shop_loading", false)
	var 提示起点 := 通知.size()
	var 页签 := _找(内容, "页签%d" % 荣誉下标) as Button
	_判(页签 != null, "商城页里找不到「页签%d」（荣誉类）" % 荣誉下标)
	if 页签 == null:
		会话.shop_catalog = 原
		后.set("in_game", false)
		return
	页签.pressed.emit()
	await _等(3)
	_判(not bool(会话.get("cash_shop_loading")) and (会话.shop_catalog as Array).size() == 1
			and str((会话.shop_catalog[0] as Dictionary).get("id", "")) == "1410001"
			and not bool(会话.get("server_cash_shop_loaded")),
			"点「荣誉类」却走了 `request_cash_shop`（432）：loading=%s catalog=%s loaded=%s" % [
				str(会话.get("cash_shop_loading")), str(会话.shop_catalog),
				str(会话.get("server_cash_shop_loaded"))])
	var 串味 := false
	for i in range(提示起点, 通知.size()):
		if str(通知[i]).contains("还没接") or str(通知[i]).contains("未接"):
			串味 = true
	_判(not 串味, "荣誉页还留着「还没接」占位提示：%s" % str(通知.slice(提示起点)))
	var 页 := _找(内容, "原版商城窗口内容") as Control
	var 列表 := 页.get_node("商品列表框/商品滚动/商品列表") as Control
	_判(not (页.get_node("分页条") as Control).visible and (页.get_node("商品列表框") as Control).visible,
			"荣誉页应藏分页条、**留**商品列表框（原版 rongYuPanel 与 listBg 占同一矩形轮换）")
	_判(列表.get_child_count() == 荣誉表.size(),
			"荣誉页应渲染 %d 行，实得 %d" % [荣誉表.size(), 列表.get_child_count()])
	_判(int(场.get("_shop_tab")) == 荣誉下标, "点完页签 _shop_tab = %s" % str(场.get("_shop_tab")))
	# 正向对照：普通页签**必须**踩标记，不然上面那条"没踩"什么也没证明
	会话.set("cash_shop_loading", false)
	var 药 := _找(内容, "页签1") as Button
	_判(药 != null, "找不到「页签1」（正向对照用）")
	if 药 != null:
		药.pressed.emit()
		await _等(3)
		_判(bool(会话.get("cash_shop_loading")) and (会话.shop_catalog as Array).is_empty(),
				"点「药品类」也没进 `request_cash_shop` ⇒ ⑤ 那条判式是空转"
				+ "（loading=%s catalog=%s）" % [str(会话.get("cash_shop_loading")), str(会话.shop_catalog)])
	会话.shop_catalog = 原
	后.set("in_game", false)
	会话.set("cash_shop_loading", false)
	# 回到荣誉页再跑后面的渲染腿
	场.call("_set_shop_tab", 荣誉下标)
	await _等(3)


## ⑥ 一行 `RongYuItemCell` 的逐件版式（第一行 famePoint=1000 ⇒ 有千分位；第二行 = 2 ⇒ 没有）。
func _六_一行版式() -> void:
	var 页 := _找(内容, "原版商城窗口内容") as Control
	var 列表 := 页.get_node("商品列表框/商品滚动/商品列表") as Control
	var 行们 := 列表.get_children()
	if 行们.size() < 2:
		_判(false, "荣誉行不足两行，⑥ 做不了（实得 %d 行）" % 行们.size())
		return
	for index in 行们.size():
		var 行 := 行们[index] as Panel
		_判(_近([行.position.x, 行.position.y, 行.size.x, 行.size.y], [0.0, 行高 * index, 行宽, 行高]),
				"第 %d 行落位应为 (0, %s, %s, %s)（`RongYuPanel.setData` 的 `y = height * index`），实得 %s" % [
					index, str(行高 * index), str(行宽), str(行高),
					str([行.position.x, 行.position.y, 行.size.x, 行.size.y])])
		for 名 in ["物品格", "物品格/图标", "名称", "荣誉标签", "兑换", "分隔线"]:
			var 件 := 行.get_node_or_null(名) as Control
			_判(件 != null and _近(_矩形(件), 行件[名]),
					"第 %d 行 %s 矩形应为 %s，实得 %s" % [index, 名, str(行件[名]),
						str(_矩形(件)) if 件 != null else "没建"])
		var 值 := 行.get_node("荣誉值") as Label
		_判(_近([值.offset_left, 值.offset_top, 值.size.y], 行件["荣誉值"]),
				"第 %d 行 荣誉值 起点/高应为 %s，实得 %s" % [index, str(行件["荣誉值"]),
					str([值.offset_left, 值.offset_top, 值.size.y])])
		var 应文 := 数字格式.千分位(int(荣誉表[index][1]))
		_判(值.text == 应文, "第 %d 行 荣誉值应为「%s」（`formatNumber`），实得「%s」" % [index, 应文, 值.text])
		_判(absf(值.size.x - (_文字宽(值) + 3.0)) < 0.51,
				"第 %d 行 荣誉值宽应为 文字宽 + 3（`:94-101`），实得 %.1f / 字宽 %.1f" % [
					index, 值.size.x, _文字宽(值)])
		var 说明 := 行.get_node("说明") as RichTextLabel
		_判(说明.size.x == 行件["说明"][2] and 说明.offset_left == 行件["说明"][0],
				"第 %d 行 说明框应是 x=175、宽 350（`itemInfo.width = 350`），实得 x=%.1f 宽=%.1f" % [
					index, 说明.offset_left, 说明.size.x])
		_判(说明.size.y >= 说明.get_content_height() - 0.51 and 说明.size.y <= 行高
				and 说明.position.y >= -0.01 and 说明.position.y <= 行高 - 说明.size.y + 0.01,
				"第 %d 行 说明框没包住正文或跑出 62 行高：高 %.1f / 正文 %.1f / y %.1f（`:191-192`）" % [
					index, 说明.size.y, 说明.get_content_height(), 说明.position.y])
	var 首 := 行们[0] as Panel
	var 次 := 行们[1] as Panel
	_判((首.get_node("荣誉值") as Label).text == "1,000" and (次.get_node("荣誉值") as Label).text == "2",
			"千分位只该在 ≥1000 那一件上：第一行「%s」第二行「%s」" % [
				(首.get_node("荣誉值") as Label).text, (次.get_node("荣誉值") as Label).text])
	_判((首.get_node("名称") as Label).text == str(游戏数据.item_name("1410001")),
			"名称应取 GameData（`StringTool.getItemStringObject`），实得「%s」" % (首.get_node("名称") as Label).text)
	_判((首.get_node("物品格/图标") as TextureRect).texture != null, "第一行的图标是空的")
	_判((首.get_node("名称") as Label).get_theme_color("font_color") == UI_BLUE,
			"名称应为 UI_BLUE(#1E90FF)，实得 %s" % str((首.get_node("名称") as Label).get_theme_color("font_color")))
	_判((首.get_node("荣誉标签") as Label).get_theme_color("font_color") == UI_GREEN,
			"「荣誉：」应为 UI_GREEN，实得 %s" % str((首.get_node("荣誉标签") as Label).get_theme_color("font_color")))
	_判((首.get_node("荣誉值") as Label).get_theme_color("font_color") == UI_WHITE,
			"荣誉值应为 UI_WHITE，实得 %s" % str((首.get_node("荣誉值") as Label).get_theme_color("font_color")))
	_判((首.get_node("荣誉标签") as Label).text == "荣誉：",
			"售价文案应为「荣誉：」（SALE_RONGYU_LABEL），实得「%s」" % (首.get_node("荣誉标签") as Label).text)
	_判((首.get_node("兑换") as Button).text == "兑换",
			"按钮文案应为「兑换」（RONGYU_DUIHUAN），实得「%s」" % (首.get_node("兑换") as Button).text)
	_判(not (次.get_node("兑换") as Button).disabled,
			"兑换钮还灰着 —— 原版是 `data` setter 走完才 `enabled = true`（`:194`），"
			+ "构造时的 disable 只是场景初值")
	for 名 in ["名称", "荣誉标签", "荣誉值"]:
		_判((首.get_node(名) as Label).get_theme_font_size("font_size") == 12,
				"%s 字号应为 MLabel 默认 12，实得 %d" % [名, (首.get_node(名) as Label).get_theme_font_size("font_size")])
	_判((首.get_node("说明") as RichTextLabel).get_theme_constant("line_separation") == 2,
			"说明行距应为 `<textformat leading=\"2\">` 的 2，实得 %d"
			% (首.get_node("说明") as RichTextLabel).get_theme_constant("line_separation"))
	# 商城那行的控件**不该**出现在荣誉行里（`RongYuItemCell` 没创建原价/角标/货币图标）
	for 多余 in ["原价", "售价", "货币", "角标", "热卖"]:
		_判(首.get_node_or_null(多余) == null, "荣誉行里多了一件「%s」（原版没这控件）" % 多余)


## ⑦ 积分链：窗开着时**只喂帧**（不手动重渲染）⇒ `功能窗口` 挂的那条 `荣誉积分帧` 转发
## 把「荣誉积分值」改写；三件不藏。
func _七_积分回写() -> void:
	var 页 := _找(内容, "原版商城窗口内容") as Control
	var 值 := 页.get_node("荣誉积分值") as Label
	var 标签 := 页.get_node("荣誉积分标签") as Control
	var 底 := 页.get_node("荣誉积分底") as Control
	_判(标签.visible and 底.visible and 值.visible,
			"荣誉积分那三件又被藏起来了（2026-09-26 那次的遗留）—— 链已经接上，该回原版全显")
	_喂("2323:8:0")
	await _等(3)
	var 零页 := _找(内容, "原版商城窗口内容") as Control
	_判((零页.get_node("荣誉积分值") as Label).text == "0",
			"积分 0 时该显示「0」（原版 `_famePoint` 初值），实得「%s」" % (零页.get_node("荣誉积分值") as Label).text)
	_喂("2323:8:98765")
	await _等(3)
	var 新页 := _找(内容, "原版商城窗口内容") as Control
	var 新值 := 新页.get_node("荣誉积分值") as Label
	_判(新值.text == "98,765",
			"只喂一帧 `2323:8:98765`、不手动重渲染，积分栏就该改成「98,765」"
			+ "（`updateRongYu` + `formatNumber`，靠的是 `功能窗口` 挂的 `荣誉积分帧` 转发），实得「%s」" % 新值.text)
	_判(_积分() == 98765, "帧存进 backend 的值应为 98765，实得 %s" % str(_积分()))


## ⑧ 点「兑换」：恰好一帧 `3:<id>:1`，且没有任何本地成功动作。
func _八_点兑换() -> void:
	var 线 := 测试后端.new()
	var 原后: Node = 场.get("_backend")
	场.set("_backend", 线)
	var 提示起点 := 通知.size()
	var 页 := _找(内容, "原版商城窗口内容") as Control
	var 列表 := 页.get_node("商品列表框/商品滚动/商品列表") as Control
	var 第二行 := 列表.get_child(1) as Panel
	var 货架长 := (会话.shop_catalog as Array).size()
	(第二行.get_node("兑换") as Button).pressed.emit()
	await _等(2)
	_判(线.sent_requests.size() == 1 and int(线.sent_requests[0]["opcode"]) == 2323
			and str(线.sent_requests[0]["content"]) == "3:13200000:1",
			"点第二行「兑换」应恰好发一帧 `2323` 的 `3:13200000:1`，实得 %s" % str(线.sent_requests))
	_判((会话.shop_catalog as Array).size() == 货架长,
			"原版三条出口都只回 `2323:8:`，加物品走另一条库存帧 ⇒ 兑换不该有本地成功动作"
			+ "（货架从 %d 条变成 %d 条）" % [货架长, (会话.shop_catalog as Array).size()])
	var 报成功 := false
	for i in range(提示起点, 通知.size()):
		if str(通知[i]).contains("成功"):
			报成功 = true
	_判(not 报成功, "兑换还没等回帧就先报「成功」：%s" % str(通知.slice(提示起点)))
	_判(not str((场.get("_status") as Label).text).contains("没发出去"),
			"发出成功了却仍报「兑换请求没发出去」：状态行是「%s」" % str((场.get("_status") as Label).text))
	场.set("_backend", 原后)
	线.free()


func _文字宽(控件: Label) -> float:
	var 字体 := 控件.get_theme_font("font")
	return float(字体.get_string_size(控件.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 控件.get_theme_font_size("font_size")).x)


func _跑() -> void:
	print("荣誉商店回归测试开始")
	root.size = Vector2i(960, 560)		# ⚠ 不钉视口，无头下布局拿不到真实尺寸
	后 = root.get_node("BackendConnection")
	会话 = root.get_node_or_null("GameSession")
	_判(会话 != null, "门跑之前 `GameSession` 这个 autoload 必须在")
	_判(后.has_method("request_muye_prize") and 后.has_signal("荣誉积分帧"),
			"后端没有 2323 那半边（`request_muye_prize` / `荣誉积分帧`）")
	if not 后.has_method("request_muye_prize"):
		收尾()
		return
	if 会话.has_signal("notification_requested"):
		会话.connect("notification_requested", func(文: String) -> void: 通知.append(String(文)))
	_判(int(后.get("OP_MUYE_BATTLE")) == 2323, "opcode 常量应为 2323（收发同号），实得 %s"
			% str(后.get("OP_MUYE_BATTLE")))
	场 = (load(窗场景路径) as PackedScene).instantiate()
	root.add_child(场)
	await _等(4)
	内容 = 场.get("_content") as Control
	if 内容 == null:
		_判(false, "功能窗口没有 `_content`（后面的渲染腿都做不了）")
		收尾()
		return
	场.call("open_page", "商城")
	await _等(3)
	_判(_找(内容, "原版商城窗口内容") != null, "商城页没开出来（`原版商城窗口内容` 找不到）")
	if _找(内容, "原版商城窗口内容") == null:
		收尾()
		return

	后.set("authoritative_muye_battle", {"fame_point": 0})
	_判(_积分() == 0, "刚登录积分应是 0（原版 `_famePoint` 初值），实得 %s" % str(_积分()))
	_一_荣誉表()
	await _二_下行积分帧()
	await _三_其余动作静默()
	await _四_上行线格式()
	await _五_页签不发请求()
	await _六_一行版式()
	await _七_积分回写()
	await _八_点兑换()
	收尾()


func 收尾() -> void:
	if 后 != null:
		后.set("in_game", false)
		if 后.荣誉积分帧.is_connected(_记帧):
			后.荣誉积分帧.disconnect(_记帧)
	跑完了 = true
	if 失败 == 0:
		print("荣誉商店回归测试：通过（表 11 行按序 / 2323:8 唯一积分源且其余动作静默 / "
				+ "上行 3:<id>:1 / 荣誉页签不发 432（带正向对照）/ 逐件版式与千分位 / 积分回写不藏 / "
				+ "点兑换一帧且无本地成功动作），共 " + str(通过) + " 项")
	else:
		print("荣誉商店回归测试：通过 " + str(通过) + "，红 " + str(失败))
