extends SceneTree

## 忍具（八咫镜）**上线同步 + 穿卸**的在线门 —— 2026-11-04 用户报
## 「穿上八咫镜就不能卸装备了，而且每次上线，八咫镜都在背包，未装备，
##  聊天框却自动显示八咫镜的属性类型」。
##
## 这三句是**一条链**：
##   ① 原版 `CharacterWarpInfo.decode:76-81` 的字段序是 shenqi/ring/lingQi/**renJu**/skillInfoList，
##      夹具 `_send_character_info` 以前**整段没发** renJu —— 而 `_send_equipped_info:17933`
##      只收 `section == "ZhuangBei"`（忍具是独立 codec）⇒ 两条路都到不了客户端。
##      结果：服务端把人穿着镜、客户端装备表里没有 -24（"上线后八咫镜在背包、未装备"）。
##   ② 客户端以为 -24 空 ⇒ 穿第二枚时服务端回的 `MOVE_REN_JU` 交换帧里，"被顶下来"那件
##      要放回源格；客户端 `目标原物` 查不到 ⇒ 源格被清空、那件在客户端消失，
##      与服务端背包错位（服务端源格上还有一枚镜）。
##   ③ 之后点卸下，客户端挑的"第一个空格"正好是服务端那格镜占着的号 ⇒
##      `handle_item_move:48657` 的 `_can_equip(镜, -1)` 不过 ⇒ **静默 return**，
##      表现就是"装备卸不下来"。
##
## 另有一条与本链无关、同一轮一起删的：服务端每次进游戏都推一句
## 「八咫镜当前为X属性抗性…」的系统通知（`_send_yata_resistance_status`，已删）。
## 原版 `handleRenJuOperationResult:65-73` 只 switch 0（开光）/3（合成），
## 抗性换档（动作 4）没有任何回帧与文案 ⇒ 上线不该冒出这一行。
##
## 判据一律读**服务端推下来的那一份**（`authoritative_equipment` / `authoritative_inventory`），
## 只有"人物窗读的会话表"才另读 `会话.equipped_items`。
##
## 钉的腿：
##   L0 穿一把刀（-1），作为"要卸的那件"；
##   L1 上线：后端与会话都有 -24，且 id = 65000002（warp 那一截真的到了）；
##   L2 上线：背包里那枚镜在**正格**、只有 1 枚（不是"两枚都算在包里"）；
##   L3 上线：**没有任何**「抗性」聊天行；
##   L4 穿第二枚镜 ⇒ -24 仍有一枚、背包仍 1 枚、两枚 unique_id 不同（是交换，不是复制/丢失）；
##   L5 真点武器格「卸下」⇒ 服务端 -1 空、背包多出那把刀、客户端会话同口径（用户报的那一步）；
##   L6 重登 ⇒ -24 仍在（"每次上线都在背包"不会再出现）；
##   L7 真点忍具格「卸下」⇒ -24 空、背包两枚镜。
##
## 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 忍具上线同步`
##
## ⚠ 端口：`夹具端口` 必须与 `跑在线用例.ps1` `$夹具额外` 的 `--port` 同时改（§3.180）。
## ⚠ 不写 `user://`：只动 `game_settings.backend_port` 一个键，收尾先还内存、再按字节还原两份档。

const 门存档快照 := preload("res://测试/门存档快照.gd")
const 门名 := "忍具上线同步在线回归测试"
const 夹具端口 := 18764			# 必须与 跑在线用例.ps1 `$夹具额外` 的 --port 同时改
const 忍具槽 := -24
const 武器槽 := -1
const 镜 := 65000002
const 刀 := 1010023			# 长太刀（夹具 `--items` 里给，木叶忍者穿得上）
const 根名 := "原版人物属性面板"

var _后端: Node
var _会话: Node
var _窗: Node
var _通知: Array = []
var _红数 := 0
var _秒 := 0.0
var _原端口 := -1
var _收过 := false
var _档前: Dictionary = {}


## 看门狗：中途崩了就再也走不到 `quit()`，夹具会一直等 Godot 退出。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 240.0:
		_红("看门狗超时（240s）—— 中途崩了没走到收尾")
	return false


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	_档前 = 门存档快照.全快照()
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _后端 == null or _会话 == null:
		_红("缺单例：BackendConnection=%s GameSession=%s" % [_后端, _会话])
		return
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 夹具端口
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_会话.notification_requested.connect(func(文: String) -> void: _通知.append(String(文)))
	_后端.sync_character()
	if not await _等(_进图好了, 20000):
		_红("连不上夹具 %d：%s - %s" % [口, _后端.status, _后端.detail])
		return
	# ══ L0a 夹具种子：两枚镜都在包里，且还没穿上（夹具没有"预穿忍具"的开关，
	#        第一枚由本门按玩家动作穿上去，再重登 —— 那才是用户说的「每次上线」）══
	if _包件(镜).size() != 2:
		_红("夹具 `--items` 该给两枚 %d；实得 %s（缺料时红在这里，不是功能坏了）" % [镜, str(_包件(镜))])
		return
	_查(_件(忍具槽) == 0, "开局 -24 本该空着（夹具只发背包）；实得 %s" % str(_后端.authoritative_equipment.get(忍具槽, "无")))
	if not _穿镜(_包件(镜)[0]):
		_红("第一枚镜穿不上（`equip_item(%d)` 返回 false；背包索引=%s）" % [镜, _背包号列表()])
		return
	if not await _等(func() -> bool: return _件(忍具槽) == 镜 and _会话穿着(忍具槽), 10000):
		_红("穿第一枚镜后 -24 没到：后端=%s 会话=%s"
				% [str(_后端.authoritative_equipment.get(忍具槽, "无")), str(_会话.equipped_items.get(忍具槽, "无"))])
		return

	# ══ L0b 再穿一把刀：后面 L5 要卸的就是它 ══
	if not _穿刀():
		_红("背包里没有 %d（长太刀）⇒ 夹具 `--items` 没发，本门 L5 无对象" % 刀)
		return
	if not await _等(func() -> bool: return _件(-1) == 刀, 10000):
		_红("穿了长太刀，服务端 -1 却一直不是 %d（后端 -1=%s）" % [刀, str(_后端.authoritative_equipment.get(-1, "无"))])
		return
	if not await _等(func() -> bool: return _会话穿着(武器槽), 8000):
		_红("服务端 -1 有刀了，人物窗读的会话表还没跟上（`apply_backend_inventory` 那跳断了）")
		return

	# ══ L1 重登：warp 帧真的把 -24 带回来了 ══
	# ⚠️ 先把客户端那两份表**清空**再重登 —— 不清的话上一跳（flag 13）留下的 -24 会让这条腿
	#    变成假绿，恰好盖住"warp 漏发 renJu"这个根因。
	_通知.clear()
	_后端.authoritative_equipment.clear()
	_后端.authoritative_special_equipment.clear()
	_会话.equipped_items.clear()
	_后端.sync_character()
	if not await _等(_上线同步好了, 20000):
		var 后: Dictionary = _后端.authoritative_equipment
		var 会: Dictionary = _会话.equipped_items
		_红("重登 20s 后忍具槽仍没同步：后端=%s 会话=%s ⇒ warp 帧的 renJu 段没到"
				% [str(后.get(忍具槽, "无")), str(会.get(忍具槽, "无"))])
		return
	var 后端镜 = _后端.authoritative_equipment.get(忍具槽, null)
	_查(后端镜 is Dictionary and _件号(后端镜) == 镜,
			"重登后 `authoritative_equipment[-24]` 应是 %d；实得 %s" % [镜, str(后端镜)])
	_查(_会话穿着(忍具槽),
			"重登后 `会话.equipped_items[-24]` 也必须有镜（人物窗读的就是这份）；实得 %s"
				% str(_会话.equipped_items.get(忍具槽, "无")))

	# ══ L2 重登后背包：只有 1 枚、且在正格 ══
	var 包镜 := _包件(镜)
	_查(包镜.size() == 1, "重登后背包该只有 1 枚镜（另一枚在身上）；实得 %d 枚，格号=%s" % [包镜.size(), str(包镜)])
	if 包镜.size() == 1:
		_查(int(包镜[0]) > 0, "背包里那枚镜的格号应是正数；实得 %d" % int(包镜[0]))

	# ══ L3 上线不该有「抗性」聊天行 ══
	var 抗性行: Array[String] = []
	for 文 in _通知:
		if String(文).contains("抗性") or String(文).contains("八咫镜当前"):
			抗性行.append(String(文))
	_查(抗性行.is_empty(),
			"上线时冒出 %d 条抗性通知（原版动作 4 没有回帧与文案，登录更不该发）：%s"
				% [抗性行.size(), str(抗性行)])

	# ══ L4 穿第二枚：交换之后两边都还各有一枚，且不是同一件 ══
	var 前枚: Dictionary = (后端镜 as Dictionary).duplicate(true) if 后端镜 is Dictionary else {}
	var 包格 := int(包镜[0]) if 包镜.size() == 1 else -1
	if 包格 <= 0:
		_红("背包里找不到镜，L4 的交换无从跑起")
		return
	if not bool(_会话.call("equip_item", str(镜), 0, 包格)):
		_红("`equip_item(%d)` 返回 false（背包索引对不上：%s）" % [镜, _背包号列表()])
		return
	# ⚠️ 不能只等「穿着 + 背包还有 1 枚」—— 交换前这两条**本来就成立**（会瞬间返回，
	#    读到的是请求还没被服务端处理的旧值，2026-11-04 首跑就是这么红在 unique_id 上的）。
	#    必须等 -24 上那件的 unique_id 真的换人。
	var 前枚号 := int(前枚.get("unique_id", 0))
	if not await _等(func() -> bool:
			var 现 = _后端.authoritative_equipment.get(忍具槽, null)
			return 现 is Dictionary and int((现 as Dictionary).get("unique_id", 0)) not in [0, 前枚号] \
					and _包件(镜).size() == 1, 10000):
		_红("穿第二枚后 10s，-24 没换成另一件、或背包没把被顶下来的那件收回来（前 unique_id=%d，现=%s，背包镜=%s）"
				% [前枚号, str(_后端.authoritative_equipment.get(忍具槽, "无")), str(_包件(镜))])
		return
	var 后镜 = _后端.authoritative_equipment.get(忍具槽, null)
	_查(后镜 is Dictionary and int((后镜 as Dictionary).get("unique_id", 0)) != int(前枚.get("unique_id", 0)),
			"交换后 -24 上应换成**另一件**镜（unique_id 要变）；前=%s 后=%s"
				% [str(前枚.get("unique_id")), str((后镜 as Dictionary).get("unique_id", "无") if 后镜 is Dictionary else "无")])
	var 包镜2 := _包件(镜)
	if 包镜2.size() == 1:
		var 包条 := _背包条(镜, int(包镜2[0]))
		_查(包条 is Dictionary and int(包条.get("unique_id", 0)) == int(前枚.get("unique_id", -1)),
				"被顶下来的那件（unique_id %s）应落回背包；实得 %s"
					% [str(前枚.get("unique_id")), str(包条)])

	# ══ L5 真点武器格「卸下」——用户报的那一步 ══
	_窗 = (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(_窗)
	for _序号 in 24:
		await process_frame
	_窗.call("open_page", "人物")
	for _序号 in 12:
		await process_frame
	if not await _点格卸下("武器格"):
		return
	if not await _等(func() -> bool: return _件(武器槽) == 0, 10000):
		_红("点了武器格「卸下」，服务端 -1 仍是 %s ⇒ 卸下请求被静默拒绝（`handle_item_move` 的 `_can_equip` 那两句 return）"
				% str(_后端.authoritative_equipment.get(武器槽, "无")))
		return
	_查(not _会话穿着(武器槽), "服务端 -1 已清空，会话表还穿着刀")
	_查(_包件(刀).size() == 1, "卸下来的刀应回到背包 1 把；实得 %d 把（格号=%s）" % [_包件(刀).size(), str(_包件(刀))])

	# ══ L6 重登：忍具槽还是同步上来的 ══
	_后端.sync_character()
	if not await _等(func() -> bool: return bool(_后端.in_game) and _会话穿着(忍具槽), 20000):
		_红("重登后 `会话.equipped_items[-24]` 没了 ⇒ 玩家又会看到「八咫镜在背包、未装备」")
		return
	_查(_件(忍具槽) == 镜, "重登后服务端 -24 应是 %d；实得 %s" % [镜, str(_后端.authoritative_equipment.get(忍具槽, "无"))])
	## 重登会让页重建一次；旧的节点句柄不作数，重新开一次页再点。
	_窗.call("open_page", "人物")
	for _序号 in 12:
		await process_frame

	# ══ L7 真点忍具格「卸下」══
	if not await _点格卸下("忍具格"):
		return
	if not await _等(func() -> bool: return _件(忍具槽) == 0, 10000):
		_红("点了忍具格「卸下」，服务端 -24 仍是 %s" % str(_后端.authoritative_equipment.get(忍具槽, "无")))
		return
	_查(_包件(镜).size() == 2, "卸下来的镜应回到背包（两枚都在包里）；实得 %d 枚，格号=%s"
			% [_包件(镜).size(), str(_包件(镜))])
	_查(_档未脏(), "本门脏了 `user://` 那两份档（硬规矩：门不许动用户存档 —— 收尾仍会按字节还原）")
	_收尾()


## 真点「人物 → 装备格 → 卸下」（与鼠标同一条代码路径）。格不存在/灰/菜单没「卸下」都判红。
func _点格卸下(格名: String) -> bool:
	var 格 := _格节点(格名)
	if 格 == null:
		_红("人物窗里没有「%s」（版式被改过，或页没重建成）" % 格名)
		return false
	if 格.disabled:
		_红("「%s」是灰的（穿着位没同步到页上）" % 格名)
		return false
	格.pressed.emit()
	for _序号 in 4:
		await process_frame
	格 = _格节点(格名)
	if 格 == null:
		_红("点开「%s」后页整个重建、旧句柄失效（本门约定点之前重取，这里还是失效）" % 格名)
		return false
	var 菜单 := _菜单节点()
	if 菜单 == null or not 菜单.visible:
		_红("点「%s」之后物品菜单没弹出来" % 格名)
		return false
	var 卸下钮: Button = null
	var 项: Array[String] = []
	for 子 in 菜单.get_children():
		var 按 := 子 as Button
		if 按 != null and 按.visible:
			项.append(按.text)
			if 按.text == "卸下":
				卸下钮 = 按
	if 卸下钮 == null:
		_红("「%s」的菜单里没有「卸下」（实得 %s）" % [格名, str(项)])
		return false
	卸下钮.pressed.emit()
	for _序号 in 3:
		await process_frame
	return true


func _格节点(格名: String) -> Button:
	var 面板 := _面板()
	if 面板 == null:
		return null
	var 容器 := 面板.get_node_or_null("装备栏/装备格子容器")
	if 容器 == null:
		return null
	return 容器.get_node_or_null(格名) as Button


func _菜单节点() -> Control:
	var 面板 := _面板()
	if 面板 == null:
		return null
	return 面板.get_parent().get_node_or_null("物品菜单") as Control


func _面板() -> Control:
	if _窗 == null:
		return null
	return _窗.find_child(根名, true, false) as Control


func _穿刀() -> bool:
	for 格 in _包件(刀):
		if bool(_会话.call("equip_item", str(刀), 0, int(格))):
			return true
	return false


## 穿忍具：`格号` 是背包 1 基格号（L0a 只穿第一枚）。
func _穿镜(格号: int) -> bool:
	return bool(_会话.call("equip_item", str(镜), 0, int(格号)))


## 服务端 -1 / -24 上那件的 id；空 = 0。
func _件(槽: int) -> int:
	var 表: Dictionary = _后端.authoritative_equipment
	var 件 = 表.get(槽, null)
	return _件号(件)


## ⚠️ 协议解出来的 `id` 是字符串、本地种的那份可能是另一个键 ⇒ 归一到 int 再比。
func _件号(件: Variant) -> int:
	if not (件 is Dictionary) or (件 as Dictionary).is_empty():
		return 0
	return int(str((件 as Dictionary).get("id", (件 as Dictionary).get("item_id", "0"))))


func _会话穿着(槽: int) -> bool:
	var 件 = _会话.equipped_items.get(槽, null)
	return 件 is Dictionary and not (件 as Dictionary).is_empty()


## 服务端背包镜像里某 id 的格号（正格）。
func _包件(号: int) -> Array:
	var 出: Array = []
	for 条v in (_后端.authoritative_inventory as Array):
		if 条v is Dictionary and _件号(条v) == 号 and int((条v as Dictionary).get("slot_index", 0)) > 0:
			出.append(int((条v as Dictionary).get("slot_index", 0)))
	出.sort()
	return 出


func _背包条(号: int, 格号: int) -> Dictionary:
	for 条v in (_后端.authoritative_inventory as Array):
		if 条v is Dictionary and _件号(条v) == 号 and int((条v as Dictionary).get("slot_index", 0)) == 格号:
			return 条v
	return {}


func _背包号列表() -> String:
	var 出: Array[String] = []
	var 会话镜: Array[String] = []
	for i in (_会话.inventory as Array).size():
		var 条 := (_会话.inventory as Array)[i] as Dictionary
		if 条.is_empty():
			continue
		出.append("%d:%s" % [i, str(条.get("id", 条.get("item_id", "")))])
		if _件号(条) == 镜:
			会话镜.append(str(i))
	return "枚=%s 会话前几格=%s" % [str(会话镜), str(出.slice(0, 6))]


func _进图好了() -> bool:
	return bool(_后端.in_game) and not (_后端.authoritative_inventory as Array).is_empty()


func _上线同步好了() -> bool:
	return _件(忍具槽) == 镜 and _会话穿着(忍具槽) and _包件(镜).size() == 1


func _档未脏() -> bool:
	for 路 in _档前:
		if 门存档快照.读字节(String(路)) != (_档前[路] as PackedByteArray):
			return false
	return true


func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while not bool(条件.call()) and Time.get_ticks_msec() < 止:
		await create_timer(0.05).timeout
	return bool(条件.call())


func _查(过: bool, 文: String) -> void:
	if not 过:
		_红数 += 1
		print("!! " + 文)


func _红(文: String) -> void:
	_查(false, 文)
	_收尾()


func _收尾() -> void:
	if _收过:
		return
	_收过 = true
	if _会话 != null:
		var 设置: Dictionary = _会话.get("game_settings")
		if _原端口 >= 0:
			设置["backend_port"] = _原端口
		else:
			设置.erase("backend_port")
		_原端口 = -1
	门存档快照.全还原(_档前)
	if _窗 != null and is_instance_valid(_窗):
		_窗.queue_free()
		_窗 = null
	if _后端 != null:
		_后端.call("disconnect_backend")
	if _红数 == 0:
		print("%s：通过（穿刀后 -24 上线同步到后端与会话 / 背包只有 1 枚镜且为正格 / 登录无抗性聊天行 / "
				% 门名
				+ "穿第二枚是交换不是丢失 / 真点武器格卸下服务端真清槽且刀回包 / 重登 -24 仍在 / "
				+ "真点忍具格卸下后两枚都在包里 / 两份 user:// 档逐字节未脏）")
		quit(0)
	else:
		print("%s：失败 %d 项" % [门名, _红数])
		quit(1)
