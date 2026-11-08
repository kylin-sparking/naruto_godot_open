## 追踪量具：勾了「自动拾取」之后开挂机，角色到底卡在哪一层（用户 2026-10-19 实机报 bug2）。
## 为什么要它：`挂机行为门` 的拾取段（戊 25 条 / 壬 13 条）判的是**分类与路线**，
## 夹具是自己造的字典 + 手摆的坐标，从没在**真地图真落脚点**上跑过"走过去捡"这一段；
## 在线腿这两轮 `掉新=[]`（服务端没掉东西）⇒ 拾取那一支在线上一次都没被执行过。
## 跑法：godot --headless --path . --script res://开发工具/量挂机拾取卡住.gd
extends SceneTree

var 行: Array[String] = []
var 红 := 0


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _判(对: bool, s: String) -> void:
	if 对:
		_记("ok   " + s)
	else:
		红 += 1
		_记("红   " + s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 场: Node = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(80)
	var 玩 := 场.find_child("Player", true, false)
	var 实体 := 场.find_child("LifeRoot", true, false)
	if 玩 == null or 实体 == null:
		_判(false, "玩家/LifeRoot 没建出来 ⇒ 全部判不了")
		_收()
		return
	var 托管 = 玩.get_node_or_null("挂机托管")
	_判(托管 != null, "玩家节点下要有 挂机托管 这一份（没有的话这量具测的是空气）")
	if 托管 == null:
		_收()
		return
	var 会: Node = root.get_node_or_null("GameSession")
	## 先等角色**落到落脚点上**：没落地就把掉落摆下去，掉落找不到地面会永远 `drop_air=true`，
	## 而 `挂机的掉落` 第一道筛就把 air 的那枚剔掉 ⇒ 后面整段追踪测的是空气。
	var 落了 := false
	for 试 in 300:
		await process_frame
		if bool(玩.get("on_ground")):
			落了 = true
			break
	_记("  角色落地=%s（等了 %d 拍）位=%s on_ground=%s" % [
			str(落了), 0, str(玩.get("global_position")), str(玩.get("on_ground"))])
	_判(落了, "角色必须先站在落脚点上，否则这道量具的掉落永远落不了地")
	if not 落了:
		_收()
		return
	## 与真机同一套配置：拾取总开关开、其余按默认
	var 配: Dictionary = (会.挂机配置 as Dictionary).duplicate(true)
	配["autoCollect"] = true
	会.套用挂机配置(配)
	会.call("request_hang", true)
	await _帧(3)
	_判(bool(托管.get("在跑")), "request_hang(true) 之后 在跑 必须为真（实得 %s）" % str(托管.get("在跑")))
	await _帧(60)						# 过 800ms 预热

	## 在**同一层落脚点**上、角色右边 260 像素处放一枚金币（离线掉落编号从 -1 往下走）。
	## ⚠ 必须用 `global_position`：玩家挂在带偏移的世界根下面，`position` 是**局部位**，
	## 拿它去摆掉落物会摆到半空（第一版就栽在这里 —— 掉落的 `drop_air` 永远不落地，
	## `挂机的掉落` 第一道筛就把它筛掉，于是整条追踪白测）。
	var 我位: Vector2 = 玩.get("global_position") as Vector2
	var 掉位 := 我位 + Vector2(260.0, 0.0)
	_记("  角色 global=%s local=%s ⇒ 掉落摆到 %s" % [str(我位), str(玩.get("position")), str(掉位)])
	实体.call("_create_loot", 掉位)
	## ⚠ 必须等它**落地**（`drop_air` 归假）：还在弹的那一枚 `挂机的掉落` 第一道就筛掉。
	var 掉了 := false
	for 试 in 200:
		await process_frame
		var 原: Dictionary = 实体.get("_server_drops") as Dictionary
		掉了 = true
		for 号 in 原.keys():
			var 件 = 原[号]
			if is_instance_valid(件) and bool((件 as Node).get_meta("drop_air", false)):
				掉了 = false
		if 掉了:
			break
	_记("  掉落落地=%s 位=%s" % [str(掉了), str(掉位)])
	## 掉落物刚生成时是 `drop_air`（还在弹），`挂机的掉落` 第一道就把它筛掉 ⇒ 先等落地。
	## 这里把"建出来没有"与"被哪一道筛掉"分开报，不然查不到只看到 0 条，分不清是没建还是被筛。
	await _帧(40)
	var 原表: Dictionary = 实体.get("_server_drops") as Dictionary
	_记("  地上掉落物：`_server_drops` 原始 %d 条" % 原表.size())
	for 编号 in 原表.keys():
		var 掉 = 原表[编号]
		if not is_instance_valid(掉):
			_记("    编号 %s：实例已失效" % str(编号))
			continue
		_记("    编号 %s：位=%s touch_up=%s air=%s picking=%s removed=%s" % [
				str(编号), str((掉 as Node2D).position),
				str((掉 as Node).get_meta("drop_touch_up", false)),
				str((掉 as Node).get_meta("drop_air", false)),
				str((掉 as Node).get_meta("drop_picking", false)),
				str((掉 as Node).get_meta("drop_removed", false))])
	var 表: Array = 实体.call("挂机的掉落", Rect2(-100000, -100000, 300000, 300000))
	_判(表.size() > 0, "刚放的那一枚必须能被 `挂机的掉落` 查到（实得 %d 条；查不到就是下面那条追踪白测）" % 表.size())
	if 表.is_empty():
		_收()
		return

	## ── 逐拍追踪：状态文字 / 位置 / 寻路中 / 待机动 / 目标 / 黑名单 ──
	var 起点: Vector2 = 玩.get("position") as Vector2
	var 走过: Array = []
	var 拾取拍数 := 0
	var 最远 := 0.0
	for 拍 in 240:
		await process_frame
		var 位: Vector2 = 玩.get("position") as Vector2
		最远 = maxf(最远, 位.distance_to(起点))
		if String(托管.get("状态文字")) == "拾取":
			拾取拍数 += 1
		if 拍 % 20 == 0:
			走过.append("拍%d 位=(%.0f,%.0f) 状态=%s 寻路中=%s 待机动=%s 目标=%s 黑名单=%d" % [
					拍, 位.x, 位.y, String(托管.get("状态文字")),
					str(bool(玩.get("自动寻路中"))), str(托管.call("_在待机动")),
					"〈无〉" if 托管.get("目标") == null else "有", int((托管.get("_黑名单") as Dictionary).size())])
	for s in 走过:
		_记("  " + s)
	_记("追踪 240 拍：最远离开起点 %.1f 像素、其中状态=拾取 %d 拍" % [最远, 拾取拍数])
	## 判据 ①：角色**动了**（走过去捡 ⇒ 至少要走一段；原地钉死就是 bug）
	_判(最远 > 40.0, "开着自动拾取、地上有一枚金币，240 拍里角色必须往它走过去（实得最远 %.1f 像素）" % 最远)
	## 判据 ②：那枚要被捡走（`_server_drops` 里不再查得到）
	await _帧(60)
	var 剩: Array = 实体.call("挂机的掉落", Rect2(-100000, -100000, 300000, 300000))
	_判(剩.is_empty(), "追完 300 拍那枚金币应该已经进包（`挂机的掉落` 还剩 %d 条）" % 剩.size())
	## 判据 ③：不许长期卡在"拾取"这一档（真机上"卡住不动"就是这个状态挂着不走）
	_判(拾取拍数 < 200, "状态=拾取 不许把整段 240 拍占满（实得 %d 拍）—— 占满就是钉在捡东西上、不打怪也不归位" % 拾取拍数)
	_收()


func _收() -> void:
	var 路 := "user://挂机拾取卡住追踪.txt"
	var f := FileAccess.open(路, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	_记("红 %d 项 → %s" % [红, 路])
	quit(0 if 红 == 0 else 1)
