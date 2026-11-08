extends SceneTree
## 拾取移除腿量具（bug「挂机自动拾取之后物品竟然还在地面上」，用户 2026-10-19 实机报）。
##
## 这一条只判**客户端这一侧**：服务端的 `272` 掉落帧来了、拾取请求发了、服务端的 `273`
## 移除帧原文也喂进来了 ⇒ 地上那一枚到底有没有消失。
## 为什么要喂原文而不是 `map_drop_removed.emit(...)`：`emit` 绕过了 `_handle_remove_drop_text`
## 的解析（段序 / `int(fields[1])` 那一档动画号），而"移除帧到了但没落到地上那枚"
## 正是这个 bug 的候选根因之一。
##
## 跑法（**不能加 `--headless`？可以**：这里不截屏，只查节点与字典）：
##     <godot> --headless --path <工程> --script res://开发工具/量拾取移除.gd
const 地图路 := "res://场景/地图/地图场景.tscn"
## 掉落生成帧原文段序 = 服务端 `fake_flash_server.py:47001-47006`：
##   `272:oid:isMeso:itemId:touchUp:aptitude:owner:x:y:fromX:fromY:dropMode:foothold`
const 掉式 := "272:%d:false:1000005:false:0:%d:420:300:420:300:0:0"
## 移除帧原文段序 = 服务端 `:47122-47124`（拾取成功那一发），也是原版 `RemoveItemInfo.decode()`：
##   `273:animation:oid:pet:cid`（animation=2 拾取动画、0/1 直接消失）
const 移式 := "273:%d:%d:false:%d"

var 红: Array[String] = []
var 判数 := 0
var 原图 := 0

func _判(对: bool, 说明: String) -> void:
	判数 += 1
	if not 对:
		红.append(说明)
		prints("红：", 说明)

func _initialize() -> void:
	call_deferred("_跑")

func _帧(n: int) -> void:
	for _i in n:
		await process_frame

func _跑() -> void:
	var 后 = root.get_node_or_null("BackendConnection")
	var 会 = root.get_node_or_null("GameSession")
	_判(后 != null and 会 != null, "取到 后端连接 / 游戏会话（拿不到就只能测空气）")
	if 后 == null or 会 == null:
		_收()
		return
	var 图 = (load(地图路) as PackedScene).instantiate()
	root.add_child(图)
	await _帧(12)
	var 实体 := 图.get_node_or_null("LifeRoot")
	_判(实体 != null, "地图场景下要有 LifeRoot（掉落物的容器）")
	if 实体 == null:
		_收()
		return
	var 我号 := 777001
	后.set("character_id", 我号)
	## 掉落帧要过 `_state_matches_current_map`（`:429`）⇒ 帧里的 map_id 必须等于"当前图"。
	## 当前图取实体自己那一份，别自己编。
	var 今图: int = int(实体.call("_get_current_map_id"))
	原图 = int(后.get("authoritative_map_id"))
	后.set("authoritative_map_id", 今图)
	会.set("current_map_id", 今图)
	var 表: Dictionary = 实体.get("_server_drops")
	## ⚠ 地图场景自带离线掉落/怪，先记下进来时已有的编号，后面只判**我造的这两枚**
	var 原有: Array = 表.keys().duplicate()

	# ── ① 造一枚"在线"掉落（服务端 272 原文），确认它躺在地上 ──
	后.call("_handle_bridge_text", 掉式 % [7001, 我号])
	await _帧(30)
	var 一枚 = 表.get(7001)
	_判(一枚 != null and is_instance_valid(一枚), "272 原文喂进去要能建出地上那一枚")
	if 一枚 == null:
		_收()
		return
	## 等落地（`drop_air` 归假）：飞行中 `挂机的掉落` 本来就不收它，不算 bug
	for _i in 240:
		if not bool((一枚 as Node).get_meta("drop_air", false)):
			break
		await _帧(2)
	_判(not bool((一枚 as Node).get_meta("drop_air", false)),
			"480 帧内要落地（`drop_air` 归假），否则拾取那条腿根本没机会跑")
	## 落地后 `挂机的掉落` 这张表里要有它 —— 挂机挑包只看这张表
	var 报了的: Array = 实体.call("挂机的掉落", Rect2(-100000.0, -100000.0, 300000.0, 300000.0))
	var 在表 := false
	var 报的号: Array = []
	for 掉 in 报了的:
		var 号 := int((掉 as Dictionary).get("object_id", 0))
		报的号.append(号)
		if 号 == 7001:
			在表 = true
	_判(在表, "落地后 `挂机的掉落` 要能报出这一枚，实得这张表 %s" % str(报的号))

	# ── ② 发拾取（= 点它 / 挂机那一支同一个入口）──
	实体.call("发拾取", 7001)
	_判(float((实体.get("_锁定表") as Dictionary).get(7001, 0.0)) > 0.0,
			"发过拾取要把这一枚上锁（`LOCK_PICK_UP` 5 秒，原版 `DropItemHandler`），实得 %s"
					% str((实体.get("_锁定表") as Dictionary).get(7001, 0.0)))
	_判(is_instance_valid(一枚), "只发了请求、还没到回帧 ⇒ 地上这枚**不该**已经消失")

	# ── ③ 喂服务端那条 273 拾取动画原文 ⇒ 地上这枚必须在动画跑完后消失 ──
	后.call("_handle_bridge_text", 移式 % [2, 7001, 我号])
	_判(bool((一枚 as Node).get_meta("drop_picking", false)),
			"273:2 到达后该进 `drop_picking`（拾取动画）这一档，实得 %s"
					% str((一枚 as Node).get_meta("drop_picking", false)))
	await _帧(90)					# 拾取动画 600ms ⇒ 留足
	_判(not 表.has(7001),
			"拾取动画跑完必须从 `_server_drops` 摘掉（用户看到的『还在地面上』就是这一条），实得还在=%s；表里现有 %s"
					% [str(表.has(7001)), str(表.keys())])
	_判(not is_instance_valid(一枚), "那一枚节点本体要被释放，实得还活着=%s" % str(is_instance_valid(一枚)))

	# ── ④ 阳性对照：另一枚**不喂** 273，它必须一直躺在地上 ──
	## 没有这一条，上面"消失"可能只是整张表被谁清空了（10-16 那种两边一起错的假绿）。
	后.call("_handle_bridge_text", 掉式 % [7002, 我号])
	await _帧(60)
	var 二枚 = 表.get(7002)
	_判(二枚 != null and is_instance_valid(二枚), "第二枚（对照）建出来了，否则对照不成立")
	if 二枚 != null:
		for _i in 240:
			if not bool((二枚 as Node).get_meta("drop_air", false)):
				break
			await _帧(2)
		await _帧(90)
		_判(表.has(7002) and is_instance_valid(二枚),
				"没收到 273 的那一枚**不许**消失（阳性对照；它要是也没了，第 ③ 段等于没判）")

	# ── ⑤ `动画=0`（过期/无动画）⇒ 不播动画、立刻消失 ──
	后.call("_handle_bridge_text", 移式 % [0, 7002, 我号])
	await _帧(6)
	_判(not 表.has(7002), "273:0 那种要当场收掉（原版 0/1 = 直接消失，不播拾取动画）")

	## 收：只清我造的这两枚，进来时已有的原样留着（不许把别人场景弄脏）
	for 号 in 表.keys().duplicate():
		if not 原有.has(号):
			var 件 = 表[号]
			if is_instance_valid(件):
				(件 as Node).queue_free()
			表.erase(号)
	后.set("authoritative_map_id", 原图)
	_收()

func _收() -> void:
	if 红.is_empty():
		prints("量拾取移除：通过（%d 条判据）" % 判数)
		quit(0)
		return
	prints("量拾取移除：%d 条判据，红 %d 条" % [判数, 红.size()])
	quit(1)
