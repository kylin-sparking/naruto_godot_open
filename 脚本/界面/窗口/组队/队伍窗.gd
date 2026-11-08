extends RefCounted

## 组队窗 = 原版 `com/mxw/uifl/controls/troop/TroopWindow2`（五页签）+ `MyTroopPane`（我的队伍）
## + `NearTroopsPane`（附近队伍）+ `NearCharsPane`（附近玩家），外加 `RelationShipHandler` 那侧的
## 状态与闸门。**逐句转写，不重写**：函数边界、条件顺序、常量都照 AS3，只多一层 API 对照。
##
## 逐件坐标：`真值/窗口/组队.md` §①②③④⑥⑦（场景由 `开发工具/生成队伍场景.py` 烘，期望同源）。
## 包形（上行 120 十四档 / 下行 59 二十档 / 203）：同文件 §⑧。
##
## ★ 三条**原版自己就是这样**、不是我们做漏了的事（别"顺手补"）：
##   ① `MyTroopPane.refreshCopyState()` 与 `TroopWindow2.refreshCopyState()` 在 MainLib 里
##      **0 处调用** ⇒ `_nowInCopy` 恒 false ⇒ `setBtnsEnabled()` 那支副本分支原版走不到。
##      这边照样把那一支搬过来（`置副本()` 只给门做覆盖用），但**不去猜**哪个帧该点亮它。
##   ② 原版**没有解散按钮**：`120:7`/`59:12` 全链在、客户端没人发，`TROOP_CONFIRM_BREAK_TIP`
##      也是死文案 ⇒ 这边同样不做那颗钮。
##   ③ `59:16 / 27 / 35 / 39` 四档原版是**空函数**（Client:3252/4215/2366/6081）⇒ 收到**画面什么都不变**。
##
## ★ 一条**口径替换**（不是照搬，写在这是为了别被当成原版算式）：
##   原版 `isInSameMap` 走 `CharacterHandler.checkInSameMap(id)`，真身是 `_characters[id] != null`
##   （`CharacterHandler.as:218-225`）=「**场上有没有那具实体**」。这边没有从页面拿地图实体索引的口子，
##   改成「成员行的 map_id 与自己相同 **且** channel_id 相同」。本机这一支服务端建远程实体就是按
##   `visible_peers`（同图同线）来的 ⇒ 两种口径在真机上必然同值，`队伍行为门` 里有一条**双口径对照**
##   的判据把它钉住；哪天不再同值，那条会红，届时要改回问实体。

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const 职业表 := preload("res://脚本/单例/职业.gd")
const 输入确认弹脚本 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 队伍面板脚本 := preload("res://脚本/界面/窗口/组队/队伍面板.gd")

const 页签皮 := "res://素材/界面/原版窗口/通用控件/分页按钮未选.png"

## ── AS3 常量（每条都有出处，别改数值）──
const 上限 := 6			# UIConfig.as:332 TROOP_MAX_NUM
const 钮四宽 := 61			# UIConfig.as:324 btn_width_four
const 宣言上限 := 9			# MyTroopPane.as:214 textField.maxChars = 9
const 搜索上限 := 20			# NearCharsPane.as:178 textField.maxChars = 20
const 队伍每页 := 11			# NearTroopsPane.as:118 troopList.rowCount
const 成员每页 := 6			# :129 memberList.rowCount
const 玩家每页 := 11			# NearCharsPane.as:195 charsList.rowCount
const 行高 := 22			# 三张表的 rowHeight 都是 22
const 离线通道 := -2			# PartyCharacter.as:19 channelIndex 的默认值 ⇒ != -2 才算在线

## ── UIConfig 色（十进制字面量）──
const 色橙 := Color(1.0, 0.568627, 0.0)		# UI_ORANGE 16748800
const 色白 := Color(1, 1, 1)			# UI_WHITE 16777215
const 色绿 := Color(0, 1, 0)			# UI_GREEN 65280
const 色蓝 := Color(0.117647, 0.564706, 1.0)	# UI_BLUE 2003199

## ── 文案（只认原版语言表；这里写死是**读表结果**，出处 = 真值 §⑩）──
const 文案 := {
	"我的队伍": "我的队伍", "附近队伍": "附近队伍", "附近玩家": "附近玩家",
	"我的羁绊": "我的羁绊", "酒宴列表": "酒宴列表",
	"提示": "每多组一个人，怪物总经验增加 5%",
	"宣言": "队伍宣言", "修改宣言": "修改宣言", "自建": "自建队伍", "退队": "自我退队",
	"添加": "添加成员", "任命": "任命队长", "请离": "请离队伍", "查看资料": "查看资料",
	"勾1": "自动接收组队邀请", "勾2": "自动接收入队申请", "勾3": "主介面显示队员头像清单",
	"刷新": "刷新列表", "申请入队": "申请入队", "邀请组队": "邀请组队",
	"队伍列表题": "当前地图队伍列表", "队伍成员题": "队伍成员",
	"队长": "队长", "人数": "人数", "名称": "队员名称", "等级字": "等级", "职业字": "职业",
	"名字字": "名字", "家族字": "家族", "称号字": "称号",
	"搜索提示": "你可以搜索当前地图中的未组队的玩家",
	"邀请入队": "邀请入队",
	"没找到符合条件": "没有符合条件的玩家", "附近没人": "附近没有其他玩家",
	"附近没队": "附近没有队伍", "该队满了": "该队伍已达人数上限",
	"人数已满": "组队人数已达上限", "请输入宣言": "请输入宣言内容",
	"加入队伍": "加入队伍", "的队伍": "的队伍", "成为队长": "%1成为队长",
	"自己已在队": "自己已在队伍中，不能再申请加入组队",
	"拒绝申请": "队长<font color=\"#ff6600\">%1</font>拒绝你加入队伍",
	"移交确认": "你想把队长让给 <font color=\"#ff6600\">%1</font> 吗？",
	"队伍已满": "队伍已满", "没找到该玩家": "没找到该玩家",
	"被踢": "你已经被队长踢出队伍",
	"拒绝邀请": " 拒绝了你的组队邀请！",
	"申请加入": "<font color=\"#ff6600\">%1</font>申请加入组队！",
	"邀请你": "<font color=\"#ff6600\">%1</font>邀请你加入组队！",
}

## ── 单例状态（原版 = `DataCenter.partyStatus` + `MyTroopPane` 私有字段；换图/关窗都不清）──
static var 队号 := 0				# partyStatus.partyId
static var 队长号 := 0				# partyStatus.leaderId
static var 队名 := ""				# partyStatus.partyName（= 宣言同一个字段，见 UI.as:2110）
static var 成员: Array = []			# UI.as:2088-2107 换算后的行
static var 页: Control = null			# ★ 回帧要靠它，漏了这一步 = 喂了帧界面一动不动
static var 页序 := 0				# _tabBar.selectedIndex
static var 选格 := -1				# selectedMemberCell（格序）
static var 格字典 := {}				# _dataDic: 角色号 → 格序
static var 副本中 := false			# _nowInCopy（原版没人点亮，见文件头 ★①）
static var 自动接受邀请 := false		# CharacterConfig.troopAutoAcceptInvite
static var 自动接受申请 := false		# CharacterConfig.troopAutoAcceptApply
static var 藏面板 := false			# SysCfg.hideTroopInfoPane（勾3 是它的**反面**）
static var 附近队: Array = []			# NearTroopsPane._data
static var 附近人: Array = []			# NearCharsPane._data
static var 搜中: Array = []			# NearCharsPane._searchData
static var 队页序 := 0				# 附近队伍的分页页码（PageComponent 那套先按页码存）
static var 人页序 := 0
static var 宿主: Node = null
static var 会话: Node = null
static var 后端: Node = null
static var 自己号 := -1				# API.dataCenter.stats.id
static var 自己名 := ""
static var 收过帧 := 0				# 只给门数：证明回帧真的进过这里
static var 发件箱: Array = []			# 只给门看
static var 队长标应显 := false			# 头像面板那颗队长标该不该亮（写入点 + 广播见 `_同步队长标`）


static func 渲染(主: Node, 场景: PackedScene) -> Control:
	宿主 = 主
	会话 = 主.get("_session") as Node
	后端 = 主.get("_backend") as Node
	页 = 场景.instantiate() as Control
	主._content.add_child(页)
	var 身: Dictionary = (会话 as Node).get("player_stats")
	## ⚠ 自己号**先问后端**（`character_id` 是登录/选角后一定有的权威值）；
	##   会话 `player_stats` 里不一定有 `id` 这个键 —— 猜错就是 `filterMyself` 静默失效
	##   （左侧面板里出现自己那一格），这条在组队在线门里被实测抓到过。
	自己号 = int(后端.get("character_id")) if 后端 != null else -1
	if 自己号 <= 0:
		自己号 = int(身.get("id", -1))
	自己名 = String(身.get("name", ""))
	_读本地开关()
	接线(页)
	## 面板是**常驻浮窗**，不跟开窗走（见 `_同步面板`）。这里只把宿主补上给点格用。
	队伍面板脚本.宿主 = 主
	_挂后端()
	_回灌()
	切页(页序)
	# TroopWindow2.initWindow:180-186 —— 开窗时如果身上已经有队伍状态，立刻重绘一次
	if 成员.size() > 0:
		上成员(成员)
	else:
		_同步面板()
	_拉一次()
	return 页


static func 新会话() -> void:
	# 登录/换号：原版单例是新建的 ⇒ 这里把会话级状态清干净（**不要**在关窗时调）
	队号 = 0
	队长号 = 0
	队名 = ""
	成员 = []
	选格 = -1
	格字典 = {}
	副本中 = false
	附近队 = []
	附近人 = []
	搜中 = []
	队页序 = 0
	人页序 = 0
	收过帧 = 0
	队伍面板脚本.清()


static func _读本地开关() -> void:
	## `MyTroopPane.init:115-117` 三份本地配置：两枚走 CharacterConfig（本工程 = 存档里的
	## `界面开关`），第三枚走 SysCfg.hideTroopInfoPane（**取反**）。
	var 存: Dictionary = (会话 as Node).get("界面开关") if (会话 as Node).get("界面开关") is Dictionary else {}
	自动接受邀请 = bool(存.get("troop_auto_accept_invite", false))
	自动接受申请 = bool(存.get("troop_auto_accept_apply", false))
	藏面板 = bool(存.get("hide_troop_info_pane", false))


static func _写本地开关() -> void:
	var 存: Dictionary = (会话 as Node).get("界面开关") if (会话 as Node).get("界面开关") is Dictionary else {}
	存["troop_auto_accept_invite"] = 自动接受邀请
	存["troop_auto_accept_apply"] = 自动接受申请
	存["hide_troop_info_pane"] = 藏面板
	(会话 as Node).set("界面开关", 存)
	if 会话.has_method("保存本地状态"):
		会话.call("保存本地状态")


static func _查当前页() -> void:
	## 原版没有"开窗就查"，只有**切页**才查（`:93-97` / `:167-171`）；开窗那一刻页序是 0
	## ⇒ 页 0 什么都不发，页 1/2 各发自己那一条。
	match 页序:
		1:
			_发查队()
		2:
			_发搜索()
		_:
			pass


static func _回灌() -> void:
	## ★ 建队/入队那几帧往往在**开窗之前**就到了（玩家点「组队」之前就已经在队里）。
	## 原版靠 `DataCenter.partyStatus` 这个常驻单例顶着，`TroopWindow2.initWindow:180-186`
	## 开窗时再 `updataTroopStatus(partyStatus)` 重绘一次。我们这边状态在后端镜像里
	## （`后端连接.authoritative_party`）⇒ 开窗时**按镜像回灌**一次，否则"开窗前组好队、开窗是空的"。
	if 后端 == null:
		return
	var 包 = 后端.get("authoritative_party")
	if not (包 is Dictionary) or (包 as Dictionary).is_empty():
		return
	var 员: Array = (包 as Dictionary).get("members", [])
	if 员.is_empty():
		return
	if not 成员.is_empty():
		return
	var 字符: Array = []
	for 行 in 员:
		var 人: Dictionary = 行
		字符.append({
			"partyCharId": int(人.get("character_id", 0)), "partyCharName": String(人.get("name", "")),
			"jobId": int(人.get("job", 0)), "level": int(人.get("level", 0)),
			"familly": String(人.get("family", "")), "channelIndex": int(人.get("channel_id", 1)) - 1,
			"mapId": int(人.get("map_id", 0)), "face": int(人.get("face", 0)),
		})
	上成员([])		# 先把页清干净（原版 setData 第一步就是 removeData）
	_上队伍({"party_id": int((包 as Dictionary).get("id", 0)),
		"leader_id": int((包 as Dictionary).get("leader_id", 0)),
		"party_name": String((包 as Dictionary).get("name", "")), "characters": 字符})


## ★ 全局挂载（登录/进图时由 `窗口管理._ready` 调一次）。
## 原版这套是**全局单例**：`CueManage` 常驻、`PartyProcessor` 一收到就 `addMsg` 进托盘，
## 跟"你打没打开组队窗"毫无关系。我们第一版把监听只写在 `渲染()` 里 ⇒ **没开过组队页的人
## 永远收不到邀请**（实机症状：对面点了邀请，这边什么都没发生）。2026-10-25 实机报障后修正。
static func 挂全局(后: Node) -> void:
	后端 = 后
	if 后端 == null or not 后端.has_signal("party_state_received"):
		return
	if not _已连(后端, "party_state_received", "服务端队伍帧"):
		后端.connect("party_state_received", 服务端队伍帧, CONNECT_PERSIST)
	if not _已连(后端, "party_member_stats_received", "服务端成员属性帧"):
		后端.connect("party_member_stats_received", 服务端成员属性帧, CONNECT_PERSIST)


static func _拉一次() -> void:
	## 原版没有"开窗就查"这一步（切页才查），这边把**当前页**该查的那一条发出去：
	## 页 1 → `120:10`（QUERY_PARTY_ON_MAP）；页 2 → 1282 searchId=3（不是 120！）。
	_查当前页()


## ══════════════ 页签（selectedBtnHandler:252-282）══════════════
static func 接线(窗: Control) -> void:
	var 签: Control = 窗.get_node("分页") as Control
	for i in 签.get_child_count():
		var 钮: Button = 签.get_child(i) as Button
		钮.button_pressed = (i == 页序)
		钮.pressed.connect(切页.bind(i))
	_接我的队伍(窗)
	_接附近队伍(窗)
	_接附近玩家(窗)


static func 切页(序: int) -> void:
	页序 = 序
	if 页 == null or not is_instance_valid(页):
		return
	var 签: Control = 页.get_node("分页") as Control
	for i in 签.get_child_count():
		(签.get_child(i) as Button).button_pressed = (i == 序)
	# 原版是 removeAllChild + 只 add 当前页（:254）⇒ 这边等价：**只有当前页 visible**
	for 名 in ["我的队伍", "附近队伍", "附近玩家", "我的羁绊", "酒宴列表"]:
		var 体: Control = 页.get_node_or_null("内容区/" + 名) as Control
		if 体 != null:
			体.visible = (["我的队伍", "附近队伍", "附近玩家", "我的羁绊", "酒宴列表"].find(名) == 序)
	# `BaseUtil.removeAllChild` 之后每个 case 都调 `dolayout()`；三页内容同尺寸 ⇒ 窗体尺寸不变。
	页.size = Vector2(页宽计算(), 页根高())
	match 序:
		1:
			# :93-97 —— 没有数据才去查（有数据不重发）
			if 附近队.is_empty():
				_发查队()
			画附近队伍()
		2:
			# :167-171 同上
			if 附近人.is_empty():
				_发查人()
			画附近玩家()
		3:
			# :174-178 showNearConsortPane：`Friend_requestTaInfo()` + `isSelectTab3 = true`
			# ⇒ 内容属 羁绊 族（#263），这里只发那一查、不画自造的东西
			if 后端 != null and 后端.has_method("request_bond_info"):
				后端.call("request_bond_info")
		4:
			# :275-280 showMarryListPane + updateMarryList([]) + requestMarryList()
			pass
		_:
			上成员(成员)


static func 页宽计算() -> float:
	return 489.0 + 26.0		# dolayout:401 `_currentPane.width + 26`


static func 页高计算() -> float:
	## `dolayout:397-403` 的**整窗高**：356 + `_contentPane.y`(63) + 13 = 432。
	## ⚠ 别拿它去设页根：页根装在宿主的页面容器里（原点已在标题栏下 29 处），
	##   页根高 = 432 − 29 = 403，见 `页根高()`。混用会把底部按钮推出窗外。
	return 356.0 + 63.0 + 13.0


static func 页根高() -> float:
	return 页高计算() - 29.0


## ══════════════ 我的队伍（MyTroopPane）══════════════
static func _接我的队伍(窗: Control) -> void:
	var 体: Control = 窗.get_node("内容区/我的队伍") as Control
	for i in 6:
		var 格: Button = 体.get_node("成员格%d" % (i + 1)) as Button
		格.pressed.connect(_点格.bind(i))
		格.mouse_entered.connect(_格悬停.bind(i, true))
		格.mouse_exited.connect(_格悬停.bind(i, false))
		格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND	# :122 buttonMode
	for i in 3:
		var 勾: CheckBox = 体.get_node("勾选%d" % (i + 1)) as CheckBox
		勾.set_pressed_no_signal([自动接受邀请, 自动接受申请, not 藏面板][i])
		勾.add_theme_color_override("font_color", 色白)		# Godot 4 的 CheckBox 没有 get_label()
		勾.toggled.connect(_点勾.bind(i))
	var 保: Button = 体.get_node("修改宣言钮") as Button
	保.pressed.connect(_存宣言)
	(体.get_node("自我退队") as Button).pressed.connect(_点退队)
	(体.get_node("添加成员") as Button).pressed.connect(_点添加)
	(体.get_node("自建队伍") as Button).pressed.connect(_点自建)
	(体.get_node("任命队长") as Button).pressed.connect(_点任命)
	(体.get_node("请离队伍") as Button).pressed.connect(_点请离)
	(体.get_node("查看资料") as Button).pressed.connect(_点查资料)


static func _点格(序: int) -> void:
	## `__setSelectedCell:264-274`：先把旧选中底关掉，再把这一格设成选中，最后刷按钮使能。
	选格 = 序
	画选中底()
	使能按钮()


static func _格悬停(序: int, 进: bool) -> void:
	## `:62-65 / :131-134` 只切 mouseOverBg.visible，不动 selectedBg。
	if 页 == null or not is_instance_valid(页):
		return
	var 底: Control = 页.get_node("内容区/我的队伍/成员格%d/悬停底" % (序 + 1)) as Control
	底.visible = 进


static func 画选中底() -> void:
	if 页 == null or not is_instance_valid(页):
		return
	for i in 6:
		var 底: Control = 页.get_node("内容区/我的队伍/成员格%d/选中底" % (i + 1)) as Control
		底.visible = (i == 选格)


static func _点勾(序: int) -> void:
	var 勾: CheckBox = 页.get_node("内容区/我的队伍/勾选%d" % (序 + 1)) as CheckBox
	match 序:
		0:
			自动接受邀请 = 勾.button_pressed		# :439-443
			_写本地开关()
		1:
			自动接受申请 = 勾.button_pressed		# :258-262
			_写本地开关()
		2:
			## `__setTroopHPPaneVisible:357-360`：`hideTroopInfoPane = !checkBox3.selected`
			## ⇒ 勾上 = **显示**面板。改完立刻重算面板在不在（原版靠 SysCfg 里那道回调）。
			藏面板 = not 勾.button_pressed
			_写本地开关()
			上成员(成员)


static func _存宣言() -> void:
	## `__saveManifesto:320-333`：长度 `0 < len <= 9` 才发 `120:8`，否则那句提示。
	var 文: LineEdit = 页.get_node("内容区/我的队伍/宣言输入") as LineEdit
	var 串 := 文.text
	if 串.length() > 0 and 串.length() <= 宣言上限:
		_上行(8, 串)
	else:
		_提示(文案["请输入宣言"])


static func _点自建() -> void:
	## `sureToCreate:106-110` → `120:1`，**不带任何参数**（PacketCreator:342-347）。
	_上行(1)


static func _点退队() -> void:
	_上行(2)						# requestLeaveParty:412-416


static func _点添加() -> void:
	## `sureToAddMember:95-104`：原版开的是**选人子窗**（searchType=2 = `UIConfig.SELECT_PLAYER_2`，
	## 且那颗多功能钮写「邀请入队」）。本工程的选人窗是按页私有的（好友/双修各一份），
	## 组队这一份（searchId=2、会随主窗拖动并进/弹出）**还没做** ⇒ 先落到「附近玩家」页：
	## 那一页的「邀请组队」发的是同一句上行 `120:4:<名字>`，字节与原版一致。
	切页(2)


static func _点选人邀请入队(行: Dictionary) -> void:
	## `__inviteJoinTroop:428-437`：INVITE + charName → `120:4:<名字>`
	if 行.is_empty():
		return
	_上行(4, String(行.get("name", "")))


static func _点任命() -> void:
	## `sureToChangeLeader:445-448`：**先弹确认**（OK|CANCEL），文案带选中格的名字。
	if 选格 < 0 or 选格 >= 成员.size():
		return
	var 行: Dictionary = 成员[选格]
	_确认(文案["移交确认"].replace("%1", String(行.get("name", ""))), func(是: bool):
		if 是:
			_上行(6, int(行.get("id", 0)))	# CHANGE_CAPTAIN → requestChangeLeader → 120:6
	)


static func _点请离() -> void:
	## `sureToKick:385-390`：**没有确认弹**，直接发 `120:5:<角色号>`。
	if 选格 < 0 or 选格 >= 成员.size():
		return
	_上行(5, int((成员[选格] as Dictionary).get("id", 0)))


static func _点查资料() -> void:
	## `__showCharInfo:238-244`：`API.ui.clickCharacter(选中.id)`
	if 选格 < 0 or 选格 >= 成员.size():
		return
	宿主.call("_查看角色资料", int((成员[选格] as Dictionary).get("id", 0)))


static func _稳定排(数组: Array, 键: String) -> Array:
	## AS3 `sortOn(键, Array.DESCENDING)` 是**稳定**降序。Godot 的 sort_custom 不保证稳定
	## ⇒ 用「值优先、原序次之」的比较式，等价于稳定降序。
	var 带序: Array = []
	for i in 数组.size():
		带序.append([数组[i], i])
	带序.sort_custom(func(a, b):
		var va = (a[0] as Dictionary).get(键, false)
		var vb = (b[0] as Dictionary).get(键, false)
		if bool(va) != bool(vb):
			return bool(va)
		return a[1] < b[1])
	var 出: Array = []
	for 项 in 带序:
		出.append(项[0])
	return 出


static func 上成员(名单: Array) -> void:
	## `setData:288-302`：先 removeData，再**两次 sortOn**（isOnline 先、isCaptain 后 ⇒ 队长为主键），
	## 然后逐格塞，最后 updateManifesto。
	成员 = 名单
	_同步面板()
	if 页 == null or not is_instance_valid(页):
		return
	var 排 := 排过序()
	格字典 = {}
	for i in 6:
		var 格: Control = 页.get_node("内容区/我的队伍/成员格%d" % (i + 1)) as Control
		if i < 排.size():
			var 行: Dictionary = 排[i]
			格字典[int(行.get("id", 0))] = i
			塞一格(格, 行)
		else:
			空格(格)
	选格 = -1
	画选中底()
	(页.get_node("内容区/我的队伍/宣言输入") as LineEdit).text = 队名
	使能按钮()


static func _刷新自己() -> void:
	## 队伍帧可能**早于开窗**到（点邀请前就已经入队）⇒ 那时 `渲染()` 还没跑过，
	## `自己号` 还是默认 -1 ⇒ `filterMyself` 失效、面板里会多出自己那一格。
	## 后端 `character_id` 是登录/选角后的权威值，每次同步面板前现取。
	if 后端 != null:
		var 号 := int(后端.get("character_id"))
		if 号 > 0:
			自己号 = 号
	if 会话 != null and is_instance_valid(会话):
		var 身 = 会话.get("player_stats")
		if 身 is Dictionary:
			自己名 = String((身 as Dictionary).get("name", 自己名))


static func _同步面板() -> void:
	## `UI.updataTroopStatus:2113-2133` 第 5 步：**跟开没开组队窗无关**。
	## 原版每次队伍状态更新都做：成员 > 1 且没勾「主界面显示队员头像清单」的隐藏
	## ⇒ 打开/重填 TroopHPPane；否则 removeData。
	## ⚠ 以前面板只在 `渲染()` 里建 ⇒ 玩家不点开组队页就永远看不到左侧队友条
	##   （2026-10-25 实机：图1/2 原版默认就有，图3/4 我们的要点开页面才出）。
	_刷新自己()
	if 队伍面板脚本.我号 != 自己号:
		队伍面板脚本.拆()		# 我号变了 ⇒ 旧的 filterMyself 结果作废，重建
	if 成员.size() > 1 and not 藏面板:
		if not 队伍面板脚本.出现着():
			var 层 := _面板层()
			if 层 == null:
				return
			队伍面板脚本.建(宿主, 层, 自己号)
		队伍面板脚本.上成员(排过序())
	else:
		队伍面板脚本.清()


static func _面板层() -> Node:
	## 面板是**常驻 HUD 浮窗**（原版挂 UI content，不跟组队窗生命周期走）。
	## 开过页 ⇒ 复用宿主自己的浮层；没开过 ⇒ 挂 `窗口管理`（CanvasLayer 110）。
	if 宿主 != null and is_instance_valid(宿主):
		var 浮层 = 宿主.get("_overlay")
		if 浮层 is Node:
			return 浮层
	var 树 := Engine.get_main_loop() as SceneTree
	if 树 == null:
		return null
	## 按组找，不按节点名：测试里连着实例化两扇窗口管理时，第二个会被 Godot 自动改名。
	var 管理 := 树.get_first_node_in_group("窗口管理")
	if 管理 != null:
		return 管理
	return 树.root.find_child("窗口管理", true, false)


static func 排过序() -> Array:
	var 步 := _稳定排(成员.duplicate(), "在线")
	return _稳定排(步, "队长")


static func 塞一格(格: Control, 行: Dictionary) -> void:
	(格.get_node("名字") as Label).text = String(行.get("name", ""))
	# :45 `CN.CHARACTOR_LEVEL + "：" + level` —— **全角冒号**，不是半角
	(格.get_node("等级") as Label).text = "%s：%d" % [文案["等级字"], int(行.get("level", 0))]
	# :70 `"【" + StringTool.getMapString(mapId) + "】"`
	(格.get_node("地图") as Label).text = "【%s】" % _图名(int(行.get("map_id", 0)))
	(格.get_node("队长") as Label).text = 文案["队长"] if bool(行.get("队长", false)) else ""
	var 头像: TextureRect = 格.get_node("头像盒/头像") as TextureRect
	var 脸 := int(行.get("face", 0))
	头像.visible = 脸 > 0
	if 脸 > 0:
		var 号 := 角色造型.造型号(脸, int(行.get("gender", 1)))
		头像.texture = OriginalSprite.portrait("character", 号)
	# :168 `portraitBg.filters = isOnline ? null : getDisableFilter()` —— **只看在线，不看同图**
	var 盒 := 格.get_node("头像盒") as Control
	盒.self_modulate = Color(1, 1, 1)
	盒.material = null if bool(行.get("在线", false)) else 队伍面板脚本.灰度材质()


static func 空格(格: Control) -> void:
	for 名 in ["名字", "等级", "地图", "队长"]:
		(格.get_node(名) as Label).text = ""
	(格.get_node("头像盒/头像") as TextureRect).texture = null
	(格.get_node("头像盒/头像") as TextureRect).visible = false
	var 盒 := 格.get_node("头像盒") as Control
	盒.self_modulate = Color(1, 1, 1)
	盒.material = null


static func 使能按钮() -> void:
	## `setBtnsEnabled:461-498` 三分支，条件顺序原样搬。
	if 页 == null or not is_instance_valid(页):
		return
	var 体: Control = 页.get_node("内容区/我的队伍") as Control
	var 输入: LineEdit = 体.get_node("宣言输入") as LineEdit
	var 保: Button = 体.get_node("修改宣言钮") as Button
	var 建: Button = 体.get_node("自建队伍") as Button
	var 退: Button = 体.get_node("自我退队") as Button
	var 加: Button = 体.get_node("添加成员") as Button
	var 任: Button = 体.get_node("任命队长") as Button
	var 踢: Button = 体.get_node("请离队伍") as Button
	var 查: Button = 体.get_node("查看资料") as Button
	var 有队 := not 成员.is_empty()
	var 是队长 := 是队长号(自己号)
	var 选中行 := (成员[选格] as Dictionary) if (选格 >= 0 and 选格 < 成员.size()) else {}
	if 副本中:
		输入.editable = false
		保.disabled = true
		加.disabled = true
		任.disabled = true
		踢.disabled = true
		查.disabled = true
		if 有队:
			建.visible = false
			退.visible = true
			加.visible = true
			任.visible = true
			踢.visible = true
			查.visible = true
			退.disabled = false
		else:
			建.disabled = true
			建.visible = true
			退.disabled = true
			退.visible = false
			加.visible = false
			任.visible = false
			踢.visible = false
			查.visible = false
	elif 有队:
		输入.editable = 是队长
		保.disabled = not 是队长
		建.visible = false
		退.disabled = false
		加.disabled = not (是队长 and 成员.size() < 上限)
		var 可动 := (not 选中行.is_empty()) and int(选中行.get("id", -1)) != 自己号 and 是队长
		任.disabled = not 可动
		踢.disabled = not 可动
		查.disabled = not ((not 选中行.is_empty()) and int(选中行.get("id", -1)) != 自己号)
		退.visible = true
		加.visible = true
		任.visible = true
		踢.visible = true
		查.visible = true
	else:
		输入.editable = false
		建.visible = true
		保.disabled = true
		退.visible = false
		加.visible = false
		任.visible = false
		踢.visible = false
		查.visible = false


static func 是队长号(号: int) -> bool:
	## `DataCenter.isPartyLeader:280-283` = `isInTroop(号) && partyStatus && 号 == leaderId`
	return 在队(号) and 队号 > 0 and 号 == 队长号


static func 在队(号: int) -> bool:
	## `DataCenter.isInTroop:792+`：partyStatus 为空 ⇒ false；否则在成员里按 **id** 找。
	if 队号 <= 0:
		return false
	for 行 in 成员:
		if int((行 as Dictionary).get("id", -1)) == 号:
			return true
	return false


static func _换队长格(新队长号: int) -> void:
	## `changeTroopCaptain:304-318`：**不是重排**，是把「队长那一格」与「新队长那一格」
	## 的 data **deepClone 后互换**，并同步 `_dataDic` ⇒ 视觉上两格内容对调、队长字跟着走。
	var 旧队长格 := -1
	for 键 in 格字典.keys():
		var 行 = 成员[int(格字典[键])] if int(格字典[键]) < 成员.size() else null
		if 行 != null and bool((行 as Dictionary).get("队长", false)):
			旧队长格 = int(格字典[键])
			break
	if 旧队长格 < 0 or not 格字典.has(新队长号):
		return
	var 新格 := int(格字典[新队长号])
	var 甲: Dictionary = (成员[旧队长格] as Dictionary).duplicate(true)
	var 乙: Dictionary = (成员[新格] as Dictionary).duplicate(true)
	乙["队长"] = true
	甲["队长"] = false
	成员[旧队长格] = 乙
	成员[新格] = 甲
	格字典[int(乙.get("id", 0))] = 旧队长格
	格字典[int(甲.get("id", 0))] = 新格


## ══════════════ 附近队伍（NearTroopsPane）══════════════
static func _接附近队伍(窗: Control) -> void:
	var 体: Control = 窗.get_node("内容区/附近队伍") as Control
	(体.get_node("刷新列表钮") as Button).pressed.connect(_发查队)
	(体.get_node("申请入队钮") as Button).pressed.connect(_点申请)
	for i in 队伍每页:
		var 行: Button = 体.get_node("队伍行%d" % (i + 1)) as Button
		行.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		行.pressed.connect(_点队伍行.bind(i))


static func _点队伍行(序: int) -> void:
	## `__selectTroop:187-191`：`memberList.dataProvider = item.members`；
	## `applyBtn.enabled = !isInTroop(自己)`。序是**页内序**，要加回页偏移。
	var 全 := 队页序 * 队伍每页 + 序
	if 全 >= 附近队.size():
		return
	选中队 = 全
	画附近队伍成员(附近队[全])
	(页.get_node("内容区/附近队伍/申请入队钮") as Button).disabled = 在队(自己号)


static var 选中队 := -1


static func _点申请() -> void:
	## `srueToApply:58-72`：先判**这一队**人数 < 6，超了只提示；没超就把申请钮禁用再发 `120:11`。
	if 选中队 < 0:
		return
	var 队: Dictionary = 附近队[选中队] if 选中队 < 附近队.size() else {}
	var 员: Array = (队.get("members", []) as Array)
	if 员.size() > 0 and 员.size() < 上限:
		(页.get_node("内容区/附近队伍/申请入队钮") as Button).disabled = true
		_上行(11, int(队.get("troopId", 0)))		# PARTYMEMBER_APPLICATION
	else:
		_提示(文案["该队满了"])			# TROOP_MEMBER_MAX


static func _发查队() -> void:
	## `TroopWindowEvent.REQUEST_NEAR_TROOPS` → UI:1440-1443 → `requestQueryPartyInMap()` = `120:10`
	var 钮: Button = 页.get_node("内容区/附近队伍/刷新列表钮") as Button if 页 != null else null
	_上行(10)
	if 钮 != null:
		钮.disabled = true				# `__refresh:74-81` 发完先把刷新钮按下去


static func 画附近队伍() -> void:
	if 页 == null or not is_instance_valid(页):
		return
	var 体: Control = 页.get_node("内容区/附近队伍") as Control
	(体.get_node("刷新列表钮") as Button).disabled = false
	(体.get_node("左表题") as Label).text = 文案["队伍列表题"]
	(体.get_node("右表题") as Label).text = 文案["队伍成员题"]
	var 起 := 队页序 * 队伍每页
	for i in 队伍每页:
		var 行: Button = 体.get_node("队伍行%d" % (i + 1)) as Button
		var 序 := 起 + i
		行.visible = 序 < 附近队.size()
		(行.get_node("选中底") as Control).visible = (序 == 选中队)
		if not 行.visible:
			continue
		var 队: Dictionary = 附近队[序]
		var 员: Array = (队.get("members", []) as Array)
		(行.get_node("宣言") as Label).text = String(队.get("manifesto", ""))
		(行.get_node("队长") as Label).text = String(队.get("leaderName", ""))
		(行.get_node("等级") as Label).text = str(int(队.get("averageLevel", 0)))
		# :250 `members.length + "/" + TROOP_MAX_NUM` ⇒ 形如「2/6」
		(行.get_node("人数") as Label).text = "%d/%d" % [员.size(), 上限]
	画附近队伍成员(附近队[选中队] if (选中队 >= 0 and 选中队 < 附近队.size()) else {})


static func 画附近队伍成员(队: Dictionary) -> void:
	if 页 == null or not is_instance_valid(页):
		return
	var 体: Control = 页.get_node("内容区/附近队伍") as Control
	var 员: Array = (队.get("members", []) as Array)
	for i in 成员每页:
		var 行: Control = 体.get_node("成员行%d" % (i + 1)) as Control
		行.visible = i < 员.size()
		if not 行.visible:
			continue
		var 人: Dictionary = 员[i]
		(行.get_node("名称") as Label).text = String(人.get("name", ""))
		(行.get_node("等级") as Label).text = str(int(人.get("level", 0)))
		(行.get_node("职业") as Label).text = _职业名(int(人.get("jobId", 人.get("job", 0))))


## ══════════════ 附近玩家（NearCharsPane）══════════════
static func _接附近玩家(窗: Control) -> void:
	var 体: Control = 窗.get_node("内容区/附近玩家") as Control
	(体.get_node("刷新列表钮") as Button).pressed.connect(_发查人)
	(体.get_node("查看资料钮") as Button).pressed.connect(_点人查资料)
	(体.get_node("邀请组队钮") as Button).pressed.connect(_点人邀请)
	(体.get_node("搜索钮") as Button).pressed.connect(_点搜索)
	for i in 玩家每页:
		var 行: Button = 体.get_node("玩家行%d" % (i + 1)) as Button
		行.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		行.pressed.connect(_点人行.bind(i))


static var 选人行 := -1


static func _发查人() -> void:
	## `REQUEST_NEAR_CHARS` → UI:1534-1537 → `requestCharSearchInMapWithoutParty(3)`
	## → `requestCharSearchInMap(3, {partyId:-1})` → **1282**（不是 120）。
	## ⚠ 原版那个第二参数在 `Client.as:8514-8519` **被丢掉**了（只把 param1 传给 processor）
	##   ⇒ "排除有队的人"这条过滤**压根没送到服务端**。这边照搬：发的是 searchId=3，不自造过滤位。
	上行(0, "", 1282) if false else _发搜索()


static func _发搜索() -> void:
	if 后端 != null and 后端.has_method("request_char_search"):
		后端.call("request_char_search", "", 1, 3)		# searchId=3 = 这一页
		var 钮: Button = 页.get_node("内容区/附近玩家/刷新列表钮") as Button if 页 != null else null
		if 钮 != null:
			钮.disabled = true


static func _点搜索() -> void:
	## `__search:149-173`：**纯客户端过滤**，不发任何包。关键词为空 ⇒ 什么都不做。
	var 词: String = (页.get_node("内容区/附近玩家/关键词") as LineEdit).text
	if 词.length() == 0:
		return
	搜中 = []
	for 行 in 附近人:
		if String((行 as Dictionary).get("charName", "")).find(词) != -1:
			搜中.append(行)
	人页序 = 0
	if 搜中.size() == 0:
		_提示(文案["没找到符合条件"])
	else:
		画附近玩家()
	(页.get_node("内容区/附近玩家/刷新列表钮") as Button).disabled = false


static func _点人行(序: int) -> void:
	## `__selectChar:201-212`：查看资料恒启用；邀请组队只在「不在队」或「是队长且队未满」时启用。
	var 实 := 人列表()
	var 全 := 序 + 人页序 * 玩家每页
	if 全 >= 实.size():
		return
	选人行 = 全
	var 自: Button = 页.get_node("内容区/附近玩家/查看资料钮") as Button
	自.disabled = false
	(页.get_node("内容区/附近玩家/邀请组队钮") as Button).disabled = not (
		not 在队(自己号) or (是队长号(自己号) and 成员.size() < 上限))


static func _点人查资料() -> void:
	## `__showCharInfo:242-245` → `clickCharacter(charsList.selectedItem.charId)`
	var 行 := _当前人行()
	if 行.is_empty():
		return
	宿主.call("_查看角色资料", int(行.get("charId", 0)))


static func _点人邀请() -> void:
	## `__invite:222-227` → INVITE + charName → `120:4`
	var 行 := _当前人行()
	if 行.is_empty():
		return
	_上行(4, String(行.get("charName", "")))


static func _当前人行() -> Dictionary:
	var 实 := 人列表()
	if 选人行 < 0 or 选人行 >= 实.size():
		return {}
	return 实[选人行]


static func 人列表() -> Array:
	## `requestData:214-220`：`_searchData.length == 0 ? _data : _searchData`
	return 搜中 if 搜中.size() > 0 else 附近人


static func 画附近玩家() -> void:
	if 页 == null or not is_instance_valid(页):
		return
	var 体: Control = 页.get_node("内容区/附近玩家") as Control
	(体.get_node("刷新列表钮") as Button).disabled = false
	(体.get_node("搜索标签") as Label).text = 文案["搜索提示"]
	var 实 := 人列表()
	var 起 := 人页序 * 玩家每页
	for i in 玩家每页:
		var 行: Button = 体.get_node("玩家行%d" % (i + 1)) as Button
		var 序 := 起 + i
		行.visible = 序 < 实.size()
		(行.get_node("选中底") as Control).visible = (序 == 选人行)
		if not 行.visible:
			continue
		var 人: Dictionary = 实[序]
		(行.get_node("名字") as Label).text = String(人.get("charName", ""))
		(行.get_node("等级") as Label).text = str(int(人.get("charLevel", 0)))
		(行.get_node("职业") as Label).text = _职业名(int(人.get("jobId", 0)))
		# :29-30 家族/称号为空 ⇒ 打「−」（**不是**空串，也不是「无」）
		var 族 := String(人.get("banghuiName", ""))
		(行.get_node("家族") as Label).text = 族 if 族 != "" else "−"
		var 号 := String(人.get("charTitle", ""))
		(行.get_node("称号") as Label).text = 号 if 号 != "" else "−"


## ══════════════ 回帧（RelationShipHandler + UI.updataTroopStatus）══════════════
static func _挂后端() -> void:
	if 后端 == null:
		return
	if not (后端.get_signal_connection_list("party_state_received").size() > 0
			and _已连(后端, "party_state_received", "服务端队伍帧")):
		后端.connect("party_state_received", 服务端队伍帧, CONNECT_PERSIST)
	if not _已连(后端, "party_member_stats_received", "服务端成员属性帧"):
		后端.connect("party_member_stats_received", 服务端成员属性帧, CONNECT_PERSIST)


static func _同步队长标() -> void:
	## 对应原版那四处 `charactorInfoPane.setTroopCaptainIcon()/removeTroopCaptainIcon()`
	## （`RelationShipHandler.as:56/60` 换队长、`:120` 建队、`:286` `removeTroopHPPane` = 离队/解散/被踢）。
	## ⚠ 不靠静态字段 `会话`：它只在 `渲染()`（开过组队页）之后才有值，而建队/离队恰恰可能
	##   发生在页没开的时候 ⇒ 和 `加托盘` 一样按名字找会话单例。`队伍窗` 不在场景里时静默跳过，
	##   帧照样记账在 `队长标应显` 上（HUD `_ready` 会自读）。
	var 树 := Engine.get_main_loop() as SceneTree
	if 树 == null:
		return
	var 会 := 树.root.get_node_or_null("GameSession")
	if 会 != null and 会.has_signal("队长标_changed"):
		会.emit_signal("队长标_changed", 队长标应显)


static func _已连(节: Node, 信号名: String, 方法名: String) -> bool:
	for c in 节.get_signal_connection_list(信号名):
		if String((c.get("callable") as Callable).get_method()) == 方法名:
			return true
	return false


static func 服务端队伍帧(state: Dictionary) -> void:
	## 这里是 `PartyProcessor.handlePartyOperationPacket` 那张 switch 的落点：
	## **动作号决定做什么**，不许只看 state 里有没有 party。
	收过帧 += 1
	var 动作 := int(state.get("action", -1))
	match 动作:
		4:
			_队伍邀请(state)		# → RelationShipHandler.onPartyInvite:196-210
		8:
			_队伍建好(state)		# → onPartyCreated:95-125
		12:
			_队伍解散(state)		# → onPartyDisband:248-257
		13:
			_队伍踢人(state)		# → onPartyExpel:259-277
		14:
			_队伍离人(state)		# → onPartyLeave:218-236
		15:
			_队伍进人(state)		# → onPartyJoin:238-246
		19:
			_队伍改名帧(state)		# → Client.onUpdatePartyName:9766-9777
		26:
			_队伍移交(state)		# → onPartyChangeLeader:36-62
		36:
			_附近队帧(state)		# → Client.onShowPartiesOnMap:4472+
		38:
			_入队申请(state)		# → Client.onPartyApplication:6900-6913
		37:
			_提示(_填(文案["拒绝申请"], String(state.get("applicant_name", ""))))
		23:
			_提示(String(state.get("char_name", "")) + 文案["拒绝邀请"])
		17:
			_提示(文案["队伍已满"])
		18:
			_提示(文案["没找到该玩家"])
		7:
			## `onPartySilentUpdateLogOnOff:212-216` = updatePartyStatus + updataTroopStatus，
			## **不弹任何提示**
			_换算队伍(state.get("party") as Dictionary)
			上成员(成员)
		16, 27, 35, 39:
			## 原版这四档都是空函数 ⇒ 什么都不做（见文件头 ★③）。
			pass
		_:
			pass


static func 服务端成员属性帧(角色号: int, 当前hp: int, 最大hp: int, 当前mp: int, 最大mp: int) -> void:
	## `RelationShipHandler.onUpdatePartyMemberStats:82-93`：
	##   ① 面板存在 ⇒ `updateSingleData(...)`；② **不是自己** ⇒ 改场上那具实体的血条。
	## 原版这一帧只进 `TroopHPPane.updateSingleData`（面板那格）+ 场上实体的血条；
	## 队伍行本身不显示血蓝。这边把四个数**同时记进行里**（等价于 `PartyMemberStats` 那份缓存），
	## 面板那一格再画 —— 两处同一个来源，不会打架。
	for 行 in 成员:
		if int((行 as Dictionary).get("id", 0)) == 角色号:
			(行 as Dictionary)["hp"] = 当前hp
			(行 as Dictionary)["maxHp"] = 最大hp
			(行 as Dictionary)["mp"] = 当前mp
			(行 as Dictionary)["maxMp"] = 最大mp
			break
	队伍面板脚本.改血蓝(角色号, 当前hp, 最大hp, 当前mp, 最大mp)
	if 角色号 != 自己号:
		_改场上实体血条(角色号, 当前hp, 最大hp)


static func _改场上实体血条(角色号: int, 当前hp: int, 最大hp: int) -> void:
	## `CharacterHandler.setCharHp`：地图场景里那具实体在不在由地图侧自己判，
	## 这边只把这一帧转过去（`地图实体._on_party_member_stats` 已在收同一条信号）。
	## ★ 这条**故意不做任何事**：真值里它只影响场上血条，而场上血条那侧已经直连后端信号；
	##   在这里重复驱动 = 两条路改同一个值（挂机轮踩过）。留函数是为了让门能断言"只有一条驱动"。
	pass


static func _换算队伍(包: Dictionary) -> void:
	## `UI.updataTroopStatus:2082-2111` 的换算，一条一条照：
	##   isCaptain = (partyCharId == leaderId)；isOnline = (channelIndex != -2)；
	##   isInSameMap = 自己恒真，别人 = checkInSameMap（见文件头那条口径替换）；gender 硬编码 1；
	##   manifesto = partyName（**宣言和队名是同一个字段**）。
	##   并且**只收 partyCharId > 0** 的行。
	if 包.is_empty():
		队号 = 0
		队长号 = 0
		队名 = ""
		成员 = []
		return
	队号 = int(包.get("party_id", 0))
	队长号 = int(包.get("leader_id", 0))
	队名 = String(包.get("party_name", ""))
	var 出: Array = []
	var 我图 := int(会话.call("自身外观").get("map_id", 0)) if _会(会话, "自身外观") else 0
	## 线路号 = 后端的 `channel_id`（1 起）。旧代码读 `line_id` —— 这个属性后端根本没有
	## ⇒ 恒为 0，所有在线队友都被算成"不同图"而灰掉（实机图2 头像发暗就是这个）。
	var 线值 = 后端.get("channel_id") if 后端 != null else null
	var 我线 := int(线值) if 线值 != null else 0
	for 原 in (包.get("characters", []) as Array):
		var 行: Dictionary = 原
		var 号 := int(行.get("partyCharId", 0))
		if 号 <= 0:
			continue
		var 通道 := int(行.get("channelIndex", 离线通道))
		出.append({
			"id": 号, "name": String(行.get("partyCharName", "")), "face": int(行.get("face", 0)),
			"gender": 1,					# UI.as:2097 硬编码
			"level": int(行.get("level", 0)), "jobId": int(行.get("jobId", 0)),
			"family": String(行.get("familly", "")), "map_id": int(行.get("mapId", 0)),
			"队长": 号 == 队长号, "在线": 通道 != 离线通道,
			"在同图": (号 == 自己号) or (int(行.get("mapId", 0)) == 我图 and 通道 + 1 == 我线),
		})
	成员 = 出


static func 加托盘(是申请: bool, 数据: Dictionary) -> void:
	## 托盘归 HUD 那侧（`邀请托盘.gd`）管。**不能走 `宿主`**：宿主只在开过页之后才有值，
	## 而邀请恰恰是"没开页"的时候最需要弹出来 ⇒ 直接按名字找托盘节点（全树唯一）。
	var 根 := Engine.get_main_loop() as SceneTree
	var 盘: Node = 根.root.find_child("邀请托盘", true, false) if 根 != null else null
	if 盘 == null:
		return
	盘.call("加队伍邀请", 是申请, 数据)


## 只发包、不弹窗（托盘那一格被点时由 `窗口管理` 弹完框再调它 —— 那时候没有 `宿主`）。
static func 答复邀请(队号值: int, 邀请人: String, 是: bool) -> void:
	if 是:
		_上行(3, 队号值)		# ACCEPT_INVITATION
	else:
		_上行(13, 邀请人)		# 拒邀请 = `120:13:<队长名>`


## 同上（申请那侧）。
static func 答复申请(申请人名: String, 是: bool) -> void:
	if 是:
		_上行(12, "%d:%s" % [队号, 申请人名])	# ACCEPT_APPLICATION
	else:
		_上行(14, 申请人名)		# 拒申请 = `120:14:<申请者名>`


static func 确认邀请(队号值: int, 邀请人: String) -> void:
	## `CuePane.__cueEventHandler` 的 `CueEvent.TROOP_INVITE` 那一支：
	##   `MDialog(TROOP_INVITE_YOU_TIP=「%1邀请你加入组队！」, OK|CANCEL)` ⇒ `__confirmJoinTroop`
	_确认(文案["邀请你"].replace("%1", 邀请人), func(是: bool) -> void:
		答复邀请(队号值, 邀请人, 是)
	)


static func 确认申请(_申请人号: int, 申请人名: String) -> void:
	## `CuePane.__confirmAcceptApplyTroop:105-118`：OK→ACCEPT_APPLY、CANCEL→REFUSE_APPLY，
	## 两个分支都带 `charName`。原版这里**不带申请人号**（只有名字）。
	_确认(文案["申请加入"].replace("%1", 申请人名), func(是: bool) -> void:
		答复申请(申请人名, 是)
	)


static func _上队伍(包: Dictionary) -> void:
	## `RelationShipHandler` 里每一条改完状态后都是「`updatePartyStatus` + `updataTroopStatus`」
	## 两步；这边合成一次：先换算（写 队号/队长号/队名/成员），再重绘。
	_换算队伍(包)
	上成员(成员)


static func _队伍建好(_state: Dictionary) -> void:
	## `onPartyCreated:95-125`：**这条回帧不带任何成员数据**（`handleAction_PARTY_CREATE:544-550`
	## 一个字段都不读）。队长的第一格完全是客户端**本地拼**的，family 是空串。
	var 身: Dictionary = (会话 as Node).get("player_stats")
	var 行 := {
		"id": 自己号, "name": 自己名, "face": int(身.get("face", 0)), "gender": int(身.get("gender", 1)),
		"jobId": int(身.get("job", 0)), "job": _职业名(int(身.get("job", 0))),
		"level": int(身.get("level", 1)), "family": "",
		"map_id": int(会话.call("自身地图号")) if _会(会话, "自身地图号") else 0,
		"队长": true, "在线": true, "hp": int(身.get("hp", 0)), "maxHp": int(身.get("max_hp", 0)),
		"mp": int(身.get("mp", 0)), "maxMp": int(身.get("max_mp", 0)), "在同图": true,
	}
	_换算队伍({"party_id": 0, "leader_id": 自己号, "party_name": "", "characters": []})
	队长号 = 自己号
	# :120 头像面板那颗队长标（原版 = charactorInfoPane.setTroopCaptainIcon）。
	# 原版头像面板常驻在 `UIMain2.content`、图标直接 addChild 到面板局部 (210,38)
	# （`CharactorInfoPane.as:278-292`）；我们的头像面板挂在地图场景里，可能还没建出来
	# ⇒ 这里先把状态记账 + 广播，面板 `_ready` 再自读一次兜底（切图重建时不丢）。
	队长标应显 = true
	_同步队长标()
	# :121-124 窗开着才 addSingleTroopData ⇒ 走 addSingleData 那条（自己造 members + 宣言）
	if 页 != null and is_instance_valid(页) and 成员.is_empty():
		队名 = "%s%s" % [自己名, 文案["的队伍"]]
		成员 = [行]
		上成员(成员)


static func _队伍进人(state: Dictionary) -> void:
	## `onPartyJoin:238-246`：名字不是自己 ⇒ 先流水字「X 加入队伍」，再重绘。
	var 名 := String(state.get("target_name", ""))
	_上队伍(state.get("party") as Dictionary)
	if 名 != 自己名:
		_提示("%s %s" % [名, 文案["加入队伍"]])


static func _队伍离人(state: Dictionary) -> void:
	## `onPartyLeave:218-236`：**targetId == 自己** ⇒ partyStatus=null、窗 removeTroopData、撤面板；
	## 否则 ⇒ 用带来的新 PartyStatus 重绘。
	var 号 := int(state.get("target_id", 0))
	if 号 == 自己号:
		_清队伍()
	else:
		_上队伍(state.get("party") as Dictionary)


static func _队伍踢人(state: Dictionary) -> void:
	## `onPartyExpel:259-277`：被踢的是自己 ⇒ 清；否则重绘。
	## 「你已经被队长踢出队伍」那句在 `TroopWindow2.showKickTip:207-210`，**只有被踢侧才弹**。
	var 号 := int(state.get("target_id", 0))
	if 号 == 自己号:
		_清队伍()
		_提示(文案["被踢"])
	else:
		_上队伍(state.get("party") as Dictionary)


static func _队伍解散(_state: Dictionary) -> void:
	## `onPartyDisband:248-257`：窗清 + 面板撤 + partyStatus=null。原版这句**没有提示**。
	_清队伍()


static func _清队伍() -> void:
	_换算队伍({})
	成员 = []
	队名 = ""
	选格 = -1
	格字典 = {}
	队伍面板脚本.清()
	队长标应显 = false
	_同步队长标()
	上成员(成员)


static func _队伍改名帧(state: Dictionary) -> void:
	## `Client.onUpdatePartyName:9766-9777`：写 `partyStatus.partyName`，窗开着 ⇒ `updateManifesto`
	## （`updateManifesto:500-504` = 塞文字 + **再刷一次按钮使能**）。
	队名 = String(state.get("party_name", ""))
	if 页 != null and is_instance_valid(页):
		(页.get_node("内容区/我的队伍/宣言输入") as LineEdit).text = 队名
		使能按钮()
	队伍面板脚本.上成员(排过序())


static func _队伍移交(state: Dictionary) -> void:
	## `onPartyChangeLeader:36-62`，五步顺序照搬：
	## leaderId 先改 → 流水字「X成为队长」→ 窗 changeTroopCaptain → 面板 changeTroopCaptain
	## → 自己是不是新队长决定头像那颗标加还是摘。
	var 新 := int(state.get("target_id", 0))
	队长号 = 新
	var 名 := ""
	for 行 in 成员:
		if int((行 as Dictionary).get("id", 0)) == 新:
			名 = String((行 as Dictionary).get("name", ""))
			break
	if 名 != "":
		_提示(_填(文案["成为队长"], 名))
	_换队长格(新)
	if 页 != null and is_instance_valid(页):
		画选中底()
		使能按钮()
		for i in 6:
			var 格: Control = 页.get_node("内容区/我的队伍/成员格%d" % (i + 1)) as Control
			if i < 成员.size():
				塞一格(格, 成员[i])
	队伍面板脚本.换队长(新)
	队长标应显 = (新 == 自己号)
	_同步队长标()


static func _队伍邀请(state: Dictionary) -> void:
	## `onPartyInvite:196-210`：**不在队里** 且 勾了自动接受 ⇒ 直接 `120:3`，画面无感；
	## 否则进托盘（按 troopId 去重），点开才弹确认。
	var 队 := int(state.get("party_id", 0))
	var 人 := String(state.get("inviter_name", ""))
	if not 在队(自己号) and 自动接受邀请:
		_上行(3, 队)
		return
	## 原版这条是「进托盘（按 troopId 去重）→ 点开托盘格才弹 `TROOP_INVITE_YOU_TIP`」
	## （`CueManage.addMsg(CueGird.TYPE_TEAM_INVITE, …)` ⇒ 点格 ⇒ `CuePane.__cueEventHandler`）。
	加托盘(false, {"troopId": 队, "captainName": 人})


static func _入队申请(state: Dictionary) -> void:
	## `Client.onPartyApplication:6900-6913`：**只有自己是队长**才处理；
	## 勾了自动接受申请 ⇒ 直接 `120:12:<partyId>:<charName>`；否则进托盘（按 partyCharId 去重）。
	if not 是队长号(自己号):
		return
	var 名 := String(state.get("applicant_name", ""))
	if 自动接受申请:
		_上行(12, "%d:%s" % [队号, 名])
		return
	加托盘(true, {"partyCharId": int(state.get("applicant_id", 0)), "partyCharName": 名})


static func _附近队帧(state: Dictionary) -> void:
	## `Client.onShowPartiesOnMap:4472+`：每条 PartyStatus 先 `getLeaderData(leaderId, characters)`，
	## **找不到队长那一行就整条丢掉**；`averageLevel = floor(Σlevel / count)`；
	## `members` 每项只有 `{id,name,level,job}`。
	附近队 = []
	for 包 in (state.get("parties", []) as Array):
		var 员: Array = (包.get("characters", []) as Array)
		var 长: Dictionary = {}
		for 行 in 员:
			if int((行 as Dictionary).get("partyCharId", 0)) == int(包.get("leader_id", 0)):
				长 = 行
				break
		if 长.is_empty():
			continue			# :2842 `if(_loc5_)` —— 没队长 ⇒ 这条不进列表
		var 总 := 0
		var 简: Array = []
		for 行 in 员:
			var 人: Dictionary = 行
			总 += int(人.get("level", 0))
			简.append({"id": int(人.get("partyCharId", 0)), "name": String(人.get("partyCharName", "")),
					"level": int(人.get("level", 0)), "jobId": int(人.get("jobId", 0)),
					"job": _职业名(int(人.get("jobId", 0)))})
		if 员.size() > 0:
			附近队.append({"troopId": int(包.get("party_id", 0)), "leaderId": int(包.get("leader_id", 0)),
					"leaderName": String(长.get("partyCharName", "")),
					"averageLevel": int(floor(float(总) / float(员.size()))),
					"manifesto": String(包.get("party_name", "")), "members": 简})
	选中队 = -1
	队页序 = 0
	画附近队伍()
	if 附近队.is_empty():
		_提示(文案["附近没队"])		# TroopWindow2.setNearTroopsData:380-390


static func 附近人帧(名单: Array) -> void:
	## `Client.onCharSearchResult:4009-4057` 的 searchId==3 那一支：字段名是
	## `{charId, channelId, jobId, charLevel, charName, banghuiName, charTitle}`（**照原样**）。
	附近人 = 名单
	搜中 = []
	人页序 = 0
	选人行 = -1
	画附近玩家()
	if 名单.is_empty():
		_提示(文案["附近没人"])		# TroopWindow2.setNearCharsData:132-142


## ══════════════ 增量更新（等级 / 换图）══════════════
static func 改等级(角色号: int, 等级: int) -> void:
	## `MyTroopPane.updateTroopMemLevel:392-399`：查 `_dataDic[id]` ⇒ **只改那一格文字**，
	## 不重建整页；同一步再转给面板（`TroopWindow2:300-307`）。
	if not 格字典.has(角色号):
		return
	var 格序 := int(格字典[角色号])
	if 格序 >= 成员.size():
		return
	(成员[格序] as Dictionary)["level"] = 等级
	if 页 != null and is_instance_valid(页):
		var 格: Control = 页.get_node("内容区/我的队伍/成员格%d" % (格序 + 1)) as Control
		(格.get_node("等级") as Label).text = "%s：%d" % [文案["等级字"], 等级]
	队伍面板脚本.改等级(角色号, 等级)


static func 换图(角色号: int, 图号: int) -> void:
	## `updateTroopMemMap:401-408` 同一条路：只改「【图名】」那一行。
	if not 格字典.has(角色号):
		return
	var 格序 := int(格字典[角色号])
	if 格序 >= 成员.size():
		return
	(成员[格序] as Dictionary)["map_id"] = 图号
	if 页 != null and is_instance_valid(页):
		var 格: Control = 页.get_node("内容区/我的队伍/成员格%d" % (格序 + 1)) as Control
		(格.get_node("地图") as Label).text = "【%s】" % _图名(图号)
	队伍面板脚本.改图(角色号, 图号)


static func 改在同图(角色号: int, 在: bool) -> void:
	## `TroopHPPane.updateMemStatus:82-89` ⇒ 面板那侧灰化条件与成员格**不同**
	## （`:113/:120` 是 `!isInSameMap || !isOnline`）。成员格只看在线。
	for 行 in 成员:
		if int((行 as Dictionary).get("id", 0)) == 角色号:
			(行 as Dictionary)["在同图"] = 在
			break
	队伍面板脚本.改状态(角色号, 在)


static func 置副本(在: bool) -> void:
	## 原版没有任何调用点能点亮它（`refreshCopyState` 0 处消费）⇒ 这边只留给门做分支覆盖。
	副本中 = 在
	使能按钮()


## ══════════════ 小工具 ══════════════
static func _上行(动作: int, 值 = "") -> void:
	## `发件箱` 只给门看：本函数每发一条都记一笔，**与后端在不在无关**
	## （后端是桩时也能断言"点了这颗钮到底发了哪一串"）。
	发件箱.append([动作, str(值)])
	if 后端 == null:
		return
	后端.call("request_party", 动作, 值)


static func 上行(动作: int, 值 = "", 号: int = 120) -> bool:
	## 只给门用的出口（断言"点这颗钮实际发出哪一串字节"）。`号` 留 1282 那一族用。
	if 后端 == null:
		return false
	if 号 == 1282:
		return bool(后端.call("request_char_search", String(值), 1, 动作))
	return bool(后端.call("request_party", 动作, 值))


static func _提示(文本: String) -> void:
	if 宿主 != null and 宿主.has_method("_通知"):
		宿主.call("_通知", 文本)


static func _确认(文本: String, 回调: Callable) -> void:
	## 原版是 `MDialog.showMessageDialog(..., MDialog.OK | MDialog.CANCEL)` ⇒ 双钮。
	## ⚠ **不能只靠 `宿主`**：托盘那一格被点时，玩家很可能**从没开过组队页** ⇒ `宿主` 是 null，
	##   以前这里就静默什么都不做（实机症状：点托盘图标零反应）。
	##   宿主在 ⇒ 走它那条（`弹出双钮确认`，与页面内那颗钮同一套）；宿主不在 ⇒ 自己在
	##   根视口上铺一层全屏 Control 当遮罩，再用同一只 `输入确认弹`。
	if 宿主 != null and is_instance_valid(宿主):
		宿主.call("弹出双钮确认", 文本, "确定",
			func(_勾: Variant) -> void: 回调.call(true),
			"取消", func(_勾: Variant) -> void: 回调.call(false), "")
		return
	var 树 := Engine.get_main_loop() as SceneTree
	if 树 == null:
		return
	## ⚠ 层号必须**和工程自己的模态弹窗同一层**。实测（`场景/界面/窗口管理.tscn`）：
	##   HUD 110、头像面板 300、**模态弹窗 400**。我前一版自造了个 128 ⇒ 还是在 400 底下，
	##   弹窗建出来了玩家依旧一个像素看不见（2026-10-25 实机"点了没弹窗"第二次）。
	##   ⇒ 直接复用 `模态确认弹层`（工程已验证能看见的那层）；找不到才自建 400。
	var 层 := 树.root.find_child("模态确认弹层", true, false) as CanvasLayer
	var 自建层 := false
	if 层 == null:
		层 = CanvasLayer.new()
		层.name = "队伍确认层"
		层.layer = 400
		树.root.add_child(层)
		自建层 = true
	var 遮 := Control.new()
	遮.name = "队伍确认遮罩"
	遮.mouse_filter = Control.MOUSE_FILTER_STOP
	层.add_child(遮)
	## ⚠ 光 `set_anchors_preset` **不够**：`家族弹窗.弹出` 是按遮罩**当时的 size** 摆位的，
	##   而 Control 刚进树时 size 还是 0 ⇒ 弹窗被摆到 (0,0)、大半在屏外（像素证据里那张
	##   "左上角露出一角『申请』"就是这么来的）。所以必须**先把 size 钉成视口尺寸**再建弹窗。
	遮.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮.position = Vector2.ZERO
	遮.size = Vector2(树.root.size)
	输入确认弹脚本.弹双钮(遮, 文本, "确定", "取消", "", func(钮: Variant) -> void:
		回调.call(钮 == 1)
		if is_instance_valid(遮):
			遮.queue_free()
		if 自建层 and is_instance_valid(层):
			层.queue_free()
	)


static func _填(模板: String, 值: String) -> String:
	## AS3 `CN.replaceString(模板, ...)` = 依次替换 `%1 %2 …`
	return 模板.replace("%1", 值)


static func _有(节: Object, 键: String) -> bool:
	return 节 != null and (键 in 节)


static func _会(节: Node, 方法名: String) -> bool:
	return 节 != null and 节.has_method(方法名)


static func _职业名(号: int) -> String:
	## `JobTool.getJobString(jobId)` 的等价件：本工程职业名的唯一真值在 `脚本/单例/职业.gd`。
	return 职业表.取(号)


static func _图名(号: int) -> String:
	## `StringTool.getMapString(mapId)`：本工程有一份地图索引
	var 表 := 加载地图索引()
	return String(表.get(str(号), 表.get(号, str(号))))


static var _地图索引: Dictionary = {}


static func 加载地图索引() -> Dictionary:
	if not _地图索引.is_empty():
		return _地图索引
	var 路 := "res://数据/地图索引.json"
	if FileAccess.file_exists(路):
		var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(路))
		if 解 is Dictionary:
			_地图索引 = 解
	return _地图索引
