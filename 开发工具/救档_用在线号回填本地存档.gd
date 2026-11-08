extends SceneTree
## 【救档工具，不是门】用在线号把服务端的权威人物/宠物写回本地 `user://玩家数据.json`。
##
## 跑法（夹具服务端必须先起在 18684 上，即 `启动游戏.bat` 的第一段，**不带 --reset**）：
##   Godot --headless --path <工程根> --script res://开发工具/救档_用在线号回填本地存档.gd
##
## 来历（2026-10-17）：新门 `测试/宠物面板回归测试.gd` 第一版没做玩档快照，把 `level=1`
## + 两只假宠写进了真实玩档。服务端（夹具 `--root .fixture-play`）里那份角色是好的：
## 木叶忍者 Lv100、7 只通灵兽（全 Lv120/品阶4）、背包 73 件、金币 4000 万 ⇒ 用真登录链回填。
##
## 做法：走**真登录链**（`后端连接.sync_character()` → 服务端推权威帧 → 会话层收下）：
##   ① 等级/属性 = `服务端会话同步.应用人物` 的结果；
##   ② 背包/装备 = `应用背包`；
##   ③ 宠物 = 显式 `request_pet_list()`（`action 0`）→ `_handle_pet_action_text` →
##      `apply_backend_pets` ⇒ `会话.pets`；
##   收齐后把 `backend_authoritative` 放下（在线态 `_save_local_state` 只写设置文件、不写大存档），
##   再调一次 `_save_local_state()` ⇒ 用**权威数据**整份重写 `user://玩家数据.json`。
##
## 安全闸（任一不满足就**不写盘**，只打印现状）：
##   · `in_game == true`；· `player_stats.level >= 50`；· `会话.pets.size() >= 1`。
## 跑之前必须已有夹具服务端在 18684 上（`启动游戏.bat` 的第一段，不带 `--reset`）。

const 存档 := "user://玩家数据.json"

var _fails: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _等秒(上限: float, 条件: Callable) -> bool:
	var 起 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - 起) / 1000.0 < 上限:
		if 条件.call():
			return true
		await create_timer(0.05).timeout
	return 条件.call()


func _字节() -> PackedByteArray:
	if not FileAccess.file_exists(存档):
		return PackedByteArray()
	var f := FileAccess.open(存档, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	return f.get_buffer(f.get_length())


func _run() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		print("★ 缺 BackendConnection / GameSession 单例")
		quit(1)
		return

	var 前 := _字节()
	var 设置: Dictionary = 会话.get("game_settings")
	print("端口=%s 账号=%s  存档现况=%d 字节" % [
		str(设置.get("backend_port", "?")), str(设置.get("backend_account", "?")), 前.size()])

	后端.sync_character()
	if not await _等秒(30.0, func() -> bool: return bool(后端.in_game)):
		print("★ 30 秒没进游戏会话：status=%s detail=%s（夹具没起来？）" % [
			str(后端.status), str(后端.detail)])
		quit(1)
		return
	print("已登录：in_game=%s 人物id=%d" % [str(后端.in_game), int(后端.character_id)])

	# 宠物列表要显式要一发：登录流程里没有自动发 `action 0`（`request_pet_list` 全工程零调用者）
	后端.request_pet_list()
	if not await _等秒(20.0, func() -> bool: return (会话.pets as Array).size() > 0):
		print("★ 20 秒没收到宠物列表（会话.pets 仍空）⇒ 不写盘")
		quit(1)
		return

	# 再等两拍，让属性/背包帧都到齐
	await create_timer(1.5).timeout

	var 级 := int((会话.player_stats as Dictionary).get("level", 0))
	var 宠数 := (会话.pets as Array).size()
	var 背包数 := (会话.inventory as Array).size()
	print("收下：等级=%d 宠物=%d 只 背包位=%d 金币=%s" % [
		级, 宠数, 背包数, str((会话.player_stats as Dictionary).get("gold", "?"))])
	for 宠 in 会话.pets:
		print("  宠 %s item=%s Lv%s %s" % [
			str(宠.get("id", "")), str(宠.get("item_id", "")),
			str(宠.get("level", "")), str(宠.get("name", ""))])

	# ── 安全闸 ──
	if 级 < 50:
		print("★ 等级只有 %d（<50）⇒ 判定没收到权威人物，不写盘" % 级)
		quit(1)
		return
	if 宠数 < 1:
		print("★ 宠物 0 只 ⇒ 不写盘")
		quit(1)
		return

	# 快照（脚本自己再存一份，双保险）
	var 备 := "user://玩家数据_救档前_%d.json" % int(Time.get_unix_time_from_system())
	var w := FileAccess.open(备, FileAccess.WRITE)
	if w != null:
		w.store_buffer(前)
		w.close()
		print("已另存：%s" % 备)

	# 放下权威标记，让 `_save_local_state` 走"写大存档"那一支
	会话.set("backend_authoritative", false)
	会话.call("_save_local_state")
	var 后 := _字节()
	print("存档重写：%d → %d 字节" % [前.size(), 后.size()])
	quit(0)
