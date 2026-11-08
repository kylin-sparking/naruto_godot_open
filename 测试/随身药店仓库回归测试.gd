extends SceneTree
## 背包底部「随身药店 / 随身仓库」的**无等级**上行 + 回帧开窗 的离线门（§3.223 立，§3.273 改成不判 VIP）。
## 上行动作号手抄自 AS3（`AllInOneProcessor.as:933/1761`），回帧格式抄自夹具
## （`_send_npc_shop` ⇒ `326`、`_send_storage_open:55713-55723` ⇒ `330:1`），**不从被测代码反查**。
##
## ⚠ 这一族**有意偏离原版**（用户 2026-10-25 报修 5.1「随身拉面馆、随身仓库…之前开放，不要求任何 vip 等级」
## + 5.2「删除 vip、vip 充值的内容按键逻辑」）⇒ 原版的 `VIPManager.vipLevel >= CANG_KU_LEVEL` 那道闸、
## 「购买VIP确认」弹和元宝那两条上行（动作 5／6）**整条删掉**了。§3.203 商城「充值」键同一族。
## 所以本门的判据是"**等级是多少都照发**"，而不再是"够格才发"；`测试/随身药店仓库回归测试.gd` 的旧 ④~⑧ 腿
## （弹的几何／文案／暗层／元宝那条）随 builder 一起作废，别再往里加。
##
## 覆盖：
##   ① VIP **0 和 3 两档各判一次** ⇒ 药店发 `1818:1`、仓库发 `1818:2`，**各只一跳**、
##      不弹任何东西、不吱声、**本地绝不开窗**（档 0 就是旧写法的死区，钉住"闸真没了"）
##   ② `_backend` 为 null / 缺那两条方法 ⇒ 同一句「未连接服务端」（而且写进看得见的标签）
##   ③ 发出去返回 false ⇒ 「请求发送失败」
##   ④ 那一扇**已建过** ⇒ 切显隐、零上行、不弹（VIP=0 与 VIP=3 各判一次 ⇒ 钉住判式顺序还在）
##   ⑤ 回帧消费者：`326` ⇒ NPC商店 自己开 + 连背包一起开（成对摆位）；`330:1` **分块拼完**才开 NPC仓库，
##      半途不许开；`330:3/4` 那种后续帧不许把关掉的仓库窗提回来
##   ⑥ 偏离/缺口钉：底部缺口表已空、`仓库等级` 常量已删、`购买VIP确认弹.gd` 不在盘上、
##      `request_vip*` 只剩三条（动作 3/4 外挂支 + 5/6 元宝支**都是故意不做**）、
##      背包页面上找不到「充值」那枚、这两扇不进 `居中弹`
##   ⑦ 接上之后**不该再往「后端状态」里写占位话**
##
## ⚠ 本门会喂 `326/330` 真帧 ⇒ 动到 `authoritative_*`、`GameSession` 与 user:// ⇒ 开场快照、收尾按字节还原。
##
## 跑法：`Godot --headless --path . --script res://测试/随身药店仓库回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 管理脚本 := preload("res://脚本/界面/窗口管理.gd")
const 背包脚本 := preload("res://脚本/界面/窗口/背包窗口.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 门存档快照 := preload("res://测试/门存档快照.gd")

## 已删掉的那一族的**盘上路径**：⑥ 拿 `FileAccess` 验它们真的不在了（不是"注释里说删了"）。
const 确认弹路径 := "res://脚本/界面/窗口/购买VIP确认弹.gd"

## `330:1:<npc>:<容量>:<金币>:<期望条数>:<条表>`（服务端 `_send_storage_open:55713-55723`）。
## 两条只差槽位/件数，故意让**第一块只到一条**来验"半途不许开窗"。
const 货一 := "2&3000001&1&5&0&0&1&测试角色&0&6001"
const 货二 := "2&3000001&2&7&0&0&1&测试角色&0&6002"
## `326:<npc>:<页签表>`（服务端 `_send_npc_shop(14)`，药店那一支的 npc 号就是 14）。
const 商店帧 := "326:14:武器&1010021#500#0#500#1#1#false"

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 秒 := 0.0
var 文件前 := {}
var 通告: Array = []


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	文件前 = 门存档快照.全快照()
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	_收尾()
	quit(1 if 失败 > 0 else 0)


## 看门狗：协程里没被守卫住的崩溃不会走到 quit ⇒ 无头**挂死**，而且脏存档留在盘上坑别的门。
func _process(delta: float) -> bool:
	秒 += delta
	if 秒 > 150.0:
		print("红：随身药店仓库离线门看门狗超时（150s）—— 中途崩了没走到收尾")
		_收尾()
		quit(1)
	return false


func _收尾() -> void:
	_还原账()
	门存档快照.全还原(文件前)
	print("随身药店仓库离线门：通过 %d，红 %d" % [通过, 失败])


var _存统计: Dictionary = {}
var _存VIP = 0
var _存商店: Dictionary = {}
var _存仓库: Array = []
var _存块: Dictionary = {}
var _存期望 = 0
var 会话: Node
var 后: Node


func _还原账() -> void:
	if 会话 == null or 后 == null:
		return
	var 统计: Dictionary = 会话.get("player_stats") as Dictionary
	统计.clear()
	统计.merge(_存统计, true)
	var 货架: Dictionary = 后.get("authoritative_npc_shop") as Dictionary
	货架.clear()
	货架.merge(_存商店, true)
	var 存货: Array = 后.get("authoritative_storage") as Array
	存货.clear()
	for 条 in _存仓库:
		存货.append(条)
	var 块: Dictionary = 后.get("_storage_chunks") as Dictionary
	块.clear()
	块.merge(_存块, true)
	后.set("authoritative_vip_level", _存VIP)
	后.set("_storage_expected_count", _存期望)


func _擦(假: Node, 状: Label) -> void:
	(假.get("sent_requests") as Array).clear()
	状.text = ""
	通告.clear()


func _发过(假) -> Array:
	var 出 := []
	for 条 in (假.get("sent_requests") as Array):
		出.append("%s:%s" % [条["opcode"], 条["content"]])
	return 出


## 背包页会被 `open_page` **重建**（伴随背包那条就把整页换过一次）⇒ 每腿现取，别攥着旧按钮。
func _背包钮(包: Node, 名: String) -> Button:
	var 页 := 包.find_child("原版背包内容", true, false) as Control
	if 页 == null:
		_判(false, "背包页没建出来 ⇒ 拿不到「%s」" % 名)
		return null
	var 钮 := 页.get_node_or_null(名) as Button
	if 钮 == null:
		_判(false, "背包页里没有「%s」" % 名)
	return 钮


## 「点底部那颗」= 现取现发。攥着上一腿的按钮句柄会踩到**已重建的旧页**：
## 背包页在开窗/置顶/属性变更时整片 `remove_child + queue_free` 重造（`_instantiate_page`），
## 旧节点 `.pressed` 直接 Invalid access（门当场断、看门狗才收尸 —— 2026-10-20 撞过一次）。
func _点(包: Node, 名: String) -> void:
	var 钮 := _背包钮(包, 名)
	if 钮 == null:
		return
	钮.pressed.emit()


func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


func _喂(原文: String) -> void:
	后.call("_handle_bridge_text", 原文)


## 整棵子树扫名字：⑥ 用它钉"背包页里没有充值那枚"（§3.203 用户明确要求删）。
func _名字里有(根: Node, 子串: String) -> Array:
	var 出: Array = []
	var 栈: Array[Node] = [根]
	while not 栈.is_empty():
		var 节: Node = 栈.pop_back()
		for 子 in 节.get_children():
			栈.append(子)
		if String(节.name).contains(子串):
			出.append(String(节.name))
	return 出


## 只用来验"缺方法"与"返回 false"两支。
class 拒后 extends Node:
	func request_vip_open_medicine() -> bool:
		return false

	func request_vip_open_store() -> bool:
		return false


func _跑() -> void:
	print("随身药店仓库离线门开始")
	await process_frame
	后 = root.get_node("BackendConnection")
	会话 = root.get_node_or_null("GameSession")
	_判(会话 != null, "门跑之前 `GameSession` 这个 autoload 必须在（那句提示靠它）")
	# ── 开场快照（内存 + 文件两层；文件那层交给 `门存档快照` 按字节还原）──
	_存统计 = (会话.get("player_stats") as Dictionary).duplicate(true)
	_存VIP = 后.get("authoritative_vip_level")
	_存商店 = (后.get("authoritative_npc_shop") as Dictionary).duplicate(true)
	_存仓库 = (后.get("authoritative_storage") as Array).duplicate(true)
	_存块 = (后.get("_storage_chunks") as Dictionary).duplicate(true)
	_存期望 = 后.get("_storage_expected_count")
	后.set("in_game", false)
	root.size = Vector2i(960, 560)
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame
	会话.notification_requested.connect(func(文本: String) -> void: 通告.append(文本))

	var 包: Node = 管理.call("取或建窗口", "背包")
	管理.call("打开", "背包")
	for i in 5:
		await process_frame
	var 状: Label = 包.get("_status") as Label
	if 状 == null:
		_判(false, "「后端状态」标签没拿到 ⇒ 「点了要给个说法」那几条判据无从跑起")
		跑完了 = true
		return
	var 药店 := _背包钮(包, "随身药店")
	var 仓库 := _背包钮(包, "随身仓库")
	_判(药店 != null and 仓库 != null,
			"底部那两颗必须**在场景里**（药店以前躺在占位表里、仓库走的是本地开窗）")
	if 药店 == null or 仓库 == null:
		跑完了 = true
		return
	var 假 := 测试后端.new()
	root.add_child(假)
	假.set("in_game", false)
	包.set("_backend", 假)

	# ── ① **等级是多少都照发** ⇒ 各发各的那一条，而且窗口那边什么都不许发生 ────────
	# ⚠ 档位取 **0 和 3**：旧写法 `>= 1` 在 0 那一档会**弹确认、一条不发** ⇒ 这一发就是"闸真删了"的钉子。
	for 档 in [0, 3]:
		假.set("authoritative_vip_level", 档)
		_擦(假, 状)
		_点(包, "随身药店")
		await process_frame
		_判(_发过(假) == ["1818:1"],
				"VIP=%s 点「随身药店」该只发 `1818:1`（**不判等级**），实测 %s" % [档, str(_发过(假))])
		_判(状.text == "", "发成功不该占「后端状态」那句话（原版只在**发不出去**时才吱声），实得「%s」" % 状.text)
		_判(通告.is_empty(), "VIP=%s 点药店不该有任何提示/通告，实测 %s" % [档, str(通告)])
		_判(管理.call("取窗口", "NPC商店") == null,
				"点下去**不许**本地把商店页开出来 —— 开窗的是服务端 `326`（原版这一跳连窗都不碰）")
		_擦(假, 状)
		_点(包, "随身仓库")
		await process_frame
		_判(_发过(假) == ["1818:2"],
				"VIP=%s 点「随身仓库」该只发 `1818:2`（**不判等级**），实测 %s" % [档, str(_发过(假))])
		_判(管理.call("取窗口", "NPC仓库") == null, "同上：仓库窗等 `330:1` 拼完才开")
		_判(通告.is_empty(), "VIP=%s 点仓库不该有任何提示/通告，实测 %s" % [档, str(通告)])

	# ── ② 没连服务端 / 缺方法 ⇒ 一句「未连接服务端」，而且要看得见 ────────────────
	for 空后端 in [null, Node.new()]:
		包.set("_backend", 空后端)
		_擦(假, 状)
		_点(包, "随身药店")
		_点(包, "随身仓库")
		await process_frame
		_判(状.text == "随身仓库：未连接服务端" and 状.visible,
				"后端%s 时点仓库该说「随身仓库：未连接服务端」且标签可见，实测「%s」/visible=%s" % [
					"为空" if 空后端 == null else "缺那两条方法", 状.text, str(状.visible)])
		_擦(假, 状)
		_点(包, "随身药店")
		await process_frame
		_判(状.text == "随身药店：未连接服务端" and 状.visible,
				"后端%s 时点药店该说「随身药店：未连接服务端」，实测「%s」" % [
					"为空" if 空后端 == null else "缺那两条方法", 状.text])
		if 空后端 != null:
			(空后端 as Node).free()
	包.set("_backend", 假)

	# ── ③ 发了但返回 false ⇒ 「请求发送失败」────────────────────────────────────
	var 拒 := 拒后.new()
	root.add_child(拒)
	包.set("_backend", 拒)
	for 名 in ["随身药店", "随身仓库"]:
		_擦(假, 状)
		_点(包, 名)
		await process_frame
		_判(状.text == "%s请求发送失败" % 名 and 状.visible,
				"上行返回 false 该说「请求发送失败」，实测「%s」" % 状.text)
	包.set("_backend", 假)

	# ── ④ 判式顺序：那一扇**已建过** ⇒ 切显隐，抢在上行之前（等级那一支没了，这条还在）─
	var 商: Node = 管理.call("取或建窗口", "NPC商店")
	_判(商 != null and not _开着(商), "取或建窗口：实例建好但没打开")
	for 档 in [0, 3]:
		假.set("authoritative_vip_level", 档)
		_擦(假, 状)
		_点(包, "随身药店")
		for i in 3:
			await process_frame
		_判(_开着(商), "VIP=%s：实例已建 ⇒ 点药店应把 NPC商店 切**出来**（`reverseDisplay`）" % 档)
		_判(_发过(假).is_empty(), "VIP=%s：切显隐这一支**一个包都不发**，实测 %s" % [档, str(_发过(假))])
		_点(包, "随身药店")
		for i in 3:
			await process_frame
		_判(not _开着(商), "VIP=%s：再点一次收起（同一次连点不该越点越开）" % 档)

	# ── ⑤ 回帧开窗 ───────────────────────────────────────────────────────────
	管理.call("全部关闭")
	for i in 2:
		await process_frame
	_喂(商店帧)
	for i in 2:
		await process_frame
	_判(_开着(管理.call("取窗口", "NPC商店")),
			"`326` 到本端 ⇒ NPC商店 **自己**开出来（消费者 `窗口管理._on_npc_shop`）")
	_判(_开着(管理.call("取窗口", "背包")),
			"伴随背包：原版 `showShopWindow` 走的是 centerTwoWindow(商店, 背包)")
	var 主窗 := 商.get_node_or_null("遮罩/主窗口") as Control
	var 包窗 := 包.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 != null and 包窗 != null:
		# 2026-10-31：背包 556 高 ⇒ 主窗按自己高度居中、背包夹进 560 屏内（y = 4）、顶边不再平齐
		# （有意偏离，见 `窗口管理.成对摆位`）。offset 相对视口中心：主 = floor((560-325)/2) - 280、包 = 4 - 280。
		_判(absf(主窗.offset_top - (floorf((560.0 - 325.0) * 0.5) - 280.0)) < 0.51
				and absf(包窗.offset_top - (4.0 - 280.0)) < 0.51,
				"成对摆位：主窗居中、背包夹进屏内（实得 %.1f / %.1f）" % [主窗.offset_top, 包窗.offset_top])
		_判(absf(包窗.offset_left - (主窗.offset_right + 1.0)) < 0.51,
				"成对摆位：背包左沿 = 商店右沿 + 1px（实得 %.1f / %.1f）" % [主窗.offset_right, 包窗.offset_left])
	else:
		_判(false, "两窗的 `遮罩/主窗口` 拿不到 ⇒ 成对摆位无从判")

	后.set("_storage_chunks", {})
	后.set("_storage_expected_count", 0)
	_喂("330:1:0:20:1000:2:%s" % 货一)
	for i in 2:
		await process_frame
	_判(not _开着(管理.call("取窗口", "NPC仓库")),
			"期望 2 块只到 1 块 ⇒ **不许**半途开窗（把空架子画出来就是修前的病）")
	_喂("330:1:0:20:1000:2:%s" % 货二)
	for i in 2:
		await process_frame
	_判(_开着(管理.call("取窗口", "NPC仓库")), "`330:1` 两块拼完 ⇒ NPC仓库 开出来（`storage_opened`）")
	管理.call("打开或收起", "NPC仓库")
	for i in 2:
		await process_frame
	_判(not _开着(管理.call("取窗口", "NPC仓库")), "先收起来，好让下一条判「后续帧不许重开」")
	_喂("330:3:30:900")
	_喂("330:4:%s" % 货一)
	for i in 2:
		await process_frame
	_判(not _开着(管理.call("取窗口", "NPC仓库")),
			"`330:3/4`（容量、单格刷新）不是「仓库被开出来」⇒ 不该把关掉的窗提回来")

	# ── ⑥ 偏离/缺口钉 ────────────────────────────────────────────────────────
	var 缺口: Dictionary = 背包脚本.缺的那一块
	_判(缺口.size() == 0,
			"底部缺口表已清空（药店/仓库/摊位列表/二级密码/#49 随身摊位摊主侧都接上了），实测 %s" % str(缺口.keys()))
	# 常量表里查，**不能**写 `背包脚本.仓库等级` —— 常量删掉后那种写法直接编译不过（门当场挂）。
	var 常量名: Array = []
	for 键 in (背包脚本 as Script).get_script_constant_map():
		常量名.append(String(键))
	_判(not 常量名.has("仓库等级"), "`仓库等级`(= `CANG_KU_LEVEL`) 那道闸已随报修 5.1 删掉，实测常量 %s" % str(常量名))
	_判(not FileAccess.file_exists(确认弹路径),
			"「购买VIP确认」那枚弹的 builder 已随报修 5.2 从盘上删掉，实测 %s 还在" % 确认弹路径)
	var 背包源: String = FileAccess.get_file_as_string("res://脚本/界面/窗口/背包窗口.gd")
	_判(not 背包源.contains("VIP确认弹"),
			"背包窗口源码里不该再有 `VIP确认弹` 这个标识（preload 与调用都该没了）")
	var VIP方法: Array = []
	for 信 in 后.get_method_list():
		var 名 := String(信["name"])
		if 名.begins_with("request_vip"):
			VIP方法.append(名)
	VIP方法.sort()
	var 期望VIP := ["request_vip", "request_vip_open_medicine", "request_vip_open_store"]
	期望VIP.sort()
	_判(VIP方法 == 期望VIP,
			"`request_vip*` 必须正好这三条：动作 3/4 是外挂专用（没有 `WaiGuaHandler` 那半边）、5/6 是元宝那条（报修 5.2 删），实测 %s" % str(VIP方法))
	var 后端源: String = FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	_判(not 后端源.contains("_by_cash"),
			"后端连接源码里不该再出现 `_by_cash`（元宝那两条上行的方法名）")
	# 2026-10-25 用户：「远程仓库会提示该随身仓库需要vip权限…帮我完整的删掉」
	# ⚠ 上一轮（§3.273）只改了 `2.2.3/tools/fake_flash_server.py`，**运行时加载的是
	#   `服务端/runtime/tools/` 那一份** ⇒ 闸仍在、实机照旧弹。这里直接钉运行时那份。
	var 服源: String = FileAccess.get_file_as_string("res://服务端/runtime/tools/fake_flash_server.py")
	_判(not 服源.is_empty(), "运行时夹具源码可读（`服务端/runtime/tools/fake_flash_server.py`）")
	var 起 := 服源.find("    def handle_vip(")
	var 止 := 服源.find("\n    def ", 起 + 1) if 起 >= 0 else -1
	var 段 := 服源.substr(起, 止 - 起) if 起 >= 0 and 止 > 起 else ""
	_判(not 段.is_empty(), "夹具 `handle_vip` 存在")
	_判(not 段.contains("需要 VIP 权限"),
			"夹具不再用「需要 VIP 权限」拦随身药店/仓库（运行时那份也改了）")
	_判(not 段.contains("action in {1, 3} and not self._has_active_vip()")
			and not 段.contains("action in {2, 4} and not self._has_active_vip()"),
			"`handle_vip` 动作 1/2/3/4 不再判 VIP 等级（上一轮只改了 2.2.3/tools 那份，别再犯）")
	_判(管理脚本.伴随背包.has("NPC商店") and 管理脚本.伴随背包.has("NPC仓库"),
			"`伴随背包` 登记了这两扇（原版 centerTwoWindow 那对）")
	_判(not 管理脚本.居中弹.has("NPC商店") and not 管理脚本.居中弹.has("NPC仓库"),
			"这两扇是可拖的普通窗，**不进** `居中弹`")
	_判(_名字里有(包, "充值").is_empty(),
			"背包整棵树里不许有「充值」（§3.203 用户明确要求删；原版 `ItemWindow2.as:414-425` 那枚是有意不移植的）")

	# ── ⑦ 收尾那条：接上之后**不该再往「后端状态」里写占位话** ─────────────────
	# （④/⑤ 之后那两扇实例都在台上了 ⇒ 这一腿走的还是①切显隐，正好也是原语义：不吱声。）
	for 名 in ["随身药店", "随身仓库"]:
		var 钮 := _背包钮(包, 名)
		if 钮 == null:
			continue
		_擦(假, 状)
		钮.pressed.emit()
		await process_frame
		_判(not 状.text.contains("还没接") and not 状.text.contains("本轮"),
				"「%s」已经接上，不该再占一句开发周期的话，实测「%s」" % [名, 状.text])

	跑完了 = true
