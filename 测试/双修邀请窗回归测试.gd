extends SceneTree
## 双修邀请窗（原版 `YaoqingShuangxiuWindow`）离线门。逐件参照值手抄自
## `真值/窗口/双修邀请窗.md`（AS3 行号都在那），**不从被测场景反查**。
##
## 覆盖：① 逐件矩形（内容局部 = AS3 − 29）② 四行文案的拼法（`昵称：`自带冒号、
## 等级/家族/职业要代码补）③ 说明三段颜色 ④ 头像按 face 取到图 ⑤ 三颗钮各发哪一发
## ⑥ 查不到邀请者 ⇒ 整页不建 ⑦ 回帧消费者：`1288:2` 开窗、`1288:1`/`1288:4` 关窗
## ⑧ 尺寸表与居中弹登记齐了。
##
## 跑法：`"godot" --path . --headless --script res://测试/双修邀请窗回归测试.gd`

const 场景路径 := "res://场景/界面/窗口/双修/双修邀请窗.tscn"
const 管理场景 := "res://场景/界面/窗口管理.tscn"

## §① 内容局部坐标（AS3 值见真值表；`整框: true` ⇒ 页内件按 AS3−29 摆）
const 逐件 := {
	"内容底": [6.0, 10.0, 268.0, 151.0],		# background2 MYellow (6,39) 268×151
	"子面板": [11.0, 63.0, 258.0, 90.0],		# background3 MPane (11,92) 258×90
	"头像格": [13.0, 16.0, 42.0, 42.0],		# headIocn MGrid (13,45)，PortraitHead 42×42
	"昵称": [60.0, 13.0, 118.0, 18.0],		# nameTf (60,42)
	"等级": [181.0, 13.0, 84.0, 18.0],		# levelTf (181,42)
	"家族": [60.0, 41.0, 120.0, 18.0],		# bangpaiTf (60,70)
	"职业": [181.0, 41.0, 84.0, 18.0],		# menpaiTf (181,70)
	"说明": [18.0, 72.0, 249.0, 69.0],		# Box (18,101) 249×69 里的 sayTf 宽 249
	"查看资料钮": [25.0, 167.0, 61.0, 22.0],		# :131-135 x=25 宽 btn_width_four=61
	"同意钮": [121.0, 167.0, 37.0, 22.0],		# :139 x=(280−37)>>1=121
	"取消钮": [218.0, 167.0, 37.0, 22.0],		# :144 x=280−37−25=218
}
const 三颗钮文字 := {"查看资料钮": "查看资料", "同意钮": "同意", "取消钮": "取消"}

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 假: Node


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)


## ⚠ `功能窗口` 的根是 **CanvasLayer，不是 Control** —— 早先用 `as Control` 取它
## 会得到 null，于是"窗没开出来"这条红其实是**门自己取错了**（探针实测窗与 overlay 都是好的）。
func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


func _喂(动作: int, 号: int, 伴: int = 0) -> void:
	var 状 := {"action": 动作}
	if 动作 == 2:
		状["pending_inviter_id"] = 号
	elif 动作 == 1:
		状["state"] = 2
		状["character_id"] = 号
		状["partner_id"] = 伴
	else:
		状["denied_by"] = 号
	假.set("authoritative_heal", 状)
	假.emit_signal("heal_state_received", 状)


func _矩形(件: Control) -> Array:
	return [件.offset_left, 件.offset_top,
			件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


## ⚠ 这份字典的键名 = **服务端 162 出生帧解出来的那一份**（`后端连接._handle_spawn_player_text`：
## `name`/`level`/`face`/`job`/`family_name`），不是控制器里想当然的那几个。
## 10-17 第一版这里写的是 `guildName`（跟被测代码里自造的键一模一样）⇒ 门与代码一起错、
## 真机上那行「家族：」永远空白。键名下面还有一条源码核对钉着。
func _邀请者态() -> Dictionary:
	return {"character_id": 1002, "name": "油女澪", "level": 23, "face": 10000204,
			"job": 2, "family_name": "木叶"}


## 页挂在宿主的 `_content` 底下（`双修邀请窗.渲染` 里那句 `宿主._content.add_child(页)`）。
## ⚠ 别猜壳的节点路径 —— 拿宿主自己的变量取，路径改了门跟着动才是真判。
func _找页(窗: Node) -> Control:
	var 内容 := 窗.get("_content") as Control
	for 子 in 内容.get_children():
		if String(子.name) == "原版双修邀请内容":
			return 子 as Control
	return null


func _跑() -> void:
	print("双修邀请窗离线门开始")
	await process_frame
	假 = root.get_node("BackendConnection")
	假.set("in_game", false)
	假.set("map_players", {})
	假.set("authoritative_heal", {})
	假.map_players[1002] = _邀请者态()
	await process_frame
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame

	# ① 回帧消费者：`1288:2` ⇒ 开窗。⚠ 走的是**信号**，不是我自己调 打开()。
	_喂(2, 1002)
	for i in 4:
		await process_frame
	var 窗: Node = 管理._窗口们.get("双修邀请")
	_判(窗 != null and _开着(窗), "收到 1288:2 那帧 ⇒ 窗自己开出来了（消费者接对了）")
	if 窗 == null:
		跑完了 = true
		print("双修邀请窗离线门：通过 %d，红 %d" % [通过, 失败])
		return
	var 页 := _找页(窗)
	_判(页 != null, "页本体建出来了（查得到邀请者才会建）")
	if 页 == null:
		跑完了 = true
		print("双修邀请窗离线门：通过 %d，红 %d" % [通过, 失败])
		return

	# ② 逐件矩形
	_判(absf(页.size.x - 280.0) < 0.51 and absf(页.size.y - 195.0) < 0.51,
			"页 = 280×195（内容区 = 整窗 224 − 标题 29），实得 %.0f×%.0f" % [页.size.x, 页.size.y])
	for 名 in 逐件:
		var 子 := 页.get_node_or_null(名) as Control
		_判(子 != null, "逐件：%s 在" % 名)
		if 子 == null:
			continue
		_判(_近(_矩形(子), 逐件[名]), "%s 矩形 = (%s)，实得 (%s)" % [名, 逐件[名], _矩形(子)])

	# ③ 四行文案（`setData:206-209` 的拼法：昵称自带冒号，其余代码补「：」）
	_判((页.get_node("昵称") as Label).text == "昵称：油女澪",
			"第一行 = 「昵称：油女澪」，实得「%s」" % (页.get_node("昵称") as Label).text)
	_判((页.get_node("等级") as Label).text == "等级：23",
			"第二行 = 「等级：23」，实得「%s」" % (页.get_node("等级") as Label).text)
	_判((页.get_node("家族") as Label).text == "家族：木叶",
			"第三行 = 「家族：木叶」，实得「%s」" % (页.get_node("家族") as Label).text)
	_判((页.get_node("职业") as Label).text == "职业：" + 职业表.取(2),
			"第四行 = 「职业：」+ 职号 2 的名字，实得「%s」" % (页.get_node("职业") as Label).text)

	# ④ 说明三段颜色（原版 htmlText ⇒ 这里必须是 BBCode，且不许漏掉任一段）
	var 说 := (页.get_node("说明") as RichTextLabel).text
	_判(说.contains("[color=#ff9100]该玩家希望与你开始打坐双修[/color]"),
			"第一段橙：#ff9100 那句在（实得「%s」）" % 说.left(46))
	_判(说.contains("[color=#00ff00]") and 说.contains("加快20%"),
			"第二段绿：#00ff00 那句在")
	_判(说.contains("[color=#1e90ff]请问你同意开始双修吗？"), "第三段蓝：#1e90ff 那句在")
	_判(not 说.contains("<font") and not 说.contains("<br"),
			"原版的 `<font>`/`<br/>` 全部转掉了（留着会当字面量印出来）")

	# ⑤ 头像按 face 取
	_判((页.get_node("头像格/头像") as TextureRect).texture != null,
			"头像按 face 取到了图（PortraitHead TYPE_CHAR, skin=face）")

	# ⑥ 三颗钮：文字 + 宽档皮 + 手型 + 各发哪一发
	for 名 in 三颗钮文字:
		var 钮 := 页.get_node(名) as Button
		_判(钮.text == String(三颗钮文字[名]), "%s 的文字 = 「%s」，实得「%s」" % [
				名, 三颗钮文字[名], 钮.text])
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 是手型" % 名)
		var 宽 := 钮.offset_right - 钮.offset_left
		_判(宽 > 60.0 if 名 == "查看资料钮" else 宽 < 40.0,
				"%s 用的是 %s 那一档宽（实得 %.0f）" % [名, "61" if 名 == "查看资料钮" else "37", 宽])
	(页.get_node("同意钮") as Button).emit_signal("pressed")
	for i in 3:
		await process_frame
	_判(not _开着(窗), "点「同意」把窗关掉（原版 `:58-61` 发完事件就 removeChild）")
	print('未判：无头里 TCP 没连，「同意」这一发只判到关窗；86:4 的包体归在线门判')

	# ⑦ 关掉之后再来一帧邀请 ⇒ 重新按**新那号**建页（缓存必须被清掉，不能还挂旧号）
	## ⚠ 没家族时服务端发的**不是空串，是字面 `-`**（`_current_family_name:33274-33276`）⇒
	## 这里喂 `-`，判的还是「家族：」后面空着。喂空串测不出"有没有把 `-` 当名字印上去"。
	假.map_players[1003] = {"character_id": 1003, "name": "夕日光", "level": 7, "face": 10000205,
			"job": 1, "family_name": "-"}
	_喂(2, 1003)
	for i in 4:
		await process_frame
	var 页2 := _找页(窗)
	_判(_开着(窗) and 页2 != null and (页2.get_node("昵称") as Label).text == "昵称：夕日光",
			"第二封邀请换人：窗重开、第一行跟着换成夕日光（实得「%s」）"
			% ((页2.get_node("昵称") as Label).text if 页2 != null else "没建页"))
	_判(页2 != null and (页2.get_node("家族") as Label).text == "家族：",
			"没家族的人就印「家族：」后面空着，不拿别人名字凑（实得「%s」）"
			% (页2.get_node("家族") as Label).text)

	if 页2 == null:
		_判(false, "第二封邀请没建页 ⇒ 后面那几步无从点起")
		跑完了 = true
		print("双修邀请窗离线门：通过 %d，红 %d" % [通过, 失败])
		return
	(页2.get_node("取消钮") as Button).emit_signal("pressed")
	for i in 3:
		await process_frame
	_判(not _开着(窗), "点「取消」把窗关掉（与右上角那颗叉同一发：`onClickCancelBtn` 只是转调）")
	_喂(2, 1002)
	for i in 3:
		await process_frame
	var 页3 := _找页(窗)
	_判(页3 != null, "第三封邀请建了页（才谈得上点「查看资料」）")
	if 页3 != null:
		(页3.get_node("查看资料钮") as Button).emit_signal("pressed")
	_判(页3 != null, "点「查看资料」没把窗弄坏（94:4 的包体同样归在线门）")

	# ⑧ 双方真的开始双修 / 被拒 ⇒ 窗该消失（原版 HealHandler 摘掉邀请框）
	_喂(1, 1002, 1003)
	for i in 3:
		await process_frame
	_判(not _开着(窗), "收到 1288:1（开始双修）⇒ 邀请窗自己关掉")
	_喂(2, 1002)
	for i in 3:
		await process_frame
	_喂(4, 1003)
	for i in 3:
		await process_frame
	_判(not _开着(窗), "收到 1288:4（被拒/不可达）⇒ 邀请窗自己关掉")

	# ⑨ 查不到邀请者 ⇒ 整页不建（宁可什么都不出现，也不弹一扇四行全空的窗）
	假.set("map_players", {})
	_喂(2, 1002)
	for i in 3:
		await process_frame
	_判(_找页(窗) == null, "同屏表里查不到那个人 ⇒ 不建页（空窗比不弹更糟）")
	假.map_players[1002] = _邀请者态()

	# ⑩ 登记面：尺寸表 + 居中弹（少了任何一条，开窗要么尺寸错、要么不居中跟着别的窗漂）
	var 表 := JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/窗口尺寸.json")) as Dictionary
	var 规格: Dictionary = 表.get("双修邀请", {}) as Dictionary
	_判(int(规格.get("宽", 0)) == 280 and int(规格.get("高", 0)) == 224
			and bool(规格.get("整框", false)) and String(规格.get("标题", "")) == "双修打坐",
			"尺寸表：280×224、整框 true、标题「双修打坐」（实得 %s）" % str(规格))
	_判(管理.居中弹.has("双修邀请"), "这扇窗登记进了「居中弹」（原版走 PopUpMananger 每次回正中）")
	_判(ResourceLoader.exists(场景路径), "场景在盘上：%s" % 场景路径)

	# ⑪ 键名核对：控制器读的那个键，必须是**解析器写出来的那个键**（参照值取解析器源码）
	## 10-17 这条坑第三次踩（前两次：对戒的 `item_id/position/count`、他人窗的装备段）。
	## 上一版这里喂 `guildName`、代码也轮着找 `guildName/guild/familyName/bangName` 四个**自造名**，
	## 而 162 帧解出来的是 `family_name` ⇒ 门与代码一起错，真机上「家族：」永远空白。
	## 键名这种"两边约定"的东西只能拿对面那份源码当参照，不能拿被测代码自己的键。
	var 服源 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	var 起 := 服源.find("func _handle_spawn_player_text")
	var 止 := 服源.find("\nfunc ", 起 + 1)
	var 解体 := 服源.substr(起, 止 - 起) if 起 >= 0 and 止 > 起 else ""
	_判(解体 != "", "切到了 `_handle_spawn_player_text` 的函数体（切不到 ⇒ 下面三条全是假的）")
	_判(解体.contains("\"family_name\": String(fields[23])"),
			"解析器把 162 的第 24 段写成键 `family_name`（参照值 = 解析器自己，不是被测代码）")
	_判(解体.contains("\"family_id\": int(fields[22])"), "同一段里族号也落了（`family_id` = fields[22]）")
	var 控源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/双修/双修邀请窗.gd")
	_判(控源.contains("态.get(\"family_name\", \"\")"), "控制器读的就是 `family_name` 这一个键（与上面同名 ⇒ 两边是同一份约定）")
	for 自造 in ["guildName", "familyName", "bangName"]:
		## 判的是**读键那一处**（`get("…")`），不是注释里提没提这个名字 ——
		## 上面那段注释正是要写下自造名才说得清"以前错在哪"，一刀切判文本会把自己的说明判成红。
		_判(not 控源.contains("get(\"%s\"" % 自造), "控制器不再读自造键 `%s`（读到就是又被改回去了）" % 自造)
	_判(控源.contains("if 值 == \"-\""), "服务端那份「没家族」的字面 `-` 被当空处理（不是原样印到屏上）")

	# ⑫ 下行 `1288:1` 那一支的「这帧讲的是谁」守卫（10-17 在线门 §⑨ 抓到红之后补的离线钉）
	## ⚠ 这一节**必须喂原文帧**走 `_handle_bridge_text`，不能用上面的 `_喂()`：`_喂` 是直接 emit
	## 假字典，等于跳过解析器自己造键 —— 那样段序写反、守卫删掉都照样绿（10-16 深夜踩过的第十六种）。
	## 参照值 = 原版 `HealHandler.as:250` 的 `if(param3 == DataCenter.stats.id)` 与
	## 服务端 `fake_flash_server.py:34884,34889`（同意时给同一条连接连发两帧、两个号对调）。
## ⚠ 串首那个号是**下行** 1288（`ReceiveOpCodes.HEAL_STATE`），不是上行的 86（`SendOpCodes.HEAL_OVER_TIME`）——
## 拿上行号喂进 `_handle_bridge_text` 会一路都不 dispatch，看着像守卫坏了（本轮就是这么红的 6 条）。。
	假.set("character_id", 1)
	假.set("authoritative_heal", {})
	var 收帧: Array = []
	假.connect("heal_state_received", func(状: Dictionary) -> void: 收帧.append(状))
	假.call("_handle_bridge_text", "1288:1:1:1:0")
	_判(int((假.get("authoritative_heal") as Dictionary).get("state", 0)) == 1,
			"阳性对照：讲我这具的 `1288:1:1:<我>:0`（单修开始）照样生效 —— 守卫不能把正常帧也吃掉")
	假.call("_handle_bridge_text", "1288:1:0:9:0")
	_判(int((假.get("authoritative_heal") as Dictionary).get("state", 0)) == 1,
			"`1288:1:0:<别人的号>:0` 不改我的态（那一支写的是**别的那具身体**，不是我这具）")
	_判(收帧.size() == 1, "别人那帧连信号都没发（实发 %d 条，期 1 条：只该有我这具那帧）" % 收帧.size())
	## ⚠ 但**不能整条丢掉**：原版 `HealHandler.as:315-331` 的 else 支把这一帧写到那一具身体上
	## （`healPartnerId`），服务端同意那一支连发两条对调帧就是为了让一台客户端同时知道两具各自的伙伴
	## ⇒ 少这一半，`tickHealDouble` 那句 `_loc3_.healPartnerId != 0` 永远假 ⇒ 我屏幕上对面那具不跟着浮。
	## 本工程没有远程 Character 对象可挂，落点是 `后端连接.远程双修伙伴`（消费者 `地图实体._双修对坐`）。
	假.call("_handle_bridge_text", "1288:1:2:9:1")
	_判(int((假.get("远程双修伙伴") as Dictionary).get(9, 0)) == 1,
			"态 2 ⇒ 9 号那具的伙伴记成我（1）—— 双修配对的另一半（实得 %s）" % str((假.get("远程双修伙伴") as Dictionary)))
	_判(int((假.get("authoritative_heal") as Dictionary).get("state", 0)) == 1,
			"写别人那具的同时**没碰**我这具的态（还是单修 1，实得 %s）" % str((假.get("authoritative_heal") as Dictionary).get("state", 0)))
	## 停坐那一支也必须把这一格清掉。⚠ 顺序要紧：**先设后清**才测得出 erase ——
	## 拿"没设过之后再清一次"判 `== 0` 就是 0 比 0 空判（记忆里第十五种）。
	假.call("_handle_bridge_text", "1288:1:0:9:0")
	_判(not (假.get("远程双修伙伴") as Dictionary).has(9),
			"态 0 ⇒ 9 号那具的伙伴被清掉了（先设后清才算数，实得 %s）" % str((假.get("远程双修伙伴") as Dictionary)))
	var 帧数前 := 收帧.size()
	## 服务端同意那一支**真的**发两帧：先是「我:对面」，紧接一帧把两个号对调。
	假.call("_handle_bridge_text", "1288:1:2:1:2")
	假.call("_handle_bridge_text", "1288:1:2:2:1")
	var 双状: Dictionary = 假.get("authoritative_heal") as Dictionary
	_判(int(双状.get("state", 0)) == 2, "对调那帧没把我的态冲掉（实得 %s）" % str(双状))
	_判(int(双状.get("partner_id", 0)) == 2,
			"`partner_id` 是**对面**不是我自己（少了守卫时后到的对调帧会把它写成 1 ⇒ 浮动与窗都认错人）")
	_判(收帧.size() == 帧数前 + 1, "两条里只有一条发信号（实发 %d 条，期 %d 条）" % [收帧.size(), 帧数前 + 1])
	假.call("_handle_bridge_text", "1288:1:0:1:0")
	_判(int((假.get("authoritative_heal") as Dictionary).get("state", 0)) == 0
			and int((假.get("authoritative_heal") as Dictionary).get("partner_id", 0)) == 0,
			"我这具的停坐帧照样落地（态与对面都归 0）")
	跑完了 = true
	print("双修邀请窗离线门：通过 %d，红 %d" % [通过, 失败])


const 职业表 := preload("res://脚本/单例/职业.gd")
