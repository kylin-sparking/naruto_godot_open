extends SceneTree

## 商城开窗发包回归门（2026-10-21，用户报修 1.1「进入商城，就会提示扩充背包需要 162 个扩充密卷」）。
##
## 病根不在 UI：`游戏会话.request_cash_shop(..., include_meta=true)` 的元数据链里
## 挂着**第二发** `request_cash_shop_capacity()` ⇒ 发 **1084**。可 1084 **不是"查背包容量"**，
## 它是原版 `SendOpCodes.CS_REQ_CATEGORY_EXTEND` = **「申请扩充背包」这个动作**
## （`服务端/runtime/tools/fake_flash_server.py:11671` 把它 dispatch 到
## `handle_bag_capacity_extend:26118` → `_extend_item_capacity:26126`）：
## 　· 密卷不够 ⇒ `_send_system_chat("扩充背包需要%d个扩充密卷。")`（:26140，**玩家看到的就这句**）；
## 　· 密卷够 ⇒ **当场扣卷、背包 +30 格并落盘**。
## ⇒ 每进一次商城等于**替玩家点一次「扩充背包」**。162 = `数据/界面/扩容需求.json` 背包第 5 页需求。
##
## 原版真值：`CashShopWindow2.as:163 init()` 只 `requestData(0,19)`（:159，走 1074/1075），
## `:241 initWindow()` 只把 `API.dataCenter.cashMoney/bandMoney/famePoint` 的**本地缓存**刷上界面
## —— **一句容量都不问**。余额 1073 是 `Client.onCashItemInfo:7787` 那条（点商品详情时）才发的，
## 本工程把它保留在开窗链里（要新数，且它是纯查询、无副作用）。
##
## 盯七条：
##   ① 开窗（meta=true、无关键词）⇒ **只**发目录(432) + 余额(431)；等过 0.4s（比链里那个 0.1s 定时器长）
##      也不许冒出 1084/1085 任何一发。
##   ② 搜索路（有关键词）⇒ 发 1075 + 余额，同样不许冒出扩充。
##   ③ `include_meta=false` ⇒ 只有目录，400ms 后余额也不许来（钉住"meta 链归开关管"，
##      防止有人把两条腿改成无条件发）。
##   ④ **扩充的正路还活着**（行为腿）：真开一扇「背包」页 → 拿页面里那枚 `扩容窗口` →
##      `确认扩充.emit("背包")` ⇒ 替身后端**必须**正好记到一发 1084。
##      这条是防"把 1084 一刀切删干净"——那会让玩家再也扩不了背包（§3.10.9 那条正路）。
##   ⑤ 源码锚：`游戏会话.gd`（剥掉注释）里**一次都不许有**扩充请求；背包/仓库两扇窗里必须还有
##      **带接收者的那一次调用**（`.request_cash_shop_capacity()`）。
##      ⚠ 判据要带点号和括号：只写函数名的话 `has_method("request_cash_shop_capacity")`
##      那行守卫也算命中 ⇒ 真把调用删了门还绿（2026-10-21 反向对照 M2 就踩在这个坑上）。
##   ⑥ 夹具口径钉：服务端 1084 仍 dispatch 到 `handle_bag_capacity_extend`、广播文案仍是
##      「扩充{label}需要…」；`扩容需求.取需求("背包", 5)` 仍是 162（对得上用户报的那个数字）。
##      —— 万一哪天服务端把 1084 改成真查询，这条会红，提醒回来重判 ①④。
##   ⑦ `后端连接` 两个扩充入口都还在（④ 那条行为腿的发送口）。
##
## ⚠ 四条口径：
##   · **不碰真链路**：把 `/root/BackendConnection` 摘掉、换一枚同名的 `测试/测试后端连接.gd`
##     替身（它**继承真后端**，只把 `send_game_request/send_game_packet` 改成只记不发 ⇒ 信号、
##     `authoritative_bag_capacity` 等字段全都在，不会像手写 `extends Node` 的替身那样一边跑一边
##     漏 `SCRIPT ERROR`；同 `后端协议回归测试.gd:55` 的用法），跑完把真 autoload 换回去。
##     替身**要在开窗之前就挂好**，因为 `功能窗口._ready:381` 是在那时抓 `/root/BackendConnection`
##     当 `_backend` 的。判据一律读 `sent_requests` 里的 **opcode 数值**，不读自造文案。
##   · 有**跑完了哨兵**：中途报错退出 ⇒ 门直接红（不然静默假绿，§3.234 那条教训）。
##   · 门自己 `quit(0/1)`，绿判定看退出码 + 末行统计。
##   · 开场钉 `root.size`（无头视口默认 64×64，窗口要按屏幕居中）。
##
## 运行：`Godot --headless --path . --script res://测试/商城开窗发包回归测试.gd`

const 会话路径 := "res://脚本/单例/游戏会话.gd"
const 后端脚本 := "res://脚本/单例/后端连接.gd"
const 夹具路径 := "res://服务端/runtime/tools/fake_flash_server.py"
const 功能窗口场景 := "res://场景/界面/功能窗口.tscn"
const 测试后端 := preload("res://测试/测试后端连接.gd")
## 元数据链里那个定时器是 0.1s，这里等够 0.4s 才能证明"第二发确实没了"
const 等待秒 := 0.4
## 请求侧 opcode（`后端连接.gd:401-412`）：目录 432 / 搜索 1075 / 余额 431 / 扩充背包 1084 / 扩充仓库 1085
const 码目录 := 432
const 码搜索 := 1075
const 码余额 := 431
const 码扩充背 := 1084
const 码扩充仓 := 1085

var _通过 := 0
var _失败: Array[String] = []
var _跑完了 := false


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_跑")


func _判(对: bool, 明: String, 反: String = "") -> void:
	if 对:
		_通过 += 1
	else:
		_失败.append("%s%s" % [明, "" if 反.is_empty() else " ⇒ " + 反])


func _剥注释(路径: String) -> String:
	var 文 := ""
	var 整 := FileAccess.get_file_as_string(路径)
	for 行 in 整.split("\n"):
		if String(行).strip_edges().begins_with("#"):
			continue
		文 += String(行) + "\n"
	return 文


## 替身记的是 `{"opcode": ..., "content": ...}`；日志与判式只看 opcode 序列。
func _码(假) -> Array[int]:
	var 出: Array[int] = []
	for 条 in 假.sent_requests:
		出.append(int((条 as Dictionary).get("opcode", 0)))
	return 出


func _含扩充(假) -> bool:
	for 码 in _码(假):
		if 码 == 码扩充背 or 码 == 码扩充仓:
			return true
	return false


func _找(根: Node, 名: String) -> Node:
	if 根 == null:
		return null
	if String(根.name) == 名:
		return 根
	for 子 in 根.get_children():
		var 命中 := _找(子, 名)
		if 命中 != null:
			return 命中
	return null


func _跑() -> void:
	var 会话 = root.get_node_or_null("GameSession")
	var 真后端 := root.get_node_or_null("BackendConnection")
	if 会话 == null or 真后端 == null:
		_失败.append("拿不到 GameSession / BackendConnection 单例")
		_收尾()
		return
	root.remove_child(真后端)
	var 假 = 测试后端.new()
	假.name = "BackendConnection"
	假.in_game = true
	root.add_child(假)
	await process_frame

	# ① 开窗（meta=true）：目录 + 余额，两条之外一条都不许多
	假.sent_requests.clear()
	var 发出去了 := bool(会话.request_cash_shop(0, "", true))
	_判(发出去了, "① 开窗请求入口返回 true（真把包发出去了）")
	_判(_码(假) == [码目录],
		"① 开窗当帧只该有一发目录(432)，实得 %s" % [str(_码(假))],
		"多出来的那条就是当年 1084 藏身的地方")
	await create_timer(等待秒).timeout
	_判(_码(假) == [码目录, 码余额],
		"① 等过 %s 秒只能补到一发余额(431)，实得 %s" % [等待秒, str(_码(假))],
		"元数据链多出一条 ⇒ 又是「把动作当查询」")
	_判(not _含扩充(假), "① 开窗链里**绝不许**出现 1084/1085（扩充动作），实得 %s" % [str(_码(假))],
		"就是这条把用户的商城变成「每进一次点一次扩充」")

	# ② 搜索路：1075 + 余额，同样不许冒出扩充
	假.sent_requests.clear()
	var 搜 := bool(会话.request_cash_shop(0, "扩充密卷", true))
	_判(搜 and _码(假) == [码搜索],
		"② 带关键词走搜索那条(1075)，实得 %s" % [str(_码(假))])
	await create_timer(等待秒).timeout
	_判(_码(假) == [码搜索, 码余额],
		"② 搜索路也只补一发余额，实得 %s" % [str(_码(假))])
	_判(not _含扩充(假), "② 搜索路也不许冒出扩充，实得 %s" % [str(_码(假))])

	# ③ 开关关掉 ⇒ 连余额都不该来（钉住"meta 链归 include_meta 管"）
	假.sent_requests.clear()
	var 关 := bool(会话.request_cash_shop(0, "", false))
	await create_timer(等待秒).timeout
	_判(关 and _码(假) == [码目录],
		"③ include_meta=false 时只发目录、余额都不发，实得 %s" % [str(_码(假))],
		"改成无条件发 ⇒ 每次翻页都多打后端两枪")

	# ④ 扩充的正路：真开一扇背包页，走扩容窗那枚「确定」（防"一刀切删干净"）
	var 窗 := (load(功能窗口场景) as PackedScene).instantiate()
	root.add_child(窗)
	await process_frame
	await process_frame
	窗.call("open_page", "背包")
	for i in 4:
		await process_frame
	var 扩容 := _找(窗, "扩容窗口") as Node
	if 扩容 == null:
		_失败.append("④ 背包页里取不到「扩容窗口」节点 ⇒ 正路无从可走（场景被改过？）")
	else:
		假.sent_requests.clear()
		扩容.emit_signal("确认扩充", "背包")
		_判(_码(假) == [码扩充背],
			"④ 扩容窗「确定」应当正好发一发 1084，实得 %s" % [str(_码(假))],
			"空 ⇒ 玩家再也扩不了背包；多 ⇒ 一次点击发了两枪")
	窗.queue_free()
	await process_frame

	# ⑤ 源码锚 & 开窗链里一条都不许有（剥注释防自证；调用要带点号与括号，见头上 ⑤）
	var 会话源 := _剥注释(会话路径)
	_判(not 会话源.contains("request_cash_shop_capacity")
			and not 会话源.contains("request_cash_storage_capacity"),
		"⑤ `游戏会话.gd`（剥注释）里不该再出现任何扩充请求调用",
		"有人把 1084 写回开窗链了 ⇒ 用户那句提示会原样复发")
	var 背包源 := _剥注释("res://脚本/界面/窗口/背包窗口.gd")
	var 仓库源 := _剥注释("res://脚本/界面/窗口/仓库窗口.gd")
	_判(背包源.contains(".request_cash_shop_capacity()"),
		"⑤ 背包扩容窗「确定」仍要**调用** 1084（判据带点号括号，光有 `has_method` 那行守卫不算）")
	_判(仓库源.contains(".request_cash_storage_capacity()"),
		"⑤ 仓库扩容窗「确定」仍要**调用** 1085（同上）")

	# ⑥ 夹具口径：1084 仍是"动作"、广播文案与 162 这两个数还在
	var 夹具 := FileAccess.get_file_as_string(夹具路径)
	_判(夹具.contains("op(ClientOpcode.CASH_CATEGORY_EXTEND): self.handle_bag_capacity_extend"),
		"⑥ 服务端仍把 1084 dispatch 到 `handle_bag_capacity_extend`（它确实是扩充动作）",
		"这条改了就是要回来重判 ①④")
	_判(夹具.contains('扩充{label}需要{required}个扩充密卷'),
		"⑥ 服务端广播文案仍是「扩充{label}需要…个扩充密卷」（用户看到的原话）")
	var 需求脚本 = load("res://脚本/界面/扩容需求.gd")
	var 第5页: Dictionary = 需求脚本.取需求("背包", 5)
	_判(int(第5页.get("需要数量", 0)) == 162,
		"⑥ 背包第 5 页需求 = 162（对得上用户报的那个数字），实得 %d" % int(第5页.get("需要数量", 0)))
	# ⑥b 每页格数：客户端 背包 90（10 列 x 9 行，用户 2026-10-31 口径）/ 仓库 30，服务端必须同值。
	# 页号 = ceil(容量/页宽)：两边页宽不一致 ⇒ 一张密卷扩出来的格数对不上界面页数（§3.316）。
	_判(夹具.contains("BAG_PAGE_SIZE = 90"),
		"⑥b 服务端背包页宽仍是 90（10 列 x 9 行，用户 2026-10-31 口径）",
		"服务端与客户端页宽不一致 = 扩容后页数对不上")
	_判(夹具.contains("MAX_BAG_CAPACITY = BAG_PAGE_SIZE * 9"),
		"⑥b 服务端背包上限 = 页宽×9（页签只有一~九）")
	_判(夹具.contains("INVENTORY_PAGE_SIZE = 30"),
		"⑥b 仓库仍按原版 30 格/页（这次只改背包）")
	_判(int(需求脚本.每页格数("背包")) == 90 and int(需求脚本.每页格数("仓库")) == 30,
		"⑥b 扩容需求的页宽该是 背包 90 / 仓库 30，实得 %d / %d" % [
				int(需求脚本.每页格数("背包")), int(需求脚本.每页格数("仓库"))])

	# ⑦ 后端那条发送口本身还在（删了它，④ 的"正路"就是空话）
	var 后端 = (load(后端脚本) as GDScript).new()
	_判(后端.has_method("request_cash_shop_capacity")
			and 后端.has_method("request_cash_storage_capacity"),
		"⑦ `后端连接` 两个扩充入口都还在")
	后端.free()

	# ⑥c 容量的整页口径是**服务端行为**（读档 from_dict / 扩充 handler），GDScript 读不到 ⇒ 跑 Python 锤。
	# 用户 2026-10-31：「背包的总格子数还是错的」—— 90 格/页的界面下，存量 308 必须补成 360。
	var 锤码 := _跑容量锤()
	_判(锤码 == 0, "⑥c 容量锤通过：读档补整页（308→360）+ 扩充补整页 + 仓库保持逐档 +30",
		"锤退出码 %d" % 锤码)

	_跑完了 = true
	假.free()
	root.add_child(真后端)
	_收尾()


func _收尾() -> void:
	if not _跑完了:
		_失败.append("门没跑到底（中途报错退出）⇒ 上面每条判式都还没量到")
	for 条 in _失败:
		print("失败 - ", 条)
	print("商城开窗发包回归测试：通过 %d，红 %d" % [_通过, _失败.size()])
	quit(0 if _失败.is_empty() else 1)


## 跑服务端容量锤（`开发工具/验背包扩容整页.py`）。解释器口径同 `亲热天堂3紫装池回归测试.gd`：
## `运行时/python/python.exe` → PATH `python`；都没有就红着说原因，绝不静默跳过。
func _跑容量锤() -> int:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程.path_join("开发工具/验背包扩容整页.py")
	if not FileAccess.file_exists(锤):
		printerr("商城开窗发包回归测试：找不到容量锤 " + 锤)
		return 1
	var 候选: Array[String] = [工程.path_join("运行时/python/python.exe"), "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		printerr("商城开窗发包回归测试：找不到 Python 解释器（试过 " + str(候选) + "）")
		return 1
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	if 码 != 0:
		printerr("商城开窗发包回归测试：容量锤退出 %d —— 整页口径不符（回归！）" % 码)
	return 码
