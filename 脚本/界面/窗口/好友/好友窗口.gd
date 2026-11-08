extends Control

## 好友主窗内容页（原版 `FriendWindow2` 295×370，本页 = 内容区，原点 (8,38)）。
## 场景与门期望都由 `开发工具/生成好友场景.py` 按 SPEC 生成 ⇒ **别手改 .tscn**。
## 真值：`game-client/真值/窗口/好友.md` §0–§4。
## 只做美术与交互：钮/行/菜单的动作一律交回宿主 `_show_guild_action("好友:…")`，不碰协议。

const 皮目录 := "res://素材/界面/原版窗口/好友/%s.png"
const 子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 好友子窗目录 := "res://场景/界面/窗口/好友/"
## 动作 → 要开的子窗（原版：`FriendTabLink.onAddHand:69-76` 开 SelectPlayerWindow；
## `FriendChatManage.openChat:63-67` 开 FriendChatWindow）。两扇都是**自成一窗**的场景
## （自带底/标题/关钮）⇒ 有壳=false，窗壳只管摆位与收放。
## ⚠️ 「对话」**不在这里**：原版 `FW2:361-366` 先判 `isOnline`，离线只提示、**不开窗**
## ⇒ 开窗交给宿主 `_好友菜单动作`（它拿得到整行数据），这里只负责交动作。
const 子窗表 := {"添加好友钮": ["好友选人窗", "查询玩家"]}
const 态后缀 := ["", "_悬停", "_按下", "_灰"]
const 行高 := 23.0			# `FG:96` list.rowHeight = 23
## 页签 → 体节点名 / 数据键（`FW2:40` tabBtnIndexs 顺序；数据键沿用本工程 `_session` 现有字段）
## ⚠️ 右侧那个键 = **本工程 `_session` 的真实字段名**（原包里写的是 `shitu`/`blacklist`，
## 与本工程对不上 —— 数据侧归我们，所以这里按真实字段订正，页签顺序/体节点名不动）：
##   friends / enemies / recent_contacts 三个原本就对得上；
##   黑名单 → `blocked_contacts`（**行字典**；`blocked_players` 只有名字、别处按名字判重，
##   不能改形状，所以会话里另存了一份，见 `游戏会话.blocked_contacts`）；
##   师徒 → 本工程**没有**这条数据面（`数据/师徒.json` 只有 gains/shop/params 配置，
##   后端也没有师徒联系列表）⇒ 保持一个不存在的键 = 空列表态，**不编数据**。
const 页签表 := {
	"好友": ["体好友", "friends"],
	"师徒": ["体师徒", "shitu"],
	"仇人": ["体仇人", "enemies"],
	"黑名单": ["体黑名单", "blocked_contacts"],
	"最近": ["体最近", "recent_contacts"],
}
var _宿主: Node
var _会话: Node
var _当前 := "好友"
var _菜单: Control
var _文案: Dictionary = {}
const 文案文件 := "res://数据/界面/好友_文案.json"


func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	# ⚠ 先取宿主手里的会话，取不到才回落到 autoload：上一版只写 `/root/GameSession`，
	# 而回归/截图工具把假宿主塞进树时**名字撞了 autoload**（Godot 自动改名 @2）⇒
	# 控制器读到的其实是真 autoload 的数据，门在"假通过"（memory: 假宿主失配=假通过）。
	_会话 = 宿主.get("_session") if 宿主 != null and 宿主.get("_session") is Node else null
	if _会话 == null:
		_会话 = get_node_or_null("/root/GameSession")
	for 名 in 页签表:
		var 钮 := get_node("页签条/页签" + 名) as TextureButton
		钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		钮.pressed.connect(切页.bind(名))
		_绑三态(钮)
	for 定 in 页签表.values():		# GDScript 4 没有列表推导式，别写 `[x[k] for k in …]`
		for 子 in get_node(定[0]).get_children():
			if 子 is TextureButton:
				_绑三态(子 as TextureButton)
				(子 as TextureButton).pressed.connect(_发动作.bind("%s:%s" % [_当前, 子.name]))
	_菜单 = load("res://脚本/界面/窗口/好友/好友菜单.gd").new()
	_菜单.name = "行菜单"
	add_child(_菜单)
	_菜单.项点击.connect(_发菜单项)
	切页(_当前)


## `FW2:463-468 setType` → `update:103-147`：只显当前体，其余 hideTab（不是删除，原版复用实例）。
func 切页(名: String) -> void:
	_当前 = 名
	for 键 in 页签表:
		var 钮 := get_node("页签条/页签" + 键) as TextureButton
		# 选中枚 = `enabled=false` ⇒ MTabButton 里 `selected=!enabled` 显示 selectedUpSkin 真皮、且不推灰度
		钮.disabled = 键 == 名
		_设态(钮, 0)
		get_node(页签表[键][0]).visible = 键 == 名
	刷新()


func 刷新() -> void:
	var 体: String = 页签表[_当前][0]
	var 列 := get_node(体 + "/列表/行容器") as Control
	if 列 == null:
		return
	for 子 in 列.get_children():
		列.remove_child(子)
		子.queue_free()
	var 键: String = 页签表[_当前][1]
	var 取: Variant = _会话.get(键) if _会话 != null else null	# 会话没这个字段就是空态，不编数据
	var 数据: Array = 取 if typeof(取) == TYPE_ARRAY else []
	for i in 数据.size():
		# 「最近」页那份要**现算**"这人是不是已经在好友列表里" —— 原版
		# `FriendGird:148` 判的是 `buddyData.isFriend(id)`，**不是数据里带的一个字段**
		# （以前 `好友菜单` 读 `项.is_friend`，而全工程没人写它 ⇒ 恒 false ⇒
		#  已经是好友的人在「最近」页里也照样出「交友」）。
		# ⚠ 复制一份再补字段：`数据[i]` 是会话里那一条，别往里写脏键。
		var 条: Dictionary = (数据[i] as Dictionary).duplicate()
		if 键 == "recent_contacts":
			条["is_friend"] = _是好友(int(条.get("character_id", 0)))
		var 行: Control = load("res://脚本/界面/窗口/好友/好友行.gd").new()
		行.name = "行%d" % i
		行.position = Vector2(0.0, 行高 * i)
		行.填(条, _当前, i)
		行.点击.connect(_出菜单)
		## ⚠ 带实参的信号**不许 `.bind()`**：Godot 4.7 把绑进去的实参排在信号实参**之后**
		## ⇒ `_发动作.bind("x:对话")` 收到的是 `_发动作(<那一项 Dictionary>, "x:对话")`，
		## 而 `_发动作(名: String)` 只有一个形参 ⇒ 双击好友行**当场报错、什么都不发生**（10-23 普查逮到）。
		行.双击.connect(func(项: Dictionary) -> void: _发动作("%s:对话" % _当前, 项))
		列.add_child(行)


## 这个角色编号在不在好友列表里（原版 `BuddyListData.isFriend`，`FriendGird:148` 用它
## 决定「最近」页要不要出「交友」）。好友条目里角色编号的键是 `character_id`
## （`后端连接._parse_social_contacts:3769`），不是 `id`。
func _是好友(编号: int) -> bool:
	if 编号 == 0 or _会话 == null:
		return false
	for 友 in _会话.friends:
		if int((友 as Dictionary).get("character_id", 0)) == 编号:
			return true
	return false


func _出菜单(项: Dictionary, 屏幕位: Vector2) -> void:
	_菜单.弹出(self, _当前, 项, 屏幕位)


## 菜单动作分流。`FW2:338-440 onMenuHand` 的对应物：
##   删除/拉黑/移除/泯恩仇 → **先弹输入确认**（`MDialog.showInputDialog`，输入框只读 =
##     `pane.input.textField.type = TextFieldType.DYNAMIC`），确认后才把动作交回宿主；
##   打探 → 开 `好友打探窗`（§6.3，自成一窗 ⇒ 有壳=false）；
##   其余（查看/对话/密语/组队/看摊/交友/赠花）→ 直接交回宿主走既有出口。
## 文案一律取 `数据/界面/好友_文案.json`（`开发工具/出好友文案数据.py` 从语言表抽，带行号出处）。
const 确认表 := {
	"删除": {"好友": "FRIEND_SHANCHU_LIANXIREN", "最近": "FRIEND_SHANCHU_ZUIJIN_LIANXIREN",
		 "仇人": "FRIEND_CHOUHEN_QINGLING"},
	"拉黑": {"好友": "FRIEND_YIRU_BLACKLIST", "最近": "FRIEND_YIRU_BLACKLIST"},
	"移除": {"黑名单": "FRIEND_CONG_BLACKLIST_YICHU"},
}

func _发菜单项(文本: String, 项: Dictionary) -> void:
	var 名 := String(项.get("name", ""))
	if 文本 == "打探":
		# `FW2:420-428` 把这一行五项交给弹窗；已经开着就只换对象，不再 toggle 关掉
		子窗壳.只在未开时开(_宿主, "好友打探窗", 文案("DATAN_WINDOW_TITLE"), false, 好友子窗目录)
		var 探窗 := 子窗壳.取内容(_宿主, "好友打探窗")
		if 探窗 != null and 探窗.has_method("设对象"):
			探窗.call("设对象", 项)
		return
	var 表: Dictionary = 确认表.get(文本, {})
	if 表.has(_当前):
		# ⚠ 键是 `couple`（`_parse_social_contacts` 的解析键），不是 `spouse` ——
		#    以前读 `spouse`，全工程没人写 ⇒ 羁绊那条闸永远不开，羁绊对也能被直接删/拉黑。
		if bool(项.get("couple", false)) and 文本 in ["删除", "拉黑"]:
			_发动作("%s:%s" % [_当前, 文本], 项)		# FW2:386-390 羁绊对直接提示"无法删除"
			return
		# 宿主没实现输入确认弹（老的单窗口用法）时退化成"直接交回动作"，不静默吞掉点击
		if _宿主 != null and _宿主.has_method("_弹出输入确认"):
			_宿主.call("_弹出输入确认", 文案(表[_当前]), 名, true,
					_确认后.bind("%s:%s" % [_当前, 文本], 项))
		else:
			_发动作("%s:%s" % [_当前, 文本], 项)
		return
	_发动作("%s:%s" % [_当前, 文本], 项)


func _确认后(输入值: Variant, 动作: String, 项: Dictionary) -> void:	# Callable.bind() 把绑定参数追加在实参**之后**
	if 输入值 == null:
		return		# 取消 / 点弹外 ⇒ 原版 handler(null)，什么都不发
	_发动作(动作, 项)


func 文案(键: String) -> String:
	if _文案.is_empty():
		var 取: Variant = JSON.parse_string(FileAccess.get_file_as_string(文案文件))
		_文案 = 取 if typeof(取) == TYPE_DICTIONARY else {}
	var 条: Dictionary = _文案.get(键, {})
	if 条.is_empty():
		push_error("好友文案缺键：%s（跑 开发工具/出好友文案数据.py）" % 键)
		return ""
	return String(条["文"])


func _发动作(名: String, 项: Dictionary = {}) -> void:
	# 先开子窗（纯 UI），再把动作交回宿主走既有 request_*；两件事互不替换。
	var 开: Array = 子窗表.get(名.split(":")[-1], [])
	if 开.size() == 2:
		子窗壳.切换(_宿主, 开[0], 开[1], false, 好友子窗目录)
	if _宿主 == null:
		return
	# 行菜单的每一项都要带上**这一行的数据**（编号/名字/在线/等级/头像）——原版
	# `onMenuHand` 拿的就是 `param1.object as BuddyMemeber`。只回传动作串的时代
	# 宿主只能开窗、发不出任何协议（A1 之前的状态）。新宿主走 `_好友菜单动作`，
	# 老宿主/纯 UI 用例仍落回 `_show_guild_action`。
	if _宿主.has_method("_好友菜单动作"):
		_宿主.call("_好友菜单动作", 名, 项)
	elif _宿主.has_method("_show_guild_action"):
		_宿主.call("_show_guild_action", "好友页|" + 名)


func _绑三态(钮: TextureButton) -> void:
	if not 钮.has_meta("skin"):
		return
	钮.mouse_entered.connect(_设态.bind(钮, 1))
	钮.mouse_exited.connect(_设态.bind(钮, 0))
	钮.button_down.connect(_设态.bind(钮, 2))
	钮.button_up.connect(_设态.bind(钮, 0))		# `MButton3.as:103-108` 松手回 STATE_UP


func _设态(钮: TextureButton, 态: int) -> void:
	if not 钮.has_meta("skin"):
		return
	var 后缀: String = 态后缀[3] if 钮.disabled and 钮.name.find("页签") != 0 else 态后缀[态]
	# 页签的 disabled 槽本来就是"选中皮"（texture_disabled），不能拿 _灰 覆盖它
	var 皮: String = String(钮.get_meta("skin")) + 后缀 + ".png"
	if not ResourceLoader.exists(皮):
		return
	钮.texture_normal = load(皮) as Texture2D
