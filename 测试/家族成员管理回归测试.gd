extends SceneTree

## 家族成员管理窗离线门（2026-11-08，B 项）。
##
## 病根（用户 2026-11 报的「家族成员管理没实装」）：`家族成员窗.tscn` 早就在盘上，但行渲染器
## 没移植 —— 列表恒空，没有选中/行菜单/排序/筛选/分页，也不分族长与副族长，
## 开除/任命/禅让/弹劾全都没有入口。
##
## 本门钉三块，期望值全部来自 AS3 字面或服务端写者（**不从被测场景反查**，否则场景与门一起错就永远绿）：
##   ① 服务端三帧解码：`1552:8` 入族申请 / `1552:15` 摘要第 8 字段自动同意 / `1552:6` 17 字段成员行；
##   ② 内容页 `家族成员填充`：9 列取值与配色 / 名字升序忽略大小写 / 等级降序 / 职务升序 /
##      排序三角只在可排的 8 列上 / 每页切档 / 三档分页禁用态 / 显示筛选 / 行选中 + 行菜单三档 /
##      按钮与自动同意复选框按「族长 / 副族长 / 族员」分档 / 两个下拉 / 滚轮夹取 / 空列表提示；
##   ③ 开窗即拉 `1552:105:<族号>`，且只拉一次（原版 `FM.as:604`）。
##
## 真值：`FamillyMembersWindow.as`（FMEM）/ `FamillyMemberItemRender.as` / `FamillyManager.as`。
##
## 运行：`Godot --headless --path . --script res://测试/家族成员管理回归测试.gd`

const 填充 := preload("res://脚本/界面/窗口/家族/家族成员填充.gd")
const 职务 := preload("res://脚本/界面/窗口/家族/家族职务.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")
const 场景路径 := "res://场景/界面/窗口/家族/家族成员窗.tscn"

## 配色真值（`FamillyMemberItemRender.as:96-105` + `FamillyManager.getRankName`）。
const 在线色 := Color("#00ff00")
const 离线色 := Color("#cccccc")
const 本周红 := Color("#ff0000")
const 空提示色 := Color("#a9957f")
const 三角皮 := "res://素材/界面/原版窗口/通用控件/下拉箭头.png"
const 选中底皮 := "res://素材/界面/原版窗口/家族/行选中底.png"
const 勾未选 := "res://素材/界面/原版窗口/通用控件/复选框未选.png"
const 勾选中 := "res://素材/界面/原版窗口/通用控件/复选框选中.png"

var _通过 := 0
var _失败: Array[String] = []
var _后: Node
var _真后端: Node
var _跑完了 := false
var _帧数 := 0


class 假会话 extends Node:
	signal social_changed
	var guild: Dictionary = {}

class 假宿主 extends Node:
	var _session: Node


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_跑")


## 看门狗：脚本报错会让 `_跑` 停在 await 上、quit 永远不来（挂死 = 假绿）。
func _process(_d: float) -> bool:
	_帧数 += 1
	if _帧数 > 900 and not _跑完了:
		_失败.append("门 900 帧内没跑完（中途报错停在 await 上？）")
		_收尾()
	return _帧数 > 900


func _判(对: bool, 明: String) -> void:
	if 对:
		_通过 += 1
	else:
		_失败.append(明)


func _近色(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 \
			and absf(a.b - b.b) < 0.004 and absf(a.a - b.a) < 0.004


## 25 行成员：i=1 族长 Zeta（rank 1）、i=2 副族长 alpha（rank 2）、i=3 beta（rank 3）、
## i=4/5 rank 4/5、其余族员 9999。等级 = i（唯一），偶数在线（3 线），奇数离线（-1）。
## 名字混大小写：默认升序按 `to_lower()` ⇒ alpha 在前、Zeta 在最后（不忽略大小写时会反过来）。
func _造族(空表 := false) -> Dictionary:
	var 行: Array = []
	for i in range(1, 26):
		var 名 := "m%02d" % i
		if i == 1:
			名 = "Zeta"
		elif i == 2:
			名 = "alpha"
		elif i == 3:
			名 = "beta"
		var 线 := 3 if i % 2 == 0 else -1
		行.append({
			"character_id": 100 + i, "name": 名, "level": i,
			"rank": i if i <= 5 else 9999,
			"job": 7, "face": 10000204, "gender": 1,
			"contribution": i * 100, "contriValue": i * 100,
			"weekly_contribution": i,
			"line": 线, "channel_id": 线, "online": 线 >= 0,
			"nick": "昵%02d" % i,
			"skill_value": i * 10, "skillValue": i * 10,
			"mai_value": i * 5, "maiValue": i * 5,
			"achievement_value": i * 2, "chengjiuValue": i * 2,
			"shengwang_value": i, "shengwangValue": i,
			"boss_value": i % 3, "bossValue": i % 3,
		})
	return {"joined": true, "id": 7, "name": "暗部", "notice": "公告",
		"leader": "Zeta", "leader_id": 101, "auto_accept": true,
		"member_list": [] if 空表 else 行}


func _建宿主(族: Dictionary) -> Node:
	var 宿 := 假宿主.new()
	宿.name = "假宿主"
	root.add_child(宿)
	var 会话 := 假会话.new()
	会话.name = "_会话"
	会话.guild = 族
	宿.add_child(会话)
	宿._session = 会话
	return 宿


func _建页() -> Control:
	var 父 := Control.new()
	父.name = "测试父"
	父.size = Vector2(660.0, 350.0)
	root.add_child(父)
	var 页 := (load(场景路径) as PackedScene).instantiate() as Control
	父.add_child(页)
	页.size = Vector2(634.0, 332.0)
	return 页


func _行(页: Control, 序: int) -> Control:
	return 页.get_node_or_null("列表/行%d" % (序 + 1)) as Control


func _字(页: Control, 行序: int, 列: int) -> Label:
	var 行 := _行(页, 行序)
	return 行.get_node_or_null("列%d" % 列) as Label if 行 != null else null


func _色(页: Control, 行序: int, 列: int) -> Color:
	var 字 := _字(页, 行序, 列)
	return 字.get_theme_color("font_color") if 字 != null else Color.BLACK


func _行数(页: Control) -> int:
	var 容器 := 页.get_node_or_null("列表") as Control
	if 容器 == null:
		return -1
	var 数 := 0
	for 子 in 容器.get_children():
		if String(子.name).begins_with("行"):
			数 += 1
	return 数


func _页文(页: Control, 路径: String) -> String:
	var 件 := 页.get_node_or_null(路径) as Label
	return 件.text if 件 != null else "（缺 %s）" % 路径


func _钮(页: Control, 名: String) -> TextureButton:
	return 页.get_node_or_null(名) as TextureButton


func _点(件: Control) -> void:
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 件.size * 0.5
	按.global_position = 件.size * 0.5
	件.gui_input.emit(按)


func _帧() -> Array[String]:
	var 出: Array[String] = []
	for 条 in _后.sent_requests:
		出.append("%d:%s" % [int((条 as Dictionary).get("opcode", 0)),
			String((条 as Dictionary).get("content", ""))])
	return 出


func _跑() -> void:
	_真后端 = root.get_node_or_null("BackendConnection")
	if _真后端 == null:
		_失败.append("拿不到真 BackendConnection 单例")
		_收尾()
		return
	root.remove_child(_真后端)
	_后 = 测试后端.new()
	_后.name = "BackendConnection"
	_后.in_game = true
	_后.character_id = 101
	root.add_child(_后)
	await process_frame

	_跑解码()
	_跑填充()

	_跑完了 = true
	_后.free()
	root.add_child(_真后端)
	_收尾()


# ───────────────────────── ① 解码 ─────────────────────────

func _跑解码() -> void:
	var 申请们: Array = []
	_后.family_apply_received.connect(func(数: Dictionary) -> void: 申请们.append(数))
	# `1552:8:<名>:<角色号>:<脸>:<等级>`（服务端 action 2 的 pending 分支）
	_后.call("_handle_bridge_text", "1552:8:候选人:2002:10000204:44")
	_判(申请们.size() == 1, "① `1552:8` 要解出一份入族申请（实得 %d 份）" % 申请们.size())
	if 申请们.size() == 1:
		var 申: Dictionary = 申请们[0]
		_判(String(申.get("name", "")) == "候选人" and String(申.get("playerName", "")) == "候选人",
				"① 申请者名字（name/playerName 都要）实得 %s" % str(申))
		_判(int(申.get("id", 0)) == 2002 and int(申.get("charId", 0)) == 2002,
				"① 角色号同时落 id/charId（托盘去重比 charId）实得 %s" % str(申))
		_判(int(申.get("face", 0)) == 10000204 and int(申.get("level", 0)) == 44,
				"① 脸/等级实得 %s" % str(申))
		_判(String(申.get("famillyName", "")) == "无",
				"① 申请行没有族名 ⇒ 补「无」（原版 `onFamillyApply` 同口径）实得 %s" % str(申))
	_后.call("_handle_bridge_text", "1552:8:短帧")
	_判(申请们.size() == 1, "① `1552:8` 段数不够要整帧丢掉（实得 %d 份）" % 申请们.size())

	# `1552:15:id:名:公告:创建时间:族长角色id:族长名:<自动同意 0|1>`
	_后.call("_handle_bridge_text", "1552:15:7:暗部:团结:1700000000:101:Zeta:1")
	var 族: Dictionary = _后.get("authoritative_guild") as Dictionary
	_判(int(族.get("id", 0)) == 7 and String(族.get("name", "")) == "暗部" and bool(族.get("joined", false)),
			"① `1552:15` 摘要落 joined/id/name，实得 %s" % str(族))
	_判(int(族.get("leader_id", 0)) == 101 and String(族.get("leader", "")) == "Zeta",
			"① `1552:15` 族长 = 角色号 101（判管理资格靠它，不是名字），实得 %s" % str(族))
	_判(bool(族.get("auto_accept", false)), "① `1552:15` 第 8 字段 = 自动同意开，实得 %s" % str(族))
	_后.call("_handle_bridge_text", "1552:15:7:暗部:团结:1700000000:101:Zeta:0")
	族 = _后.get("authoritative_guild") as Dictionary
	_判(not bool(族.get("auto_accept", true)), "① 第 8 字段为 0 ⇒ 自动同意关，实得 %s" % str(族))

	# `1552:6` 17 字段行（服务端 action 105 的写者）
	var 状态们: Array = []
	_后.guild_state_received.connect(func(态: Dictionary) -> void: 状态们.append(态))
	_后.call("_handle_bridge_text",
		"1552:6:2002&候选人&44&2&7&10000204&1&0&5000&300&3&阿候&12&3&8&99&6")
	var 行: Dictionary = {}
	if not 状态们.is_empty() and (状态们[-1] as Dictionary).get("members") is Array:
		var 表: Array = (状态们[-1] as Dictionary)["members"] as Array
		if not 表.is_empty():
			行 = 表[0] as Dictionary
	_判(int(行.get("character_id", 0)) == 2002 and String(行.get("name", "")) == "候选人",
			"① 17 字段行：id/名实得 %s" % str(行))
	_判(int(行.get("level", 0)) == 44 and int(行.get("rank", 0)) == 2,
			"① 17 字段行：等级/职务实得 %s" % str(行))
	_判(int(行.get("job", 0)) == 7 and int(行.get("face", 0)) == 10000204 and int(行.get("gender", 0)) == 1,
			"① 17 字段行：职业/脸/性别实得 %s" % str(行))
	_判(int(行.get("contriValue", 0)) == 5000 and int(行.get("weekly_contribution", 0)) == 300,
			"① 17 字段行：总贡献 parts[8] / 周贡献 parts[9]（错位过一次）实得 %s" % str(行))
	_判(int(行.get("channel_id", 0)) == 3 and bool(行.get("online", false)) and String(行.get("nick", "")) == "阿候",
			"① 17 字段行：线 / 在线 / 族内昵称实得 %s" % str(行))
	_判(int(行.get("skillValue", 0)) == 12 and int(行.get("maiValue", 0)) == 3
			and int(行.get("chengjiuValue", 0)) == 8 and int(行.get("shengwangValue", 0)) == 99
			and int(行.get("bossValue", 0)) == 6,
			"① 17 字段行：忍术/八门/成就/声望/本周BOSS 五列实得 %s" % str(行))
	# 12 字段伪行（单机无多人族）
	状态们.clear()
	_后.call("_handle_bridge_text", "1552:6:3003&旧行&10&1&0&0&0&0&0&123&1&0")
	行 = {}
	if not 状态们.is_empty() and (状态们[-1] as Dictionary).get("members") is Array:
		var 表2: Array = (状态们[-1] as Dictionary)["members"] as Array
		if not 表2.is_empty():
			行 = 表2[0] as Dictionary
	_判(int(行.get("contriValue", 0)) == 123 and int(行.get("channel_id", 0)) == 0
			and bool(行.get("online", true)),
			"① 12 字段伪行按在线、总贡献取 parts[9]，实得 %s" % str(行))


# ───────────────────────── ② 填充 ─────────────────────────

func _跑填充() -> void:
	var 族 := _造族()
	var 宿 := _建宿主(族)
	var 页 := _建页()
	_后.character_id = 101		# 族长
	_后.sent_requests.clear()
	填充.填(页, 宿)

	# ── 列头：8 颗三角，最后一列没有（`FMEM.as:186` param6=false）──
	for i in 8:
		_判(页.get_node_or_null("列成员%d/排序三角%d" % [i, i]) != null,
				"② 第 %d 列挂了排序三角" % i)
	_判(页.get_node_or_null("列成员8/排序三角8") == null,
			"② 最后一列「本族贡献」不挂排序三角（原版没有回调）")
	var 三0 := 页.get_node_or_null("列成员0/排序三角0") as TextureRect
	_判(三0 != null and 三0.visible, "② 默认排序列是「成员名称」⇒ 0 号三角亮")
	_判(页.get_node_or_null("列成员1/排序三角1") is TextureRect
			and not (页.get_node_or_null("列成员1/排序三角1") as TextureRect).visible,
			"② 非当前排序列的三角不亮")

	# ── 默认名字升序（忽略大小写）──
	_判(_行数(页) == 10, "② 25 行按每页 10 ⇒ 首页 10 行，实得 %d" % _行数(页))
	var 首 := _字(页, 0, 0)
	_判(首 != null and 首.text == "alpha",
			"② 默认按名字升序且忽略大小写 ⇒ 首行 alpha（实得「%s」）" % (首.text if 首 != null else "无"))
	_判(_字(页, 0, 1) != null and _字(页, 0, 1).text == "2",
			"② 等级列取整数文本，实得「%s」" % _页文(页, "列表/行1/列1"))

	# ── 9 列取值 ──
	_判(_字(页, 0, 3) != null and _字(页, 0, 3).text == "20", "② 忍术层数 = skillValue 实得「%s」" % _页文(页, "列表/行1/列3"))
	_判(_字(页, 0, 4) != null and _字(页, 0, 4).text == "10", "② 八门进度 = maiValue 实得「%s」" % _页文(页, "列表/行1/列4"))
	_判(_字(页, 0, 5) != null and _字(页, 0, 5).text == "4", "② 成就进度 = chengjiuValue 实得「%s」" % _页文(页, "列表/行1/列5"))
	_判(_字(页, 0, 6) != null and _字(页, 0, 6).text == "2", "② 战场声望 = shengwangValue 实得「%s」" % _页文(页, "列表/行1/列6"))
	_判(_字(页, 0, 7) != null and _字(页, 0, 7).text == "2", "② 本周BOSS = bossValue 实得「%s」" % _页文(页, "列表/行1/列7"))
	_判(_字(页, 0, 8) != null and _字(页, 0, 8).text == "200", "② 本族贡献 = contriValue 实得「%s」" % _页文(页, "列表/行1/列8"))

	# ── 颜色 + tooltip（在线绿 / 离线灰 / BOSS 红）──
	_判(_近色(_色(页, 0, 0), 在线色), "② 在线成员名列绿 #00ff00，实得 %s" % str(_色(页, 0, 0)))
	_判(_近色(_色(页, 1, 0), 离线色), "② 离线成员名列灰 #cccccc，实得 %s" % str(_色(页, 1, 0)))
	_判(_近色(_色(页, 0, 7), 本周红), "② 本周BOSS 列红 #ff0000，实得 %s" % str(_色(页, 0, 7)))
	var 行0 := _行(页, 0)
	var 行1 := _行(页, 1)
	_判(行0 != null and 行0.tooltip_text == "[3线]alpha",
			"② 在线行提示 `[<线>线]<名>`，实得「%s」" % (行0.tooltip_text if 行0 != null else "无"))
	_判(行1 != null and 行1.tooltip_text == "",
			"② 离线行不给假时间（服务端没下发登出时间）实得「%s」" % (行1.tooltip_text if 行1 != null else "无"))
	_判(行0 != null and 行0.mouse_filter == Control.MOUSE_FILTER_STOP,
			"② 行要收鼠标（IGNORE 会选不中也弹不出菜单）")

	# ── 点列头排序：等级降序、职务升序 ──
	_点(页.get_node("列成员1") as Label)
	_判(_字(页, 0, 1) != null and _字(页, 0, 1).text == "25",
			"② 点「等级」⇒ 降序，首行等级 25（实得「%s」）" % _页文(页, "列表/行1/列1"))
	_判(_字(页, 0, 0) != null and _字(页, 0, 0).text == "m25",
			"② 等级 25 的行是 m25（实得「%s」）" % _页文(页, "列表/行1/列0"))
	_判(页.get_node_or_null("列成员1/排序三角1") is TextureRect
			and (页.get_node_or_null("列成员1/排序三角1") as TextureRect).visible,
			"② 排序换了列，三角跟着换到 1 号")
	_判(not (页.get_node_or_null("列成员0/排序三角0") as TextureRect).visible,
			"② 0 号三角熄灭")
	_点(页.get_node("列成员2") as Label)
	_判(_字(页, 0, 2) != null and _字(页, 0, 2).text == "族长", "② 点「职务」⇒ 升序，首行族长")
	_判(_字(页, 1, 2) != null and _字(页, 1, 2).text == "副族长", "② 第二行副族长")
	_判(_字(页, 4, 2) != null and _字(页, 4, 2).text == "精英", "② 第五行精英（rank 5）")
	_判(_近色(_色(页, 0, 2), Color("#a800ff")), "② 族长职务色 #a800ff，实得 %s" % str(_色(页, 0, 2)))
	_判(_近色(_色(页, 1, 2), Color("#1e90ff")), "② 副族长职务色 #1e90ff，实得 %s" % str(_色(页, 1, 2)))
	_判(_近色(_色(页, 2, 2), Color("#00ff00")), "② 长老职务色 #00ff00，实得 %s" % str(_色(页, 2, 2)))
	_判(_近色(_色(页, 3, 2), Color.WHITE), "② 顾问职务色白，实得 %s" % str(_色(页, 3, 2)))

	# ── 分页四钮的禁用态 ──
	var 首页 := 页.get_node("分页分页/首页") as TextureButton
	var 上 := 页.get_node("分页分页/上一页") as TextureButton
	var 下 := 页.get_node("分页分页/下一页") as TextureButton
	var 末 := 页.get_node("分页分页/末页") as TextureButton
	_判(_页文(页, "分页分页/页码") == "1/3", "② 25 行 / 每页 10 ⇒ 页码 1/3，实得 %s" % _页文(页, "分页分页/页码"))
	_判(首页.disabled and 上.disabled, "② 第 1 页：首页/上一页禁用")
	_判(not 下.disabled and not 末.disabled, "② 第 1 页：下一页/末页可点")
	填充.翻页(页, 宿, "下一页")
	_判(_页文(页, "分页分页/页码") == "2/3", "② ×下一页⇒ 2/3，实得 %s" % _页文(页, "分页分页/页码"))
	_判(_行数(页) == 10, "② 第 2 页仍 10 行，实得 %d" % _行数(页))
	_判(not 首页.disabled and not 上.disabled, "② 第 2 页：首页/上一页可点")
	填充.翻页(页, 宿, "末页")
	_判(_页文(页, "分页分页/页码") == "3/3", "② ×末页⇒ 3/3，实得 %s" % _页文(页, "分页分页/页码"))
	_判(_行数(页) == 5, "② 第 3 页剩 5 行，实得 %d" % _行数(页))
	_判(下.disabled and 末.disabled, "② 末页：下一页/末页禁用")
	填充.翻页(页, 宿, "首页")
	_判(_页文(页, "分页分页/页码") == "1/3", "② ×首页⇒ 1/3，实得 %s" % _页文(页, "分页分页/页码"))

	# ── 显示筛选 ──
	填充.选筛选(页, 宿, 1)
	_判(_页文(页, "下拉成员/文字") == "线上", "② 筛选「线上」写进下拉触发器")
	_判(_页文(页, "分页分页/页码") == "1/2", "② 13 名在线 / 10 ⇒ 1/2，实得 %s" % _页文(页, "分页分页/页码"))
	var 全绿 := true
	for i in _行数(页):
		if not _近色(_色(页, i, 0), 在线色):
			全绿 = false
	_判(全绿, "② 线上筛选后可见行全绿")
	填充.选筛选(页, 宿, 2)
	_判(_页文(页, "下拉成员/文字") == "离线", "② 筛选「离线」写进下拉触发器")
	_判(_页文(页, "分页分页/页码") == "1/2", "② 12 名离线 / 10 ⇒ 1/2，实得 %s" % _页文(页, "分页分页/页码"))
	var 全灰 := true
	for i in _行数(页):
		if not _近色(_色(页, i, 0), 离线色):
			全灰 = false
	_判(全灰, "② 离线筛选后可见行全灰")
	填充.选筛选(页, 宿, 0)

	# ── 每页条数切档 ──
	填充.选每页(页, 宿, 1)
	_判(_页文(页, "下拉页/文字") == "30项", "② 每页切 30 ⇒ 触发器文字「30项」")
	_判(_页文(页, "分页分页/页码") == "1/1", "② 25 行 / 30 ⇒ 1/1，实得 %s" % _页文(页, "分页分页/页码"))
	_判(_行数(页) == 25, "② 每页 30 ⇒ 25 行全露，实得 %d" % _行数(页))
	_判(首页.disabled and 上.disabled and 下.disabled and 末.disabled,
			"② 只有一页时四个分页钮全禁用")

	# ── 滚轮夹取 ──
	var 容器 := 页.get_node("列表") as Control
	var 上限 := maxf(0.0, 25.0 * 23.0 - 容器.size.y)
	填充._滚(页, 12.0)
	_判(absf(float(页.get_meta("mg_offset", 0.0)) - 12.0) < 0.01, "② 滚轮下 12px ⇒ 偏移 12")
	填充._滚(页, 99999.0)
	_判(absf(float(页.get_meta("mg_offset", 0.0)) - 上限) < 0.01,
			"② 滚到底夹在「行数×23 − 列表高」=%.0f（实得 %.1f）" % [上限, float(页.get_meta("mg_offset", 0.0))])
	_判(_行(页, 0) != null and absf(_行(页, 0).position.y + 上限) < 0.01, "② 首行跟着上移")
	填充._滚(页, -99999.0)
	_判(absf(float(页.get_meta("mg_offset", 0.0))) < 0.01, "② 往上滚夹到 0")

	# ── 两个下拉 ──
	填充.弹下拉(页, 宿, "页")
	var 罩 := 页.get_node_or_null("成员弹层") as Control
	_判(罩 != null, "② ×「每页」弹出弹层")
	var 菜单 := 罩.get_node_or_null("菜单") as Panel if 罩 != null else null
	_判(菜单 != null and 菜单.get_child_count() == 4, "② 每页下拉四档")
	if 菜单 != null:
		var 项0 := 菜单.get_node_or_null("项0") as Button
		var 项1 := 菜单.get_node_or_null("项1") as Button
		_判(项1 != null and 项1.text == "30项", "② 第二档文字「30项」")
		_判(项1 != null and 项1.get_theme_color("font_color") == Color.WHITE,
				"② 当前档（30项）白字")
		_判(项0 != null and 项0.get_theme_color("font_color") == Color("#FCF49C"),
				"② 非当前档 #FCF49C")
		if 项0 != null:
			项0.pressed.emit()
	_判(页.get_node_or_null("成员弹层") == null, "② 点选项后弹层收起")
	_判(_页文(页, "下拉页/文字") == "10项", "② 选回 10 项并生效")
	_判(_页文(页, "分页分页/页码") == "1/3", "② 换每页条数把页码打回 1（原版 PageComponent.reset）")
	填充.弹下拉(页, 宿, "成员")
	var 罩2 := 页.get_node_or_null("成员弹层") as Control
	var 菜单2 := 罩2.get_node_or_null("菜单") as Panel if 罩2 != null else null
	_判(菜单2 != null and 菜单2.get_child_count() == 3, "② 显示下拉三档")
	if 菜单2 != null:
		var 筛项 := 菜单2.get_node_or_null("项1") as Button
		_判(筛项 != null and 筛项.text == "线上", "② 第二档文字「线上」")
		if 筛项 != null:
			筛项.pressed.emit()
	_判(_页文(页, "下拉成员/文字") == "线上", "② 选中线上后触发器文字跟着换")
	填充.选筛选(页, 宿, 0)
	填充.弹下拉(页, 宿, "页")
	填充.弹下拉(页, 宿, "页")
	_判(页.get_node_or_null("成员弹层") == null, "② 再点一次同一个下拉 = 收起")

	# ── 行选中 + 行菜单三档 ──
	填充.排序列(页, 宿, "成员名称")
	_点(_行(页, 0))
	_判(int(页.get_meta("mg_selected", -1)) == 0, "② 点行 ⇒ mg_selected=0，实得 %d" % int(页.get_meta("mg_selected", -1)))
	var 选底 := _行(页, 0).get_node_or_null("选中底") as NinePatchRect
	_判(选底 != null and 选底.visible, "② 选中行亮选中底")
	_判(String(选底.texture.resource_path) == 选中底皮, "② 选中底用 MSelected_background1 那张皮")
	# 原版 scale9 = 7 / 5.35 / 7.9 / 5.75（AS3 的 Rectangle 可小数）；Godot patch_margin 是 int
	# ⇒ 落盘只能截断成 7 / 5 / 7 / 5。期望照「截断后的真实值」钉，不拿浮点当 int 比。
	_判(选底.patch_margin_left == 7 and 选底.patch_margin_top == 5
			and 选底.patch_margin_right == 7 and 选底.patch_margin_bottom == 5,
			"② 选中底九宫格边距落到 int 档 = 7/5/7/5（原版 7/5.35/7.9/5.75 截断）实得 %d/%d/%d/%d"
			% [选底.patch_margin_left, 选底.patch_margin_top,
					选底.patch_margin_right, 选底.patch_margin_bottom])
	var 选 := 填充.选中成员(页)
	_判(String(选.get("name", "")) == "alpha", "② 选中成员返回那一行，实得 %s" % str(选))
	var 菜 := 页.get_node_or_null("行菜单") as Control
	_判(菜 != null and 菜.visible, "② 点行弹出菜单")
	_判(菜.get_node_or_null("查看资料") != null and 菜.get_node_or_null("加为好友") != null,
			"② 菜单有两颗基础项")
	_判(菜.get_node_or_null("任命副族长") != null and 菜.get_node_or_null("任命族员") != null,
			"② 族长菜单有任命五项")
	# 族长看自己那行：_菜单表 仍给族长整表（原版菜单不按行过滤），「不能对自己操作」拦在宿主动作层
	_判(菜.get_node_or_null("禅让族长") != null, "② 族长菜单含禅让族长（整表不论看谁那行）")
	var 表族长: Array = 填充._菜单表(宿, 选)
	_判(表族长.size() == 10, "② 族长菜单项数 = 2 + 分隔 + 5 + 分隔 + 禅让 = 10，实得 %d" % 表族长.size())
	_判(表族长[-1] is Dictionary and String((表族长[-1] as Dictionary).get("name", "")) == "禅让族长"
			and (表族长[-1] as Dictionary).get("color") == Color("#ff0000"),
			"② 禅让族长是红字项（MPM 的 {name,color} 项）实得 %s" % str(表族长[-1]))
	# 副族长看族长那一行 ⇒ 基础两项 + 弹劾（红）
	_后.character_id = 102
	填充.刷新(页, 宿)
	_点(_行(页, 0))		# 排序按名字，首行 alpha（自己）；换成族长行 m? 先按职务排
	填充.排序列(页, 宿, "职务")
	_点(_行(页, 0))		# 首行 = 族长 Zeta
	var 表副: Array = 填充._菜单表(宿, 填充.选中成员(页))
	_判(表副.size() == 4, "② 副族长看族长行 = 查看/加好友/分隔/弹劾 = 4 项，实得 %d" % 表副.size())
	_判(表副[-1] is Dictionary and String((表副[-1] as Dictionary).get("name", "")) == "弹劾族长"
			and (表副[-1] as Dictionary).get("color") == Color("#ff0000"),
			"② 弹劾族长是红字项，实得 %s" % str(表副[-1]))
	_判(菜.get_node_or_null("弹劾族长") != null, "② 副族长点族长行，菜单里真有「弹劾族长」")
	# 普通族员看普通成员 ⇒ 只有两项
	_后.character_id = 103
	填充.刷新(页, 宿)
	_点(_行(页, 2))		# 职务升序：1 族长 / 2 副 / 3 长老(m03) ⇒ 第 3 行
	var 表员: Array = 填充._菜单表(宿, 填充.选中成员(页))
	_判(表员.size() == 2 and String(表员[0]) == "查看资料" and String(表员[1]) == "加为好友",
			"② 普通成员只有查看资料/加为好友，实得 %s" % str(表员))

	# ── 按钮与自动同意复选框按身份分档（`FMEM.as:369-385,405`）──
	_后.character_id = 101		# 族长
	族["auto_accept"] = true
	填充.刷新(页, 宿)
	_判(not _钮(页, "钮添加成员").disabled and not _钮(页, "钮开除出族").disabled,
			"② 族长：添加成员/开除出族可点")
	_判(not _钮(页, "钮解散家族").disabled and _钮(页, "钮退出家族").disabled,
			"② 族长：解散可点、退出禁用")
	var 勾 := 页.get_node_or_null("复选自动同意") as Control
	_判(勾 != null and 勾.visible, "② 族长看得到自动同意复选框")
	_判(String((勾.get_node("框") as TextureRect).texture.resource_path) == 勾选中,
			"② 自动同意=true ⇒ 复选框打勾")
	_后.character_id = 102		# 副族长
	填充.刷新(页, 宿)
	_判(not _钮(页, "钮添加成员").disabled and not _钮(页, "钮开除出族").disabled,
			"② 副族长：添加成员/开除出族可点（rank 2 也算管理）")
	_判(_钮(页, "钮解散家族").disabled and not _钮(页, "钮退出家族").disabled,
			"② 副族长：解散禁用、退出可点")
	_判(not 勾.visible, "② 副族长看不到自动同意复选框（原版 checkBox.visible = isManager）")
	_后.character_id = 103		# 普通族员
	族["auto_accept"] = false
	填充.刷新(页, 宿)
	_判(_钮(页, "钮添加成员").disabled and _钮(页, "钮开除出族").disabled,
			"② 普通族员：添加/开除都禁用")
	_判(_钮(页, "钮解散家族").disabled and not _钮(页, "钮退出家族").disabled,
			"② 普通族员：解散禁用、退出可点")
	_后.character_id = 101
	填充.刷新(页, 宿)
	_判(String((勾.get_node("框") as TextureRect).texture.resource_path) == 勾未选,
			"② 自动同意=false ⇒ 复选框未打勾")

	# ── 职务表 ──
	_判(职务.职务名(1) == "族长" and 职务.职务名(2) == "副族长" and 职务.职务名(3) == "长老"
			and 职务.职务名(4) == "顾问" and 职务.职务名(5) == "精英"
			and 职务.职务名(9999) == "族员" and 职务.职务名(0) == "族员",
			"② 职务表 1..5 + 9999/未知 ⇒ 族员（rank 1 是族长，不是成员）")

	# ── 空表 + 开窗即拉 105 ──
	_后.sent_requests.clear()
	var 空宿 := _建宿主(_造族(true))
	var 空页 := _建页()
	填充.填(空页, 空宿)
	var 帧 := _帧()
	_判(帧 == ["1552:105:7"], "② 开窗没有成员行 ⇒ 发一次 `1552:105:<族号>`，实得 %s" % str(帧))
	_判(bool(空页.get_meta("mg_asked", false)), "② 拉表用 meta 挡重复")
	填充.填(空页, 空宿)
	_判(_帧().size() == 1, "② 再填一次不重复发 105，实得 %s" % str(_帧()))
	var 空容器 := 空页.get_node("列表") as Control
	var 提示 := 空容器.get_node_or_null("空提示") as Label
	_判(提示 != null and 提示.text == "暂无成员", "② 空列表落「暂无成员」")
	_判(提示 != null and _近色(提示.get_theme_color("font_color"), 空提示色),
			"② 空提示色 #a9957f，实得 %s" % (str(提示.get_theme_color("font_color")) if 提示 != null else "无"))
	_判(填充.选中成员(空页).is_empty(), "② 空列表选中成员是空字典（宿主开除读它）")

	# ── 素材与场景 ──
	for 皮 in [三角皮, 选中底皮, 勾未选, 勾选中,
			"res://素材/界面/原版窗口/通用控件/菜单底.png",
			"res://素材/界面/原版窗口/通用控件/菜单按钮.png"]:
		_判(ResourceLoader.exists(皮), "② 素材在盘上：%s" % 皮)
	_判(ResourceLoader.exists(场景路径), "② 场景在盘上：%s" % 场景路径)


func _收尾() -> void:
	if not _跑完了:
		_失败.append("门没跑到底（中途报错退出）⇒ 上面每条判式都还没量到")
	for 条 in _失败:
		print("失败 - ", 条)
	print("家族成员管理回归测试：通过 %d，红 %d" % [_通过, _失败.size()])
	quit(0 if _失败.is_empty() else 1)
