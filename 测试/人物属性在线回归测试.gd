extends SceneTree

## 人物「战斗属性」那几个字段，**真的从服务端拿得到**。
##
## 为什么单开一条：这些字段曾经被解析漏掉 —— 于是"攻击速度""移动速度"在人物面板上
## **恒显示 0**。服务端一直在发（字段号 `20=ATTACK_SPEED` / `21=WALK_SPEED`）。
##
## ⚠️ **更正（2026-09-25）**：这里原来写"走的是二进制统计包（`后端连接._handle_stats`）"——
##    **错的**。本客户端恒走 AMF3 通道，属性走的是**文本路** `_handle_stats_text`，
##    那个二进制 `_handle_stats` 是**不可达的死代码**，已于 §3.27 删除。
##    字段号真值以服务端 `StatType` 为准（`fake_flash_server.py:1058`）。
##
## ⚠️ **这条要连夹具**（默认 127.0.0.1:18684）。夹具没跑就会失败 —— 那是**环境问题**，
## 不是用例坏了；跑之前先确认端口在听（见 memory「开游戏前先查服务端」）。
##
## 用法：
##   Godot --headless --path . --script res://测试/人物属性在线回归测试.gd

## ⚠️ **判据要分两栏，别混**（2026-09-25 修：原来 6 个字段一律要求 > 0，是**错的**）。
##
## 服务端给**硬编码基值**的字段 —— 裸角色也非零，所以要求 > 0：
##   `attack_speed` 基值 160 起（`fake_flash_server.py:48231 _unscaled_current_attack_speed`），
##   attack / defense / move_speed 同理。
const 必须有且大于零 := ["attack", "defense", "attack_speed", "move_speed"]

## 由**装备 / 加点 / 成长**算出来的字段 —— **裸角色本来就是 0**，只要求"在"：
##   暴击 = 基础加点 + 装备 + 成长（`fake_flash_server.py:48186 _unscaled_current_critical`）
##   闪避 = 同上（`:47953`）
##   夹具角色（`本地服务端夹具.py` 造的）是裸装、没加点 → 这两个恒 0。
##   **别把它俩列进"必须 > 0"** —— 那是判据错，不是"接漏了"。
##   （这两栏原来混在一起，于是这条用例从来没通过过；又因为没人跑它，一直没人发现。）
const 必须有 := ["level", "job", "max_hp", "max_mp", "critical", "dodge"]

## ⚠️ **判准确值，不是"键存在"**（2026-10-09）。
## 罪恶值（`StatType.CRIME = 33`）：原来客户端这张 id 表**没有 33**、而人物窗那行读的是
## `fame`（字段 26 —— 服务端**从不发**）⇒ 面板上的罪恶值永远是旧数。
## 夹具把 `crime` 设成 `MAIN_CRIME = 123`（**故意非零**）：若这条按"键在不在"判，
## 默认值 0 也会绿 —— 那就是假绿。所以这里比**值**。
const 必须等于 := {"crime": 123}
## 原版 `ExpTable.as` 的等级经验表（由 `开发工具/生成等级经验表.py` 生成）—— 经验条的分母。
const 表脚本 := preload("res://脚本/单例/等级经验表.gd")
# ⚠️ 键名以 `服务端会话同步.应用人物` 的**字段映射**为准（它会把 maxHp→max_hp 等改名），
# 不是原版协议里的名字。查错了键名会误报"没接"。

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var session := root.get_node_or_null("GameSession")
	if backend == null or session == null:
		_失败.append("缺少 BackendConnection / GameSession 单例")
		_收尾()
		return

	backend.sync_character()
	var 期限 := Time.get_ticks_msec() + 10000
	while not backend.in_game and Time.get_ticks_msec() < 期限:
		await create_timer(0.05).timeout
	if not backend.in_game:
		_失败.append("连不上夹具（%s - %s）。先确认 18684 在听" % [backend.status, backend.detail])
		_收尾()
		return

	# 统计包可能在进游戏之后才到，再等一会儿
	var 期限2 := Time.get_ticks_msec() + 5000
	var 属性: Dictionary = session.player_stats if session.get("player_stats") != null else {}
	while 属性.is_empty() and Time.get_ticks_msec() < 期限2:
		await create_timer(0.05).timeout
		属性 = session.player_stats if session.get("player_stats") != null else {}

	if 属性.is_empty():
		_失败.append("进游戏了但没收到统计包（GameSession.player_stats 是空的）")
		_收尾()
		return

	var 报 := []
	for 字段 in 必须有:
		if not 属性.has(字段):
			_失败.append("统计包里没有「%s」（服务端发了，是我们没接）" % 字段)
	for 字段 in 必须有且大于零:
		if not 属性.has(字段):
			_失败.append("统计包里没有「%s」—— 服务端原版协议发的是 20/21 号字段，八成是 id 表又漏了" % 字段)
		elif int(属性[字段]) <= 0:
			_失败.append("「%s」拿到的是 %s，应当 > 0" % [字段, 属性[字段]])
		else:
			报.append("%s=%s" % [字段, 属性[字段]])
	# 值必须对得上（夹具里是固定值）—— 见上面 `必须等于` 的注释。
	for 字段 in 必须等于:
		if not 属性.has(字段):
			_失败.append("统计包里没有「%s」—— 服务端发的是 33 号字段，八成是 id 表又漏了" % 字段)
		elif int(属性[字段]) != int(必须等于[字段]):
			_失败.append("「%s」拿到的是 %s，应当是 %s（服务端那条字段没接上/被别处覆盖了）"
				% [字段, 属性[字段], 必须等于[字段]])
		else:
			报.append("%s=%s" % [字段, 属性[字段]])

	if not _失败.is_empty():
		print("人物属性在线回归测试：**失败时**的会话键 = %s" % [属性.keys()])
		_收尾()
		return
	# ── #180 经验条分母：真服务端一局里核对「分母 = 原版等级经验表[当前等级]」─────────────
	# 修前 `max_exp` 从来没被喂过，停在离线示例数据那个 100 ⇒ 底栏与人物面板那两根条恒满。
	# 原版分母只来自 `ExpTable.getExpNeededForLevel(level)`（`DataCenter.as:2443` 与 `:1462`），
	# 服务端属性包里没有"升级所需经验"这一号 ⇒ 这一条只能在客户端查表，查不到就是没有分母。
	if not 属性.has("max_exp"):
		_失败.append("会话里没有 max_exp ⇒ 经验条没有分母（底栏与人物面板那两根会恒为满格）")
	elif int(属性["max_exp"]) != 表脚本.本级所需(int(属性.get("level", 1))):
		_失败.append("max_exp=%s 不等于 表[等级 %s]=%s（等级经验表 = 原版 ExpTable.as）" % [
				str(属性["max_exp"]), str(属性.get("level", 1)),
				str(表脚本.本级所需(int(属性.get("level", 1))))])
	elif int(属性["max_exp"]) == 100:
		_失败.append("max_exp 又是 100 —— 那是离线示例数据的兜底值，说明权威分母没落进去")
	elif 属性.has("exp") and int(属性["exp"]) > int(属性["max_exp"]):
		_失败.append("exp=%s 大于本级所需 %s ⇒ 比例会被 clamp 成满格，条子看着就不动了" % [
				str(属性["exp"]), str(属性["max_exp"])])
	print("人物属性在线回归测试：通过（%s）；经验 %s / 本级所需 %s（等级 %s）" % [
			", ".join(报), str(属性.get("exp", "?")), str(属性.get("max_exp", "?")),
			str(属性.get("level", "?"))])
	print("人物属性在线回归测试：会话现有键 = %s" % [属性.keys()])
	quit(0)


func _收尾() -> void:
	for 项 in _失败:
		push_error("人物属性在线回归测试：失败 - %s" % 项)
	quit(1)
