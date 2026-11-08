extends SceneTree

## 「滚动条在框内」+「打开商店/仓库要带出背包且两窗平齐」的回归门（2026-10-04，用户实机打回）。
##
## 它盯的两件事，都不是文本门能看见的：
##   1. **滚动条被容器撑到窗外**。Godot 的 `ScrollContainer.get_combined_minimum_size()`
##      = 内容最小宽 **+ 滚动条宽**，而 Control 的 `size` 恒 ≥ 最小尺寸 ⇒
##      内容最小宽一旦写成"滚动区全宽"（商店 255 / 商城 608），容器就自己变宽一条滚动条，
##      滚动条整条画到窗口框外。真值口径在 `原版皮肤表.gd:配原版滚动区`
##      （`ScrollBar.as:13` WIDTH=15、`BaseScrollPane.as:22/:354` contentPadding=0）。
##      ⚠ 空货架时滚动条不显示 ⇒ `窗口布局体检` 抓不到，**这里必须先喂数据**。
##   2. **成对开窗**。原版 `UIMain2.as:4894-4901 showShopWindow()` / `:4544`（仓库）
##      都走 `centerTwoWindow(主, 背包)`（`:3159-3185`）：背包一起开、
##      `:3170-3171` 主窗按自己高度居中、`:3174-3175` 整对水平居中且背包紧贴主窗右侧 1px。
##      ⚠ 2026-10-31 起本工程背包 556 高（10 行一屏全露）⇒ 背包单独夹进 560 屏内
##      （y = 4），**顶边不再平齐**（有意偏离，见 `窗口管理.成对摆位`）。
##
## 运行：Godot --headless --path . --script res://测试/滚动条在框内回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页表 := [["NPC商店", "商品面板/商品滚动", 255.0], ["商城", "商品列表框/商品滚动", 608.0]]

var 帧 := 0
var 阶段 := 0
var 场景: Node
var 管: Node
var 红 := 0
var 日志: Array[String] = []


func _记(过: bool, 文本: String) -> void:
	if not 过:
		红 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文本])


func _喂数据() -> void:
	var 会 = root.get_node("/root/GameSession")
	会.backend_authoritative = true
	会.server_npc_shop_loaded = true
	会.npc_shop_items.clear()
	for i in 20:
		会.npc_shop_items.append({"id": "16000110", "name": "商品%02d" % i, "price": 150 + 50 * i,
				"icon": "res://素材/物品/原版/FuZhuWuPin/FuZhuWuPin_16000110_info.swf_1_FuZhuWuPin_16000110_info_icon.png"})


func _process(_d: float) -> bool:
	帧 += 1
	if 帧 < 8:
		return false
	if 阶段 == 0:
		场景 = (load(地图场景路) as PackedScene).instantiate()
		root.add_child(场景)
	elif 阶段 == 1:
		管 = 场景.get_node_or_null("窗口管理")
		if 管 == null:
			print("!! 地图场景下没有 窗口管理")
			quit(1)
			return true
		_喂数据()
	elif 阶段 >= 2 and 阶段 - 2 < 页表.size() * 2:
		var 序: int = int((阶段 - 2) / 2)
		if (阶段 - 2) % 2 == 0:
			# 无头视口默认 64×64（2026-10-31 发现本门一直没钉 ⇒ 居中算式读 64，两窗堆在负坐标）。
			# 每次开窗前重钉：headless 过帧会把 root.size 打回 64×64。
			root.size = Vector2i(960, 560)
			管.call("打开", String((页表[序] as Array)[0]))
		else:
			_量一页(页表[序])
	elif 阶段 - 2 == 页表.size() * 2:
		_收尾()
		return true
	阶段 += 1
	return false


func _窗(页名: String) -> Node:
	return 管._窗口们.get(页名) as Node


## 页根的名字各页不同（`原版NPC商店内容` / 商城那页另一套），所以按**末段名**递归找，
## 不写死整条路径 —— 写死就等于把"页面根改名"变成假绿。
func _找滚动(父: Node, 名: String) -> Node:
	for 子 in 父.get_children():
		if String(子.name) == 名 and 子 is ScrollContainer:
			return 子
		var 果 := _找滚动(子, 名)
		if 果 != null:
			return 果
	return null


func _量一页(条: Array) -> void:
	var 页名 := String(条[0])
	var 滚动路 := String(条[1])
	var 区宽 := float(条[2])
	var 窗 := _窗(页名)
	日志.append("=== %s ===" % 页名)
	if 窗 == null:
		_记(false, "%s 没开出来" % 页名)
		return
	var 滚动 := _找滚动(窗, 滚动路.split("/")[-1]) as ScrollContainer
	if 滚动 == null:
		_记(false, "%s 找不到滚动容器 %s" % [页名, 滚动路])
		return
	var 外框: Rect2 = (窗.get_node("遮罩/主窗口") as Control).get_global_rect()
	var 滚动盒: Rect2 = 滚动.get_global_rect()
	var 条2: Control = 滚动.get_v_scroll_bar() as Control
	var 条盒: Rect2 = 条2.get_global_rect()
	_记(滚动盒.size.x <= 区宽 + 0.5,
			"%s 滚动容器实测宽 %.1f ≤ 真值 %.0f（被撑宽 = 滚动条掉到框外）" % [页名, 滚动盒.size.x, 区宽])
	_记(条2.custom_minimum_size.x == 15.0,
			"%s 滚动条压回原版 15 宽（ScrollBar.as:13 WIDTH=15；主题默认 19），实测 %.1f"
			% [页名, 条2.custom_minimum_size.x])
	if not 条2.visible:
		# 内容没超出滚动区 ⇒ 滚动条不显示（商城这一页离线没货时就是这态）。
		# 这时比它的矩形没有意义 —— 但**容器有没有被撑宽**照样量得到，上面那条已经盯住了。
		日志.append("  -- %s 滚动条未显示（内容没超高）⇒ 只量了容器宽" % 页名)
	else:
		_记(条盒.end.x <= 外框.end.x + 0.5 and 条盒.position.x >= 外框.position.x - 0.5,
				"%s 滚动条整条在窗口外框内：条 %s / 框 %s" % [页名, str(条盒), str(外框)])
		# 原版 `BaseScrollPane.as:354` `_verticalScrollBar.x = width − WIDTH − contentPadding`、
		# `:22` contentPadding=0 ⇒ 滚动条**右沿 == 滚动区右沿**（不是父面板的右沿：
		# 商城的滚动区 (3,2) 608×308 就坐在 618 宽的 listBg 里，见 `CashShopWindow2.as:213-216`）。
		_记(absf(条盒.end.x - 滚动盒.end.x) <= 1.0,
				"%s 滚动条右沿 == 滚动区右沿（贴边在内）：%.1f vs %.1f" % [页名, 条盒.end.x, 滚动盒.end.x])
	# 成对开窗只对 NPC商店 / NPC仓库 成立
	if 页名 == "NPC商店" or 页名 == "NPC仓库":
		var 包 := _窗("背包")
		_记(包 != null and bool(包.call("已打开")), "%s 打开时背包**同步开出来**（centerTwoWindow）" % 页名)
		if 包 != null:
			var 主盒: Rect2 = (窗.get_node("遮罩/主窗口") as Control).get_global_rect()
			var 包盒: Rect2 = (包.get_node("遮罩/主窗口") as Control).get_global_rect()
			# 原版 `:3170` 主窗按**自己**高度居中；本工程背包 556 高 ⇒ 夹进 560 屏内 y = 4、
			# 顶边因此不再平齐（2026-10-31 有意偏离，见 `窗口管理.成对摆位`）。
			# 期望写死：主 y = floor((560-主高)/2)，背包 y = 4。
			_记(absf(主盒.position.y - floorf((560.0 - 主盒.size.y) * 0.5)) <= 0.6,
					"%s 主窗按自己高度竖直居中（:3170），实测 %.1f（应 %.1f）"
					% [页名, 主盒.position.y, floorf((560.0 - 主盒.size.y) * 0.5)])
			_记(absf(包盒.position.y - 4.0) <= 0.6 and 包盒.end.y <= 560.5,
					"%s 背包（556 高）夹进屏内 y = 4、底 %.1f 不出屏，实测 y %.1f"
					% [页名, 包盒.end.y, 包盒.position.y])
			_记(absf(包盒.position.x - (主盒.end.x + 1.0)) <= 0.6,
					"背包紧贴主窗右侧 1px（:3175）：%.1f vs %.1f" % [包盒.position.x, 主盒.end.x + 1.0])


func _收尾() -> void:
	for 一 in 日志:
		print(一)
	print("滚动条在框内回归：%s（红 %d 项）" % ["通过" if 红 == 0 else "不通过", 红])
	quit(1 if 红 > 0 else 0)
