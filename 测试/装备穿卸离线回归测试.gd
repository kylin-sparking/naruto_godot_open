extends SceneTree

## 离线（没连服务端）时 `装备穿上 / 替换 / 卸下` 的**数据语义**。
##
## 为什么要这一道：2026-10-01 用户报"装备卸下、替换没有实装"。
## 在线那路是发 `ITEM_MOVE`、由服务端做交换（`fake_flash_server.py:47483-47491`
## 两边 pop、互为回填；卸下自动进背包空格，满了原话"背包已满，无法卸下装备"`:47417-4721`）；
## **离线那两条分支是假的**：
##   · `unequip_item` 只把 `equipped_items[位置]` 置空 —— 件**蒸发**，不去背包；
##   · `equip_item` 只写穿着 —— 背包那件**没挪走**（一穿就复制），原穿着的件被**覆盖蒸发**。
## 这道门把服务端的四条语义在离线上原样钉住。
##
## ⚠️ 本门会真走 `equip/unequip` ⇒ 每步 `_save_local_state()` **落盘 user://**。
##    照 §3.76.1 的规约：开场快照、收尾**还原并再落盘一次**（净效果为零）；
##    新门连跑两遍第二遍必须还绿。
##
## 运行：Godot --headless --path . --script res://测试/装备穿卸离线回归测试.gd

var _失败: Array[String] = []
var _受检 := 0
var _快照: Dictionary = {}
var _通知: Array[String] = []
## 内存态还原后再 `_save_local_state()` 的**字节并不等于磁盘原文件** ⇒ 再加一层文件级快照。
const 门存档快照 := preload("res://测试/门存档快照.gd")
var _文件前 := {}

func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")

func _check(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _武器位() -> int:
	return int(load("res://脚本/单例/装备部位.gd").武器)

func _穿着(会话) -> Dictionary:
	var 物 = 会话.equipped_items.get(_武器位(), null)
	return 物 if 物 is Dictionary else {}

func _背包里(会话, 物品id: String) -> int:
	for 序号 in 会话.inventory.size():
		if String((会话.inventory[序号] as Dictionary).get("id", "")) == 物品id:
			return 序号
	return -1

func _run() -> void:
	var 会话 := root.get_node("/root/GameSession")
	_快照 = {
		"player_stats": (会话.player_stats as Dictionary).duplicate(true),
		"inventory": (会话.inventory as Array).duplicate(true),
		"equipped_items": (会话.equipped_items as Dictionary).duplicate(true),
	}
	会话.notification_requested.connect(func(话: String): _通知.append(话))

	# —— ① 穿上：背包件必须**离开背包**，落进穿着槽 ——
	# ⚠️ `inventory` 是**带类型**的 `Array[Dictionary]`（`游戏会话.gd:59`）——
	#    直接赋普通数组字面量会在运行时报错，一律 `clear()+append()`。
	# ⚠️ 2026-10-01 §3.81.2 稳定格位制：手工 append 的件 **格号 = 数组下标+1**，
	#    种子参数里的"格号"只是同值备注；①穿走会在格1 留一个洞。
	会话.equipped_items[_武器位()] = {}
	会话.inventory.clear()
	会话.inventory.append(_造件("01010011", 1))
	_check(bool(会话.call("equip_item", "01010011")), "equip_item 应成功")
	_check(not _穿着(会话).is_empty(), "穿上后武器位应有件")
	_check(String(_穿着(会话).get("id", "")) == "01010011", "穿上的应是那件武器")
	_check(_背包里(会话, "01010011") < 0, "穿上后背包里**不该再有**这件（原来复制）")

	# —— ② 替换：新件上桌，**旧件回到新件腾出的那一格**（服务端交换语义） ——
	# 实测口径（跑出来核对过的）：①穿走 A 在格1 留洞，但那是**尾洞**、被 `_trim_尾洞` 裁掉，
	# 所以 B 追加后坐的仍是格1；交换后 A 回格1 —— 尾洞裁不裁只影响"洞看不看得见"，不影响位置。
	会话.inventory.append(_造件("01010013", 1))
	_check(bool(会话.call("equip_item", "01010013")), "替换 equip_item 应成功")
	_check(String(_穿着(会话).get("id", "")) == "01010013", "替换后穿着的应是新件")
	_check(_背包里(会话, "01010013") < 0, "替换后新件不该还留在背包")
	var 顶下位 := _背包里(会话, "01010011")
	_check(顶下位 >= 0, "替换后**旧件应回到背包**（原来直接蒸发）")
	if 顶下位 >= 0:
		_check(int((会话.inventory[顶下位] as Dictionary).get("slot_index", 0)) == 顶下位 + 1,
				"slot_index 恒等于 下标+1（稳定格位制不变量），实际 下标%d/字段%s" % [顶下位, str((会话.inventory[顶下位] as Dictionary).get("slot_index", 0))])

	# —— ③ 卸下：件进**第一个空格** —— 此刻背包 [A@格1] ⇒ B 回格2；槽位留键置空 ——
	会话.unequip_item(_武器位())
	_check(_穿着(会话).is_empty(), "卸下后武器位应空（留键置空，判值不判 has）")
	var 回到位 := _背包里(会话, "01010013")
	_check(回到位 >= 0, "卸下那件应回到背包（原来蒸发）")
	if 回到位 >= 0:
		_check(回到位 == 1, "卸下应进第一个空格（格2），实际下标 %d" % 回到位)
		var 格 := int((会话.inventory[回到位] as Dictionary).get("slot_index", 0))
		_check(格 == 2, "回包件 slot_index 跟格号一致（2），实际 %d" % 格)
		_check(String(会话._占用条(会话.inventory, 1).get("id", "")) == "01010011",
				"①②留下的 A 必须还在格1 —— 谁来谁走，别人的位不许动（§3.81.2 核心断言）")

	# —— ④ 背包满：**不卸**，原话提示（`fake_flash_server.py:47418-47422`） ——
	# ⚠️ 灌满的格数必须取**会话真实容量**：2026-10-31 背包改 90 格/页后写死的 96
	#    只是"占了 96 格"，卸下照样成功，这条腿就红了（甚至假红成"背包满没提示"）。
	var 上限 := int(会话.call("背包总格数"))
	_check(上限 >= 90, "背包总格数应起于 90（每页 90 格口径），实际 %d" % 上限)
	会话.equipped_items[_武器位()] = _造件("01010013", -1)
	var 满包: Array = []
	for 格序号 in range(1, 上限 + 1):
		满包.append({"id": "3000001", "name": "拉面（小）", "quantity": 1, "slot_index": 格序号})
	会话.inventory.assign(满包)
	_通知.clear()
	会话.unequip_item(_武器位())
	_check(not _穿着(会话).is_empty(), "背包满时**不该卸**")
	_check(_通知.has("背包已满，无法卸下装备"), "背包满应发原版那句提示（实际 %s）" % [_通知])

	# —— ⑤ 空槽再卸：静默返回，背包不该多出一件"空" ——
	会话.inventory.clear()
	会话.equipped_items[_武器位()] = {}
	会话.unequip_item(_武器位())
	_检查式背包不变(会话)

	_收尾()

## ④/⑤ 的辅助：对"什么都不该发生"的态，别写成永真式。
func _检查式背包不变(会话) -> void:
	_check((会话.inventory as Array).is_empty(), "空槽再卸不该往背包塞东西（实际 %d 件）" % (会话.inventory as Array).size())

func _造件(物品id: String, 格: int) -> Dictionary:
	return {"id": 物品id, "name": "测试武器", "quantity": 1, "slot_index": 格,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"}

func _收尾() -> void:
	if not _快照.is_empty():
		var 会话 := root.get_node("/root/GameSession")
		会话.player_stats = _快照["player_stats"]
		# ⚠️ `inventory` 是 `Array[Dictionary]`：直接赋普通 `Array` 会 Invalid assignment
		#    报错但不中断（§3.196 同型坑）⇒ 走 `assign`。
		(会话.inventory as Array).assign(_快照["inventory"] as Array)
		会话.equipped_items = _快照["equipped_items"]
		会话.call("_save_local_state")
	# 文件级还原放在最后：`_save_local_state()` 重写的字节与原档不必一致。
	门存档快照.全还原(_文件前)
	if _失败.is_empty():
		print("装备穿卸离线回归测试：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("装备穿卸离线回归测试：" + 项)
	quit(1)
