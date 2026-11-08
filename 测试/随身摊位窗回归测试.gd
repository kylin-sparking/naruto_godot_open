extends SceneTree
## 随身摊位窗（原版 `StallWindow`）+ 物品购买窗（`StallUpShelfWindow`）离线门。
## 逐件参照值手抄自 `真值/窗口/随身摊位窗.md` §②④⑤（AS3 行号都在那），**不从被测场景反查**。
##
## 覆盖：① 回帧解析（喂**服务端原文**，串由 `开发工具/出错摊夹具.py` 反查 `_send_stall` 生成）
## ② 半条/子命令不对/行列数不足 三种坏帧各自的出口 ③ 那一帧到本端 ⇒ 窗自己开（消费者）
## ④ 摊位窗逐件矩形 + 三枚 82 宽页签 ⑤ 行渲染 220×50 的 14 件矩形与层序
## ⑥ 三档画法（物品/宠物/货币）⑦ 买家档只露「购买」、摊主档露 上架/下架/修改 且摊名行改排
## ⑧ 切页换行集与钮文字、选中回第 0 行 ⑨ 同刻只有一行底亮
## ⑩ 点「购买」⇒ 开确认窗、六格填对 ⑪ 余额不足 ⇒ **一帧都不发**、只出通知
## ⑫ 余额够 ⇒ `1296:7:<卖家号>:<卖家名>:<uid>` 三个参数逐值 ⑬ 尺寸表两条 + 居中弹。
##
## 跑法：`"godot" --path . --headless --script res://测试/随身摊位窗回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 夹具路径 := "res://数据/界面/摆摊夹具.json"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 行脚本 := preload("res://脚本/界面/窗口/摆摊/摊位行.gd")
const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## §② 摊位窗逐件（页局部 = AS3 − 29）
const 窗件 := {
	"内容底": [8.0, 9.0, 261.0, 369.0],		# `UIWindow.as:36-39`+`:64-65`：(8,38) 277−16 × 437−68
	"列表底板": [13.0, 34.0, 251.0, 250.0],		# `StallWindow.as:147-148`+`:166`+`:170`
	"记录底板": [13.0, 312.0, 251.0, 60.0],		# `:151-152`+`:166`+`:172`
	"页签条": [13.0, 14.0, 248.0, 22.0],		# `:167`+`:169`；宽 = 82×3 + gap 1×2
	"列表": [21.0, 38.0, 235.0, 242.0],		# `:161-162`+`:168`+`:171`
	"日志": [21.0, 320.0, 235.0, 44.0],		# `:175-179`
	"记录标签": [21.0, 286.0, 112.0, 20.0],		# `:193-195`
	"上架钮": [129.0, 287.0, 61.0, 22.0],		# `:200`+`:216`+`:219` x = 195−61−5
	"下架钮": [195.0, 287.0, 61.0, 22.0],		# `:211`+`:217` x = 261−5−61
	"购买钮": [219.0, 287.0, 37.0, 22.0],		# `:205`+`:218` x = 261−5−37
	"摊名框": [76.0, 381.0, 125.0, 21.0],		# `:221-225` + `showView(false)`：(277−125)/2
	"修改钮": [186.5, 381.0, 37.0, 22.0],		# `:226-232`（买家档不可见，位置仍是构造那格）
}
## 三枚页签在**页上**的绝对框（`TabButtonBar.as:22` horizontalGap=1、`left/top=0`）
const 页签件 := {"页签0": [13.0, 14.0, 82.0, 22.0], "页签1": [96.0, 14.0, 82.0, 22.0],
				"页签2": [179.0, 14.0, 82.0, 22.0]}
const 页签文字 := ["出售中的物品", "出售中的宠物", "出售中的货币"]
const 行集数 := [2, 1, 1]					# 夹具四行按类型分桶：物品 2、宠物 1、货币 1
## §⑤ 购买确认窗逐件（页局部 = AS3 − 29）
const 购件 := {
	"内容底": [8.0, 9.0, 150.0, 118.0],		# (8,38) 166−16 × 186−68
	"名称标签": [16.0, 11.0, 95.0, 20.0],		# `StallUpShelfWindow.as:229-233`
	"物品格": [113.0, 15.0, 40.0, 40.0],		# `:235-238` x = 8+150−40−5
	"名称框": [16.0, 33.0, 85.0, 20.0],		# `:239-244` setSize(85,20)、y = 40+20+2
	"数量行": [16.0, 56.0, 141.0, 20.0],		# `:245-250` FormItem2 = 40+gap4+97
	"总价标签": [16.0, 76.0, 40.0, 20.0],		# `:251-257`
	"价1底": [56.0, 76.0, 98.0, 21.0],		# `:258-267` x = 16+40
	"金币": [59.0, 78.0, 17.0, 17.0],		# `:268-270` +(3,2)
	"价2底": [56.0, 100.0, 98.0, 21.0],		# `:282-283` y = 76+21+3
	"元宝": [59.0, 103.0, 19.0, 13.0],		# `:284-286` +(3,3)（与行渲染那枚的 +(3,2) 不同）
	"确定钮": [68.0, 130.0, 30.0, 22.0],		# `:290-296` y = 186−22−5、宽 = 24+6（isScale9Grid）
}
const 购内件 := {"数量标签": [0.0, 0.0, 40.0, 20.0], "数量文": [44.0, 0.0, 97.0, 20.0]}
const 行层序 := ["分隔线", "悬停条", "价1底", "价2底", "价1文", "价2文", "金币", "元宝",
				"元宝底", "物品格", "名字", "类型", "售价", "查看钮"]

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 夹: Dictionary = {}
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


## 按名字找页（⚠ `功能窗口` 的根是 CanvasLayer，别 `as Control` 取它）
func _找页(窗: Node, 名: String) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String(子.name) == 名:
			return 子 as Control
	return null


func _喂(原文: String) -> void:
	root.get_node("BackendConnection").call("_handle_bridge_text", 原文)


## 真鼠标点一下某个件。**无头门三条硬口径**（工程里实测过，缺一条就"点了静默没反应"）：
## ① 先钉 `root.size`（无头默认视口太小，GUI 拾取拿不到命中）
## ② 点击之前要先发一次 `InputEventMouseMotion` 把鼠标挪过去
## ③ `position` 与 `global_position` **都要写**，按下还要带 `button_mask`
## 坐标必须是**屏幕坐标**：件的 `position` 不是屏幕位，走 `get_global_rect()`。
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


func _红完就退(窗: Node, 名: String) -> bool:
	if 窗 == null:
		_判(false, "%s 没开出来 ⇒ 后面的判据无从跑起" % 名)
		跑完了 = true
		print("随身摊位窗离线门：通过 %d，红 %d" % [通过, 失败])
		return true
	return false


## 假后端：只管**出帧**那半边（入帧走真后端）。字段名一律和真后端里那两个同名，
## 别在这里覆写 `get()`（Godot 会当成覆写 `Object.get` ⇒ 整脚本 parse 失败）。
class 假后 extends Node:
	var character_id := 9001
	var authoritative_stall: Dictionary = {}
	var authoritative_bag_capacity := 90
	var authoritative_inventory: Array[Dictionary] = []
	var authoritative_stats := {"money": 0, "cash": 0}
	var 买过: Array = []

	func request_stall_buy(卖家号: int, 卖家名: String, 挂牌: int) -> bool:
		买过.append([卖家号, 卖家名, 挂牌])
		return true


func _跑() -> void:
	print("随身摊位窗离线门开始")
	await process_frame
	夹 = JSON.parse_string(去BOM(FileAccess.get_file_as_string(夹具路径))) as Dictionary
	_判(夹 != null and not 夹.is_empty(),
			"夹具读得到（先跑 `python 开发工具/出错摊夹具.py`，它自带服务端段序反查）")
	if 夹 == null or 夹.is_empty():
		跑完了 = true
		print("随身摊位窗离线门：通过 %d，红 %d" % [通过, 失败])
		return
	var 原 := String(夹["原文"])
	var 后 = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("authoritative_stall", {})
	root.size = Vector2i(960, 560)		# ⚠ 不钉视口，无头 push_input 拿不到 GUI 命中 ⇒ 点了静默没反应
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame

	# ① 入帧：喂服务端原文 ⇒ 解析出摊主/摊名/四行
	_喂(原)
	var 状: Dictionary = 后.get("authoritative_stall") as Dictionary
	_判(int(状.get("owner_id", 0)) == int(夹["摊主号"]),
			"摊主号 = %s（实得 %s）" % [夹["摊主号"], 状.get("owner_id")])
	_判(String(状.get("owner_name", "")) == String(夹["摊主名"])
			and String(状.get("stall_name", "")) == String(夹["摊名"]),
			"摊主名/摊名两段各归各位（实得「%s」「%s」）" % [状.get("owner_name"), 状.get("stall_name")])
	var 行表: Array = 状.get("listings", []) as Array
	_判(行表.size() == 4, "四行挂牌都解出来（实得 %d 行）" % 行表.size())
	var 期望行: Array = 夹["期望行"] as Array
	for i in 期望行.size():
		if i >= 行表.size():
			_判(false, "第 %d 行没解出来" % i)
			continue
		var 实: Dictionary = 行表[i] as Dictionary
		var 期: Dictionary = 期望行[i] as Dictionary
		_判(int(实.get("uid", -1)) == int(期["uid"]) and int(实.get("kind", -1)) == int(期["kind"])
				and int(实.get("point_price", -1)) == int(期["point_price"])
				and int(实.get("cash_price", -1)) == int(期["cash_price"]),
				"第 %d 行 uid/类型/两个价 = (%s,%s,%s,%s)，实得 (%s,%s,%s,%s)" % [i,
					期["uid"], 期["kind"], 期["point_price"], 期["cash_price"],
					实.get("uid"), 实.get("kind"), 实.get("point_price"), 实.get("cash_price")])
	# 负载里 `!` 必须还原成 `&`（还原不了的话物品号/数量全查不到 ⇒ 整页格子是空的）
	var 负 := String((行表[0] as Dictionary).get("payload", "")) if 行表.size() > 0 else ""
	_判(负.split("&").size() >= 10 and int(负.split("&")[1]) == 10000001,
			"负载 `!`→`&` 还原后能数出 ≥10 段、第 2 段是物品号 10000001（实得「%s」）" % 负)

	# ② 三种坏帧各有各的出口
	# (a) 半条（缺行表那一段）⇒ 整条丢，不许留下半截摊
	后.set("authoritative_stall", {})
	_喂("1296:1:1002:油女澪:澪的杂货摊")
	_判((后.get("authoritative_stall") as Dictionary).is_empty(),
			"只有 5 段的半条 ⇒ 整条丢（实得 %s）" % [(后.get("authoritative_stall") as Dictionary).keys()])
	# (b) 子命令不是 1 ⇒ 整条丢（`:3` 是下架回执、`:4` 是卖家侧成交通知，形状完全不同）
	_喂(原.replace("1296:1:", "1296:3:"))
	_判((后.get("authoritative_stall") as Dictionary).is_empty(),
			"子命令 3 ⇒ 不走「摊位内容」这一支（实得 %s）" % [(后.get("authoritative_stall") as Dictionary).keys()])
	# (c) 某一行少一列 ⇒ **只丢那一行**，其余照收（不许拿残列凑出一行假挂牌）
	后.set("authoritative_stall", {})
	_喂(原.replace("5001&1002&2&1000&0&", "5001&1002&2&1000&"))
	var 残: Array = (后.get("authoritative_stall") as Dictionary).get("listings", []) as Array
	_判(残.size() == 3 and int((残[0] as Dictionary).get("uid", 0)) == 5002,
			"缺列的那一行被跳过、剩下 3 行照收（实得 %d 行，首行 uid=%s）" % [残.size(),
				(残[0] as Dictionary).get("uid") if 残.size() > 0 else "无"])
	后.set("authoritative_stall", {})
	_喂(原)

	# ③ 那一帧到本端 ⇒ 窗自己开（消费者 = 窗口管理._on_stall_state）
	# 先钉住"原文里那个摊主不是我" ⇒ 走的必须是买家档
	后.set("character_id", int(夹["摊主号"]) + 1)
	for i in 3:
		await process_frame
	var 窗: Node = 管理._窗口们.get("随身摊位")
	if _红完就退(窗, "摊位窗"):
		return
	_判(_开着(窗), "喂 1296:1 那帧 ⇒ 摊位窗自己开出来了（消费者接对了）")
	var 页 := _找页(窗, "原版随身摊位内容")
	if _红完就退(页, "摊位窗页本体"):
		return

	# ④ 逐件矩形
	_判(absf(页.size.x - 277.0) < 0.51 and absf(页.size.y - 408.0) < 0.51,
			"页 = 277×408（内容区 = 整窗 437 − 标题 29），实得 %.0f×%.0f" % [页.size.x, 页.size.y])
	for 名 in 窗件:
		var 子 := 页.get_node_or_null(名) as Control
		_判(子 != null, "逐件：%s 在" % 名)
		if 子 != null:
			_判(_近(_矩形(子), 窗件[名]), "%s 矩形 = (%s)，实得 (%s)" % [名, 窗件[名], _矩形(子)])
	## ⚠ 九宫格边距必须**读回来**判：这个 4.7 的 `NinePatchRect` 只有 `patch_margin_*`（整数），
	## `.tscn` 里写 `texture_margin_*` 不报错、也不生效（变成整幅拉伸），只看矩形的量具完全看不出来。
	var 底 := 页.get_node_or_null("内容底") as NinePatchRect
	_判(底 != null and 底.patch_margin_left == 11 and 底.patch_margin_right == 10
			and 底.patch_margin_top == 10 and 底.patch_margin_bottom == 11,
			"内容底的九宫格边距真的生效 = 11/10/10/11（实得 %s）" % (
				"%d/%d/%d/%d" % [底.patch_margin_left, 底.patch_margin_right,
					底.patch_margin_top, 底.patch_margin_bottom] if 底 != null else "没建"))
	for 名 in 页签件:
		var 枚 := 页.get_node_or_null("页签条/" + 名) as Button
		var 期 := [页签件[名][0] - 13.0, 0.0, 82.0, 22.0]		# 枚的框是**页签条局部**
		_判(枚 != null and _近(_矩形(枚), 期),
				"%s 在条内 x = %.0f、宽 82，实得 (%s)" % [名, 页签件[名][0],
					_矩形(枚) if 枚 != null else "没建"])
		_判(枚 != null and String(枚.text) == 页签文字[int(名.right(1))],
				"%s 文字 = 「%s」，实得「%s」" % [名, 页签文字[int(名.right(1))],
					枚.text if 枚 != null else ""])
	_判(页.get_node("页签条/页签0") is Button
			and (页.get_node("页签条/页签0") as Button).theme_type_variation == &"OrigTab",
			"页签走 OrigTab 主题变体（82 宽靠九宫格拉，自己烘一张 = 自造）")
	_判(absf((页.get_node("列表/行区") as Control).custom_minimum_size.x - 220.0) < 0.51,
			"行区宽 = 220（原版行渲染的 `_width`，不是列表的 235）")
	_判(absf((页.get_node("日志/日志文") as Control).custom_minimum_size.x - 217.0) < 0.51,
			"日志文宽 = 235 − 18（`_logPanel.width − 18`）")

	# ⑦ 买家档显隐（`:452-454`）：只有「购买」露
	_判((页.get_node("购买钮") as Button).visible
			and not (页.get_node("上架钮") as Button).visible
			and not (页.get_node("下架钮") as Button).visible
			and not (页.get_node("修改钮") as Button).visible,
			"买家档只露「购买」（上架/下架/修改都隐）")
	_判(absf((页.get_node("摊名框") as Control).position.x - 76.0) < 0.51,
			"买家档摊名框 x = (277−125)/2 = 76，实得 %.1f" % (页.get_node("摊名框") as Control).position.x)
	_判((页.get_node("摊名框/摊名文") as Label).text == String(夹["摊名"]),
			"摊名印进那一格（`setStall:558`），实得「%s」" % (页.get_node("摊名框/摊名文") as Label).text)
	_判((页.get_node("记录标签") as Label).text == "出售记录：",
			"状态行文字 = STALL_RECORD_LABEL，实得「%s」" % (页.get_node("记录标签") as Label).text)

	# ⑤⑥ 行：逐件矩形、层序、三档画法
	_判((窗.get("_摊位行们") as Array).size() == 2,
			"页 0「物品」= 2 行（另两行分别是宠物/货币），实得 %d" % (窗.get("_摊位行们") as Array).size())
	var 样 := 行脚本.new()
	root.add_child(样)
	_判(absf(样.size.x - 220.0) < 0.51 and absf(样.size.y - 50.0) < 0.51,
			"行 = 220×50（`StallItemRenderer.as:58-60`，`setSize()` 是空函数 ⇒ 不受列宽影响）")
	for 名 in 行脚本.矩形:
		var 子 := 样.get_node_or_null(名) as Control
		_判(子 != null, "行内逐件：%s 在" % 名)
		if 子 != null:
			_判(_近(_矩形(子), 行脚本.矩形[名]), "行内 %s = (%s)，实得 (%s)" % [名, 行脚本.矩形[名], _矩形(子)])
	var 序名: Array = []
	for 子 in 样.get_children():
		序名.append(String(子.name))
	## ⚠ `%` 右边必须再套一层数组：`"…%s" % 序名`（序名本身就是 14 个元素的数组）会被当成
	##   **14 个参数** ⇒ 运行期"not all arguments converted"，整条判据**根本没执行过**
	##   （门照样打「通过 N，红 0」，是零覆盖的假绿）。
	_判(序名 == 行层序, "行内层序按 AS3 的 addChild 序（实得 %s）" % [序名])
	_判(not (样.get_node("悬停条") as CanvasItem).visible
			and not (样.get_node("元宝底") as CanvasItem).visible
			and not (样.get_node("类型") as CanvasItem).visible
			and not (样.get_node("售价") as CanvasItem).visible
			and not (样.get_node("查看钮") as CanvasItem).visible,
			"建行时那五件默认隐（原版 createView 里就 .visible=false）")
	var 格边 := 样.get_node("物品格") as NinePatchRect
	_判(格边 != null and 格边.patch_margin_left == 9 and 格边.patch_margin_right == 6
			and 格边.patch_margin_top == 9 and 格边.patch_margin_bottom == 6,
			"行内物品格的九宫格边距 = 9/6/9/6（原版 40×40 的 `MGrid_background`，实得 %s）" % (
				"%d/%d/%d/%d" % [格边.patch_margin_left, 格边.patch_margin_right,
					格边.patch_margin_top, 格边.patch_margin_bottom] if 格边 != null else "没建"))
	var 角标 := 样.get_node("物品格/数量") as Label
	样.填(行表[0] as Dictionary)
	_判((样.get_node("名字") as Label).text == 游戏数据.item_name(10000001) and 角标.text == "5",
			"物品档：名字按物品号查（熊皮）、角标 = 数量 5（实得「%s」「%s」）" % [
				(样.get_node("名字") as Label).text, 角标.text])
	_判((样.get_node("价1文") as Label).text == "1000" and (样.get_node("价2文") as Label).text == "0",
			"物品档两格价 = 1000 / 0（`:313-314`），实得「%s」「%s」" % [
				(样.get_node("价1文") as Label).text, (样.get_node("价2文") as Label).text])
	_判(not (样.get_node("元宝底") as CanvasItem).visible, "现金价 0 ⇒ 不铺那层选中条（`:315-322`）")
	样.填(行表[1] as Dictionary)
	_判((样.get_node("元宝底") as CanvasItem).visible, "要元宝的挂牌（现金价 20）⇒ 那格底下铺一层选中条")
	样.填(行表[2] as Dictionary)
	_判((样.get_node("名字") as Label).text == "蜃" and 角标.text == "1"
			and (样.get_node("查看钮") as Button).visible
			and absf((样.get_node("名字") as Control).position.y) < 0.51
			and absf((样.get_node("名字") as Control).size.x - 84.0) < 0.51,
			"宠物档：名字「蜃」、角标恒 1、露「查看」、名字框挪到 y=0 并放宽到 84（`:284-291`）")
	样.填(行表[3] as Dictionary)
	_判((样.get_node("类型") as Label).text == "游戏金币"
			and (样.get_node("售价") as Label).text == "售价："
			and (样.get_node("名字") as Label).text == "10000",
			"货币档：「游戏金币」+「售价：」+ 数量 10000（`:342`/`:348-349`）")
	_判((样.get_node("价1文") as Label).text == "" and (样.get_node("价2文") as Label).text == "30",
			"货币档金币槽清空、元宝槽 = 要付的 30（`:343-344`），实得「%s」「%s」" % [
				(样.get_node("价1文") as Label).text, (样.get_node("价2文") as Label).text])
	_判(not (样.get_node("金币") as CanvasItem).visible and (样.get_node("元宝") as CanvasItem).visible,
			"卖金币 ⇒ 只露元宝那枚币（`:346-347`）")
	_判(absf((样.get_node("名字") as Control).position.y - 26.0) < 0.51
			and absf((样.get_node("金币") as Control).position.y - 26.0) < 0.51,
			"`dolayout:255-263`：名字行挪到 26、金币图标跟元宝图标同 y")
	_判(not (样.get_node("元宝底") as CanvasItem).visible, "货币档不铺元宝那层底（`:345`）")
	样.queue_free()

	# ⑧ 切页：换行集 + 换上下架文字 + 选中回到第 0 行
	for 序 in 3:
		await _点在(页.get_node("页签条/页签%d" % 序) as Button)
		for i in 2:
			await process_frame
		var n := (窗.get("_摊位行们") as Array).size()
		_判(n == 行集数[序], "切到页 %d ⇒ 行数 %d（实得 %d）" % [序, 行集数[序], n])
		_判(int(窗.get("_摊位选中")) == (0 if n > 0 else -1),
				"切页后选中回到第 0 行（`:526` selectedIndex = 0）")
		var 别人亮了 := 0
		for i in 3:
			if (页.get_node("页签条/页签%d" % i) as Button).button_pressed:
				别人亮了 += 1
		_判(别人亮了 == 1 and (页.get_node("页签条/页签%d" % 序) as Button).button_pressed,
				"页 %d：三枚里只有它自己是被选中那枚（实得 %d 枚亮）" % [序, 别人亮了])
	_判((页.get_node("上架钮") as Button).text == "货币上架"
			and (页.get_node("下架钮") as Button).text == "货币下架",
			"页 2 的上下架文字换成「货币上架/货币下架」（`:511-517`），实得「%s」「%s」" % [
				(页.get_node("上架钮") as Button).text, (页.get_node("下架钮") as Button).text])
	await _点在(页.get_node("页签条/页签0") as Button)
	for i in 2:
		await process_frame

	# ⑨ 选中唯一
	## 先证"真鼠标点行"确实触发 `被点击`：只 emit 信号会绕过 `_gui_input` 那一层，
	## 而工程里这类门被打回过（源码对上了 ≠ 点得动）。
	var 实点 := 行脚本.new()
	root.add_child(实点)
	实点.填(行表[0] as Dictionary)
	var 收到: Array = []
	实点.被点击.connect(func(x): 收到.append(x))
	await _点在(实点)
	for i in 2:
		await process_frame
	_判(收到.size() == 1 and int((收到[0] as Dictionary).get("uid", 0)) == 5001,
			"真鼠标点一行 ⇒ `被点击` 带着那条挂牌出来（实得 %d 次：%s）" % [收到.size(), str(收到)])
	实点.queue_free()
	var 两行: Array = 窗.get("_摊位行们")
	_判(两行.size() == 2, "回到页 0 还是两行（实得 %d）" % 两行.size())
	if 两行.size() == 2:
		await _点在(两行[1] as Control)
		_判(not bool((两行[0] as Control).选中) and bool((两行[1] as Control).选中),
				"点第二行 ⇒ 只有第二行亮（实得 行0=%s 行1=%s 选中号=%s；行1全屏框=%s 悬到=%s）" % [
					(两行[0] as Control).选中, (两行[1] as Control).选中, 窗.get("_摊位选中"),
					(两行[1] as Control).get_global_rect(),
					str(root.gui_get_hovered_control())])
		await _点在(两行[0] as Control)
		_判(bool((两行[0] as Control).选中) and not bool((两行[1] as Control).选中),
				"点第一行 ⇒ 换它亮、第二行灭（实得 行0=%s 行1=%s 选中号=%s）" % [
					(两行[0] as Control).选中, (两行[1] as Control).选中, 窗.get("_摊位选中")])

	# ⑩⑪⑫ 出帧这半边换假后端（入帧已经用真后端核过了）
	## 通知直接挂在 autoload `GameSession` 上（每一页各有一个 `功能窗口` 实例，
	## 但 `_session` 全是同一个 `/root/GameSession` ⇒ 从根上连一次就够，别从窗口身上绕）。
	var 会 = root.get_node_or_null("GameSession")
	_判(会 != null, "门跑之前 `GameSession` 这个 autoload 必须在（不然通知那条判据是零覆盖）")
	if 会 != null:
		会.connect("notification_requested", func(话): 通知.append(String(话)))
	var 假 := 假后.new()
	假.authoritative_stall = 状
	窗.set("_backend", 假)
	窗.set("_摊位选中", -1)
	await _点在(页.get_node("购买钮") as Button)
	for i in 2:
		await process_frame
	_判(管理._窗口们.get("摊位购买") == null, "没选中任何一行 ⇒ 点「购买」什么都不发生（`:595` 那层闸）")
	窗.set("_摊位选中", 0)
	假.authoritative_stats = {"money": 500, "cash": 0}
	await _点在(页.get_node("购买钮") as Button)
	for i in 4:
		await process_frame
	var 购: Node = 管理._窗口们.get("摊位购买")
	if _红完就退(购, "摊位购买窗"):
		return
	_判(_开着(购), "选中一行点「购买」⇒ 确认窗开出来了")
	## ⚠ 每一页都是**独立的 `功能窗口` 实例**，`_backend` 是各自在 `_ready` 里按节点名取的 ⇒
	## 只把摊位窗那一个换成假后端，确认弹仍然读**真**后端的余额（实测表现：点「确定」静默不发帧、
	## 通知也是空的，看着像产品坏了，其实是门只换了一半）。
	购.set("_backend", 假)
	var 购页 := _找页(购, "原版摊位购买内容")
	if _红完就退(购页, "确认窗页本体"):
		return
	_判(absf(购页.size.x - 166.0) < 0.51 and absf(购页.size.y - 157.0) < 0.51,
			"确认窗页 = 166×157（内容区 = 整窗 186 − 29），实得 %.0f×%.0f" % [购页.size.x, 购页.size.y])
	for 名 in 购件:
		var 子 := 购页.get_node_or_null(名) as Control
		_判(子 != null and _近(_矩形(子), 购件[名]),
				"确认窗 %s = (%s)，实得 (%s)" % [名, 购件[名],
					_矩形(子) if 子 != null else "没建"])
	for 名 in 购内件:
		var 子 := 购页.get_node_or_null("数量行/" + 名) as Control
		_判(子 != null and _近(_矩形(子), 购内件[名]),
				"数量行里 %s = (%s)，实得 (%s)" % [名, 购内件[名],
					_矩形(子) if 子 != null else "没建"])
	_判((购页.get_node("名称标签") as Label).text == "物品名称："
			and (购页.get_node("数量行/数量标签") as Label).text == "数量："
			and (购页.get_node("总价标签") as Label).text == "总价：",
			"三行标题 = 物品名称：/ 数量：/ 总价：（`DIALOG_NEED_MONEY_STRING` 的值不带冒号，代码补）")
	_判((购页.get_node("名称框/名称文") as Label).text == 游戏数据.item_name(10000001)
			and (购页.get_node("数量行/数量文") as Label).text == "5"
			and (购页.get_node("价1文") as Label).text == "1000"
			and (购页.get_node("价2文") as Label).text == "0"
			and (购页.get_node("确定钮") as Button).text == "购买",
			"确认窗填的是 熊皮 / 5 / 1000 / 0 / 钮「购买」")
	# ⑪ 余额不足：这一发**必须发不出去**，而且要说话（原版 `buyItem:323-332` 先比余额再发帧）。
	# ⚠ 这里要**真点一次「购买」**：光设余额不点，那条"一帧都不发"就是零覆盖的假绿。
	await _点在(购页.get_node("确定钮") as Button)
	_判(假.买过.is_empty(), "金币只有 500、要 1000 ⇒ 一帧都不发（实发 %s）" % str(假.买过))
	_判(通知.size() == 1 and 通知[0] == "对不起，你的金币不足",
			"余额不足要出那条 `UNION_QUITE_SORRY_NOT_COIN_YOU`（实得 %s）" % str(通知))
	_判(_开着(购), "余额不足时这扇**不许自己关**（原版 `:326` 直接 return，窗还留着）")
	# ⑫ 够 ⇒ 发 `7:<卖家号>:<卖家名>:<uid>` 并关窗
	假.authoritative_stats = {"money": 2000, "cash": 0}
	await _点在(购页.get_node("确定钮") as Button)
	for i in 4:
		await process_frame
	_判(假.买过.size() == 1, "钱够了点「购买」⇒ 正好再发一帧（实发 %d 次：%s；钮全屏框=%s 悬到=%s）" % [
			假.买过.size(), str(假.买过), (购页.get_node("确定钮") as Control).get_global_rect(),
			str(root.gui_get_hovered_control())])
	if 假.买过.size() == 1:
		var 发 := 假.买过[0] as Array
		_判(int(发[0]) == int(夹["摊主号"]) and String(发[1]) == String(夹["摊主名"])
				and int(发[2]) == int((行表[0] as Dictionary)["uid"]),
				"发的是 `1296:7:<摊主号=1002>:<摊主名=油女澪>:<挂牌 uid=5001>`（实得 %s）" % str(发))
	_判(not _开着(购), "买完这扇自己关掉（`buyItem:335 → onCloseBtnClick`）")

	# 摊主档（同一条算式的另一半）
	摊位窗.设档(页, true)
	_判((页.get_node("上架钮") as Button).visible and (页.get_node("下架钮") as Button).visible
			and (页.get_node("修改钮") as Button).visible
			and not (页.get_node("购买钮") as Button).visible,
			"摊主档露 上架/下架/修改、收「购买」（`:452-454`）")
	_判(absf((页.get_node("摊名框") as Control).position.x - 53.5) < 0.51
			and absf((页.get_node("修改钮") as Control).position.x - 186.5) < 0.51,
			"摊主档摊名行：框 x = (277−125−37−8)/2 = 53.5、钮 x = 186.5（`:456-459`），实得 %.1f/%.1f" % [
				(页.get_node("摊名框") as Control).position.x, (页.get_node("修改钮") as Control).position.x])
	摊位窗.设档(页, false)

	# ⑬ 尺寸表与居中弹
	var 表: Dictionary = JSON.parse_string(去BOM(FileAccess.get_file_as_string(尺寸表路径))) as Dictionary
	_判(表.has("随身摊位") and int(表["随身摊位"]["宽"]) == 277 and int(表["随身摊位"]["高"]) == 437
			and bool(表["随身摊位"]["整框"]) and String(表["随身摊位"]["标题"]) == "随身摊位",
			"尺寸表「随身摊位」= 277×437、整框、标题「随身摊位」")
	_判(表.has("摊位购买") and int(表["摊位购买"]["宽"]) == 166 and int(表["摊位购买"]["高"]) == 186
			and bool(表["摊位购买"]["整框"]) and String(表["摊位购买"]["标题"]) == "物品购买",
			"尺寸表「摊位购买」= 166×186、整框、标题「物品购买」")
	var 居: Dictionary = 管理.get("居中弹") as Dictionary
	_判(居.has("摊位购买") and not 居.has("随身摊位"),
			"确认弹进 `居中弹`、摊位窗不进（原版摊位窗是可拖的普通窗）")
	跑完了 = true
	print("随身摊位窗离线门：通过 %d，红 %d" % [通过, 失败])


static func 去BOM(文: String) -> String:
	return 文.trim_prefix("﻿")
