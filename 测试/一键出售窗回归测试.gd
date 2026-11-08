extends SceneTree

## 一键出售窗回归门（2026-10-17，巡检 #18）。
##
## 病根：商店页那枚「一键出售」**从来不弹窗** —— `功能窗口._quick_sell_items` 直接发
## `request_npc_shop_one_key_sell(1, 30, 0)`（§3.42 当年"折成一条协议"记的账）。而原版是
## `ShopWindow2.as:569-572 onQuickSaleBtn` → `UIMain2.as:2401-2407 showQuickSaleWindow()`
## → `PopUpMananger.centerWindow(new QuickSaleWindow(), true)`：**先弹窗选条件**，
## 再由 `QuickSaleWindow.as:71` 发 `requestOnekeySellEquips(level, star, color, target)`。
##
## 报文真值：`PacketCreator.getNPCShopOnekeySellRequestPacket:102-111`
## = `writeByte(5)` + **4 个 writeInt**（等级、星、品质、目标位图）。
## 旧写法只有 3 个 ⇒ 夹具把第 3 个读成**品质上限 = 0** ⇒ 每次必回 SHOP_ERROR；
## 而"1..30 格"这个区间本身在原版协议里根本不存在（扩容后的格子更卖不到）。
##
## 盯六件：
##   ① 点按钮 ⇒ **弹窗**、且**一发都不发**（旧写法正好是反的）；
##   ② 版式：410x300、说明框 10..225 压在三枚下拉（175）上面 ⇒ 必须 `mouse_filter = IGNORE`，
##      否则下拉与两枚勾选全点不动（原版 `TextArea2` 透明不吃鼠标）；
##   ③ 三枚下拉的**份数/文案序/默认档**（AS3 没有 setData ⇒ `selectedIndex=0`
##      ⇒ 20级、3星、白品，两枚勾选不勾）+ 重开回默认；
##   ④ 确定 ⇒ 按**值数组**下标取值（不是选项序号）+ 位图 `1|2|4` ⇒ `[20,3,1,1]` / `[80,5,3,7]`；
##   ⑤ 确定即关窗（`:72 onCloseBtnClick`）、取消关窗但**不发**，两者都把整舞台遮罩撤掉；
##   ⑥ 离线（`in_game=false`）点确定 ⇒ 不发、状态行给说法，不假装成功。
##
## ⚠ 三条口径：
##   · 开场钉 `root.size`（无头视口是 64×64，居中算式读它）；
##   · 本门走 `call_deferred` ⇒ 宿主 `_ready` 才跑得起来（§3.124.4）；
##   · 记包后端**必须带 `in_game` 属性**：`_成交一键出售` 第一件事就是 `bool(_backend.in_game)`，
##     裸 `Node` 上取不到这个属性会当场崩（"崩而不红"，§3.113）。
##
## 运行：`Godot --headless --path . --script res://测试/一键出售窗回归测试.gd`

const 窗场景 := "res://场景/界面/功能窗口.tscn"
const 出售窗场景 := "res://场景/界面/组件/一键出售窗.tscn"


## 只记参数、不发包的假后端。第四参默认 1 = `SELL_TARGET_EQUIP`（对应 AS3 的 `param4:int = 1`）。
class 记包后端 extends Node:
	var 记录: Array = []
	var in_game := true

	func request_npc_shop_one_key_sell(等级: int, 星级: int, 品质: int, 对象 := 1) -> bool:
		记录.append([等级, 星级, 品质, 对象])
		return true

var 红数 := 0
var _秒 := 0.0


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("一键出售窗回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 场: Node = (load(窗场景) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame
	场.call("open_page", "NPC商店")
	await process_frame

	var 遮罩层 := 场.get("_overlay") as Control
	var 页 := 场.get("_content") as Control
	if 遮罩层 == null or 页 == null:
		_记(false, "依赖不齐：遮罩层=%s 商店页=%s" % [遮罩层, 页])
		_finish()
		return
	var 按钮 := 页.find_child("一键出售", true, false) as Button
	if 按钮 == null:
		_记(false, "商店页没有「一键出售」按钮（`NPC商店窗口.tscn:99`）")
		_finish()
		return

	var 记包 := 记包后端.new()
	记包.name = "记包后端"
	场.set("_backend", 记包)

	# ① 点按钮 ⇒ 弹窗、**一发都不发**
	按钮.pressed.emit()
	await process_frame
	var 弹窗 := _取窗(遮罩层)
	_记(弹窗 != null, "点「一键出售」没弹出 QuickSaleWindow（原版先弹窗选条件，不是直接发包）")
	if 弹窗 == null:
		场.set("_backend", null)
		记包.free()
		_finish()
		return
	_记(弹窗.visible, "一键出售窗弹出来了但 visible=false")
	_记(记包.记录.is_empty(), "点按钮就直接发包了（实测 %s）—— 原版这一段只弹窗" % str(记包.记录))

	# ② 版式与说明框的鼠标穿透
	_记(弹窗.size == Vector2(410, 300), "窗尺寸 %s ≠ 410x300（`super(410,300,true)`）" % str(弹窗.size))
	var 说明 := 弹窗.get_node("说明") as RichTextLabel
	_记(说明.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"说明框没设 IGNORE —— 它会挡住下面那三枚下拉与两枚勾选")
	_记(说明.text.contains("镶嵌有宝石的装备不会被出售")
			and 说明.text.contains("强化+7以上的装备不会被出售")
			and 说明.text.contains("非紫色品质、且未镶嵌勾玉的玉链")
			and 说明.text.contains("会排除奥义忍术残卷"),
			"说明文案缺条（`SHOP_QUICKSALE_TIPS` :2473 五条里的某一条没烘进场景）")
	_记((弹窗.get_node("残卷勾选") as CheckBox).text == "一键出售残卷(排除奥义忍术残卷)"
			and (弹窗.get_node("玉链勾选") as CheckBox).text == "一键出售玉链(排除紫色品质玉链)",
			"两枚勾选文案没逐字对 `QuickSaleWindow.as:118-119`")
	_记((弹窗.get_node("标题") as Label).text == "一键出售装备",
			"标题 ≠ `SHOP_QUICKSALE_TITTLE`（:3177「一键出售装备」）")
	var 挡 := 遮罩层.get_node_or_null("购买窗遮罩") as ColorRect
	_记(挡 != null and 挡.visible, "缺一整舞台遮罩（原版 `centerWindow(..., true)`）")
	if 挡 != null:
		_记(挡.get_index() < 弹窗.get_index(), "遮罩该压在一键出售窗**下面**")

	# ③ 三枚下拉：份数、文案序、默认档
	var 等级下拉 := 弹窗.get_node("等级下拉") as OptionButton
	var 星级下拉 := 弹窗.get_node("星级下拉") as OptionButton
	var 品质下拉 := 弹窗.get_node("品质下拉") as OptionButton
	_记(等级下拉.item_count == 6 and 星级下拉.item_count == 4 and 品质下拉.item_count == 3,
			"下拉份数 %d/%d/%d ≠ 6/4/3（LEVELARR :1268 / STARARR :2727 / COLORARR :200）"
			% [等级下拉.item_count, 星级下拉.item_count, 品质下拉.item_count])
	_记(等级下拉.selected == 0 and 星级下拉.selected == 0 and 品质下拉.selected == 0,
			"三枚下拉没默认落在第一档（原版无初值 ⇒ 20级/3星/白品）")
	_记(等级下拉.get_item_text(5) == "120级及以下" and 星级下拉.get_item_text(3) == "6星及以下"
			and 品质下拉.get_item_text(2) == "蓝品及以下",
			"下拉文案顺序与语言表不符")
	_记(not (弹窗.get_node("残卷勾选") as CheckBox).button_pressed
			and not (弹窗.get_node("玉链勾选") as CheckBox).button_pressed,
			"两枚勾选默认就该不勾（原版 new 出来就是未选）")

	# ④ 确定 ⇒ 按下标去**值数组**取值 + 位图；⑤ 确定即关窗、遮罩跟着撤
	(弹窗.get_node("确定") as Button).pressed.emit()
	await process_frame
	_记(记包.记录.size() == 1 and int(记包.记录[0][0]) == 20 and int(记包.记录[0][1]) == 3
			and int(记包.记录[0][2]) == 1 and int(记包.记录[0][3]) == 1,
			"默认档发出去的不是 [20,3,1,1]，实测 %s（第四位是 `QuickSaleWindow.as:18-22` 的位图）"
			% str(记包.记录))
	_记(not 弹窗.visible, "点完确定窗还开着（原版 OKBtnClickHandler 里就关了）")
	_记(挡 != null and not 挡.visible, "确定关窗后整舞台遮罩没撤")

	# ④b 重开 ⇒ 先回默认档，再换档 + 勾两枚 ⇒ [80,5,3,7]（1|2|4）
	# ⚠️ 重开**前**要把档位/勾选弄脏：`确定` 只是关窗、节点还活着，不弄脏这一条就是空判
	#    （实测：把 `打开()` 里的复位整段删掉，本门照样全绿）。
	等级下拉.selected = 5
	(弹窗.get_node("残卷勾选") as CheckBox).button_pressed = true
	按钮.pressed.emit()
	await process_frame
	_记(等级下拉.selected == 0 and 星级下拉.selected == 0 and 品质下拉.selected == 0
			and not (弹窗.get_node("残卷勾选") as CheckBox).button_pressed
			and not (弹窗.get_node("玉链勾选") as CheckBox).button_pressed,
			"重开一键出售窗没回到默认档（原版每次 `new QuickSaleWindow()`）")
	等级下拉.selected = 3
	星级下拉.selected = 2
	品质下拉.selected = 2
	(弹窗.get_node("残卷勾选") as CheckBox).button_pressed = true
	(弹窗.get_node("玉链勾选") as CheckBox).button_pressed = true
	(弹窗.get_node("确定") as Button).pressed.emit()
	await process_frame
	_记(记包.记录.size() == 2 and int(记包.记录[1][0]) == 80 and int(记包.记录[1][1]) == 5
			and int(记包.记录[1][2]) == 3 and int(记包.记录[1][3]) == 7,
			"80级/5星/蓝品 + 两枚勾选发出去的不是 [80,5,3,7]，实测 %s" % str(记包.记录))

	# ⑤b 取消 ⇒ 关窗但**不发**
	按钮.pressed.emit()
	await process_frame
	(弹窗.get_node("取消") as Button).pressed.emit()
	await process_frame
	_记(记包.记录.size() == 2, "点取消也发出去了（原版 cancleBtnClickHandler 只关窗）")
	_记(not 弹窗.visible and 挡 != null and not 挡.visible, "取消后窗或遮罩还留着")

	# ⑥ 离线 ⇒ 不发、也不假装发出去了
	var 离线 := 记包后端.new()
	离线.in_game = false
	场.set("_backend", 离线)
	按钮.pressed.emit()
	await process_frame
	(弹窗.get_node("确定") as Button).pressed.emit()
	await process_frame
	_记(离线.记录.is_empty(), "离线（in_game=false）还把请求发出去了")
	var 状态 := 场.get("_status") as Label
	_记(状态 != null and 状态.text.contains("服务端"),
			"离线点确定没给说法（状态行实测 %s）" % (状态.text if 状态 != null else "<无 _status>"))
	场.set("_backend", null)
	记包.free()
	离线.free()

	# 组件单独实例化也要能自己建出下拉（文案烘在脚本里、不在场景里）
	var 单窗 := (load(出售窗场景) as PackedScene).instantiate() as Control
	root.add_child(单窗)
	await process_frame
	_记((单窗.get_node("等级下拉") as OptionButton).item_count == 6,
			"一键出售窗组件单独实例化时下拉是空的（`_ready` 里没填）")
	单窗.free()

	_finish()


## 遮罩上那枚一键出售窗。按**前缀**找：叠了两枚时 Godot 会把后一枚改名 `@Control@N`。
func _取窗(遮罩层: Control) -> Control:
	for 子 in 遮罩层.get_children():
		if String(子.name).begins_with("一键出售窗"):
			return 子 as Control
	return null


func _finish() -> void:
	if 红数 == 0:
		print("一键出售窗回归测试：通过（点按钮只弹窗不发包 / 410x300 版式与说明 IGNORE / "
				+ "下拉份数与默认档 / 确定按值数组取档并发出四位报文 / 取消不发 / 离线不假装）")
		quit(0)
	else:
		print("一键出售窗回归测试：失败 %d 项" % 红数)
		quit(1)
