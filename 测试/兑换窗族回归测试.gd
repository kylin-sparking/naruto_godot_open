extends SceneTree

## 「活动大使兑换窗族」回归测试（§3.119，2026-10-11）—— **忍具兑换 / 十拳剑兑换** 两扇。
##
## 为什么单开一条：`原版服务窗回归测试` 是**只读磁盘文本**那条腿（它头注自己写着"不 load 场景"）
## ⇒ "碎片格填没填、兑换钮点下去发不发"**从来没有被看过**。本轮把两扇窗的兑换钮都接到真协议上
## （`RENJU 2082` 动作 3 / `LING 2081` 动作 3）之后必须补这条。
##
## 每扇窗钉四件事（判据一律取**行为**）：
##   ① 六枚碎片格按背包**真数量**填（原版 `validateItem:134-153`）；
##   ② 数量 0 的格子**灰化**、有货的不灰（原版 `applyGrayFilter`），**数量文本不跟着灰**；
##   ③ 碎片不全时点「兑换」⇒ **一个请求都不发** + 一句提示（原版是静默返回，我们给提示）；
##   ④ 六种齐了 ⇒ 发**一次**对应请求并**关窗**（原版那两扇都是 `setDOShow(...,false)`）；
##   ⑤ 成品格与碎片格**悬停能弹提示框**（原版 `SimpleItemCell.as:220`；§3.332 补）。
##
## ⚠️ 不写 `user://玩家数据.json`：背包只往内存里加、退出前**原地**还原
##    （`inventory` 是类型化数组，整份赋值会被 Godot 拒 —— 只能 clear + 重新 append）。
##
## 用法：Godot --headless --path . --script res://测试/兑换窗族回归测试.gd

## 两扇窗的差异全在这张表里（其余结构一模一样：`子面板/碎片格1..6/碎片格N_格`）。
const 窗表 := [
	{
		"页名": "忍具兑换", "根": "原版忍具兑换内容", "名字": "八咫镜",
		"成品格": "子面板/忍具格/忍具格_格", "成品id": 65000001,
		"碎片": [16000278, 16000279, 16000280, 16000281, 16000282, 16000283],
		"方法": "request_renju_combine",
		# 忍具那扇原版把「名」硬编码成 `"碎片" + (i+1)` ⇒ 碎片1..6（十拳剑那扇是 碎片0..5，别动它）
		"名文案": ["碎片1", "碎片2", "碎片3", "碎片4", "碎片5", "碎片6"],
	},
	{
		"页名": "十拳剑兑换", "根": "原版十拳剑兑换内容", "名字": "十拳剑",
		"成品格": "子面板/十拳剑格/十拳剑格_格", "成品id": 20100001,
		"碎片": [16000110, 16000111, 16000112, 16000113, 16000114, 16000115],
		"方法": "request_ling_equip_combine",
		"名文案": ["碎片0", "碎片1", "碎片2", "碎片3", "碎片4", "碎片5"],
	},
]

var _失败: Array[String] = []


## 假后端：只收不连，用来**看请求到底发没发**。两个方法都要有（两扇窗各用一条）。
class 假后端:
	extends Node
	var in_game := true
	var 忍具次数 := 0
	var 十拳剑次数 := 0

	func request_renju_combine() -> bool:
		忍具次数 += 1
		return true

	func request_ling_equip_combine() -> bool:
		十拳剑次数 += 1
		return true


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _序号 in 5:
		await process_frame

	var 会话: Node = root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("拿不到 GameSession")
		return
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_停("拿不到 窗口管理")
		return

	var 备份: Array = (会话.get("inventory") as Array).duplicate(true)
	var 通知: Array = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(String(文)))

	for 扇: Dictionary in 窗表:
		await _验一扇(管理, 会话, 扇, 通知)

	_还原背包(会话, 备份)
	_收尾()


func _验一扇(管理: Node, 会话, 扇: Dictionary, 通知: Array) -> void:
	var 碎片: Array = 扇["碎片"]
	var 页名 := String(扇["页名"])
	var 名字 := String(扇["名字"])
	var 方法 := String(扇["方法"])
	# 只给前两种碎片（第三种以后一件都没有）—— "填数量 / 灰化 / 前置拦截"一起可判
	for i in 碎片.size():
		_设件数(会话, str(碎片[i]), 3 if i == 0 else (1 if i == 1 else 0))

	var 窗 = 管理.call("取或建窗口", 页名)
	管理.call("打开", 页名)
	for _序号 in 4:
		await process_frame
	if 窗 == null or not bool(窗.call("已打开")):
		_失败.append("%s 页没打开" % 页名)
		return
	var 页 := _取页(窗, String(扇["根"]))
	if 页 == null:
		_失败.append("窗口里没有「%s」" % String(扇["根"]))
		return

	_验碎片格(页, 扇, ["3", "1", "0", "0", "0", "0"])
	await _验提示(页, 扇)

	# ③ 碎片不全 ⇒ 一个请求都不发 + 一句提示
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	通知.clear()
	var 兑 := 页.get_node_or_null("兑换钮") as Button
	if 兑 == null:
		_失败.append("%s 找不到「兑换钮」" % 页名)
	else:
		if int(兑.mouse_default_cursor_shape) != int(Control.CURSOR_POINTING_HAND):
			_失败.append("%s 的兑换钮没设手型（原版 `MButton3` 一律手型）" % 页名)
		兑.pressed.emit()
		await process_frame
		if _次数(假, 方法) != 0:
			_失败.append("%s：碎片不全时不该发请求，实际发了 %d 次" % [页名, _次数(假, 方法)])
		if not _有集齐提示(窗, 通知):
			_失败.append("%s：碎片不全时该给一句提示（本页不允许静默返回），实际：%s" % [页名, 通知])

	# ④ 六种齐了 ⇒ 发一次 + 关窗
	for id in 碎片:
		_设件数(会话, str(id), 1)
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, String(扇["根"]))
	if 页 == null:
		窗.set("_backend", null)
		_失败.append("%s：补满碎片后重渲染，页面不见了" % 页名)
		return
	_验碎片格(页, 扇, ["1", "1", "1", "1", "1", "1"])
	兑 = 页.get_node_or_null("兑换钮") as Button
	if 兑 != null:
		兑.pressed.emit()
		await process_frame
		if _次数(假, 方法) != 1:
			_失败.append("%s：六种碎片齐了该发**一次** %s，实际 %d 次" % [页名, 方法, _次数(假, 方法)])
		elif bool(窗.call("已打开")):
			_失败.append("%s：请求发出去之后该关窗（原版 `setDOShow(...,false)`）" % 页名)
	窗.set("_backend", null)	# 假后端别留给下一扇/下一门（窗口实例是跨门复用的）


## 悬停详情框（§3.332）：成品格 + 六枚碎片格都得能弹。
## 原版这两扇窗的格子是 `SimpleItemCell`，每枚都挂 `MToolTipItem`（`SimpleItemCell.as:220`）；
## 我们这两页的场景里**没有烘**提示框节点 ⇒ `功能窗口._给页挂提示框` 运行期补 + `_接兑换提示` 接线。
## 成品是装备位（65000001 → 忍具 -24、20100001 → 灵器 -23）⇒ 走「装备提示框」；
## 碎片是普通物品（1600 段）⇒ 走「物品提示框」。
func _验提示(页: Control, 扇: Dictionary) -> void:
	var 页名 := String(扇["页名"])
	var 物品框 := 页.get_node_or_null("物品提示框") as Control
	var 装备框 := 页.get_node_or_null("装备提示框") as Control
	if 物品框 == null or 装备框 == null:
		_失败.append("%s 页上缺提示框节点（该由 `_给页挂提示框` 运行期补）" % 页名)
		return
	var 成品格 := 页.get_node_or_null(String(扇["成品格"])) as Control
	if 成品格 == null:
		_失败.append("%s 找不到成品格「%s」" % [页名, String(扇["成品格"])])
	elif 成品格.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_失败.append("%s 成品格的 mouse_filter 是 IGNORE ⇒ 永远收不到悬停（接线该抬成 PASS）" % 页名)
	else:
		成品格.emit_signal("mouse_entered")
		await process_frame
		if not 装备框.visible:
			_失败.append("%s 悬停成品格该弹出「装备提示框」" % 页名)
		else:
			var 标 := 装备框.get_node("标题") as Label
			if 标.text != String(扇["名字"]):
				_失败.append("%s 成品提示框标题该是「%s」，实际「%s」" % [页名, String(扇["名字"]), 标.text])
			if int(扇["成品id"]) == 65000001:
				var 信息 := 装备框.get_node("信息") as Label
				if not 信息.text.contains("佩戴部位　忍具"):
					_失败.append("忍具兑换的成品提示框该走忍具版式（佩戴部位　忍具），实际「%s」"
						% 信息.text.replace("\n", "\\n"))
				var 明细 := (装备框.get_node("明细") as RichTextLabel).text
				if not 明细.contains("攻击　+3666"):
					_失败.append("忍具兑换的成品提示框该有 baseAttr 那几条（攻击　+3666），实际「%s」"
						% 明细.replace("\n", "\\n").substr(0, 100))
				if not 明细.contains("耐久度　永不磨损"):
					_失败.append("忍具兑换的成品提示框该有耐久行")
		装备框.visible = false
	var 碎片格 := 页.get_node_or_null("子面板/碎片格1/碎片格1_格") as Control
	if 碎片格 == null:
		_失败.append("%s 找不到碎片格1_格" % 页名)
	elif 碎片格.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_失败.append("%s 碎片格1 的 mouse_filter 是 IGNORE ⇒ 收不到悬停" % 页名)
	else:
		碎片格.emit_signal("mouse_entered")
		await process_frame
		if not 物品框.visible:
			_失败.append("%s 悬停碎片格该弹出「物品提示框」" % 页名)
		else:
			var 标2 := 物品框.get_node("标题") as Label
			if not 标2.text.contains("碎片"):
				_失败.append("%s 碎片提示框标题该是碎片名，实际「%s」" % [页名, 标2.text])
		物品框.visible = false


func _次数(假, 方法: String) -> int:
	return int(假.get("忍具次数" if 方法 == "request_renju_combine" else "十拳剑次数"))


## 六枚碎片格：数量 / 名 / 图标 / 灰化（判据全部取实际值）。
func _验碎片格(页: Control, 扇: Dictionary, 期望: Array) -> void:
	var 页名 := String(扇["页名"])
	var 名文案: Array = 扇["名文案"]
	for i in 期望.size():
		var 格 := 页.get_node_or_null("子面板/碎片格%d/碎片格%d_格" % [i + 1, i + 1]) as Control
		if 格 == null:
			_失败.append("%s 缺「碎片格%d_格」节点" % [页名, i + 1])
			continue
		var 数 := 格.get_node_or_null("碎片格%d_格_数量" % (i + 1)) as Label
		var 名 := 格.get_node_or_null("碎片格%d_名" % (i + 1)) as Label
		var 图 := 格.get_node_or_null("碎片格%d_格_图标" % (i + 1)) as TextureRect
		if 数 == null or 数.text != String(期望[i]):
			_失败.append("%s 碎片格%d 的数量应是背包真值 %s，实际「%s」（原版 `validateItem`）"
				% [页名, i + 1, String(期望[i]), 数.text if 数 != null else "无"])
		if 名 == null or 名.text != String(名文案[i]):
			_失败.append("%s 碎片格%d 的名应是「%s」，实际「%s」"
				% [页名, i + 1, String(名文案[i]), 名.text if 名 != null else "无"])
		if 图 == null or 图.texture == null:
			_失败.append("%s 碎片格%d 的图标没取到（六种碎片在 `数据/物品.json` 里都有）" % [页名, i + 1])
		var 该灰 := String(期望[i]) == "0"
		if (格.material != null) != 该灰:
			_失败.append("%s 碎片格%d 的格皮灰化不对：数量 %s ⇒ 应%s灰"
				% [页名, i + 1, String(期望[i]), "" if 该灰 else "不"])
		if 图 != null and (图.material != null) != 该灰:
			_失败.append("%s 碎片格%d 的图标灰化不对（原版 `applyGrayFilter` 挂的是格皮+图标两件）" % [页名, i + 1])
		if 数 != null and 数.material != null:
			_失败.append("%s 碎片格%d 的**数量文本**不该灰（原版只灰格皮+图标）" % [页名, i + 1])


## 「碎片不全」的提示：`_show_hint` 写进 `_status.text`（§3.107 之后那口是**显形**的），
## 同时也会走 `_通知`。两处任一命中即算 —— 但**必须命中一处**（空壳钮不算）。
func _有集齐提示(窗, 通知: Array) -> bool:
	var 状态 := 窗.get("_status") as Label
	if 状态 != null and 状态.text.contains("集齐"):
		return true
	for 文 in 通知:
		if String(文).contains("集齐"):
			return true
	return false


func _设件数(会话, id: String, 数量: int) -> void:
	var 包: Array = 会话.get("inventory")
	for 物品 in 包:
		if String((物品 as Dictionary).get("id", "")) == id:
			(物品 as Dictionary)["quantity"] = 数量
			return
	包.append({"id": id, "quantity": 数量})


## ⚠️ `inventory` 是**类型化数组**，整份赋值会被 Godot 拒（"Invalid assignment … Array"）⇒ 原地还原。
func _还原背包(会话, 备份: Array) -> void:
	var 包: Array = 会话.get("inventory")
	包.clear()
	for 条 in 备份:
		包.append(条)


func _取页(窗, 根名: String) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	return 内容.get_node_or_null(根名) as Control


func _停(原因: String) -> void:
	push_error("兑换窗族回归测试：中断 - %s" % 原因)
	quit(1)


func _收尾() -> void:
	if _失败.is_empty():
		print("兑换窗族回归测试：通过（忍具/十拳剑 两扇：碎片数量/灰化/前置拦截/真请求 + 悬停详情框 + 关窗）")
		quit(0)
		return
	for 项 in _失败:
		push_error("兑换窗族回归测试：失败 - %s" % 项)
	quit(1)
