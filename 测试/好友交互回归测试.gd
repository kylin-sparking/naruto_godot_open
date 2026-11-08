extends SceneTree

## 好友三扇子窗交互门（2026-11-08，A2）。
##
## 钉的是**控制器那一层**（几何已由 `好友子窗回归测试.gd` 逐件量过）：
##   ① 选人窗：搜索出帧 `1282:1:1:<名>`（空名不带尾冒号）、发完 destroy（清行/清页码/藏选中条/禁用两钮），
##      回包只认 type 1、每页 5 行、页码 N/M、默认选中首行、翻页重选首行、
##      查看资料 → 宿主 `_查看角色资料`、多功能 → 宿主 `好友:交友`（空名只提示）；
##      行内三列坐标/颜色/等级描边也按 `SelectPlayerWindowCell.as` 的字面量钉住。
##   ② 打探窗：`127:10:<号>`、三档回包文案（0 线/名/图/坐标、2 离线、1 没密卷）、
##      乾坤密卷数量/整格灰度、购买 → `1086:<物品号>`、没有对象时不发只提示。
##   ③ 私聊窗：标题「与%1对话中」、发送 `127:8:<号>:<过滤后正文>`、
##      `ChatUtil.filterStr` 的剥标签/去全角空格/表情只留前 5、ESC 关窗的历史清理口径、
##      消息行宽 216 与收发标题色、表情面板 188×188/6 列/36 格/5 间距/插满 5 个不再插。
##   ④ 好友主窗的羁绊闸读的是 `couple`（不是没人写过的 `spouse`）。
##   ⑤ `后端连接` 四条包装帧本身（7/9/8/10）与 0 号/空正文闸。
##
## 口径：假宿主自带 `测试/测试后端连接.gd`（继承真后端、只记不发）；门直接读
## `sent_requests`。不碰 `user://`、不连真服。有「跑完了」哨兵 + `_process` 看门狗。
##
## 运行：`Godot --headless --path . --script res://测试/好友交互回归测试.gd`

const 假宿主脚本 := preload("res://测试/假好友宿主.gd")
const 文案 := preload("res://脚本/界面/窗口/好友/好友文案.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")
const 职业 := preload("res://脚本/单例/职业.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 选人场景 := "res://场景/界面/窗口/好友/好友选人窗.tscn"
const 打探场景 := "res://场景/界面/窗口/好友/好友打探窗.tscn"
const 私聊场景 := "res://场景/界面/窗口/好友/好友私聊窗.tscn"
const 主场景 := "res://场景/界面/窗口/好友/好友窗口.tscn"

## AS3 字面量（`SelectPlayerWindowCell.as:104-116`、`FriendChat.as:33-40`）：
const 名色 := Color(0.11764705882352941, 0.56470588235294118, 1.0)	# #1E90FF
const 值色 := Color(0.0, 1.0, 1.0)					# #00FFFF
const 自己色 := Color(0.0, 0.6470588235294118, 0.25882352941176473)	# #00A542
const 他色 := Color(0.0, 0.4, 1.0)					# #0066FF
const 密卷号 := 16000005
const 码搜索 := 1282
const 码好友 := 127
const 码商城 := 1086

var _通过 := 0
var _失败: Array[String] = []
var _宿
var _跑完了 := false
var _帧数 := 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_跑")


## 看门狗：脚本报错会让 `_跑` 停在某个 await 上、quit 永远不来（门挂死 = 假绿）。
func _process(_d: float) -> bool:
	_帧数 += 1
	if _帧数 > 600 and not _跑完了:
		_失败.append("门 600 帧内没跑完（中途报错停在 await 上？）")
		_收尾()
	return _帧数 > 600


func _判(对: bool, 明: String) -> void:
	if 对:
		_通过 += 1
	else:
		_失败.append(明)


func _帧() -> Array[String]:
	var 出: Array[String] = []
	for 条 in _宿.get("_backend").sent_requests:
		出.append("%d:%s" % [int((条 as Dictionary).get("opcode", 0)),
			str((条 as Dictionary).get("content", ""))])
	return 出


func _清帧() -> void:
	_宿.get("_backend").sent_requests.clear()


func _按(窗: Control, 钮名: String) -> void:
	var 钮 := 窗.get_node_or_null(钮名) as TextureButton
	if 钮 == null:
		_判(false, "%s 缺节点「%s」⇒ 这一腿没量到" % [窗.name, 钮名])
		return
	钮.pressed.emit()


func _跑() -> void:
	_宿 = 假宿主脚本.new()
	_宿.name = "假好友宿主"
	root.add_child(_宿)
	await process_frame
	选人窗()
	打探窗()
	await 私聊窗()
	羁绊闸()
	_包装帧()
	_跑完了 = true
	_收尾()


# ─────────────────────────── ① 选人窗 ───────────────────────────

func 选人窗() -> void:
	var 窗 := (load(选人场景) as PackedScene).instantiate() as Control
	root.add_child(窗)
	窗.call("装配", _宿)
	窗.call("设添加好友")

	var 多功能字 := 窗.get_node_or_null("多功能钮/Label") as Label
	_判(多功能字 != null and 多功能字.text == 文案.取("FRIEND_ADD"),
		"① 加好友档多功能钮 = FRIEND_ADD，实得 %s" % [多功能字.text if 多功能字 != null else "缺节点"])

	# 初值两钮 disabled（`SPW:215,218`），且没有结果就没有选中项
	var 资料钮 := 窗.get_node_or_null("查看资料钮") as TextureButton
	var 多功钮 := 窗.get_node_or_null("多功能钮") as TextureButton
	_判(资料钮 != null and 资料钮.disabled, "① 初值「查看资料」应 disabled")
	_判(多功钮 != null and 多功钮.disabled, "① 初值「多功能」应 disabled")

	# 搜索出帧；发完 destroy：清行、清页码、藏选中条、两钮禁用
	var 列 := 窗.get_node_or_null("行容器") as Control
	var 页码 := 窗.get_node_or_null("页码") as Label
	var 选中条 := 窗.get_node_or_null("选中条") as Control
	var 输入 := 窗.get_node_or_null("名输入") as LineEdit
	if 列 == null or 页码 == null or 选中条 == null or 输入 == null:
		_判(false, "① 选人窗缺 行容器/页码/选中条/名输入，整段没量到")
		窗.free()
		return
	输入.text = "木叶"
	_清帧()
	_按(窗, "搜索钮")
	var 帧 := _帧()
	_判(帧 == ["%d:1:1:木叶" % 码搜索],
		"① 搜索 ⇒ 1282:1:1:<名>，实得 %s" % [str(帧)])
	_判(列.get_child_count() == 0 and 页码.text == "" and not 选中条.visible,
		"① 搜索后必须 destroy（行 0/页码空/选中条藏），实得 行=%d 页码=%s 选中=%s"
		% [列.get_child_count(), 页码.text, str(选中条.visible)])
	_判(资料钮 != null and 资料钮.disabled and 多功钮 != null and 多功钮.disabled,
		"① 搜索后两钮要禁用（等回包）")

	输入.text = ""
	_清帧()
	_按(窗, "搜索钮")
	帧 = _帧()
	_判(帧 == ["%d:1:1" % 码搜索],
		"① 空名搜索 ⇒ 1282:1:1（不带尾冒号），实得 %s" % [str(帧)])

	# type 1 回包：7 条 ⇒ 第 1 页 5 行、页码 1/2、默认选中首行、两钮启用
	_宿.get("_backend").authoritative_char_search_类型 = 1
	var 结果: Array = []
	for i in 7:
		结果.append({"character_id": 700 + i, "name": "玩家%d" % i, "level": 10 + i,
			"job": 100, "online": true})
	_宿.get("_backend").char_search_received.emit(结果)
	_判(列.get_child_count() == 5, "① 每页 5 行（SPW:47），实得 %d" % 列.get_child_count())
	_判(页码.text == "1/2", "① 页码 N/M，实得 %s" % 页码.text)
	_判(选中条.visible and 选中条.position.is_equal_approx(列.position),
		"① 默认选中首行：选中条应在行容器原点，实得 %s vs %s" % [str(选中条.position), str(列.position)])
	_判(资料钮 != null and not 资料钮.disabled and 多功钮 != null and not 多功钮.disabled,
		"① 有选中行后两钮要启用")

	# 行内三列（坐标/宽度/颜色/等级描边）按 `SPWC` 钉住
	var 行0 := 列.get_child(0) as Control
	var 名节 := 行0.get_node_or_null("名") as Label
	var 级节 := 行0.get_node_or_null("等级") as Label
	var 职节 := 行0.get_node_or_null("职业") as Label
	_判(名节 != null and 名节.position == Vector2(2, 2) and 名节.size == Vector2(137, 18)
		and 名节.get_theme_color("font_color") == 名色,
		"① 名列 2,2 137×18 #1E90FF，实得 %s %s %s"
		% [str(名节.position) if 名节 != null else "缺", str(名节.size) if 名节 != null else "缺",
			str(名节.get_theme_color("font_color")) if 名节 != null else "缺"])
	_判(级节 != null and 级节.position == Vector2(144, 2) and 级节.size == Vector2(44, 18)
		and 级节.get_theme_color("font_color") == 值色
		and 级节.get_theme_constant("outline_size") == 2,
		"① 等级列 144,2 44×18 #00FFFF + 发光(2px)，实得 %s"
		% [str(级节.position) if 级节 != null else "缺"])
	_判(职节 != null and 职节.position == Vector2(188, 2) and 职节.size == Vector2(58, 18)
		and 职节.text == 职业.取(100),
		"① 职业列 188,2 58×18 且职号转名（%s），实得 %s"
		% [职业.取(100), 职节.text if 职节 != null else "缺"])

	# 再搜一次：必须先 destroy **上一次**的结果（清行/清页码/藏选中条/两钮禁用），窗不关
	输入.text = "再搜"
	_清帧()
	_按(窗, "搜索钮")
	_判(_帧() == ["%d:1:1:再搜" % 码搜索],
		"① 再搜 ⇒ 1282:1:1:<名>，实得 %s" % [str(_帧())])
	_判(列.get_child_count() == 0 and 页码.text == "" and not 选中条.visible
		and 资料钮 != null and 资料钮.disabled and 多功钮 != null and 多功钮.disabled,
		"① 再搜必须 destroy 上一次结果（行 0/页码空/选中藏/两钮禁），实得 行=%d 页码=%s 选中=%s"
		% [列.get_child_count(), 页码.text, str(选中条.visible)])
	_宿.get("_backend").char_search_received.emit(结果)
	_判(列.get_child_count() == 5, "① 重新回包后照常铺页（给翻页腿铺态），实得 %d" % 列.get_child_count())

	# 翻页：第 2 页 2 行、页码 2/2、默认选中本页首行（选中条下移 23）
	_按(窗, "下一页钮")
	_判(页码.text == "2/2" and 列.get_child_count() == 2,
		"① 下一页 ⇒ 2/2 且 2 行，实得 %s / %d" % [页码.text, 列.get_child_count()])
	# 行容器整页重建（局部 y 从 0 起），所以选中条回到容器原点；本页首行应是玩家5
	var 二页首名 := 列.get_child(0).get_node_or_null("名") as Label
	_判(选中条.position.is_equal_approx(列.position)
		and 二页首名 != null and 二页首名.text == "玩家5",
		"① 翻页后默认选中本页首行（玩家5、选中条回容器原点），实得 %s / %s"
		% [str(选中条.position), 二页首名.text if 二页首名 != null else "缺"])

	# type 不是 1 的回包不归这扇窗：数据原样不动
	_宿.get("_backend").authoritative_char_search_类型 = 0
	_宿.get("_backend").char_search_received.emit(结果)
	_判(页码.text == "2/2" and 列.get_child_count() == 2,
		"① type≠1 的回包不该重铺，实得 %s / %d" % [页码.text, 列.get_child_count()])

	# 查看资料 → 宿主出口（当前选中 = 第 2 页首行 = 玩家5/编号 705）
	var 资料前: int = (_宿.get("查看资料") as Array).size()
	_按(窗, "查看资料钮")
	var 资料: Array = _宿.get("查看资料")
	_判(资料.size() == 资料前 + 1 and int(资料[资料.size() - 1]) == 705,
		"① 查看资料 ⇒ 宿主 _查看角色资料(选中行编号)，实得 %s" % [str(资料)])

	# 多功能（加好友档）→ 宿主 `好友:交友`，并带着整行
	var 记前: int = (_宿.get("菜单动作") as Array).size()
	_按(窗, "多功能钮")
	var 记: Array = _宿.get("菜单动作")
	_判(记.size() == 记前 + 1
		and str((记[记.size() - 1] as Dictionary).get("character_id", 0)) == "705",
		"① 多功能（加好友）⇒ 宿主「好友:交友」且带整行，实得 %s"
		% [str(记[记.size() - 1]) if 记.size() > 记前 else "没交回"])

	# 空名字的行：只提示 FRIEND_TIP_INPUT_CHAR_NAME，不发动作
	_宿.get("_backend").authoritative_char_search_类型 = 1
	var 空名: Array = [{"character_id": 999, "name": "", "level": 1, "job": 100}]
	_宿.get("_backend").char_search_received.emit(空名)
	var 通知前: int = (_宿.get("通知") as Array).size()
	记前 = 记.size()
	_按(窗, "多功能钮")
	var 通知: Array = _宿.get("通知")
	_判(记.size() == 记前, "① 空名字不该交回「好友:交友」，实得新增 %d" % (记.size() - 记前))
	_判(通知.size() == 通知前 + 1 and str(通知[通知.size() - 1]) == 文案.取("FRIEND_TIP_INPUT_CHAR_NAME"),
		"① 空名字要提示 FRIEND_TIP_INPUT_CHAR_NAME，实得 %s" % [str(通知)])

	# 空结果：只禁用两钮，行/页码清空
	_宿.get("_backend").char_search_received.emit([])
	_判(列.get_child_count() == 0 and 页码.text == ""
		and 资料钮 != null and 资料钮.disabled and 多功钮 != null and 多功钮.disabled,
		"① 空结果 ⇒ 清行/页码、两钮禁用（SPW:353-368）")
	_判(选中条.get_index() == 窗.get_child_count() - 1,
		"① 选中条要排在最后（SPW:245 后 addChild，画在行上）")

	窗.free()


# ─────────────────────────── ② 打探窗 ───────────────────────────

func 打探窗() -> void:
	var 窗 := (load(打探场景) as PackedScene).instantiate() as Control
	root.add_child(窗)
	窗.call("装配", _宿)
	var 会: Node = _宿.get("_session")
	会.inventory = [{"id": 密卷号, "quantity": 2}]
	var 对象 := {"character_id": 301, "name": "仇八", "level": 40, "face": 7, "gender": 0}
	窗.call("设对象", 对象)

	var 信息 := 窗.get_node_or_null("信息串") as RichTextLabel
	var 红字 := 窗.get_node_or_null("红字") as RichTextLabel
	var 盒 := 窗.get_node_or_null("材料盒") as Control
	var 数量 := 盒.get_node_or_null("物品格/数量") as Label if 盒 != null else null
	var 图标 := 盒.get_node_or_null("物品格/图标") as TextureRect if 盒 != null else null
	var 买 := 盒.get_node_or_null("购买") as TextureButton if 盒 != null else null
	if 信息 == null or 红字 == null or 数量 == null or 图标 == null or 买 == null:
		_判(false, "② 打探窗缺 信息串/红字/材料盒零件，整段没量到")
		窗.free()
		return

	# 打开时先报名字（DATA_INFOSTR_3），红字位是两格空白
	_判(信息.text == 富文本.译文为BBCode(文案.取("DATA_INFOSTR_3").replace("%1", "仇八")),
		"② 打开先报名字（DATA_INFOSTR_3），实得 %s" % 信息.text)
	_判(红字.text == "  ", "② 初始红字位 = 两格空白，实得「%s」" % 红字.text)

	# 有 2 张密卷：角标 2、不套灰度
	_判(数量.text == "2" and 图标.material == null,
		"② 背包 2 张 ⇒ 角标 2 且无灰度，实得「%s」/ %s" % [数量.text, str(图标.material)])
	# 清空背包并通知 ⇒ 角标空、整格灰度（`ICLB:hasItem`）
	会.inventory = []
	会.inventory_changed.emit([])
	_判(数量.text == "" and 图标.material is ShaderMaterial,
		"② 0 张 ⇒ 角标空 + 整格灰度，实得「%s」/ %s" % [数量.text, str(图标.material)])

	# 购买 → 商城道具信息（`ICLB:44-52` → REQUEST_CASH_ITEM_INFO）
	_清帧()
	买.pressed.emit()
	_判(_帧() == ["%d:%d" % [码商城, 密卷号]],
		"② 购买 ⇒ 1086:<乾坤密卷号>，实得 %s" % [str(_帧())])

	# 打探 → 127:10:<号>
	_清帧()
	_按(窗, "打探钮")
	_判(_帧() == ["%d:10:301" % 码好友],
		"② 打探 ⇒ 127:10:<编号>，实得 %s" % [str(_帧())])

	# code 0：线/名/图/坐标（floor(x/100)、floor(y/100)），红字两格空白
	_宿.get("_backend").find_enemy_result_received.emit(
		{"errorCode": 0, "channel": 2, "map": 7, "x": 12450, "y": 4560})
	var 期0 := 文案.取("DATA_INFOSTR_1")
	期0 = 期0.replace("%1", "2").replace("%2", "仇八")
	期0 = 期0.replace("%3", GAME_DATA.map_name(7)).replace("%4", "124").replace("%5", "45")
	_判(信息.text == 富文本.译文为BBCode(期0) and 红字.text == "  ",
		"② code 0 ⇒ DATA_INFOSTR_1（线/名/图/floor 坐标），实得 %s / 「%s」" % [信息.text, 红字.text])

	# code 2：不在线
	_宿.get("_backend").find_enemy_result_received.emit({"errorCode": 2})
	_判(信息.text == 富文本.译文为BBCode(文案.取("DATA_INFOSTR_2").replace("%1", "仇八"))
		and 红字.text == 富文本.译文为BBCode(文案.取("DATAN_PROMPT_1")),
		"② code 2 ⇒ DATA_INFOSTR_2 + DATAN_PROMPT_1，实得 %s / 「%s」" % [信息.text, 红字.text])

	# code 1：背包没密卷（提示里带物品名）
	var 期1红 := 文案.取("DATAN_PROMPT_2").replace("%1", GAME_DATA.item_name(密卷号))
	_宿.get("_backend").find_enemy_result_received.emit({"errorCode": 1})
	_判(信息.text == 富文本.译文为BBCode(文案.取("DATA_INFOSTR_2").replace("%1", "仇八"))
		and 红字.text == 富文本.译文为BBCode(期1红),
		"② code 1 ⇒ DATA_INFOSTR_2 + DATAN_PROMPT_2（带密卷名），实得 %s / 「%s」" % [信息.text, 红字.text])

	# 其它码：两句都清空（`MPW:327-347` 只认 0/1/2）
	_宿.get("_backend").find_enemy_result_received.emit({"errorCode": -1})
	_判(信息.text == "" and 红字.text == "", "② 其它码 ⇒ 两句清空，实得「%s」/「%s」" % [信息.text, 红字.text])

	# 没有对象：不发包、落一句
	窗.call("设对象", {})
	_清帧()
	var 通知前: int = (_宿.get("通知") as Array).size()
	_按(窗, "打探钮")
	var 通知: Array = _宿.get("通知")
	_判(_帧().is_empty(), "② 没有对象时打探不该发包，实得 %s" % [str(_帧())])
	_判(通知.size() == 通知前 + 1 and str(通知[通知.size() - 1]) == "打探：找不到这名玩家的数据",
		"② 没有对象要明说，实得 %s" % [str(通知)])

	# 材料盒几何（`ICLB:86-98`）：格 40×40 @(10,20)、数量 40×20 @(0,20)、购买 37×22 @(11.5,63)
	var 格 := 盒.get_node_or_null("物品格") as Control
	_判(格 != null and 格.position == Vector2(10, 20) and 格.size == Vector2(40, 40),
		"② 材料格 40×40 @(10,20)，实得 %s %s"
		% [str(格.position) if 格 != null else "缺", str(格.size) if 格 != null else "缺"])
	_判(数量.position == Vector2(0, 20) and 数量.size == Vector2(40, 20),
		"② 数量角标 40×20 @(0,20)，实得 %s %s" % [str(数量.position), str(数量.size)])
	_判(买.position == Vector2(11.5, 63) and 买.size == Vector2(37, 22),
		"② 购买钮 37×22 @(11.5,63)，实得 %s %s" % [str(买.position), str(买.size)])

	窗.free()


# ─────────────────────────── ③ 私聊窗 ───────────────────────────

func 私聊窗() -> void:
	var 窗 := (load(私聊场景) as PackedScene).instantiate() as Control
	root.add_child(窗)
	窗.call("装配", _宿)
	var 会: Node = _宿.get("_session")
	会.好友私聊记录 = {}
	会.清好友私聊次 = 0
	窗.call("设对象", 101, "瑞树")

	var 题 := 窗.get_node_or_null("标题") as Label
	_判(题 != null and 题.text == 文案.取("FRIENDCHAT_WINDOW_TITLE").replace("%1", "瑞树"),
		"③ 标题 = 与<名>对话中，实得 %s" % [题.text if 题 != null else "缺节点"])

	# 发送：过滤链（去换行、剥 <...>、去**第一个**全角空格、表情只留前 5 个）
	var 输入 := 窗.get_node_or_null("输入") as TextEdit
	if 输入 == null:
		_判(false, "③ 私聊窗缺「输入」节点，发送段没量到")
		窗.free()
		return
	输入.text = " 你好\n世界　[f1][f2][f3][f4][f5][f6]<> "
	_清帧()
	_按(窗, "发送钮")
	var 期文 := "你好世界[f1][f2][f3][f4][f5]"
	_判(_帧() == ["%d:8:101:%s" % [码好友, 期文]],
		"③ 发送 ⇒ 127:8:<号>:<过滤后正文>，实得 %s" % [str(_帧())])
	_判(输入.text == "", "③ 发送后输入框要清空，实得「%s」" % 输入.text)
	var 记: Array = 会.取好友私聊(101)
	_判(记.size() == 1 and bool((记[0] as Dictionary).get("自己", false))
		and str((记[0] as Dictionary).get("文", "")) == 期文
		and str((记[0] as Dictionary).get("名", "")) == "我",
		"③ 自己发的那条要落历史（自己=true/名=我/文=过滤后），实得 %s" % [str(记)])

	# 收信信号到达后重铺：两条消息、行宽 216、收发标题色不同
	会.记录好友私聊(false, 101, "瑞树", "回你")
	await process_frame
	var 容 := 窗.get_node_or_null("消息视口/消息容器") as Control
	_判(容 != null and 容.get_child_count() == 2,
		"③ 收信应重铺成 2 行，实得 %d" % [容.get_child_count() if 容 != null else -1])
	if 容 != null and 容.get_child_count() == 2:
		var 行0 := 容.get_child(0) as Control
		var 行1 := 容.get_child(1) as Control
		_判(行0.size.x == 216 and 行1.size.x == 216, "③ 消息行宽 216（FC:12）")
		var 题0 := 行0.get_node_or_null("题") as Label
		var 题1 := 行1.get_node_or_null("题") as Label
		_判(题0 != null and 题0.get_theme_color("font_color") == 自己色,
			"③ 自己那条标题色 #00A542，实得 %s"
			% [str(题0.get_theme_color("font_color")) if 题0 != null else "缺"])
		_判(题1 != null and 题1.get_theme_color("font_color") == 他色,
			"③ 对方那条标题色 #0066FF，实得 %s"
			% [str(题1.get_theme_color("font_color")) if 题1 != null else "缺"])
		_判(题0 != null and 题0.text.begins_with("我 "),
			"③ 自己那条标题是「我 时:分:秒」，实得 %s" % [题0.text if 题0 != null else "缺"])

	# 关窗历史口径：有消息 ⇒ 只清显示、不删历史；没有消息 ⇒ 连历史一起删
	_按(窗, "关钮")
	_判(int(会.清好友私聊次) == 0 and 会.取好友私聊(101).size() == 2,
		"③ 有消息时关窗不该清历史，实得 清%d 条%d" % [int(会.清好友私聊次), 会.取好友私聊(101).size()])
	会.好友私聊记录 = {}
	_按(窗, "关钮")
	_判(int(会.清好友私聊次) == 1, "③ 没有消息时关窗要把历史也清掉，实得 清%d" % int(会.清好友私聊次))

	# 表情面板：188×188 @(239,13)、6 列、36 格、5 间距
	var 面板 := 窗.get_node_or_null("表情面板") as Control
	var 网格 := 窗.get_node_or_null("表情面板/表情网格") as GridContainer
	_判(面板 != null and 面板.position == Vector2(239, 13) and 面板.size == Vector2(188, 188),
		"③ 表情面板 188×188 @(239,13)，实得 %s %s"
		% [str(面板.position) if 面板 != null else "缺", str(面板.size) if 面板 != null else "缺"])
	_判(网格 != null and 网格.columns == 6 and 网格.get_child_count() == 36
		and 网格.get_theme_constant("h_separation") == 5
		and 网格.get_theme_constant("v_separation") == 5,
		"③ 表情网格 6 列/36 格/间距 5，实得 %s"
		% [str(网格.columns) + "/" + str(网格.get_child_count()) if 网格 != null else "缺"])

	# 插表情：已有 5 个就不再插；空框插一个 → [f3]
	_按(窗, "表情钮")
	_判(面板 != null and 面板.visible, "③ 表情钮要翻出面板")
	输入.text = "[f1][f2][f3][f4][f5]"
	_判(输入.text.count("[f") == 5, "③ 前置：输入 5 个表情")
	var f6 := 窗.get_node_or_null("表情面板/表情网格/f6") as TextureButton
	if f6 != null:
		f6.pressed.emit()
	_判(输入.text == "[f1][f2][f3][f4][f5]",
		"③ 已有 5 个表情时再点表情钮不许插入，实得 %s" % 输入.text)
	输入.text = ""
	var f3 := 窗.get_node_or_null("表情面板/表情网格/f3") as TextureButton
	if f3 != null:
		f3.pressed.emit()
	_判(输入.text == "[f3]", "③ 空框点 f3 ⇒ 插入 [f3]，实得「%s」" % 输入.text)
	_判(面板 != null and not 面板.visible, "③ 插完表情要把面板收起")

	窗.free()


# ─────────────────────── ④ 好友主窗羁绊闸 ───────────────────────

func 羁绊闸() -> void:
	var 窗 := (load(主场景) as PackedScene).instantiate() as Control
	root.add_child(窗)
	窗.call("装配", _宿)
	var 动: Array = _宿.get("动作")
	var 弹: Array = _宿.get("弹")

	# couple=true ⇒ 直接交回（原版 FW2:386-390 羁绊对提示"无法删除"，不走确认弹）
	var 前动 := 动.size()
	窗.call("_发菜单项", "删除", {"character_id": 1, "name": "夫妻", "couple": true})
	_判(弹.is_empty(), "④ 羁绊对删除不该弹输入确认，实得 %d 扇" % 弹.size())
	_判(动.size() == 前动 + 1 and str(动[动.size() - 1]) == "好友页|好友:删除",
		"④ 羁绊对删除要直接交回「好友:删除」，实得 %s" % [str(动)])

	# couple=false ⇒ 走确认弹
	窗.call("_发菜单项", "删除", {"character_id": 2, "name": "路人", "couple": false})
	_判(弹.size() == 1, "④ 普通好友删除要先弹输入确认，实得 %d 扇" % 弹.size())

	# 旧键 spouse 不算数（曾经读它，全工程没人写 ⇒ 闸永远不开）
	窗.call("_发菜单项", "删除", {"character_id": 3, "name": "旧键", "couple": false, "spouse": true})
	_判(弹.size() == 2, "④ 只带 spouse 的行仍按普通好友处理（要弹确认），实得 %d 扇" % 弹.size())

	窗.free()


# ─────────────────────── ⑤ 后端包装帧 ───────────────────────

func _包装帧() -> void:
	var 后 = _宿.get("_backend")
	_清帧()
	var 成 := [
		bool(后.call("request_friend_delete_recent", 5)),
		bool(后.call("request_friend_delete_enemy", 5)),
		bool(后.call("request_friend_chat", 5, "a:b")),
		bool(后.call("request_friend_find_enemy", 5)),
		bool(后.call("request_char_search", "", 1, 1)),
		bool(后.call("request_char_search", "名", 1, 1)),
	]
	_判(成 == [true, true, true, true, true, true], "⑤ 六条包装都该发得出去，实得 %s" % [str(成)])
	_判(_帧() == ["127:7:5", "127:9:5", "127:8:5:a:b", "127:10:5", "1282:1:1", "1282:1:1:名"],
		"⑤ 包装帧形状（7/9/8/10/1282；私聊正文里的冒号不许被洗掉），实得 %s" % [str(_帧())])

	# 0 号/空正文一律不发（原版 int 必填；0 号会打到服务端的"我自己"分支）
	_清帧()
	var 拒 := [
		bool(后.call("request_friend_delete_recent", 0)),
		bool(后.call("request_friend_delete_enemy", 0)),
		bool(后.call("request_friend_chat", 0, "x")),
		bool(后.call("request_friend_chat", 5, "")),
		bool(后.call("request_friend_find_enemy", 0)),
	]
	_判(拒 == [false, false, false, false, false], "⑤ 0 号/空正文应全部拒发，实得 %s" % [str(拒)])
	_判(_帧().is_empty(), "⑤ 拒发时不许有帧，实得 %s" % [str(_帧())])


func _收尾() -> void:
	if not _跑完了:
		_失败.append("门没跑到底（中途报错退出）⇒ 上面每条判式都还没量到")
	for 条 in _失败:
		print("失败 - ", 条)
	print("好友交互回归测试：通过 %d，红 %d" % [_通过, _失败.size()])
	quit(0 if _失败.is_empty() else 1)
