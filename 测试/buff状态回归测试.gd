extends SceneTree

## Buff 状态回归（2026-10-17 用户报「buff 状态没有提示框／buff 道具是否实装」）。
##
## 钉住的真值（都在文件头写清出处，改之前先回去读 AS3）：
##   ① `GIVE_BUFF` 的名字/描述/图标：`SkillHandler.applyBuff:858-890`
##      · 玩家技能：name = String/Skill，desc = `getSkillBuffDesc`（buffDesc，不是技能详情），
##        `valueTotal`/`duration` 用**本次帧**的值替换；
##      · 宠物技能（skillId < 1000）：PetSkill 的 name/buffDesc/icon。
##      旧实现写的是 `description` 键、HUD 读 `desc` ⇒ 描述永远空；宠物技能连名字/图标都没有。
##   ② 限时道具效果**按 itemId/type 分格**：`BuffCell` 的去重键是 type+skillId；
##      旧实现只按 kind 存 ⇒ 第二种属性药剂把第一种的图标顶掉。
##   ③ HUD 状态格：原版最多 18 格（`BuffPane.as:81-93`）；悬停提示是
##      `MToolTipTextWithTitle`（橙标题 + 白描述 + 剩余时间），不是原生单行 tooltip。
##   ④ 每秒倒计时；到点先闪 120ms×10 再收格（`BuffCell.setCD:194-223`）。
##
## 用法：Godot --headless --path . --script res://测试/buff状态回归测试.gd

const 头像面板场景 := preload("res://场景/界面/头像面板.tscn")

var _失败: Array[String] = []
var _后端: Node
var _会话: Node
var _旧族: Dictionary


func _initialize() -> void:
	call_deferred("_跑")


func _判(条件: bool, 话: String) -> void:
	if not 条件:
		_失败.append(话)


func _跑() -> void:
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _后端 == null or _会话 == null:
		_失败.append("缺 BackendConnection / GameSession 单例")
		_收尾()
		return
	# 别让本机 user:// 里的家族/打坐等离线态混进"增益栏里应该有几条"的判断。
	_旧族 = (_会话.get("guild") as Dictionary).duplicate(true)
	_会话.set("guild", {"joined": false})
	(_后端.get("authoritative_buffs") as Dictionary).clear()
	(_后端.get("authoritative_item_effects") as Dictionary).clear()
	_会话.call("清空服务端增益")
	_会话.call("清空限时效果")

	# ── ① 玩家技能 buff → 名字/描述/图标 ───────────────────────────────────
	_喂buff("0&0.1&1002003&1&300000")
	var 条 := _找增益("淬毒")
	_判(not 条.is_empty(), "玩家技能 buff 1002003（淬毒）没进 hud_state.buffs")
	if not 条.is_empty():
		_判(String(条.get("name", "")) == "淬毒", "buff 名字错：%s" % 条.get("name", ""))
		var 述 := String(条.get("desc", ""))
		_判(not 述.is_empty(), "buff 描述是空的（旧实现把 desc 写成了 description 键）")
		_判(述.contains("中毒"), "buff 描述没取 buffDesc：%s" % 述)
		_判(述.contains("10.00%"), "buffDesc 的 valueTotal 没按帧里的 10%% 替换：%s" % 述)
		_判(述.contains("300秒"), "buffDesc 的 duration 没按帧里的 300 秒替换：%s" % 述)
		var 图 := String(条.get("icon", ""))
		_判(图.begins_with("res://") and ResourceLoader.exists(图),
				"玩家技能 buff 图标没解析成工程贴图：%s" % 图)
		_判(int(条.get("duration_ms", 0)) == 300000 and int(条.get("received_at_msec", 0)) > 0,
				"buff 没留下 duration/received_at，HUD 无法倒计时")
		_判(述 != "" and String(条.get("description", "")) == 述,
				"desc / description 两个键不一致（HUD 读 desc）")

	# ── ② 宠物技能 buff（skillId < 1000）→ PetSkill 的名字/描述/图标 ─────────
	_喂buff("44&0.1&106&1&300000")
	var 宠 := _找增益("暴遁封印")
	_判(not 宠.is_empty(), "宠物 buff 106 没进 hud_state.buffs（旧实现查 技能.json 查不到）")
	if not 宠.is_empty():
		_判(String(宠.get("desc", "")).contains("暴击降低10.00%"),
				"宠物 buffDesc 错：%s" % 宠.get("desc", ""))
		var 宠图 := String(宠.get("icon", ""))
		_判(宠图.begins_with("res://") and ResourceLoader.exists(宠图),
				"宠物技能图标没从 PetSkill 的 className 解析出来：%s" % 宠图)

	# ── ③ HUD：18 格 / 可悬停 / 原版提示框 / 倒计时 ──────────────────────────
	var 面板 := (头像面板场景.instantiate()) as CanvasLayer
	root.add_child(面板)
	await process_frame
	var 格们: Array = 面板.get("_status_slots")
	_判(格们.size() == 18, "状态格应为原版 18 格，实为 %d" % 格们.size())
	for 格 in 格们:
		_判((格 as TextureRect).mouse_filter != Control.MOUSE_FILTER_IGNORE,
				"状态格是 IGNORE，悬停事件到不了（提示框永远弹不出来）")
	面板.call("_on_hud_state_changed", _会话.get("hud_state"))
	var 增: Array = (_会话.get("hud_state") as Dictionary).get("buffs", []) as Array
	var 淬毒序 := _找序号(增, "淬毒")
	_判(淬毒序 >= 0, "HUD 渲染时找不到淬毒那条")
	if 淬毒序 >= 0:
		var 格 := 格们[淬毒序] as TextureRect
		_判(bool(格.visible), "淬毒那条没画到状态格上")
		# 10-25 起一格是三层（格底 + 图标 + 扇形，`BuffCell.as:234-292`）：
		# 格自己的 `texture` 是 MGrid_background，图标在「图标」子节点上。
		var 图件 := 格.get_node_or_null("图标") as TextureRect
		_判(图件 != null and 图件.texture != null
				and 图件.texture.resource_path == String((_找增益("淬毒")).get("icon", "")),
				"淬毒格子的图标层画的不是 skill 图标")
		面板.call("_显示状态提示", 淬毒序)
		var 提示 := 面板.get_node_or_null("头像区域/buff提示框") as Control
		_判(提示 != null, "头像面板没建出原版 buff 提示框")
		if 提示 != null:
			_判(bool(提示.visible), "悬停淬毒后提示框没显示")
			var 题 := 提示.get_node_or_null("标题") as RichTextLabel
			var 文 := 提示.get_node_or_null("文") as RichTextLabel
			_判(题 != null and 题.text.contains("淬毒"), "提示框标题里没有 buff 名字")
			_判(文 != null and 文.text.contains("中毒"), "提示框描述里没有 buffDesc")
			_判(文 != null and 文.text.contains("剩余时间："), "技能 buff 提示框没显示剩余时间")
		面板.call("_收起状态提示")
		# 过期：原版到点先闪 120ms×10（`BuffCell.as:194-223`），1.2 秒后才收格。
		var 条示 := (面板.get("_状态提示") as Array)[淬毒序] as Dictionary
		条示["expires"] = Time.get_ticks_msec() - 1
		面板.call("_刷新状态提示")
		_判((面板.get("_闪烁") as Dictionary).has(淬毒序), "到期的 buff 没进入原版的闪烁档")
		面板.call("_推进闪烁", Time.get_ticks_msec() + 1300)
		_判(not bool((格们[淬毒序] as TextureRect).visible), "闪烁结束后到期的 buff 格子没有被收掉")

	# ── ③b 连斩 / 打坐：原版 HUD 各一格，本机服务端用 1291:2 / 1288:1 驱动 ─────
	# 连斩：`LianzhanHandler.applyBuff:47-66`，名字/描述取 Buff/Lianzhan，剩余/总秒来自帧；
	# 打坐：`HealHandler.addBuff:119-136`，单人 Heal/0、双修 Heal/1，int.MAX 永久。
	var 真id := int(_后端.get("character_id"))
	_后端.set("character_id", 42)
	_后端.call("_handle_lianzhan_text", PackedStringArray(["1291", "2", "2", "30", "100", "900", "42"]))
	var 连 := _找增益("二百连")
	_判(not 连.is_empty(), "连斩阶段 2 没进增益栏（原版 LianzhanHandler 会加一格「二百连」）")
	if not 连.is_empty():
		_判(String(连.get("desc", "")).contains("打怪经验+30%"), "连斩描述错：%s" % 连.get("desc", ""))
		_判(int(连.get("expires_at_msec", 0)) > 0, "连斩格没留到期时间，HUD 无法倒计时")
	_后端.call("_handle_lianzhan_text", PackedStringArray(["1291", "2", "3", "40", "100", "900", "43"]))
	_判(_找增益("三百连").is_empty(), "别的角色号（43）的连斩不该点亮自己（42）的格子")
	_后端.call("_handle_lianzhan_text", PackedStringArray(["1291", "2", "0", "0", "0", "0", "42"]))
	_判(_找增益("二百连").is_empty(), "连斩阶段归 0 后格子没摘掉")
	_后端.call("_handle_heal_text", PackedStringArray(["1288", "1", "1", "42", "0"]))
	_判(not _找增益("单人打坐").is_empty(), "单人打坐没进增益栏（Heal/0）")
	_后端.call("_handle_heal_text", PackedStringArray(["1288", "1", "2", "42", "43"]))
	_判(not _找增益("双修").is_empty() and _找增益("单人打坐").is_empty(),
			"双修状态应换成「双修」一格（Heal/1），并摘掉单人那格")
	_后端.call("_handle_heal_text", PackedStringArray(["1288", "1", "0", "42", "0"]))
	_判(_找增益("双修").is_empty(), "停止打坐后双修格子没摘掉")
	_后端.set("character_id", 真id)

	# ── ③c 罪状格：按罪恶值判 C/B/A/S，图标取 iconSkillId 的技能图 ──────────
	# 原版 `PVPHandler.checkAddCrimeBuff:740-800`：阈值来自 Buff/PK 的 crimeC/B/A/S.begin；
	# 图标是 `PicTool.getSkillPic(iconSkillId)`（Buff 行自己没有 icon）。
	var 旧属性: Dictionary = (_会话.get("player_stats") as Dictionary).duplicate(true)
	var 属性: Dictionary = _会话.get("player_stats")
	属性["crime"] = 600
	_会话.player_stats_changed.emit(属性.duplicate(true))
	_判(not _找增益("C级叛忍").is_empty(), "罪恶值 600 应出 C 级叛忍格")
	属性["crime"] = 4000
	_会话.player_stats_changed.emit(属性.duplicate(true))
	_判(not _找增益("B级叛忍").is_empty() and _找增益("C级叛忍").is_empty(),
			"罪恶值 4000 应换成 B 级叛忍、摘掉 C 级")
	属性["crime"] = 10000
	_会话.player_stats_changed.emit(属性.duplicate(true))
	var 叛 := _找增益("S级叛忍")
	_判(not 叛.is_empty(), "罪恶值 10000 应出 S 级叛忍格")
	if not 叛.is_empty():
		_判(String(叛.get("desc", "")).contains("攻击+200"), "S 级叛忍文案错：%s" % 叛.get("desc", ""))
		var 叛图 := String(叛.get("icon", ""))
		_判(叛图.contains("9000313") and ResourceLoader.exists(叛图),
				"S 级叛忍图标应取 iconSkillId=9000313 的技能图，实为 %s" % 叛图)
	属性["crime"] = 100
	_会话.player_stats_changed.emit(属性.duplicate(true))
	_判(_找增益("C级叛忍").is_empty() and _找增益("B级叛忍").is_empty()
			and _找增益("A级叛忍").is_empty() and _找增益("S级叛忍").is_empty(),
			"罪恶值 100 不该有任何叛忍格")
	属性["crime"] = int(旧属性.get("crime", 0))
	_会话.player_stats_changed.emit(属性.duplicate(true))

	# ── ④ 限时道具效果：两种属性药剂并存 + 提示框描述/剩余容量 ──────────────
	_喂道具效果("attribute_boost", "15003001", 180, 180)
	_喂道具效果("attribute_boost", "15003003", 180, 180)
	var 效: Array = (_会话.get("hud_state") as Dictionary).get("effects", []) as Array
	_判(效.size() == 2, "两瓶不同属性药剂应并存 2 格（旧实现按 kind 存只剩最后 1 格），实为 %d" % 效.size())
	var 攻 := _找效果(效, "攻击药剂")
	_判(not 攻.is_empty(), "攻击药剂没进限时效果列表")
	if not 攻.is_empty():
		_判(String(攻.get("desc", "")).contains("提升"), "限时效果没带道具描述：%s" % 攻.get("desc", ""))
		_判(int(攻.get("received_at_msec", 0)) > 0, "限时效果没留下收到时刻，HUD 无法倒计时")
	# 画出来：天气 -1；**槽位按首次到达序**（原版 `BuffPane.as:177-183`），
	# 不能拿 effects 数组下标当槽位 —— 前面的 buff 先到就会占掉前面几格。
	面板.call("_on_hud_state_changed", _会话.get("hud_state"))
	var 效序 := _找槽位(面板, "攻击药剂")
	_判(效序 >= 0, "HUD 效果栏里找不到攻击药剂")
	if 效序 >= 0:
		面板.call("_显示状态提示", 效序)
		var 提示2 := 面板.get_node_or_null("头像区域/buff提示框") as Control
		if 提示2 != null:
			var 文2 := 提示2.get_node_or_null("文") as RichTextLabel
			_判(文2 != null and 文2.text.contains("剩余容量："),
					"道具效果提示框没显示原版的「剩余容量：」")
		面板.call("_收起状态提示")
	_喂道具效果("double_exp", "15002001", 3600, 3600, 0)
	_喂道具效果("double_exp", "15002002", 3600, 3600, 1)
	效 = (_会话.get("hud_state") as Dictionary).get("effects", []) as Array
	_判(效.size() == 4, "两种双倍符 + 两瓶属性药剂应并存 4 格，实为 %d" % 效.size())
	_喂道具效果("attribute_boost", "15003001", 0, 180)
	效 = (_会话.get("hud_state") as Dictionary).get("effects", []) as Array
	_判(效.size() == 3, "剩余 0 秒的效果没按 key 摘掉（应剩 3 格），实为 %d" % 效.size())

	# ── ⑤ 离线灵药（zidong）不许当瞬回药 ────────────────────────────────────
	# 服务端 `_use_auto_consume_item` 把它灌进"自动补给容量"，只回 1292；旧离线因为表里
	# 有 hp_restore 就当场回血并扣件。离线必须明说"要在服务端结算"且**不扣件**。
	var 旧背包: Array = (_会话.get("inventory") as Array).duplicate(true)
	var 通知: Array[String] = []
	var 收通知 := func(文本: String) -> void: 通知.append(文本)
	_会话.notification_requested.connect(收通知)
	var 试背: Array[Dictionary] = [{"id": "15004001", "slot_index": 1, "quantity": 1, "use_all": 1}]
	_会话.set("inventory", 试背)
	var 用成 := bool(_会话.call("use_inventory_slot", 1))
	_会话.notification_requested.disconnect(收通知)
	var 剩 := int(((_会话.get("inventory") as Array)[0] as Dictionary).get("quantity", 0))
	_判(not 用成, "离线使用 zidong 灵药应被拒（效果在服务端结算）")
	_判(剩 == 1, "离线拒用后灵药被扣了：剩 %d" % 剩)
	var 说了 := false
	for t in 通知:
		if String(t).contains("服务端结算"):
			说了 = true
	_判(说了, "离线拒用灵药要说清原因，实得 %s" % str(通知))
	_会话.set("inventory", 旧背包)

	# ── ⑥ CANCEL_BUFF 只摘掉对应类型 ─────────────────────────────────────────
	_后端.call("_handle_cancel_buff_text", PackedStringArray(["36", "0"]))
	_判(_找增益("淬毒").is_empty(), "CANCEL_BUFF 0 之后淬毒还在")
	_判(not _找增益("暴遁封印").is_empty(), "CANCEL_BUFF 0 把宠物那条也一起摘了")

	面板.queue_free()
	await process_frame
	_收尾()


func _喂buff(编码: String) -> void:
	_后端.call("_handle_give_buff_text", PackedStringArray(["35", 编码]))


func _喂道具效果(kind: String, item_id: String, 剩余: int, 总: int, 类型 := 0) -> void:
	if kind == "double_exp":
		_后端.call("_handle_double_exp_text",
				PackedStringArray(["1433", str(类型), "100", item_id, str(剩余), str(总)]))
	else:
		_后端.call("_handle_timed_item_effect_text", kind,
				PackedStringArray(["1433", item_id, str(剩余), str(总)]))


func _找增益(名: String) -> Dictionary:
	var 列: Array = (_会话.get("hud_state") as Dictionary).get("buffs", []) as Array
	for v in 列:
		var 条 := v as Dictionary
		if String(条.get("name", "")) == 名:
			return 条
	return {}


func _找序号(列: Array, 名: String) -> int:
	for i in 列.size():
		if String((列[i] as Dictionary).get("name", "")) == 名:
			return i
	return -1


## 按提示框标题找它在**状态排里占第几格**（不是数组下标）。
func _找槽位(面板: Node, 名: String) -> int:
	var 提示: Array = 面板.get("_状态提示") as Array
	for i in 提示.size():
		var 条 := 提示[i] as Dictionary
		if String(条.get("title", "")) == 名:
			return i
	return -1


func _找效果(效: Array, 名: String) -> Dictionary:
	for v in 效:
		var 条 := v as Dictionary
		if String(条.get("name", "")) == 名:
			return 条
	return {}


func _收尾() -> void:
	_会话.set("guild", _旧族)
	if _失败.is_empty():
		print("buff状态回归测试：通过（玩家/宠物 buff 文案 · 18 格可悬停 · 原版提示框 · 倒计时/过期 · 限时效果多实例）")
		quit(0)
		return
	for 条 in _失败:
		print("  FAIL " + 条)
	print("buff状态回归测试：%d 项不通过" % _失败.size())
	quit(1)
