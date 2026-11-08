extends SceneTree
## 摊位列表窗（原版 `StallListWindow` + `StallListItemRenderer`）离线门。
## 逐件参照值手抄自 `真值/窗口/摊位列表.md` 与 `2.2.3/.../controls/stall/*.as`，**不从被测场景反查**。
##
## 覆盖：① `1296:0:` 入帧（13 行、摊名带 `&` 的折回、`-` 空表、六段短行只丢那一条、
##          以及 `1296:1:` **不许**串到列表那条信号上）
##        ② 开窗那一跳：`打开或收起` ⇒ 窗开 + 发 `0:0:11`；背包**不**被连带叫出来
##        ③ 逐件矩形（底板/顶线/六列头/五竖线/五条斑马纹/列表区/底部三排）+ 字号 12 + 三种颜色
##        ④ 灌表只画 11 行（每页 11）、序号 = 页×11+序+1、六格、`moneynum` 不画、行 442×22、选中条 430×21
##        ⑤ 选中（单击换选中条）／双击 ⇒ 发 `1296:2:<payer_id>` 且**不**在本端开摊面窗
##        ⑥ 翻页：请求帧 `0:11:22` + 载入中 + 六枚一起灰；回帧 ⇒ 页码「2 / 2」、序号从 12 起、后向两枚回灰
##        ⑦ 搜索：空词只弹「请输入关键字！」一帧不发；非空 ⇒ `1:<data>:<词>:<起>:<止>`
##        ⑧ 刷新：词清、重载**当前页**；框里的字与下拉的显示**都不清**（原版的呆账，两条各钉一次）
##        ⑨ 总数 0 ⇒ 页码格**不写**（留着上一句）、四枚翻页钮全灰、「查看摊位／查看信息」照旧能点
##        ⑩ 下拉三项（顺序与 data 都不是递增）；换类目**不发帧**（`quickSearchHandler` 是死代码）
##        ⑪ 查看信息：摊主是自己 ⇒ 开自己的人物窗、一帧不发
##        ⑫ 关窗后到的回帧 ⇒ 不灌、窗不复活（原版 `if (stallListWindow)`）
##        ⑬ 再开窗 ⇒ 从第 0 页重发、框空、类目回「按物品名称」
##        ⑭ 尺寸表那条 + 不在 `伴随背包` + 不在 `居中弹`。
##
## 跑法：`Godot --headless --path . --script res://测试/摊位列表窗回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 管理脚本 := preload("res://脚本/界面/窗口管理.gd")
const 窗脚本 := preload("res://脚本/界面/窗口/摆摊/摊位列表窗.gd")

## 十三条摊：**总数照线给 13**（`_handle_stall_list` 读的是 `fields[2]`，不是行数），
## 于是 `总页 = ceil(13/11) = 2` ⇒ 第 0 页 11 行、第 1 页 2 行，序号连着排。
## 第 3 行的摊名故意带 `&`：服务端 `fake_flash_server.py:25431-25450` 是拿 `&`.join 直接拼的，
## 摊名里带分隔符就是一条**多一段**的坏行 ⇒ 钉住「从右数六段、剩下全算摊名」那一步。
const 行1 := "杂货摊&1001&流尘&55&12&3&500"
const 行2 := "轻藤兽铠&1002&小明&60&5&1&0"
const 行3 := "杂货&摊&1003&阿柯&42&7&2&88"
const 行4 := "忍具铺&1004&木叶丸&71&20&0&1200"
const 行5 := "卡片摊&1005&长门&80&3&4&0"
const 行6 := "拉面摊&1006&小樱&33&9&1&15"
const 行7 := "蛇皮摊&1007&佐井&48&6&0&60"
const 行8 := "木盒摊&1008&鹿丸&29&2&2&7"
const 行9 := "苦无摊&1009&丁次&61&14&0&99"
const 行10 := "药草摊&1010&井野&37&8&5&320"
const 行11 := "装备摊&1011&天天&52&11&0&45"
const 行12 := "宠物摊&1012&志乃&66&1&6&12"
const 行13 := "尾巴摊&1013&鸣人&99&30&7&777"
## ⚠ 这三条是 `var` 不是 `const` —— `String.join` / `%` 格式化在 GDScript 里不算常量表达式，
## 写成 `const` 直接「Assigned value for constant isn't a constant expression」整个脚本载入失败。
var 帧13 := "1296:0:13:" + "@".join([行1, 行2, 行3, 行4, 行5, 行6, 行7, 行8, 行9, 行10, 行11, 行12, 行13])
## **真实的一页**：服务端切的是 `[startIndex:endIndex)`（`fake_flash_server.py:25453`
## `stalls = matching_stalls[start_index:end_index]`），而 `总` 报的是**全量**（`:25474`
## `len(matching_stalls)`）⇒ 第 0 页那一帧只带 11 行、总数写 13。
var 帧页0 := "1296:0:13:" + "@".join([行1, 行2, 行3, 行4, 行5, 行6, 行7, 行8, 行9, 行10, 行11])
var 帧后2 := "1296:0:13:%s@%s" % [行12, 行13]
## 第 6 行少了最后一段（只剩六段）⇒ 整条丢掉，其余 12 条照收，而且**不许串位**。
var 帧坏 := "1296:0:13:" + "@".join([行1, 行2, 行3, 行4, 行5,
		"拉面摊&1006&小樱&33&9&1", 行7, 行8, 行9, 行10, 行11, 行12, 行13])

## 页上六列的**期望文字**（照抄上面那十三条线，不是从代码里读出来的）。
const 期摊名 := ["杂货摊", "轻藤兽铠", "杂货&摊", "忍具铺", "卡片摊", "拉面摊", "蛇皮摊",
		"木盒摊", "苦无摊", "药草摊", "装备摊"]
const 期出售人 := ["流尘", "小明", "阿柯", "木叶丸", "长门", "小樱", "佐井",
		"鹿丸", "丁次", "井野", "天天"]
const 期等级 := ["55", "60", "42", "71", "80", "33", "48", "29", "61", "37", "52"]
const 期物品 := ["12", "5", "7", "20", "3", "9", "6", "2", "14", "8", "11"]
const 期宠物 := ["3", "1", "2", "0", "4", "1", "0", "2", "0", "5", "0"]

## §③ 页局部（= AS3 外框坐标 − 29，`数据/界面/窗口尺寸.json` 的 `整框: true` 那一支）。
## 底板原点：`_contentBg = (8,38) 458×310`（`super(474,378,true)` + `UIWindow` 的 宽−16 / 高−68），
## `_listBg = 底板 ± BORDER_GAP(5)` ⇒ 外框 (13,43) 448×269 ⇒ 页 (13,14)。
const 窗件 := {
	"底板": [13.0, 14.0, 448.0, 269.0],		# `StallListWindow.as:220-222`
	"顶线": [16.0, 39.0, 442.0, 2.0],		# `CommonListSkin2.as:20-24` skin-local (3,25)、宽 = 448−6
	"列头1": [15.0, 17.0, 48.0, 20.0],		# `:225-227` Point(底板x+2, 底板y+5)，label 摆 (x, y−2)、高 20
	"列头2": [65.0, 17.0, 116.0, 20.0],		# `:228-230` x += 48+2
	"列头3": [183.0, 17.0, 94.0, 20.0],		# `:231-233` x += 116+2
	"列头4": [279.0, 17.0, 44.0, 20.0],		# `:234-236` x += 94+2
	"列头5": [325.0, 17.0, 66.0, 20.0],		# `:237-239` x += 44+2
	"列头6": [393.0, 17.0, 66.0, 20.0],		# `:240-242` x += 66+2、**末参 false ⇒ 后面没有竖线**
	"列分隔1": [63.0, 19.0, 2.0, 20.0],		# `:199-205` 竖线摆 (x+w, y) ⇒ 外框 y=48 ⇒ 页 19
	"列分隔2": [181.0, 19.0, 2.0, 20.0],
	"列分隔3": [277.0, 19.0, 2.0, 20.0],
	"列分隔4": [323.0, 19.0, 2.0, 20.0],
	"列分隔5": [391.0, 19.0, 2.0, 20.0],
	"列表": [16.0, 40.0, 442.0, 240.0],		# `:243-247` x = 底板x+3、y = 末列头y+21 = 69、宽 = 底板宽−6
	"快速搜索": [13.0, 286.0, 88.0, 20.0],	# `:253-258` y = 列表y+高+6 = 315、w 设 88、align right
	"下拉": [101.0, 286.0, 105.0, 20.0],	# `:259-263` x = 快速搜索x+w、宽设 105
	"关键字": [221.0, 286.0, 50.0, 20.0],	# `:265-268` x = 下拉x+w+15、w 设 50
	"输入框": [271.0, 288.0, 125.0, 21.0],	# `:269-271` x = 关键字x+50、y = 那一行 + 2、MTextInput2 原生 125×21
	"搜索钮": [401.0, 286.0, 37.0, 22.0],	# `:273-274` x = 输入框x+w+5、宽 = btn_width_two(37)
	"总数": [15.0, 321.0, 60.0, 20.0],		# `:275-277` (15, 378−28)、setSize(60,20)
	"刷新钮": [80.0, 322.0, 37.0, 22.0],		# `:278-279` x = 总数x+w+5、y = 378−5−22
	"首页": [127.0, 324.0, 18.0, 13.0],		# `:280` x = 刷新x+w+10、y = 刷新y+2、MPageFirstBtnF 原生 18×13
	"上一页": [155.0, 324.0, 15.0, 13.0],	# `:281` x = 首页x+18+10
	"页码": [170.0, 321.0, 50.0, 20.0],		# `:282-284` x = 上一页x+w、y 跟「总数」那一行、setSize(50,20)
	"下一页": [220.0, 324.0, 15.0, 13.0],	# `:285` x = **上一页x+w+50**（不是 15+2：原版这里跨过了页码格）
	"末页": [245.0, 324.0, 18.0, 13.0],		# `:286` x = 下一页x+15+10
	"查看摊位": [273.0, 322.0, 61.0, 22.0],	# `:287-288` x = 末页x+18+10、宽 = btn_width_four(61)
	"查看信息": [344.0, 322.0, 61.0, 22.0],	# `:289-290`
	"载入中": [167.0, 150.0, 140.0, 20.0],	# `:291-292` ((474−140)/2, (378−20)/2)
}
## 五条斑马纹（`CommonListSkin2.as:25-37`）：起 y = 顶线y+高+20 = 47（skin-local），
## 步长 = 条高 24 + 20 = 44，条数 = `int(11/2)` = **5**（不是 6 —— 原版少画一条，照抄）。
const 条纹 := [[16.0, 61.0], [16.0, 105.0], [16.0, 149.0], [16.0, 193.0], [16.0, 237.0]]
## 行内六格（`StallListItemRenderer.as:131-136`，`cretateLabel(宽, x, 色)` ⇒ `setSize(w,20)`、`setPosition(x,1)`）。
const 格 := {
	"序号": [0.0, 1.0, 50.0, 20.0],
	"摊名": [50.0, 1.0, 118.0, 20.0],
	"出售人": [168.0, 1.0, 93.0, 20.0],
	"等级": [261.0, 1.0, 50.0, 20.0],
	"物品数": [311.0, 1.0, 65.0, 20.0],
	"宠物数": [376.0, 1.0, 65.0, 20.0],
}

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 帧数 := 0


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


## 看门狗：门里任何一处运行期报错都会让协程半路断掉 ⇒ `quit()` 永远轮不到、
## 无头进程挂着不出红（工程已栽过）。约 90 秒到点就老实认红。
func _process(秒: float) -> bool:
	帧数 += 1
	if 帧数 > 5400 and not 跑完了:
		print("红：门超时未跑完（约 90 秒），后面的判据没执行")
		print("摊位列表窗离线门：通过 %d，红 %d" % [通过, 失败 + 1])
		quit(1)
		return true
	return false


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
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


## `_render_page` 是 `remove_child` + `queue_free`，摘得很利索；这层
## `is_queued_for_deletion` 只是防"同一帧里新旧两页都在"拿错旧的。
func _找页(窗: Node, 名: String) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String(子.name) == 名 and not 子.is_queued_for_deletion():
			return 子 as Control
	return null


func _找弹(窗: Node, 型: String) -> Control:
	var 台 := 窗.get("_overlay") as Control
	if 台 == null:
		return null
	for 子 in 台.get_children():
		if 子.has_meta("mdialog") and String(子.get_meta("mdialog")) == 型 \
				and not 子.is_queued_for_deletion():
			return 子 as Control
	return null


func _喂(原文: String) -> void:
	root.get_node("BackendConnection").call("_handle_bridge_text", 原文)


## 真鼠标点某个件。无头三条硬口径：钉视口、先挪鼠标、坐标走 `get_global_rect()`。
func _点在(件: Control) -> void:
	var 屏: Vector2 = 件.get_global_rect().position + Vector2(
			min(10.0, 件.size.x * 0.5), min(10.0, 件.size.y * 0.5))
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	root.push_input(移)
	await process_frame
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	root.push_input(按)
	await process_frame
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	root.push_input(放)
	await process_frame
	await process_frame
	await process_frame


## 真双击：第二记按下要自己带 `double_click`（无头里 Godot 不会合成这个标志）。
## 两记落在**同一处** —— 原版 `ITEM_DOUBLE_CLICK` 也是同一次鼠标动作上的两个事件。
func _双击(件: Control) -> void:
	var 屏: Vector2 = 件.get_global_rect().position + Vector2(
			min(10.0, 件.size.x * 0.5), min(10.0, 件.size.y * 0.5))
	for 次 in 2:
		var 按 := InputEventMouseButton.new()
		按.button_index = MOUSE_BUTTON_LEFT
		按.pressed = true
		按.button_mask = MOUSE_BUTTON_MASK_LEFT
		按.double_click = (次 == 1)
		按.position = 屏
		按.global_position = 屏
		root.push_input(按)
		await process_frame
		var 放 := InputEventMouseButton.new()
		放.button_index = MOUSE_BUTTON_LEFT
		放.pressed = false
		放.position = 屏
		放.global_position = 屏
		root.push_input(放)
		await process_frame
		await process_frame


## 点确认弹底下的那枚钮。**弹不在就直接判红**，不许"没弹就跳过"（那是把判据悄悄吃掉）。
func _点弹钮(弹: Control, 件名: String) -> void:
	if 弹 == null:
		_判(false, "确认弹不在 ⇒ 点不到「%s」" % 件名)
		return
	var 件 := 弹.get_node_or_null("主体/" + 件名) as Button
	if 件 == null:
		_判(false, "确认弹里没有「%s」" % 件名)
		return
	await _点在(件)




func _未完就退(窗: Node, 名: String) -> bool:
	if 窗 == null:
		_判(false, "%s 没开出来 ⇒ 后面的判据无从跑起" % 名)
		跑完了 = true
		print("摊位列表窗离线门：通过 %d，红 %d" % [通过, 失败])
		return true
	return false


## 假后端：只管**出帧**那半边（入帧走真后端）。字段名一律和真后端里那个同名，
## 别在这里覆写 `get()`（Godot 会当成覆写 `Object.get` ⇒ 整脚本 parse 失败）。
class 假后 extends Node:
	var in_game := true
	var character_id := 9999
	var 发过: Array = []

	func request_stall_list(起始: int, 止: int) -> bool:
		发过.append(["list", 起始, 止])
		return true

	func request_stall_search(类: int, 词: String, 起始: int, 止: int) -> bool:
		发过.append(["search", 类, 词, 起始, 止])
		return true

	func request_stall_open(号: int) -> bool:
		发过.append(["open", 号])
		return true

	func request_character_info(号: int) -> bool:
		发过.append(["info", 号])
		return true


func _跑() -> void:
	print("摊位列表窗离线门开始")
	await process_frame
	var 后 = root.get_node("BackendConnection")
	后.set("in_game", false)
	root.size = Vector2i(960, 560)
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame

	# ── ① 入帧解析（真后端、还没开窗 ⇒ 只验信号与解析） ──────────────────────
	var 列响: Array = []
	var 态响: Array = []
	后.connect("stall_list_received", func(总: int, 行表: Array) -> void: 列响.append([总, 行表]))
	后.connect("stall_state_received", func(_状: Dictionary) -> void: 态响.append(1))
	_喂(帧13)
	_判(列响.size() == 1 and 态响.is_empty(),
			"`1296:0:` 只叫列表那一条信号（实得 列表=%d 摊态=%d）" % [列响.size(), 态响.size()])
	if 列响.is_empty():
		跑完了 = true
		print("摊位列表窗离线门：通过 %d，红 %d（解析一条没通，后面全跑不动）" % [通过, 失败])
		return
	var 总: int = int(列响[0][0])
	var 解析: Array = 列响[0][1] as Array
	_判(总 == 13 and 解析.size() == 13, "总数 13、十三行全解出来（实得 %s / %d 行）" % [总, 解析.size()])
	var 头: Dictionary = 解析[0] as Dictionary
	_判(String(头.get("stall_name", "")) == "杂货摊" and int(头.get("payer_id", -1)) == 1001
			and String(头.get("player_name", "")) == "流尘" and int(头.get("player_level", -1)) == 55
			and int(头.get("itemnum", -1)) == 12 and int(头.get("petnum", -1)) == 3
			and int(头.get("moneynum", -1)) == 500,
			"第 1 行七段各归各位（实得 %s）" % str(头))
	## 摊名带 `&` 那条：线上是**八段** ⇒ 从右数六段、剩下全算摊名。
	## 写成"取第一段"这里摊名会是「杂货」；写成"多一段就丢整行"这里会少一行。
	var 折: Dictionary = 解析[2] as Dictionary
	_判(String(折.get("stall_name", "")) == "杂货&摊" and int(折.get("payer_id", -1)) == 1003
			and String(折.get("player_name", "")) == "阿柯" and int(折.get("player_level", -1)) == 42
			and int(折.get("itemnum", -1)) == 7 and int(折.get("petnum", -1)) == 2
			and int(折.get("moneynum", -1)) == 88,
			"摊名带 `&` 的那条折回成「杂货&摊」、后六段照旧（实得 %s）" % str(折))
	# 空表：服务端发的是根 `-`（`fake_flash_server.py:25451` 那句 `or "-"`）
	列响.clear()
	_喂("1296:0:0:-")
	_判(列响.size() == 1 and int(列响[0][0]) == 0 and (列响[0][1] as Array).is_empty(),
			"空表 `-` ⇒ 零行、总数照收（实得 %s）" % str(列响))
	# 六段的短行 ⇒ 只丢那一条，其余 12 条照收、顺序不许串位
	列响.clear()
	_喂(帧坏)
	var 残: Array = 列响[0][1] as Array
	_判(残.size() == 12 and String((残[5] as Dictionary).get("stall_name", "")) == "蛇皮摊",
			"少一列的那条被跳过、其余 12 条照收且不串位（实得 %d 行，第 6 位 %s）" % [
				残.size(), (残[5] as Dictionary).get("stall_name") if 残.size() > 5 else "无"])
	# `1296:1:` 是摊面快照，走另一条信号 ⇒ **不许**串到列表这条上（`_handle_stall_text` 那三支分流）
	列响.clear()
	态响.clear()
	_喂("1296:1:1001:流尘:杂货摊:-:-")
	_判(列响.is_empty() and 态响.size() == 1,
			"`1296:1:` 只叫 `stall_state_received`（实得 列表=%d 摊态=%d）" % [列响.size(), 态响.size()])

	# ── ② 开窗那一跳：窗开 + 发 `0:0:11`；背包**不**被连带 ────────────────────
	var 假 := 假后.new()
	root.add_child(假)
	var 窗: Node = 管理.call("取或建窗口", "摊位列表")
	if _未完就退(窗, "摊位列表窗"):
		return
	窗.set("_backend", 假)
	管理.call("打开或收起", "摊位列表")
	for i in 4:
		await process_frame
	_判(_开着(窗), "「打开或收起」⇒ 窗在台上")
	_判(假.发过 == [["list", 0, 11]],
			"开窗那一刻发 `1296:0:0:11`（原版 `init():152-156` 全文一句 `loadPage(0)`），实发 %s" % str(假.发过))
	var 包: Node = 管理._窗口们.get("背包")
	_判(包 == null or not _开着(包),
			"背包**没**被连带叫出来（原版那里只有 `setDOShow(STALL_LIST_WINDOW,true)` 一句，没有 `centerTwoWindow`）")
	var 页 := _找页(窗, "原版摊位列表内容")
	if _未完就退(页, "页本体"):
		return

	# ── ③ 逐件矩形 ─────────────────────────────────────────────────────────────
	_判(absf(页.size.x - 474.0) < 0.51 and absf(页.size.y - 349.0) < 0.51,
			"页 = 474×349（整框 378 − 标题 29），实得 %.0f×%.0f" % [页.size.x, 页.size.y])
	for 名 in 窗件:
		var 件: Control = 页.get_node_or_null(名) as Control
		_判(件 != null and _近(_矩形(件), 窗件[名]),
				"%s = (%s)，实得 (%s)" % [名, 窗件[名], _矩形(件) if 件 != null else "没建"])
	## 六列头的字（`LangUtil.get("STALL_LIST_WINDOW_LIST_TITLE")` 拆逗号，
	## `en_US$message_properties.as:1628`）—— 手抄，不从代码里读。
	var 期列头 := ["摊位号", "摊位名称", "出售人", "等级", "物品数量", "宠物数量"]
	for i in 6:
		var 头2 := 页.get_node_or_null("列头%d" % (i + 1)) as Label
		_判(头2 != null and 头2.text == 期列头[i],
				"列头%d 文字 = 「%s」，实得「%s」" % [i + 1, 期列头[i],
					头2.text if 头2 != null else "没建"])
	_判(页.get_node_or_null("列分隔6") == null,
			"第六列后面**没有**竖线（`createListLable(..., false)` 那一步就不 addChild）")
	for i in 条纹.size():
		var 条 := 页.get_node_or_null("条纹%d" % (i + 1)) as Control
		_判(条 != null and _近(_矩形(条), [条纹[i][0], 条纹[i][1], 442.0, 24.0]),
				"条纹%d = (%s, 442, 24)，实得 (%s)" % [i + 1, 条纹[i],
					_矩形(条) if 条 != null else "没建"])
	_判(页.get_node_or_null("条纹6") == null, "条数 = `int(11/2)` = 5，不是 6（原式的数，照抄）")
	var 底: NinePatchRect = 页.get_node("底板") as NinePatchRect
	_判(底 != null and 底.patch_margin_left == 8 and 底.patch_margin_right == 7
			and 底.patch_margin_top == 7 and 底.patch_margin_bottom == 7,
			"底板（`MPane_background`）九宫格边距**生效** = 8/7/7/7，实得 %s" % (
				"%d/%d/%d/%d" % [底.patch_margin_left, 底.patch_margin_right,
					底.patch_margin_top, 底.patch_margin_bottom] if 底 != null else "没建"))
	var 条1: NinePatchRect = 页.get_node("条纹1") as NinePatchRect
	_判(条1 != null and 条1.patch_margin_left == 12 and 条1.patch_margin_right == 12
			and 条1.patch_margin_top == 0 and 条1.patch_margin_bottom == 0,
			"条纹（`ListSeparator_background`）九宫格边距 = 12/12/0/0，实得 %s" % (
				"%d/%d/%d/%d" % [条1.patch_margin_left, 条1.patch_margin_right,
					条1.patch_margin_top, 条1.patch_margin_bottom] if 条1 != null else "没建"))
	## 文字那套：12 号（`cretateLabel():366-378` 的 `_loc4_.size = 12`）+ 白 + 右对齐那句。
	var 总字 := 页.get_node("总数") as Label
	_判(总字.get_theme_font_size("font_size") == 12 and 总字.get_theme_color("font_color") == Color(1, 1, 1),
			"「总数」12 号白字，实得 %s 号 %s" % [总字.get_theme_font_size("font_size"),
				总字.get_theme_color("font_color")])
	_判((页.get_node("快速搜索") as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
			"「快速搜索：」右对齐（`:256 align = \"right\"`，那格是 88 宽的盒子、字贴右沿）")
	_判((页.get_node("载入中") as Label).text == "正在载入资料，请稍候...",
			"载入那句 = STALL_LIST_WINDOW_PROGRESS（语言表 :3259），实得「%s」" % (页.get_node("载入中") as Label).text)
	_判((页.get_node("搜索钮") as Button).text == "搜索" and (页.get_node("刷新钮") as Button).text == "刷新"
			and (页.get_node("查看摊位") as Button).text == "查看摊位"
			and (页.get_node("查看信息") as Button).text == "查看信息",
			"底部四颗的文字 = 搜索／刷新／查看摊位／查看信息")
	var 区 := 页.get_node("列表") as Control
	_判(区.clip_contents,
			"列表区开 `clip_contents`：原版 `verticalScrollPolicy = \"off\"`（`:252`）⇒ 超出的行看不见，
			而 11×22 = 242 比 240 多 2px ⇒ 第 11 行下沿天生被裁（原版的数，不是我们摆错）")
	_判((页.get_node("输入框") as LineEdit).max_length == 20,
			"关键字框限 20 字（`MTextInput2` 的 maxChars），实得 %d" % (页.get_node("输入框") as LineEdit).max_length)

	# ── ④ 灌真实的一页（11 行、总数 13）⇒ 逐格摆出来 ────────────────────────────
	_喂(帧页0)
	for i in 3:
		await process_frame
	页 = _找页(窗, "原版摊位列表内容")
	区 = 页.get_node("列表") as Control
	_判(区.get_child_count() == 11,
			"第 0 页那一帧带 11 行 ⇒ 摆 11 行（切页在服务端，`_pageSize` 只写进请求的起止号），实得 %d" % 区.get_child_count())
	for 序 in 11:
		var 行: Control = 区.get_node_or_null("行%d" % 序) as Control
		if 行 == null:
			_判(false, "行%d 没建出来" % 序)
			continue
		_判(_近(_矩形(行), [0.0, float(序) * 22.0, 442.0, 22.0]),
				"行%d = (0, %s, 442, 22)，实得 (%s)" % [序, float(序) * 22.0, _矩形(行)])
		_判((行.get_node("选中底") as Control).size == Vector2(430.0, 21.0),
				"行%d 选中底 = 430×21（`:127-128` 那两个 set，**不是行宽 442**）" % 序)
		for 名 in 格:
			var 字: Control = 行.get_node_or_null(名) as Control
			_判(字 != null and _近(_矩形(字), 格[名]),
					"行%d/%s = (%s)，实得 (%s)" % [序, 名, 格[名], _矩形(字) if 字 != null else "没建"])
		_判((行.get_node("序号") as Label).text == str(序 + 1),
				"行%d 序号 = %d（`currentPage(0 基)×11 + index + 1`），实得「%s」" % [
					序, 序 + 1, (行.get_node("序号") as Label).text])
		_判((行.get_node("摊名") as Label).text == 期摊名[序],
				"行%d 摊名 = 「%s」，实得「%s」" % [序, 期摊名[序], (行.get_node("摊名") as Label).text])
		_判((行.get_node("出售人") as Label).text == 期出售人[序]
				and (行.get_node("等级") as Label).text == 期等级[序]
				and (行.get_node("物品数") as Label).text == 期物品[序]
				and (行.get_node("宠物数") as Label).text == 期宠物[序],
				"行%d 出售人/等级/物品/宠物 = %s/%s/%s/%s，实得 %s/%s/%s/%s" % [序,
					期出售人[序], 期等级[序], 期物品[序], 期宠物[序],
					(行.get_node("出售人") as Label).text, (行.get_node("等级") as Label).text,
					(行.get_node("物品数") as Label).text, (行.get_node("宠物数") as Label).text])
		_判((行.get_node("摊名") as Label).get_theme_color("font_color") == Color(0, 1, 0),
				"行%d 摊名 65280 = 0x00FF00（`:132`），实得 %s" % [序,
					(行.get_node("摊名") as Label).get_theme_color("font_color")])
		_判((行.get_node("出售人") as Label).get_theme_color("font_color") == Color(0.117647, 0.564706, 1),
				"行%d 出售人 2003199 = 0x1E90FF（`:133`），实得 %s" % [序,
					(行.get_node("出售人") as Label).get_theme_color("font_color")])
		_判(行.get_node_or_null("钱数") == null,
				"行内**没有**货币那一格（`:131-136` 只六枚 label、语言表也只六个列头 ⇒ `moneynum` 进档但不画）")
	_判((区.get_node("行2/摊名") as Label).text == "杂货&摊",
			"带 `&` 的摊名在页上也带 `&`（既没被拆成两行、也没只剩「杂货」）")
	_判((页.get_node("总数") as Label).text == "总数：13",
			"「总数：」后头接的是帧里的**总数** 13（`:359`），实得「%s」" % (页.get_node("总数") as Label).text)
	_判((页.get_node("页码") as Label).text == "1 / 2",
			"页码「1 / 2」（`ceil(13/11) = 2`、`:133`），实得「%s」" % (页.get_node("页码") as Label).text)
	_判(not (页.get_node("载入中") as Label).visible,
			"回帧落了 ⇒ 「正在载入」收起来（`setPageData:356 showProgress(false)`）")
	## 反腿：服务端**多送**（一帧塞满 13 行）时客户端不自己切页 —— 原版 `setPageData:362`
	## 是 `new DataProvider(param2)` 整表塞给 List，超出的行由 List 的视口（`clip_contents`）裁。
	## 这条钉住的是"别画蛇添足加 `slice(页*11, 页*11+11)`"：加了这里就转红。
	_喂(帧13)
	for i in 3:
		await process_frame
	区 = (_找页(窗, "原版摊位列表内容")).get_node("列表") as Control
	_判(区.get_child_count() == 13, "多送不切，13 行全摆（第 12、13 行看不见是 clip 的功劳）⇒ 实得 %d" % 区.get_child_count())
	_喂(帧页0)
	for i in 3:
		await process_frame
	区 = (_找页(窗, "原版摊位列表内容")).get_node("列表") as Control

	# ── ⑤ 选中 / 双击 ──────────────────────────────────────────────────────────
	await _点在(区.get_node("行3") as Control)
	_判((区.get_node("行3/选中底") as CanvasItem).visible
			and not (区.get_node("行1/选中底") as CanvasItem).visible,
			"单击第 4 行 ⇒ 只有那一行的选中条出来")
	var 走: Dictionary = 窗.get("_摊位列表走") as Dictionary
	_判(int(走.get("选", -9)) == 3, "选中号落在宿主那份账上，实得 %s" % 走.get("选"))
	假.发过.clear()
	## ⚠ ① 腿喂过一条 `1296:1:`，`窗口管理._on_stall_state` 会把摊面窗开出来 ⇒
	## 这里判的是**双击前后不许变化**，不是"它此刻是关着的"（后者会被上一条腿的残留判红）。
	var 摊面先 := _开着(管理._窗口们.get("随身摊位") as Node)
	await _双击(区.get_node("行5") as Control)
	_判(假.发过 == [["open", 1006]],
			"双击 ⇒ 发 `1296:2:<摊主号>`（`:250 ITEM_DOUBLE_CLICK → viewStallHandler → API.ui.viewStall(payerId)`），实发 %s" % str(假.发过))
	_判(_开着(管理._窗口们.get("随身摊位") as Node) == 摊面先,
			"双击**不**在本端把摊面窗开出来（开窗的是回帧 `1296:1:`，消费者在 `窗口管理._on_stall_state`）")
	await _点在(_找页(窗, "原版摊位列表内容").get_node("查看摊位") as Button)
	_判(假.发过 == [["open", 1006], ["open", 1006]],
			"双击那下顺带把选中落在第 6 行 ⇒ 点「查看摊位」发的是**同一号**，实发 %s" % str(假.发过))
	await _点在(_找页(窗, "原版摊位列表内容").get_node("查看信息") as Button)
	_判(假.发过[-1] == ["info", 1006],
			"点「查看信息」⇒ 走 `requestCharFullInfo`（`:137-150` → `UI.as:674-677`），实发 %s" % str(假.发过))

	# ── ⑥ 翻页：请求帧 + 载入态（六枚一起灰）+ 回帧后的状态 ──────────────────
	页 = _找页(窗, "原版摊位列表内容")
	假.发过.clear()
	await _点在(页.get_node("下一页") as TextureButton)
	_判(假.发过 == [["list", 11, 22]],
			"下一页 ⇒ `1296:0:11:22`（`loadPage:175-178` 的 startIndex/endIndex），实发 %s" % str(假.发过))
	页 = _找页(窗, "原版摊位列表内容")
	_判((页.get_node("载入中") as Label).visible, "发出去那一拍「正在载入」立刻出来（`showProgress()` 在发包之前）")
	## 六枚一起灰 = `showProgress:306-311` 点名的那六枚。**这里必须断"灰"**：
	## 上一版注释把它写成"不许灰"，判据正好反着 —— 反面由 §⑦「载入中也能改词」与 §⑤
	## 「查看摊位／查看信息从不灰」钉住，别让这两条替它兜着。
	for 名 in ["首页", "上一页", "下一页", "末页", "刷新钮", "搜索钮"]:
		## ⚠ 四枚翻页钮是 `TextureButton`、刷新/搜索是 `Button` ⇒ 只能按共同的父类 `BaseButton` 取。
		## `get_node("首页") as Button` 得到 **null**，下一句 `.disabled` 就是
		## 「Invalid access to property or key 'disabled' on a base object of type 'Nil'」⇒ 门崩而不红。
		var 钮: BaseButton = 页.get_node(名) as BaseButton
		_判(钮 != null and 钮.disabled and 钮.material != null,
				"载入中 ⇒「%s」disabled **并且套灰度材质**（禁用态不是另一张图、也不是压暗）" % 名)
	for 名 in ["查看摊位", "查看信息"]:
		_判(not (页.get_node(名) as Button).disabled,
				"「%s」**不在** `showProgress` 的六枚名单里 ⇒ 等回帧的时候照旧能点" % 名)
	var 载: Dictionary = 窗.get("_摊位列表走") as Dictionary
	_判(bool(载.get("载", false)) and int(载.get("请页", -1)) == 1 and int(载.get("页", -9)) == 0,
			"「请求页」与「当前页」是两个字段：发出去时 请页=1、页还是 0（`_requestPageIndex` / `_currentPage`）")
	_喂(帧后2)
	for i in 3:
		await process_frame
	页 = _找页(窗, "原版摊位列表内容")
	var 区2: Control = 页.get_node("列表") as Control
	_判(区2.get_child_count() == 2, "第 1 页只有 2 行（13 − 11），实得 %d" % 区2.get_child_count())
	_判((区2.get_node("行0/序号") as Label).text == "12" and (区2.get_node("行1/序号") as Label).text == "13",
			"第二页的序号从 12 起（`currentPage(1)×11 + index + 1`），实得 %s/%s" % [
				(区2.get_node("行0/序号") as Label).text, (区2.get_node("行1/序号") as Label).text])
	_判((区2.get_node("行0/摊名") as Label).text == "宠物摊" and (区2.get_node("行1/摊名") as Label).text == "尾巴摊",
			"第二页摆的是最后两条摊")
	_判((页.get_node("页码") as Label).text == "2 / 2", "页码「2 / 2」，实得「%s」" % (页.get_node("页码") as Label).text)
	for 名 in ["首页", "上一页"]:
		_判(not (页.get_node(名) as BaseButton).disabled and (页.get_node(名) as CanvasItem).material == null,
				"页 1 > 0 ⇒「%s」回亮（`updateButtonState:111-115`）" % 名)
	for 名 in ["下一页", "末页"]:
		_判((页.get_node(名) as BaseButton).disabled,
				"页 1 = 总页−1 ⇒「%s」灰着（`:121-130`）" % 名)
	_判(int((窗.get("_摊位列表走") as Dictionary).get("选", -9)) == -1,
			"换页 ⇒ 选中清零（`:362` 整表换 `dataProvider`，原版这里**没有** `selectedIndex = 0`）")

	# ── ⑦ 搜索：空词弹一句、一帧不发；非空发 `1:<data>:<词>:<起>:<止>` ────────
	页 = _找页(窗, "原版摊位列表内容")
	var 前: int = 假.发过.size()
	(页.get_node("输入框") as LineEdit).text = ""
	await _点在(页.get_node("搜索钮") as Button)
	var 弹 := _找弹(窗, "message")
	_判(弹 != null and (弹.get_node("主体/正文") as RichTextLabel).get_parsed_text() == "请输入关键字！",
			"空词 ⇒ 弹 STALL_LIST_WINDOW_INPUT_KEY（`:101`），实得「%s」" % (
				(弹.get_node("主体/正文") as RichTextLabel).get_parsed_text() if 弹 != null else "没弹"))
	_判(假.发过.size() == 前, "空词那一发**一帧都不许发**（`:99-103` 是 `return`，不是往下走），实发 %s" % str(假.发过))
	await _点弹钮(弹, "确定")
	for i in 2:
		await process_frame
	_判(_找弹(窗, "message") == null, "点「确定」⇒ 弹收掉")
	页 = _找页(窗, "原版摊位列表内容")
	(页.get_node("输入框") as LineEdit).text = "轻藤"
	await _点在(页.get_node("搜索钮") as Button)
	## 类目默认是第一项「按物品名称」，而它的 `data` 是 **1**（`_searchTags[0].data = 1`，
	## 而 `_quickKey` 初值也是 1）⇒ 这里发出去的类号是 1，不是 0。
	_判(假.发过[-1] == ["search", 1, "轻藤", 0, 11],
			"非空 ⇒ `1296:1:1:轻藤:0:11`（`UI.as:800-808` 词非空那一支走 `requestStallSearch`；`loadPage(0)` ⇒ 起 0 止 11），实发 %s" % str(假.发过))
	_喂("1296:0:1:%s" % 行2)
	for i in 3:
		await process_frame
	页 = _找页(窗, "原版摊位列表内容")
	var 区3: Control = 页.get_node("列表") as Control
	_判(区3.get_child_count() == 1 and (区3.get_node("行0/摊名") as Label).text == "轻藤兽铠",
			"搜索回帧只灌那一条，实得 %d 行" % 区3.get_child_count())
	_判((页.get_node("总数") as Label).text == "总数：1", "总数跟着回帧走，实得「%s」" % (页.get_node("总数") as Label).text)
	_判((页.get_node("页码") as Label).text == "1 / 1", "一条 ⇒ 总页 1 ⇒ 页码「1 / 1」，实得「%s」" % (页.get_node("页码") as Label).text)

	# ── ⑧ 刷新：词清、重载**当前页**；框里的字与下拉显示都不清 ────────────────
	假.发过.clear()
	await _点在(_找页(窗, "原版摊位列表内容").get_node("刷新钮") as Button)
	_判(假.发过 == [["list", 0, 11]],
			"刷新 ⇒ 回到「无词」那一支、重载的是**当前页**（`refreshHandler:385-390`），实发 %s" % str(假.发过))
	页 = _找页(窗, "原版摊位列表内容")
	_判((页.get_node("输入框") as LineEdit).text == "轻藤",
			"框里的字**不清**（原版两句 clear 都没有）⇒ 玩家看得见一个已经不生效的词，这是原语义不是漏做")
	_判((页.get_node("下拉/文字") as Label).text == "按物品名称",
			"下拉显示也不跟着 `_quickKey` 复位（`:387` 只改 `_quickKey`，没碰 `_searchBox`）")

	# ── ⑨ 总数 0 ⇒ 页码格不写（留着上一句）、四枚全灰、两颗查看钮照旧能点 ──────
	_喂("1296:0:0:-")
	for i in 3:
		await process_frame
	页 = _找页(窗, "原版摊位列表内容")
	_判(页.get_node("列表").get_child_count() == 0, "空表 ⇒ 行清空，实得 %d 行" % 页.get_node("列表").get_child_count())
	_判((页.get_node("总数") as Label).text == "总数：0", "「总数：0」（`:358-359` 写的就是帧里的总数），实得「%s」" % (页.get_node("总数") as Label).text)
	## ⚠ 这一条钉的是原版的**呆账**：`updateButtonState:131` 外层是 `if (_totalPage > 0)`
	## ⇒ 一条摊都没有时页码格**压根不写**，于是屏幕上留的是上一句「1 / 1」。
	## 谁"顺手"加一句 else 写空，这条就红。
	_判((页.get_node("页码") as Label).text == "1 / 1",
			"总页 = 0 时页码格**不重写**（原版那支 if 没有 else）⇒ 页上留的是上一句「1 / 1」，实得「%s」" % (页.get_node("页码") as Label).text)
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		_判((页.get_node(名) as BaseButton).disabled, "零条 ⇒「%s」灰着（0 > 0 与 0 < −1 都不成立）" % 名)
	for 名 in ["刷新钮", "搜索钮", "查看摊位", "查看信息"]:
		_判(not (页.get_node(名) as BaseButton).disabled, "回帧已到 ⇒「%s」不灰（`showProgress(false)` 把六枚一起放开）" % 名)

	# ── ⑩ 下拉：三项齐全、换类目**不发帧**、下一次搜索才用新 data ─────────────
	页 = _找页(窗, "原版摊位列表内容")
	## ⚠ 门自己把窗提到顶上：无头视口只有 560 高，这扇 378 高的窗被 `窗口偏移` 钳在视口里时
	## 底边落在 547，而菜单是往**下**长 72px（原版 `MComboBox` 也朝下 ⇒ 本工程不翻向上弹）
	## ⇒ 第三个 item 整条掉出视口，`push_input` 打不到（表现为"点了静默没反应"）。
	## 这改的是门的摆位，不是窗的行为；真机 800×600 以上不会撞到这个。
	窗.call("窗口偏移", Vector2(0.0, -91.0))
	for i in 2:
		await process_frame
	前 = 假.发过.size()
	await _点在(页.get_node("下拉") as TextureButton)
	var 盘: Control = 窗.get("_摊位列表下拉") as Control
	_判(盘 != null and 盘.get_child_count() == 3, "点下拉 ⇒ 三项菜单（实得 %s）" % (
			str(盘.get_child_count()) if 盘 != null else "没弹"))
	## ⚠ **结构判据**，不是行为判据：菜单挂在 `遮罩` 上、和页里那些 `STOP` 的底图是同族兄弟，
	## 靠 `z_index=50` 才压在它们之上。无头拾取看不出这件事（变异掉这一句本门照旧全绿，实测过），
	## 真机 800×600 上第三项就打在页的底图上 —— 点了没反应＝坏了。所以把它钉成数值。
	_判(盘 != null and int(盘.z_index) == 50 and 盘.mouse_filter == Control.MOUSE_FILTER_STOP,
			"菜单 `z_index=50`（本工程弹出层口径，见 `功能窗口.gd:5730`）且自身吃点击，实得 z=%s filter=%s" % [
				str(盘.z_index) if 盘 != null else "-", str(盘.mouse_filter) if 盘 != null else "-"])
	if 盘 != null:
		var 期项 := ["按物品名称", "按摊位名称", "按宠物名称"]
		for i in 3:
			var 项 := 盘.get_node_or_null("项%d" % i) as Button
			_判(项 != null and 项.text == 期项[i],
					"下拉第 %d 项 = 「%s」（语言表 :2578 / :2600 / :2919），实得「%s」" % [
						i, 期项[i], 项.text if 项 != null else "没建"])
		_判(假.发过.size() == 前, "把菜单弹出来这一动作本身不发帧")
		await _点在(盘.get_node("项1") as Button)
		_判((_找页(窗, "原版摊位列表内容").get_node("下拉/文字") as Label).text == "按摊位名称",
				"点第二项 ⇒ 显示换成「按摊位名称」（合成点击在这一项上是打得着的）")
		页 = _找页(窗, "原版摊位列表内容")
		await _点在(页.get_node("下拉") as TextureButton)
		## ⚠ 第三项只能走 `pressed.emit()`，无头里点不着 —— **已取证这不是端口的坏**：
		## `摊位列表下拉` 挂在 `遮罩`（全矩形、`filter=IGNORE`）上、`z_index=50`，宿主窗的
		## CanvasLayer `layer=112` **高于**同屏的随身摊位（111），命中栈里那一点上
		## 除菜单自己以外没有任何控件压着。可 `root.push_input` 在这一屏偏把**先建的 canvas**
		## 排在后建的上面（`gui_get_hovered_control()` 报的是随身摊位的内容页），与
		## `窗口管理.gd:315-326` 在真编辑器里实测的「`layer` 才是说了算的那个」相反
		## ⇒ 判为**夹具拾取**的局限，不改端口行为，改由 `emit` 钉住。
		var 盘2: Control = 窗.get("_摊位列表下拉") as Control
		_判(盘2 != null, "选中一项后**再点触发器** ⇒ 菜单重开（不重开就没有第三项可点）")
		if 盘2 != null:
			(盘2.get_node("项2") as Button).pressed.emit()
		for i in 2:
			await process_frame
		_判(假.发过.size() == 前,
				"选一项**也不发帧**（原版 `quickSearchHandler:158-162` 全文没有一句 addEventListener ⇒ 死代码；生效的是下一次点「搜索」）")
		页 = _找页(窗, "原版摊位列表内容")
		_判((页.get_node("下拉/文字") as Label).text == "按宠物名称",
				"选完 ⇒ 显示换成「按宠物名称」，实得「%s」" % (页.get_node("下拉/文字") as Label).text)
	_判(窗.get("_摊位列表下拉") == null, "选完菜单收掉（挂在遮罩上，不跟着页重建被连手清掉）")
	页 = _找页(窗, "原版摊位列表内容")
	(页.get_node("输入框") as LineEdit).text = "尾巴"
	await _点在(页.get_node("搜索钮") as Button)
	## 第三项「按宠物名称」的 data = **2** ⇒ 发的类号是 2。
	_判(假.发过[-1] == ["search", 2, "尾巴", 0, 11],
			"换完类目再搜 ⇒ data 跟着换成 2（**序号 ≠ data**：第 1 项 data 1、第 2 项 data 0、第 3 项 data 2），实发 %s" % str(假.发过))

	# ── ⑩b 点菜单**外面**也要收 ───────────────────────────────────────────────
	## 真值 = `MComboBox.as:29-41 close()` 里摘掉的那句 `stage` 上的 `MOUSE_DOWN` ⇒ `open()` 挂的
	## 就是"点舞台任意处 ⇒ 关"。补之前端口只在"选中一项 / 页重建 / 关窗"三路收菜单，
	## 玩家点一下列表菜单却赖着不走 —— 变异 `_收下拉于别处` 的那句 `关下拉` 这一条就该红。
	页 = _找页(窗, "原版摊位列表内容")
	前 = 假.发过.size()
	await _点在(页.get_node("下拉") as TextureButton)
	_判(窗.get("_摊位列表下拉") != null, "⑩b 先把菜单弹开（下面要点别处）")
	await _点在(页.get_node("总数") as Label)
	_判(窗.get("_摊位列表下拉") == null, "点菜单外的一处 ⇒ 菜单收掉（`功能窗口._收下拉于别处`）")

	# ── ⑪ 查看信息：摊主是自己 ⇒ 开自己的人物窗、一帧不发 ──────────────────────
	_喂(帧13)
	for i in 3:
		await process_frame
	页 = _找页(窗, "原版摊位列表内容")
	await _点在(页.get_node("列表/行0") as Control)
	假.character_id = 1001
	前 = 假.发过.size()
	await _点在(页.get_node("查看信息") as Button)
	_判(假.发过.size() == 前,
			"摊主是自己 ⇒ **不发包**（`:141-148` 那支走 `setDOShow2(charWindow,true)`），实发 %s" % str(假.发过))
	_判(_开着(管理._窗口们.get("人物") as Node), "并且把自己的人物窗开出来")
	假.character_id = 9999

	# ── ⑫ 关窗后到的回帧 ⇒ 不灌、窗不复活 ─────────────────────────────────────
	管理.call("打开或收起", "摊位列表")
	for i in 2:
		await process_frame
	_判(not _开着(窗), "同页再点一次 = 收起（原版 `:1549-1552` 那支 `setDOShow(..., false)`）")
	前 = 假.发过.size()
	_喂(帧后2)
	for i in 3:
		await process_frame
	_判(not _开着(窗), "关着的时候回帧**不许**把窗顶回来（原版 `StallDataManager:88-94` 那句 `if (stallListWindow)`）")
	_判(int((窗.get("_摊位列表走") as Dictionary).get("总", -9)) == 0,
			"关窗 = 复位 ⇒ 那份账也清了（实得 %s）" % str((窗.get("_摊位列表走") as Dictionary).get("总")))
	_判(假.发过.size() == 前, "回帧那一路不引起任何新请求（不发↔不灌成环）")

	# ── ⑬ 再开窗 ⇒ 从第 0 页重发、框空、类目回第一项 ─────────────────────────
	假.发过.clear()
	管理.call("打开或收起", "摊位列表")
	for i in 4:
		await process_frame
	_判(假.发过 == [["list", 0, 11]], "重新开窗 ⇒ 又从第 0 页发一跳（原版每次建新窗都 `init()`），实发 %s" % str(假.发过))
	页 = _找页(窗, "原版摊位列表内容")
	_判(页 != null and (页.get_node("输入框") as LineEdit).text == "",
			"上次那个「尾巴」不留下来（原版建新窗时框是空的；本工程窗实例只藏不删 ⇒ 靠 `复位`）")
	_判(页 != null and (页.get_node("下拉/文字") as Label).text == "按物品名称",
			"类目也回第一项，实得「%s」" % ((页.get_node("下拉/文字") as Label).text if 页 != null else "没页"))
	_判(页 != null and 页.get_node("列表").get_child_count() == 0, "行也没留着")
	## 离线（**真后端**、没进游戏）⇒ 开窗不发包，也不许留一句「发送失败」：
	## 本工程开窗口径是 `_backend != null and in_game` 才拉数据（`功能窗口.gd:881/889` 一排同型守卫）。
	## 这条为什么值得钉：把 `open_page` 那句 `in_game` 守卫删掉，`request_stall_list` 立刻返回 false
	## ⇒ `_show_hint("摊位列表请求发送失败")` 会**改写**状态行 ⇒ 下面那句「文字没变」转红。
	## ⚠ 判的是"和开窗前一模一样"，不是"空串" —— `_status` 那行归 `_on_backend_status` 所有，
	## 未连接时本来就写着「后端：未连接」，拿空串判据会把这句当成我们弹的提示。
	管理.call("打开或收起", "摊位列表")		# 先收起（此刻是开着的 ⇒ 这一句是 close）
	for i in 3:
		await process_frame
	窗.set("_backend", 后)
	后.set("in_game", false)
	var 状态先 := String((窗.get("_status") as Label).text)
	管理.call("打开或收起", "摊位列表")
	for i in 4:
		await process_frame
	_判(_开着(窗), "离线照样把窗开出来（原版开窗不发帧，回不来也只是空表 ⇒ 不许改成「离线就别开」）")
	_判(not bool((窗.get("_摊位列表走") as Dictionary).get("载", true)),
			"离线开窗 ⇒ 不发包，也就**不许**把「载入中」挂着等一个永远不来的回帧")
	_判(String((窗.get("_status") as Label).text) == 状态先,
			"离线开窗是一句安静的 no-op，状态行从「%s」变成「%s」" % [
				状态先, (窗.get("_status") as Label).text])

	# ── ⑭ 尺寸表 + 不在 伴随背包 + 不在 居中弹 ────────────────────────────────
	var 表文: Dictionary = JSON.parse_string(去BOM(FileAccess.get_file_as_string(尺寸表路径))) as Dictionary
	_判(表文.has("摊位列表") and int(表文["摊位列表"]["宽"]) == 474 and int(表文["摊位列表"]["高"]) == 378
			and bool(表文["摊位列表"]["整框"]) and bool(表文["摊位列表"]["内容底"])
			and String(表文["摊位列表"]["标题"]) == "摊位列表",
			"尺寸表「摊位列表」= 474×378、整框、内容底、标题「摊位列表」")
	_判(not 管理脚本.伴随背包.has("摊位列表"),
			"摊位列表**不进** `伴随背包`（原版入口只有 `setDOShow` 一句，没有 `centerTwoWindow`）")
	_判(not 管理脚本.居中弹.has("摊位列表"), "也不进 `居中弹`（它是可拖的普通窗）")
	跑完了 = true
	print("摊位列表窗离线门：通过 %d，红 %d" % [通过, 失败])


static func 去BOM(文: String) -> String:
	return 文.trim_prefix("﻿")
