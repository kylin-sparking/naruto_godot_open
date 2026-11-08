extends RefCounted
## 家族邀请窗（原版 `MPromptWindow.popupHasPlayerInfoWindow`）控制器。
## 逐件真值：`真值/窗口/家族邀请窗.md`（页 264×136 = 整窗 165 减 29 标题栏）。
##
## 触发链：族长点目标信息条菜单「族邀」⇒ 上行 `1552:19:<对方角色号>`
## （`BanghuiProcessor.requestInvite:809-815` 写 `writeShort(19)` + `writeInt`）⇒
## 服务端 `:33523`（闸 = `is_leader`）给**被邀方**推 `1552:16:<族长名>:<级>:<职>:<脸>:<族名>:<族长号>:<族号>`
## ⇒ `后端连接.family_invite_received` ⇒ `窗口管理` 只往头顶托盘塞一格（原版
## `FamillyManager.onAcceptFamillyInvite:331-343` 就是塞 `CueGird`，**不直接开窗**），
## 点那一格才走本文件的 `渲染`（原版 `inviteHandler:235-239`）。
##
## ⚠ 两个 id 不是一回事：`charId`（族长角色号）只给「查看资料」和托盘去重；
## 「同意加入 / 拒绝」那两发带的是**家族 id**（`agreeInvite:1157` / `rejectInvite:801`
## 都传 `param1.id`），服务端按存着的 `familyInviteId` 比对，对不上就一句话都不回。

const 标题 := "邀请入族"					# FAMILLY_MANAGER_YAOQING_RUZU
const 正文文 := "该玩家邀请你加入他的家族，请问你是否审核通过"	# FAMILLY_MANAGER_YAOQING_NI_JIARU
const 确定文字 := "同意加入"				# FAMILLY_MANAGER_TONGYI_JIARU
const 取消文字 := "拒绝"					# DIALOG_BTN_DECLINE
## 审核档（`1552:8` 入族申请，`applyHandler:127-131`）：同一扇 `MPromptWindow` 子类，
## 只换标题 / 正文 / 主钮三处文字；两发上行也换成 acceptApply / rejectApply。
const 申请标题 := "申请入族"				# FAMILLY_MANAGER_SHENQING_RUZU
const 申请正文文 := "该玩家申请加入你的家族，请问你是否审核通过"	# FAMILLY_MANAGER_SHIFO_TONGGUO
const 批准文字 := "批准入族"				# FAMILLY_MANAGER_PIZHUN_RUZU
const 查资料文字 := "查看资料"				# TROOP_SHOW_CHAR_INFO_BTN
const 级后缀 := "级"						# COMMON_JI（原版直接拼在数字后面，没有冒号）
const 职业表 := preload("res://脚本/单例/职业.gd")

## `createHasPlayerInfoWindow:215` 那一列的原文 = `level + COMMON_JI + "\r" + getJobName(job)`。
## ⚠ 换行是 `\r` 不是 `\n`（AS3 里写死的），Godot 侧一律换成 `\n`（同全工程其它富文本口径）。
static func 等级职业行(邀: Dictionary) -> String:
	return str(int(邀.get("level", 0))) + 级后缀 + "\n" + 职业表.取(int(邀.get("job", 0)))

## 建页 + 填数据 + 接三颗钮。`宿主` = 一个 `功能窗口` 实例（页壳）。
## 页局部坐标 = AS3 坐标 − 29（`MWindow` 标题拖动区），件序按 `addChild` 原序，见真值表 §③。
static func 渲染(宿主: Node, 场景: PackedScene, 邀: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 是申请 := bool(邀.get("是申请", false))
	(页.get_node("族长名") as Label).text = String(邀.get("playerName", 邀.get("name", "")))
	(页.get_node("族名") as Label).text = String(邀.get("famillyName", ""))
	(页.get_node("等级职业") as RichTextLabel).text = 等级职业行(邀)
	(页.get_node("正文") as RichTextLabel).text = 申请正文文 if 是申请 else 正文文
	## `:193-199` = `PortraitHead(true,40,40,TYPE_CHAR)`，`skin = face`，格内摆在 `(20,20)`。
	## AS3 那句字面上会把头像甩出格子，本工程按同族已验收的 `双修邀请窗`/`物品格` 口径
	## **等比居中塞进 40×40 的格子**（`stretch_mode = 4`）—— 真值表 §⑤.4 记了这一条偏离。
	var 脸 := str(int(邀.get("face", 1))).pad_zeros(8)
	(页.get_node("头像格/头像") as TextureRect).texture = OriginalSprite.portrait("character", 脸)
	var 族号 := int(邀.get("id", 0))
	var 族长号 := int(邀.get("charId", 0))
	if 是申请:
		# `applyHandler:129` 的主钮文字 = 批准入族；上行 `agreeAply:1114-1117` = acceptApply(id)。
		((页.get_node("同意钮") as TextureButton).get_node("文字") as Label).text = 批准文字
		(页.get_node("同意钮") as TextureButton).pressed.connect(_点批准.bind(宿主, 族长号))
		(页.get_node("拒绝钮") as TextureButton).pressed.connect(_点拒审.bind(宿主, 族长号))
	else:
		(页.get_node("同意钮") as TextureButton).pressed.connect(_点同意.bind(宿主, 族号))
		(页.get_node("拒绝钮") as TextureButton).pressed.connect(_点拒绝.bind(宿主, 族号))
	(页.get_node("查看资料钮") as TextureButton).pressed.connect(_点查资料.bind(族长号))
	for 颗 in ["同意钮", "拒绝钮", "查看资料钮"]:
		_绑三态(页.get_node(颗) as TextureButton)
	return 页

## ── MButtonF 三态（`MButtonF extends MButton3` ⇒ 一张皮 + 运行时加性滤镜，不是四张皮）──
## 只换 `texture_normal`，**不用** `texture_hover` / `texture_pressed`：Godot 松手后只要鼠标
## 还悬着会停在 hover 档，而原版 `mouseUpHandler:103-108` 回的是 STATE_UP（不移出鼠标就不再亮）。
## 三档皮 = 同一张 `钮底N.png` 过 `skinFilters` 的 +30 / −40 预烘（`StyleUtil.as:7-12`）。
const 态后缀 := ["", "_悬停", "_按下", "_灰"]
## `MButton3.as:69-74` `_textColors`（up/over/down/disabled）。
const 态文字色 := [Color(0.988235, 0.956863, 0.611765, 1), Color(1, 1, 0.764706, 1),
		Color(0.67451, 0.67451, 0.698039, 1), Color(0.576471, 0.576471, 0.576471, 1)]

static func _绑三态(钮: TextureButton) -> void:
	if not 钮.has_meta("skin"):
		return
	钮.mouse_entered.connect(_设态.bind(钮, 1))
	钮.mouse_exited.connect(_设态.bind(钮, 0))
	钮.button_down.connect(_设态.bind(钮, 2))
	钮.button_up.connect(_设态.bind(钮, 0))
	_设态(钮, 0)

static func _设态(钮: TextureButton, 态: int) -> void:
	if not 钮.has_meta("skin"):
		return
	var 皮: String = String(钮.get_meta("skin")) + 态后缀[3 if 钮.disabled else 态] + ".png"
	if not ResourceLoader.exists(皮):
		return
	钮.texture_normal = load(皮) as Texture2D
	var 文字 := 钮.get_node_or_null("文字") as Label
	if 文字 != null:
		文字.add_theme_color_override("font_color", 态文字色[3 if 钮.disabled else 态])

## `agreeInvite:1151-1158` = `requestBanghuiAcceptInvitation(param1.id)` ⇒ `1552:15:<族号>`，
## 然后 `okHandler:146-163` 自己关窗（`_viewType != 1` 那一条恒真）。
## 成功帧服务端给**我**回 `1552:15:` 摘要 + `1552:21` 家徽 + 给每个在线族员 `1552:7:<号>`，
## 那几条已有消费者（家族窗/家徽），这里不重复处理。
static func _点同意(宿主: Node, 族号: int) -> void:
	var 后 := _后端(宿主)
	if 后 != null:
		后.call("request_family_invite_accept", 族号)
	宿主.call("关掉家族邀请")

## `rejectInvite:795-802` = `requestBanghuiRejectInvitation(param1.id)` ⇒ `1552:3:<族号>`；
## 服务端给**族长**回 `1552:9:<拒绝者名>`，族长侧 `actionBanghuiRejectInvitation` 什么都不弹
## ⇒ 本工程也不给族长加提示（加了就是自造）。
static func _点拒绝(宿主: Node, 族号: int) -> void:
	var 后 := _后端(宿主)
	if 后 == null:
		return
	后.call("request_family_invite_reject", 族号)
	后.call("clear_family_invite")
	宿主.call("关掉家族邀请")


## 审核档主钮：`agreeAply:1114-1117` = `requestBanghuiAcceptApply(param1.id)` ⇒ `1552:14:<申请人号>`。
## 这里带的是**申请人角色号**（`onFamillyApply:153` 里 `charId = id`），不是家族号。
static func _点批准(宿主: Node, 申请人号: int) -> void:
	var 后 := _后端(宿主)
	if 后 != null:
		后.call("request_guild_accept_apply", 申请人号)
	宿主.call("关掉家族邀请")


## 审核档次钮：`rejectAply:524-527` = `requestBanghuiRejectApply(param1.id)` ⇒ `1552:13:<申请人号>`。
static func _点拒审(宿主: Node, 申请人号: int) -> void:
	var 后 := _后端(宿主)
	if 后 != null:
		后.call("request_guild_reject_apply", 申请人号)
	宿主.call("关掉家族邀请")

## `viewPlayHandler:310-316` = `API.ui.clickCharacter(this._data.charId)` ⇒ **上行 `94:0:<号>`**，
## 回帧由 `窗口管理._on_他人详细信息` 去开"别人的人物窗"（同双修邀请窗那一颗）。
static func _点查资料(号: int) -> void:
	var 后 := _后端(null)
	if 后 != null and bool(后.call("get", "in_game")):
		后.call("request_char_full_info", 号)

## ⚠ 必须写 `var 后: Node = ...` 这种**带类型**的接法：`Engine.get_main_loop()` 回来的是
## MainLoop，链式 `.root` 是 Variant ⇒ `:=` 推不出类型直接 parse 失败，
## 而这份脚本是 功能窗口.gd preload 进来的 ⇒ 一坏就把整个功能窗口拖死（实测）。
static func _后端(_宿主: Node) -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root.get_node_or_null("BackendConnection") if 树 != null else null
